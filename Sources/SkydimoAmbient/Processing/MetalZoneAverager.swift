import CoreVideo
import Metal
import simd

enum MetalZoneAveragerError: Error {
    case noDevice
    case libraryCompileFailed(String)
    case textureCacheCreateFailed
    case pixelBufferTextureFailed
}

final class MetalZoneAverager {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipeline: MTLComputePipelineState
    private let rowBrightnessPipeline: MTLComputePipelineState
    private var textureCache: CVMetalTextureCache!

    private var zoneRectsBuffer: MTLBuffer?
    private var outputBuffer: MTLBuffer?
    private var cachedZoneCount = 0
    private var cachedFrameSize: (Int, Int) = (0, 0)
    private var builtContentBounds: (Int, Int) = (0, 0)

    private var rowBrightnessBuffer: MTLBuffer?
    private var cachedRowBufferHeight = 0
    private var smoothedContentTop: Float = 0
    private var smoothedContentBottom: Float = 0
    private var lastContentBounds: (Int, Int) = (0, 0)
    private var framesSinceLetterboxCheck = 0
    private let letterboxCheckInterval = 15

    let zoneLayout: ZoneLayout

    @Locked var brightness: Float
    @Locked var gammaExponent: Float
    @Locked var letterboxDetection: Bool
    @Locked var letterboxThreshold: Float

