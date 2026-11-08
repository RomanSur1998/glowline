import Foundation

enum ShaderSource {
    static let averageZonesKernel = """
        #include <metal_stdlib>
        using namespace metal;

        constant uint THREADS_PER_ZONE = 64;

        kernel void averageZones(texture2d<float, access::read> frame [[texture(0)]],
                                  constant uint4 *zones [[buffer(0)]],
                                  constant float2 &params [[buffer(1)]],
                                  device float4 *output [[buffer(2)]],
                                  uint2 tgid [[threadgroup_position_in_grid]],
                                  uint tid [[thread_index_in_threadgroup]])
        {
            uint4 z = zones[tgid.x];
            uint width = z.z - z.x;
            uint height = z.w - z.y;
            uint totalPixels = width * height;

            float4 partial = float4(0.0);
            for (uint i = tid; i < totalPixels; i += THREADS_PER_ZONE) {
                uint2 coord = uint2(z.x + (i % width), z.y + (i / width));
                partial += frame.read(coord);
            }

            threadgroup float4 shared[THREADS_PER_ZONE];
            shared[tid] = partial;
            threadgroup_barrier(mem_flags::mem_threadgroup);
            for (uint stride = THREADS_PER_ZONE / 2; stride > 0; stride >>= 1) {
                if (tid < stride) {
                    shared[tid] += shared[tid + stride];
                }
                threadgroup_barrier(mem_flags::mem_threadgroup);
            }

            if (tid == 0) {
                float4 avg = totalPixels > 0 ? (shared[0] / float(totalPixels)) : float4(0.0);
                avg.rgb = pow(max(avg.rgb, float3(0.0)), float3(params.y));
                avg.rgb = clamp(avg.rgb * params.x, 0.0, 1.0);
                output[tgid.x] = avg;
            }
        }

        kernel void rowBrightness(texture2d<float, access::read> frame [[texture(0)]],
                                   device float *output [[buffer(0)]],
                                   uint gid [[thread_position_in_grid]])
        {
            uint width = frame.get_width();
            float sum = 0.0;
            for (uint x = 0; x < width; x++) {
                float4 c = frame.read(uint2(x, gid));
                sum += (c.r + c.g + c.b) / 3.0;
            }
            output[gid] = width > 0 ? sum / float(width) : 0.0;
        }
        """
}
