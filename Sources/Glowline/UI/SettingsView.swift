import AppKit
import SwiftUI

private let commonBaudRates = [115_200, 230_400, 460_800, 500_000, 921_600, 1_000_000, 2_000_000]

struct SettingsView: View {
    @ObservedObject var store: SettingsStore
    let onRestart: () -> Void

    var body: some View {
        ScrollView {
            SettingsContent(store: store, onRestart: onRestart)
        }
        .scrollIndicators(.never)
        .background(Theme.background)
        .preferredColorScheme(.dark)
        .tint(Theme.accent)
        .frame(width: 480, height: 780)
    }
}

struct SettingsContent: View {
    @ObservedObject var store: SettingsStore
    let onRestart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            header
            if store.restartRequired {
                restartBanner
            }
            StripPreview(store: store)
            modeSection
            outputSection
            if store.lightingMode == .screen {
                screenSection
            }
            connectionSection
            zonesSection
            Text(store.configPath)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Theme.dim.opacity(0.7))
                .textSelection(.enabled)
                .padding(.leading, 4)
        }
        .padding(.horizontal, 22)
        .padding(.top, 40)
        .padding(.bottom, 24)
    }

    private var header: some View {
        HStack(alignment: .center) {
            DotMatrixText(text: "GLOWLINE", dot: 3.5, spacing: 1.5)
            Spacer()
            HStack(spacing: 7) {
                Circle()
                    .fill(store.isConnected ? Theme.accent : Theme.dotOff)
                    .frame(width: 7, height: 7)
                Text(store.statusLine.uppercased())
                    .font(Theme.label)
                    .tracking(1)
                    .foregroundStyle(Theme.dim)
                    .lineLimit(1)
            }
        }
    }

    private var restartBanner: some View {
        HStack(spacing: 10) {
            Circle().fill(Theme.accent).frame(width: 8, height: 8)
            Text("RESTART TO APPLY")
                .font(Theme.label)
                .tracking(1.2)
                .foregroundStyle(Theme.text)
            Spacer()
            PillButton(title: "Restart", filled: true, action: onRestart)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.accent, lineWidth: 1.5))
    }

    private var modeSection: some View {
        PanelSection(title: "MODE") {
            HStack(spacing: 8) {
                ForEach(LightingMode.allCases, id: \.self) { mode in
                    ModeTile(mode: mode, isSelected: store.lightingMode == mode) {
                        store.lightingMode = mode
                    }
                }
            }
            if store.lightingMode.usesPrimaryColor {
                LEDColorField(title: store.lightingMode.usesSecondaryColor ? "Edge color" : "Color", color: $store.primaryColor)
            }
            if store.lightingMode.usesSecondaryColor {
                LEDColorField(title: "Center color", color: $store.secondaryColor)
            }
            if store.lightingMode.isAnimated {
                DotSlider(title: "Speed", value: $store.effectSpeed, range: 0.2...3.0, step: 0.1, format: "%.1f×")
            }
        }
    }

    private var outputSection: some View {
        PanelSection(title: "OUTPUT") {
            DotSlider(title: "Brightness", value: $store.brightness, range: 0.2...2.0, step: 0.05, format: "%.2f")
            DotSlider(title: "Gamma", value: $store.gamma, range: 0.5...3.0, step: 0.05, format: "%.2f")
        }
    }

    private var screenSection: some View {
        PanelSection(title: "SCREEN") {
            DotMenu(
                title: "Display", selection: $store.displayIndex,
                options: store.availableDisplays.map { (value: $0.index, label: $0.label) })
            DotSlider(title: "Capture width", value: $store.captureWidth, range: 96...960, step: 16, format: "%.0f px")
            DotSlider(title: "Frame rate", value: $store.targetFPS, range: 5...60, step: 1, format: "%.0f fps")
            DotToggle(title: "Skip letterbox bars", isOn: $store.letterboxDetection)
            if store.letterboxDetection {
                DotSlider(title: "Bar threshold", value: $store.letterboxThreshold, range: 0.01...0.3, step: 0.01, format: "%.2f")
            }
        }
    }

    private var connectionSection: some View {
        PanelSection(title: "CONNECTION") {
            DotMenu(
                title: "Serial port", selection: $store.serialPortOverride,
                options: [(value: "", label: "Auto-detect")] + store.availableSerialDevices.map { (value: $0.path, label: $0.path) })
            DotMenu(title: "Baud rate", selection: $store.baudRate, options: commonBaudRates.map { (value: $0, label: "\($0)") })
            DotToggle(title: "Fixed Ada header (Skydimo)", isOn: $store.fixedAdaHeader)
            if !store.fixedAdaHeader {
                DotMenu(
                    title: "Color order", selection: $store.colorOrder,
                    options: ColorOrder.allCases.map { (value: $0, label: $0.rawValue) })
            }
            HStack {
                Spacer()
                PillButton(title: "Refresh devices", action: store.refreshDeviceLists)
            }
        }
    }

    private var zonesSection: some View {
        PanelSection(title: "ZONES") {
            Grid(horizontalSpacing: 12, verticalSpacing: 16) {
                GridRow {
                    CountStepper(title: "Top", value: $store.zonesTop, range: 0...255)
                    CountStepper(title: "Right", value: $store.zonesRight, range: 0...255)
                }
                GridRow {
                    CountStepper(title: "Bottom", value: $store.zonesBottom, range: 0...255)
                    CountStepper(title: "Left", value: $store.zonesLeft, range: 0...255)
                }
            }
            CornerPicker(corner: $store.startCorner)
            DotToggle(title: "Clockwise", isOn: $store.clockwise)
            DotSlider(title: "Edge depth", value: $store.edgeDepthFraction, range: 0.05...0.4, step: 0.01, format: "%.2f")
        }
    }
}

