import SwiftUI

/// Sheet for editing chat message text styling (colors, font size)
/// Organized by punctuation marker so users choose what each formatting type looks like
struct ChatStyleEditorView: View {
    @Binding var chatStyle: ChatStyle
    var hasConversationOverride: Bool = false
    var onResetToGlobal: (() -> Void)?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Chat Style")
                    .font(.title2.bold())
                if hasConversationOverride {
                    Text("(Custom)")
                        .font(.system(size: 12))
                        .foregroundColor(.accentColor)
                }
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if hasConversationOverride {
                        HStack(spacing: 8) {
                            Image(systemName: "paintbrush.pointed")
                                .foregroundColor(.accentColor)
                            Text("This conversation has custom styling. Changes here only affect this conversation.")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            Spacer()
                            Button("Reset to Global") {
                                onResetToGlobal?()
                            }
                            .controlSize(.small)
                            .buttonStyle(.bordered)
                        }
                        .padding(10)
                        .background(Color.accentColor.opacity(0.06))
                        .cornerRadius(8)
                    } else {
                        Text("Customize how chat message text is displayed. Changing style here creates a custom override for this conversation.")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }

                    // Font size
                    HStack {
                        Text("Font Size")
                            .font(.system(size: 12, weight: .medium))
                        Spacer()
                        TextField("", value: $chatStyle.fontSize, format: .number.precision(.fractionLength(0)))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 60)
                            .multilineTextAlignment(.trailing)
                    }
                    Slider(value: $chatStyle.fontSize, in: 10...24, step: 1)

                    Divider()

                    Text("Text Colors by Formatting")
                        .font(.headline)

                    Text("Pick a color for each type of punctuation. Use this to style speech, actions, thoughts, or narration however you like.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    // "Quoted text"
                    markerColorPicker(
                        marker: "\"Double Quotes\"",
                        example: "\"Like this.\"",
                        hint: "Speech / dialogue",
                        color: $chatStyle.quotedTextColor
                    )

                    // *Italic text*
                    markerColorPicker(
                        marker: "*Asterisks* (Italic)",
                        example: "*Like this.*",
                        hint: "Internal thinking / inner monologue",
                        color: $chatStyle.italicActionColor
                    )

                    // (Parenthesized text)
                    markerColorPicker(
                        marker: "(Parentheses)",
                        example: "(Like this.)",
                        hint: "OOC or side notes",
                        color: $chatStyle.thinkingColor
                    )

                    // Plain text
                    markerColorPicker(
                        marker: "Plain Text",
                        example: "Like this.",
                        hint: "Narration and actions",
                        color: $chatStyle.narrativeColor
                    )

                    Divider()

                    // Live preview
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Preview")
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 12) {
                            previewRow(
                                label: "Speech (\"Quotes\")",
                                text: "\"Hey, I was wondering when you'd show up.\""
                            )

                            previewRow(
                                label: "Thinking (*Asterisks*)",
                                text: "*I wonder if she noticed me staring...*"
                            )

                            previewRow(
                                label: "OOC ((Parentheses))",
                                text: "(Let's move to a different scene.)"
                            )

                            previewRow(
                                label: "Narration & Actions (Plain)",
                                text: "She leans against the doorframe, arms crossed, and smiles warmly."
                            )

                            Divider()

                            previewRow(
                                label: "Combined",
                                text: "She leans against the doorframe. \"Hey there.\" *I hope I look cool.* (OOC: nice scene!) She steps aside to let you in."
                            )
                        }
                        .padding(10)
                        .background(Color(.controlBackgroundColor))
                        .cornerRadius(12)
                    }

                    Divider()

                    // Reset
                    HStack {
                        Spacer()
                        Button("Reset to Defaults") {
                            chatStyle = .default
                        }
                        .controlSize(.small)
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 520, height: 700)
    }

    // MARK: - Marker Color Picker

    @ViewBuilder
    private func markerColorPicker(
        marker: String,
        example: String,
        hint: String,
        color: Binding<CodableColor>
    ) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(marker)
                    .font(.system(size: 12, weight: .semibold))
                Text(hint)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            Spacer()
            // Inline mini-preview swatch
            Text(example)
                .font(.system(size: 11))
                .foregroundColor(color.wrappedValue.color)
                .lineLimit(1)
            ColorPicker("", selection: Binding(
                get: {
                    Color(red: color.wrappedValue.r, green: color.wrappedValue.g,
                          blue: color.wrappedValue.b, opacity: color.wrappedValue.a)
                },
                set: { newColor in
                    if let components = NSColor(newColor).usingColorSpace(.sRGB) {
                        color.wrappedValue = CodableColor(
                            r: Double(components.redComponent),
                            g: Double(components.greenComponent),
                            b: Double(components.blueComponent),
                            a: Double(components.alphaComponent)
                        )
                    }
                }
            ))
            .labelsHidden()
        }
    }

    // MARK: - Preview Row

    @ViewBuilder
    private func previewRow(label: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
            MarkdownTextView(
                text: text,
                chatStyle: chatStyle
            )
            .font(.system(size: chatStyle.fontSize))
        }
    }
}
