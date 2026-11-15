import AppKit
import SwiftUI

struct PanelSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            DotMatrixText(text: title, dot: 2, spacing: 1, color: Theme.dim)
                .padding(.leading, 4)
            VStack(alignment: .leading, spacing: 16) {
                content
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.line, lineWidth: 1))
        }
    }
}

struct FieldLabel: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text.uppercased())
            .font(Theme.label)
            .tracking(1.2)
            .foregroundStyle(Theme.dim)
    }
}

struct FieldRow<Trailing: View>: View {
    let title: String
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(spacing: 12) {
            FieldLabel(title)
            Spacer(minLength: 8)
            trailing
        }
    }
}

struct DotSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let format: String

    private var fraction: Double {
        guard range.upperBound > range.lowerBound else { return 0 }
        return min(max((value - range.lowerBound) / (range.upperBound - range.lowerBound), 0), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                FieldLabel(title)
                Spacer()
                Text(String(format: format, value))
                    .font(Theme.value)
                    .monospacedDigit()
                    .foregroundStyle(Theme.text)
            }
            GeometryReader { geo in
                Canvas { context, size in
                    let pitch: CGFloat = 9
                    let count = max(Int(size.width / pitch), 2)
                    let gap = (size.width - 5) / CGFloat(count - 1)
                    let lit = Int((fraction * Double(count - 1)).rounded())
                    for i in 0..<count {
                        let isKnob = i == lit
                        let d: CGFloat = isKnob ? 9 : 5
                        let x = CGFloat(i) * gap + 2.5 - d / 2
                        let rect = CGRect(x: x, y: size.height / 2 - d / 2, width: d, height: d)
                        let color = isKnob ? Theme.accent : (i < lit ? Theme.text : Theme.dotOff)
                        context.fill(Path(ellipseIn: rect), with: .color(color))
                    }
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0).onChanged { drag in
                        let f = min(max(drag.location.x / max(geo.size.width, 1), 0), 1)
                        let raw = range.lowerBound + f * (range.upperBound - range.lowerBound)
                        let snapped = (raw / step).rounded() * step
                        value = min(max(snapped, range.lowerBound), range.upperBound)
                    }
                )
            }
            .frame(height: 12)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(String(format: format, value))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: value = min(value + step, range.upperBound)
            case .decrement: value = max(value - step, range.lowerBound)
            @unknown default: break
            }
        }
    }
}

struct DotToggle: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        FieldRow(title: title) {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule()
                    .fill(isOn ? Theme.text : Color.clear)
                    .overlay(Capsule().stroke(isOn ? Theme.text : Theme.dotOff, lineWidth: 1.5))
                Circle()
                    .fill(isOn ? Theme.accent : Theme.dim)
                    .frame(width: 10, height: 10)
                    .padding(.horizontal, 5)
            }
            .frame(width: 40, height: 22)
            .animation(.easeOut(duration: 0.15), value: isOn)
            .contentShape(Capsule())
            .onTapGesture { isOn.toggle() }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(isOn ? "On" : "Off")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { isOn.toggle() }
    }
}

struct DotMenu<Value: Hashable>: View {
    let title: String
    @Binding var selection: Value
    let options: [(value: Value, label: String)]

    private var currentLabel: String {
        options.first { $0.value == selection }?.label ?? "—"
    }

    var body: some View {
        FieldRow(title: title) {
            Menu {
                ForEach(options, id: \.value) { option in
                    Button(option.label) { selection = option.value }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(currentLabel)
                        .font(Theme.value)
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Theme.dim)
                }
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
    }
}

struct PillButton: View {
    let title: String
    var filled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title.uppercased())
                .font(Theme.label)
                .tracking(1.2)
                .foregroundStyle(filled ? Color.black : Theme.text)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Capsule().fill(filled ? Theme.text : Color.clear))
                .overlay(Capsule().stroke(filled ? Theme.text : Theme.dotOff, lineWidth: 1.5))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct CountStepper: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            FieldLabel(title)
            HStack(spacing: 10) {
                stepButton("minus", delta: -1)
                Text("\(Int(value))")
                    .font(Theme.large)
                    .monospacedDigit()
                    .foregroundStyle(Theme.text)
                    .frame(minWidth: 40)
                stepButton("plus", delta: 1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue("\(Int(value))")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: change(by: 1)
            case .decrement: change(by: -1)
            @unknown default: break
            }
        }
    }

    private func change(by delta: Double) {
        value = min(max(value + delta, range.lowerBound), range.upperBound)
    }

    private func stepButton(_ symbol: String, delta: Double) -> some View {
        Button {
            change(by: delta)
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Theme.text)
                .frame(width: 24, height: 24)
                .overlay(Circle().stroke(Theme.dotOff, lineWidth: 1.5))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

struct CornerPicker: View {
    @Binding var corner: Corner

    var body: some View {
        FieldRow(title: "LED #0 corner") {
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Theme.dotOff, lineWidth: 1.5)
                    .frame(width: 58, height: 34)
                ForEach(Corner.allCases, id: \.self) { c in
                    Circle()
                        .fill(c == corner ? Theme.accent : Theme.dim)
                        .frame(width: c == corner ? 11 : 7, height: c == corner ? 11 : 7)
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                        .onTapGesture { corner = c }
                        .offset(x: c == .topLeft || c == .bottomLeft ? -29 : 29, y: c == .topLeft || c == .topRight ? -17 : 17)
                        .accessibilityLabel(c.rawValue)
                }
            }
            .frame(width: 84, height: 56)
        }
    }
}