private struct ModeTile: View {
    let mode: LightingMode
    let isSelected: Bool
    let action: () -> Void

    private var shortTitle: String {
        switch mode {
        case .screen: return "SCREEN"
        case .solid: return "SOLID"
        case .gradient: return "GRADIENT"
        case .rainbow: return "RAINBOW"
        case .breathing: return "BREATHE"
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ModeIcon(mode: mode, ink: isSelected ? .black : Theme.text)
                    .frame(width: 26, height: 26)
                Text(shortTitle)
                    .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                    .tracking(0.6)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(isSelected ? Color.black : Theme.dim)
            }
            .frame(maxWidth: .infinity, minHeight: 74)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(isSelected ? Theme.text : Theme.surfaceRaised))
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mode.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct ModeIcon: View {
    let mode: LightingMode
    let ink: Color

    var body: some View {
        Canvas { context, size in
            let n = 5
            let pitch = size.width / CGFloat(n)
            let d = pitch * 0.62
            for y in 0..<n {
                for x in 0..<n {
                    guard let color = dotColor(x: x, y: y, n: n) else { continue }
                    let rect = CGRect(
                        x: CGFloat(x) * pitch + (pitch - d) / 2, y: CGFloat(y) * pitch + (pitch - d) / 2, width: d, height: d)
                    context.fill(Path(ellipseIn: rect), with: .color(color))
                }
            }
        }
    }

    private func dotColor(x: Int, y: Int, n: Int) -> Color? {
        let edge = x == 0 || y == 0 || x == n - 1 || y == n - 1
        let corner = (x == 0 || x == n - 1) && (y == 0 || y == n - 1)
        switch mode {
        case .screen:
            return edge ? ink : nil
        case .solid:
            return corner ? nil : ink
        case .gradient:
            return ink.opacity(1 - Double(x) / Double(n))
        case .rainbow:
            let (r, g, b) = EffectRenderer.hueToRGB(Double(x + y) / Double(2 * n - 1) * 0.85)
            return Color(red: r, green: g, blue: b)
        case .breathing:
            let dx = Double(x - n / 2), dy = Double(y - n / 2)
            let distance = (dx * dx + dy * dy).squareRoot()
            return distance > 2.3 ? nil : ink.opacity(1 - distance / 3)
        }
    }
}

private struct StripPreview: View {
    @ObservedObject var store: SettingsStore

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
            Canvas { context, size in
                let points = store.previewPoints
                let colors = currentColors(time: timeline.date.timeIntervalSinceReferenceDate, count: points.count)
                let screenRect = CGRect(x: 0, y: 0, width: size.width, height: size.height).insetBy(dx: 34, dy: 24)
                let screenPath = Path(roundedRect: screenRect, cornerRadius: 6)
                context.stroke(screenPath, with: .color(Theme.line), lineWidth: 1.5)

                let ringRect = screenRect.insetBy(dx: -12, dy: -12)
                let dot: CGFloat = points.count > 120 ? 4 : 6
                for (index, point) in points.enumerated() {
                    let center = CGPoint(
                        x: ringRect.minX + point.x * ringRect.width, y: ringRect.minY + point.y * ringRect.height)
                    let color = colors[index]
                    if let color {
                        let glow = CGRect(x: center.x - dot * 1.6, y: center.y - dot * 1.6, width: dot * 3.2, height: dot * 3.2)
                        context.fill(Path(ellipseIn: glow), with: .color(color.opacity(0.18)))
                    }
                    let rect = CGRect(x: center.x - dot / 2, y: center.y - dot / 2, width: dot, height: dot)
                    context.fill(Path(ellipseIn: rect), with: .color(color ?? Theme.dotOff))
                }

                if let first = points.first {
                    let center = CGPoint(
                        x: ringRect.minX + first.x * ringRect.width, y: ringRect.minY + first.y * ringRect.height)
                    context.stroke(
                        Path(ellipseIn: CGRect(x: center.x - dot, y: center.y - dot, width: dot * 2, height: dot * 2)),
                        with: .color(Theme.text.opacity(0.6)), lineWidth: 1)
                }
            }
        }
        .frame(height: 190)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.line, lineWidth: 1))
        .accessibilityLabel("LED strip preview")
    }

    private func currentColors(time: TimeInterval, count: Int) -> [Color?] {
        if store.lightingMode == .screen {
            let live = store.liveColors.colors
            guard store.isConnected, live.count == count else { return Array(repeating: nil, count: count) }
            return live.map { Color(red: Double($0.0) / 255, green: Double($0.1) / 255, blue: Double($0.2) / 255) }
        }
        var parameters = store.currentConfig.effectParameters
        parameters.gamma = 1
        parameters.brightness = 1
        return EffectRenderer.colors(for: parameters, ledCount: count, time: time).map {
            Color(red: Double($0.0) / 255, green: Double($0.1) / 255, blue: Double($0.2) / 255)
        }
    }
}

