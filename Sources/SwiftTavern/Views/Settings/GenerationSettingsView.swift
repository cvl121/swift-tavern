import SwiftUI

/// Generation parameter controls for LLM chat completion requests
struct GenerationSettingsView: View {
    @Binding var params: GenerationParameters

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // MARK: - Core Sampling

            Text("Core Sampling")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)

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
                ), in: 1...16384, step: 64)
                .accessibilityValue("\(params.maxTokens)")
            }

            // Context Size
            VStack(alignment: .leading) {
                HStack {
                    Text("Context Size")
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                    TextField("", value: Binding(
                        get: { params.contextSize },
                        set: { params.contextSize = max(512, min(1_000_000, $0)) }
                    ), format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 90)
                    .font(.system(size: 12))
                    .multilineTextAlignment(.trailing)
                }
                Slider(value: .init(
                    get: { Double(params.contextSize) },
                    set: { params.contextSize = Int($0) }
                ), in: 512...1_000_000, step: 512)
                .accessibilityValue("\(params.contextSize)")
                Text("Maximum total tokens (input + output) for the conversation context")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
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

            // Min P
            parameterSlider("Min P", value: $params.minP, range: 0...1, step: 0.01, decimals: 2,
                            hint: "Minimum probability threshold for token sampling")

            // Top A
            parameterSlider("Top A", value: $params.topA, range: 0...1, step: 0.01, decimals: 2,
                            hint: "Quadratic sampling threshold")

            // Typical P
            parameterSlider("Typical P", value: $params.typicalP, range: 0...1, step: 0.01, decimals: 2,
                            hint: "Locally typical sampling (1.0 = disabled)")

            // Tail Free Sampling
            parameterSlider("Tail Free Sampling", value: $params.tfs, range: 0...1, step: 0.01, decimals: 2,
                            hint: "Removes low-probability tail tokens (1.0 = disabled)")

            Divider()

            // MARK: - Penalties

            Text("Penalties")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)

            // Frequency Penalty
            parameterSlider("Frequency Penalty", value: $params.frequencyPenalty, range: -2...2, step: 0.01, decimals: 2)

            // Presence Penalty
            parameterSlider("Presence Penalty", value: $params.presencePenalty, range: -2...2, step: 0.01, decimals: 2)

            // Repetition Penalty
            parameterSlider("Repetition Penalty", value: $params.repetitionPenalty, range: 1...2, step: 0.01, decimals: 2)

            // Encoder Repetition Penalty
            parameterSlider("Encoder Rep. Penalty", value: $params.encoderRepetitionPenalty, range: 0.8...1.5, step: 0.01, decimals: 2,
                            hint: "Penalizes tokens from the input prompt (1.0 = disabled)")

            // No Repeat Ngram Size
            intParameterSlider("No Repeat Ngram Size", value: Binding(
                get: { params.noRepeatNgramSize },
                set: { params.noRepeatNgramSize = $0 }
            ), range: 0...64, step: 1, hint: "Prevents repeating N-gram sequences (0 = disabled)")

            Divider()

            // MARK: - Mirostat

            Text("Mirostat")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)

            intParameterSlider("Mirostat Mode", value: Binding(
                get: { params.mirostatMode },
                set: { params.mirostatMode = $0 }
            ), range: 0...2, step: 1, hint: "0 = disabled, 1 = Mirostat, 2 = Mirostat 2.0")

            if params.mirostatMode > 0 {
                parameterSlider("Mirostat Tau", value: $params.mirostatTau, range: 0...10, step: 0.1, decimals: 1,
                                hint: "Target entropy / surprise level")

                parameterSlider("Mirostat Eta", value: $params.mirostatEta, range: 0...1, step: 0.01, decimals: 2,
                                hint: "Learning rate")
            }

            Divider()

            // MARK: - Dynamic Temperature

            Text("Dynamic Temperature")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)

            Toggle("Enable Dynamic Temperature", isOn: $params.dynaTempEnabled)
                .font(.system(size: 12))

            if params.dynaTempEnabled {
                parameterSlider("Min Temp", value: $params.dynaTempLow, range: 0...2, step: 0.01, decimals: 2)
                parameterSlider("Max Temp", value: $params.dynaTempHigh, range: 0...2, step: 0.01, decimals: 2)
                parameterSlider("Exponent", value: $params.dynaTempExponent, range: 0...5, step: 0.1, decimals: 1)
            }

            Divider()

            // MARK: - Advanced

            Text("Advanced")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)

            // Min Length
            intParameterSlider("Min Length", value: Binding(
                get: { params.minLength },
                set: { params.minLength = $0 }
            ), range: 0...2000, step: 1, hint: "Minimum response tokens (0 = no minimum)")

            // Smoothing Factor
            parameterSlider("Smoothing Factor", value: $params.smoothingFactor, range: 0...10, step: 0.1, decimals: 1,
                            hint: "Quadratic smoothing (0 = disabled)")

            // Smoothing Curve
            parameterSlider("Smoothing Curve", value: $params.smoothingCurve, range: 0...10, step: 0.1, decimals: 1)

            // Seed
            VStack(alignment: .leading) {
                HStack {
                    Text("Seed")
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                    TextField("", value: $params.seedValue, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 90)
                        .font(.system(size: 12))
                        .multilineTextAlignment(.trailing)
                }
                Text("-1 = random")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            // Stream toggle
            Toggle("Stream Response", isOn: $params.streamResponse)
                .font(.system(size: 12))

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
    private func parameterSlider(
        _ title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        decimals: Int,
        hint: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
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
                        if newVal < range.lowerBound { value.wrappedValue = range.lowerBound }
                        if newVal > range.upperBound { value.wrappedValue = range.upperBound }
                    }
            }
            Slider(value: value, in: range, step: step)
                .accessibilityValue(String(format: "%.\(decimals)f", value.wrappedValue))
            if let hint = hint {
                Text(hint)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder
    private func intParameterSlider(
        _ title: String,
        value: Binding<Int>,
        range: ClosedRange<Int>,
        step: Int,
        hint: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
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
            .accessibilityValue("\(value.wrappedValue)")
            if let hint = hint {
                Text(hint)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
    }
}
