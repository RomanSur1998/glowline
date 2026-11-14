import AppKit
import SwiftUI

private let commonBaudRates = [115_200, 230_400, 460_800, 500_000, 921_600, 1_000_000, 2_000_000]

struct SettingsView: View {
    @ObservedObject var store: SettingsStore
    let onRestart: () -> Void

    var body: some View {
        Form {
            if store.restartRequired {
                Section {
                    HStack {
                        Label("Changes take effect after a restart", systemImage: "arrow.triangle.2.circlepath")
                            .foregroundStyle(.orange)
                        Spacer()
                        Button("Restart now", action: onRestart)
                    }
                }
            }

            Section("Mode") {
                Picker("Mode", selection: $store.lightingMode) {
                    ForEach(LightingMode.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                if store.lightingMode.usesPrimaryColor {
                    LEDColorField(title: store.lightingMode.usesSecondaryColor ? "Edge color" : "Color", color: $store.primaryColor)
                }
                if store.lightingMode.usesSecondaryColor {
                    LEDColorField(title: "Center color", color: $store.secondaryColor)
                }
                if store.lightingMode.isAnimated {
                    LabeledSlider(title: "Speed", value: $store.effectSpeed, range: 0.2...3.0, step: 0.1, format: "%.1f×")
                }
            }

            Section("Screen capture") {
                Picker("Display", selection: $store.displayIndex) {
                    ForEach(store.availableDisplays, id: \.index) { d in
                        Text(d.label).tag(d.index)
                    }
                }
                LabeledSlider(title: "Capture width", value: $store.captureWidth, range: 96...960, step: 16, format: "%.0f px")
                LabeledSlider(title: "Frame rate", value: $store.targetFPS, range: 5...60, step: 1, format: "%.0f fps")
            }

            Section("Connection (Adalight)") {
                Picker("Serial port", selection: $store.serialPortOverride) {
                    Text("Auto-detect").tag("")
                    ForEach(store.availableSerialDevices, id: \.path) { d in
                        Text(d.path).tag(d.path)
                    }
                }
                Picker("Baud rate", selection: $store.baudRate) {
                    ForEach(commonBaudRates, id: \.self) { rate in
                        Text("\(rate)").tag(rate)
                    }
                }
                Button("Refresh device list", action: store.refreshDeviceLists)
                Toggle("Fixed Ada header (Skydimo)", isOn: $store.fixedAdaHeader)
                Picker("Color order", selection: $store.colorOrder) {
                    ForEach(ColorOrder.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .disabled(store.fixedAdaHeader)
            }

            Section("LED zones") {
                LabeledSlider(title: "Top", value: $store.zonesTop, range: 0...100, step: 1, format: "%.0f")
                LabeledSlider(title: "Right", value: $store.zonesRight, range: 0...100, step: 1, format: "%.0f")
                LabeledSlider(title: "Bottom", value: $store.zonesBottom, range: 0...100, step: 1, format: "%.0f")
                LabeledSlider(title: "Left", value: $store.zonesLeft, range: 0...100, step: 1, format: "%.0f")
                Picker("Start corner (LED #0)", selection: $store.startCorner) {
                    ForEach(Corner.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                Toggle("Clockwise", isOn: $store.clockwise)
                LabeledSlider(title: "Edge depth", value: $store.edgeDepthFraction, range: 0.05...0.4, step: 0.01, format: "%.2f")
            }

            Section("Color") {
                LabeledSlider(title: "Brightness", value: $store.brightness, range: 0.2...2.0, step: 0.05, format: "%.2f")
                LabeledSlider(title: "Gamma", value: $store.gamma, range: 0.5...3.0, step: 0.05, format: "%.2f")
                Toggle("Detect letterbox bars", isOn: $store.letterboxDetection)
                LabeledSlider(title: "Letterbox threshold", value: $store.letterboxThreshold, range: 0.01...0.3, step: 0.01, format: "%.2f")
                    .disabled(!store.letterboxDetection)
            }

            Section {
                Text("Config: \(store.configPath)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 620)
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
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                Spacer()
                TextField("#RRGGBB or r,g,b", text: $text)
                    .textFieldStyle(.roundedBorder)
                    .font(.body.monospaced())
                    .frame(width: 130)
                    .foregroundStyle(LEDColor(text: text) == nil ? Color.red : Color.primary)
                    .onSubmit { text = color.hex }
                ColorPicker("", selection: pickerBinding, supportsOpacity: false)
                    .labelsHidden()
            }
            HStack(spacing: 6) {
                ForEach(colorPresets, id: \.hex) { preset in
                    Button {
                        color = preset
                    } label: {
                        Circle()
                            .fill(swiftUIColor(preset))
                            .frame(width: 18, height: 18)
                            .overlay(
                                Circle().stroke(
                                    preset == color ? Color.accentColor : Color.secondary.opacity(0.4), lineWidth: preset == color ? 2 : 1))
                    }
                    .buttonStyle(.plain)
                    .help(preset.hex)
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

private struct LabeledSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let format: String

    var body: some View {
        HStack {
            Text(title)
            Slider(value: $value, in: range, step: step)
            Text(String(format: format, value))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .trailing)
        }
    }
}