private let colorPresets: [LEDColor] = [
    LEDColor(r: 255, g: 255, b: 255),
    LEDColor(r: 255, g: 180, b: 100),
    LEDColor(r: 255, g: 0, b: 0),
    LEDColor(r: 255, g: 122, b: 26),
    LEDColor(r: 255, g: 220, b: 0),
    LEDColor(r: 0, g: 255, b: 0),
    LEDColor(r: 0, g: 220, b: 255),
    LEDColor(r: 0, g: 60, b: 255),
    LEDColor(r: 150, g: 0, b: 255),
    LEDColor(r: 255, g: 0, b: 150),
]

private struct LEDColorField: View {
    let title: String
    @Binding var color: LEDColor
    @State private var text = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                FieldLabel(title)
                Spacer()
                VStack(spacing: 3) {
                    TextField("#RRGGBB", text: $text)
                        .textFieldStyle(.plain)
                        .font(Theme.value)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(LEDColor(text: text) == nil ? Theme.accent : Theme.text)
                        .frame(width: 110)
                        .onSubmit { text = color.hex }
                    Rectangle().fill(Theme.dotOff).frame(width: 110, height: 1)
                }
                ColorPicker("", selection: pickerBinding, supportsOpacity: false)
                    .labelsHidden()
            }
            HStack(spacing: 0) {
                ForEach(colorPresets, id: \.hex) { preset in
                    Button {
                        color = preset
                    } label: {
                        Circle()
                            .fill(swiftUIColor(preset))
                            .frame(width: 14, height: 14)
                            .padding(3)
                            .overlay(Circle().stroke(preset == color ? Theme.text : Color.clear, lineWidth: 1.5))
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(preset.hex)
                    .accessibilityLabel(preset.hex)
                }
            }
        }
        .onAppear { text = color.hex }
        .onChange(of: color) { newColor in
            if LEDColor(text: text) != newColor { text = newColor.hex }
        }
        .onChange(of: text) { newText in
            if let parsed = LEDColor(text: newText), parsed != color { color = parsed }
        }
    }

    private var pickerBinding: Binding<Color> {
        Binding(
            get: { swiftUIColor(color) },
            set: { newValue in
                guard let srgb = NSColor(newValue).usingColorSpace(.sRGB) else { return }
                func byte(_ v: CGFloat) -> UInt8 { UInt8((min(max(v, 0), 1) * 255).rounded()) }
                color = LEDColor(r: byte(srgb.redComponent), g: byte(srgb.greenComponent), b: byte(srgb.blueComponent))
            }
        )
    }

    private func swiftUIColor(_ c: LEDColor) -> Color {
        Color(.sRGB, red: Double(c.r) / 255, green: Double(c.g) / 255, blue: Double(c.b) / 255)
    }
}
