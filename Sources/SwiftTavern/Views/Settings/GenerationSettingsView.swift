import SwiftUI

/// Generation parameter controls (temperature, top_p, etc.)
struct GenerationSettingsView: View {
    @Binding var params: GenerationParameters

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Max Tokens
            VStack(alignment: .leading) {
                HStack {
                    Text("Max Tokens")
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                    TextField("", value: Binding(
                        get: { params.maxTokens },
                        set: { params.maxTokens = max(1, min(1_000_000, $0)) }
                    ), format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 90)
                    .font(.system(size: 12))
                    .multilineTextAlignment(.trailing)
                }
                Slider(value: .init(
                    get: { Double(params.maxTokens) },
                    set: { params.maxTokens = Int($0) }
                ), in: 1...1_000_000, step: 1)
            }

            // Temperature
            parameterSlider("Temperature", value: $params.temperature, range: 0...2, step: 0.01, decimals: 2)

            // Top P
            parameterSlider("Top P", value: $params.topP, range: 0...1, step: 0.01, decimals: 2)

            // Top K
            intParameterSlider("Top K", value: Binding(
                get: { params.topK },
                set: { params.topK = $0 }
            ), range: 0...500, step: 1)

            // Frequency Penalty
            parameterSlider("Frequency Penalty", value: $params.frequencyPenalty, range: -2...2, step: 0.01, decimals: 2)

            // Presence Penalty
            parameterSlider("Presence Penalty", value: $params.presencePenalty, range: -2...2, step: 0.01, decimals: 2)

            // Repetition Penalty
            parameterSlider("Repetition Penalty", value: $params.repetitionPenalty, range: 1...2, step: 0.01, decimals: 2)

            // Stream toggle
            Toggle("Stream Response", isOn: $params.streamResponse)

            // Reset button
            HStack {
                Spacer()
                Button("Reset to Defaults") {
                    params = .default
                }
                .controlSize(.small)
            }
        }
    }

    @ViewBuilder
    private func parameterSlider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double, decimals: Int) -> some View {
        VStack(alignment: .leading) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                Spacer()
                TextField("", value: value, format: .number.precision(.fractionLength(decimals)))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 70)
                    .font(.system(size: 12))
                    .multilineTextAlignment(.trailing)
                    .onChange(of: value.wrappedValue) { _, newVal in
                        // Clamp to range
                        if newVal < range.lowerBound { value.wrappedValue = range.lowerBound }
                        if newVal > range.upperBound { value.wrappedValue = range.upperBound }
                    }
            }
            Slider(value: value, in: range, step: step)
        }
    }

    @ViewBuilder
    private func intParameterSlider(_ title: String, value: Binding<Int>, range: ClosedRange<Int>, step: Int) -> some View {
        VStack(alignment: .leading) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                Spacer()
                TextField("", value: Binding(
                    get: { value.wrappedValue },
                    set: { value.wrappedValue = max(range.lowerBound, min(range.upperBound, $0)) }
                ), format: .number)
                .textFieldStyle(.roundedBorder)
                .frame(width: 70)
                .font(.system(size: 12))
                .multilineTextAlignment(.trailing)
            }
            Slider(value: .init(
                get: { Double(value.wrappedValue) },
                set: { value.wrappedValue = Int($0) }
            ), in: Double(range.lowerBound)...Double(range.upperBound), step: Double(step))
        }
    }
}