    init(zoneLayout: ZoneLayout, brightness: Double, gamma: Double, letterboxDetection: Bool = true, letterboxThreshold: Double = 0.06)
        throws
    {
        guard let device = MTLCreateSystemDefaultDevice() else { throw MetalZoneAveragerError.noDevice }
        self.device = device
        guard let queue = device.makeCommandQueue() else { throw MetalZoneAveragerError.noDevice }
        self.commandQueue = queue
        self.zoneLayout = zoneLayout
        self.brightness = Float(brightness)
        self.gammaExponent = gamma > 0 ? Float(gamma) : 1.0
        self.letterboxDetection = letterboxDetection
        self.letterboxThreshold = Float(letterboxThreshold)

        let library: MTLLibrary
        do {
            library = try device.makeLibrary(source: ShaderSource.averageZonesKernel, options: nil)
        } catch {
            throw MetalZoneAveragerError.libraryCompileFailed("\(error)")
        }
        guard let function = library.makeFunction(name: "averageZones") else {
            throw MetalZoneAveragerError.libraryCompileFailed("missing averageZones function")
        }
        self.pipeline = try device.makeComputePipelineState(function: function)
        guard let rowFunction = library.makeFunction(name: "rowBrightness") else {
            throw MetalZoneAveragerError.libraryCompileFailed("missing rowBrightness function")
        }
        self.rowBrightnessPipeline = try device.makeComputePipelineState(function: rowFunction)

        var cache: CVMetalTextureCache?
        let status = CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &cache)
        guard status == kCVReturnSuccess, let cache else { throw MetalZoneAveragerError.textureCacheCreateFailed }
        self.textureCache = cache
    }

    private func rebuildZoneBuffersIfNeeded(frameWidth: Int, frameHeight: Int, contentTop: Int, contentBottom: Int) {
        let contentBounds = (contentTop, contentBottom)
        guard cachedFrameSize != (frameWidth, frameHeight) || builtContentBounds != contentBounds else { return }
        cachedFrameSize = (frameWidth, frameHeight)
        builtContentBounds = contentBounds

        let rects = zoneLayout.buildZoneRects(
            frameWidth: frameWidth, frameHeight: frameHeight, contentTop: contentTop, contentBottom: contentBottom)
        cachedZoneCount = rects.count
        zoneRectsBuffer = rects.withUnsafeBufferPointer { ptr in
            device.makeBuffer(bytes: ptr.baseAddress!, length: ptr.count * MemoryLayout<SIMD4<UInt32>>.stride, options: .storageModeShared)
        }
        outputBuffer = device.makeBuffer(length: max(1, rects.count) * MemoryLayout<SIMD4<Float>>.stride, options: .storageModeShared)
    }

    private func detectContentBounds(texture: MTLTexture, frameHeight: Int) -> (Int, Int) {
        if cachedRowBufferHeight != frameHeight {
            cachedRowBufferHeight = frameHeight
            rowBrightnessBuffer = device.makeBuffer(length: frameHeight * MemoryLayout<Float>.stride, options: .storageModeShared)
            smoothedContentTop = 0
            smoothedContentBottom = Float(frameHeight)
        }
        guard let rowBrightnessBuffer,
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let encoder = commandBuffer.makeComputeCommandEncoder()
        else {
            return (Int(smoothedContentTop), Int(smoothedContentBottom))
        }

        encoder.setComputePipelineState(rowBrightnessPipeline)
        encoder.setTexture(texture, index: 0)
        encoder.setBuffer(rowBrightnessBuffer, offset: 0, index: 0)
        encoder.dispatchThreadgroups(
            MTLSize(width: frameHeight, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        let rows = rowBrightnessBuffer.contents().bindMemory(to: Float.self, capacity: frameHeight)
        let maxCrop = Int(Float(frameHeight) * 0.3)

        var rawTop = 0
        while rawTop < maxCrop && rows[rawTop] < letterboxThreshold { rawTop += 1 }

        var rawBottom = frameHeight
        while rawBottom > frameHeight - maxCrop && rows[rawBottom - 1] < letterboxThreshold { rawBottom -= 1 }

        guard rawBottom - rawTop > 1 else { return (Int(smoothedContentTop), Int(smoothedContentBottom)) }

        let smoothing: Float = 0.2
        smoothedContentTop += (Float(rawTop) - smoothedContentTop) * smoothing
        smoothedContentBottom += (Float(rawBottom) - smoothedContentBottom) * smoothing
        return (Int(smoothedContentTop.rounded()), Int(smoothedContentBottom.rounded()))
    }

    func averageZoneColors(pixelBuffer: CVPixelBuffer) -> [(UInt8, UInt8, UInt8)]? {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

        var cvTexture: CVMetalTexture?
        let status = CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault, textureCache, pixelBuffer, nil,
            .bgra8Unorm, width, height, 0, &cvTexture
        )
        guard status == kCVReturnSuccess, let cvTexture, let texture = CVMetalTextureGetTexture(cvTexture) else {
            return nil
        }

        let contentBounds: (Int, Int)
        if letterboxDetection {
            if framesSinceLetterboxCheck >= letterboxCheckInterval || cachedRowBufferHeight != height {
                framesSinceLetterboxCheck = 0
                contentBounds = detectContentBounds(texture: texture, frameHeight: height)
                lastContentBounds = contentBounds
            } else {
                contentBounds = lastContentBounds
            }
            framesSinceLetterboxCheck += 1
        } else {
            contentBounds = (0, height)
        }
        rebuildZoneBuffersIfNeeded(frameWidth: width, frameHeight: height, contentTop: contentBounds.0, contentBottom: contentBounds.1)
        guard cachedZoneCount > 0, let zoneRectsBuffer, let outputBuffer else { return nil }

        guard let commandBuffer = commandQueue.makeCommandBuffer(),
            let encoder = commandBuffer.makeComputeCommandEncoder()
        else { return nil }

        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(texture, index: 0)
        encoder.setBuffer(zoneRectsBuffer, offset: 0, index: 0)
        var params = SIMD2<Float>(brightness, gammaExponent)
        encoder.setBytes(&params, length: MemoryLayout<SIMD2<Float>>.stride, index: 1)
        encoder.setBuffer(outputBuffer, offset: 0, index: 2)

        let threadsPerThreadgroup = MTLSize(width: 64, height: 1, depth: 1)
        let threadgroupsPerGrid = MTLSize(width: cachedZoneCount, height: 1, depth: 1)
        encoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        CVMetalTextureCacheFlush(textureCache, 0)

        let resultPointer = outputBuffer.contents().bindMemory(to: SIMD4<Float>.self, capacity: cachedZoneCount)
        var colors: [(UInt8, UInt8, UInt8)] = []
        colors.reserveCapacity(cachedZoneCount)
        for i in 0..<cachedZoneCount {
            let c = resultPointer[i]
            colors.append(
                (
                    UInt8((c.x.isFinite ? c.x : 0) * 255.0 + 0.5),
                    UInt8((c.y.isFinite ? c.y : 0) * 255.0 + 0.5),
                    UInt8((c.z.isFinite ? c.z : 0) * 255.0 + 0.5)
                ))
        }
        return colors
    }
}
