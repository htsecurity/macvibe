import SwiftUI

/// A Control Center–style module: glass rounded rectangle with a symbol, value and caption.
struct Tile: View {
    let symbol: String
    let tint: Color
    let value: String
    let caption: String

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tint)
                .frame(height: 20)
                .contentTransition(.symbolEffect(.replace))
            Spacer(minLength: 8)
            Text(value)
                .font(.system(size: 21, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(caption)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, minHeight: 70, alignment: .leading)
        .padding(12)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
    }
}

/// A row in the Battery Care card: symbol, title, value and a stepper.
struct StepperRow: View {
    let symbol: String
    let title: String
    let value: Int
    let range: ClosedRange<Int>
    let step: Int
    let format: (Int) -> String
    let onChange: @MainActor @Sendable (Int) -> Void

    var body: some View {
        HStack(spacing: 10) {
            RowIcon(symbol: symbol)
            Text(title)
            Spacer(minLength: 8)
            Text(format(value))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
            Stepper(title, value: Binding(get: { value }, set: onChange), in: range, step: step)
                .labelsHidden()
                .controlSize(.small)
        }
        .font(.system(size: 12.5))
        .frame(minHeight: 30)
    }
}

struct RowIcon: View {
    let symbol: String

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 12, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(.secondary)
            .frame(width: 18)
    }
}

struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 6)
    }
}
