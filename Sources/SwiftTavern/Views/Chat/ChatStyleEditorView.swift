import SwiftUI

/// Sheet for editing chat message text styling (colors, font size)
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

                    // Quoted text color
                    colorPicker(
                        title: "Quoted Text Color",
                        description: "Color for text in \"double quotes\" (dialogue)",
                        color: $chatStyle.quotedTextColor
                    )

                    // Action text color
                    colorPicker(
                        title: "Action/Emote Color",
                        description: "Color for text in *asterisks* (actions, emotes)",
                        color: $chatStyle.italicActionColor
                    )

                    // Narrative text color
                    colorPicker(
                        title: "Narrative Text Color",
                        description: "Color for regular narrative text",
                        color: $chatStyle.narrativeColor
                    )

                    Divider()

                    // Preview
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Preview")
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Dialogue (Quoted Text)")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.secondary)
                                MarkdownTextView(
                                    text: "\"Hey, I was wondering when you'd show up.\"",
                                    chatStyle: chatStyle
                                )
                                .font(.system(size: chatStyle.fontSize))
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Actions (Italic/Emote)")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.secondary)
                                MarkdownTextView(
                                    text: "*She leans against the doorframe, arms crossed.*",
                                    chatStyle: chatStyle
                                )
                                .font(.system(size: chatStyle.fontSize))
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Narrative")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.secondary)
                                MarkdownTextView(
                                    text: "She smiles warmly and steps aside to let you in.",
                                    chatStyle: chatStyle
                                )
                                .font(.system(size: chatStyle.fontSize))
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Italic Speech (*\"...\"*)")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.secondary)
                                MarkdownTextView(
                                    text: "*\"I was wondering when you'd show up,\"* *she says with a grin.*",
                                    chatStyle: chatStyle
                                )
                                .font(.system(size: chatStyle.fontSize))
                            }

                            Divider()

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Combined Example")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.secondary)
                                MarkdownTextView(
                                    text: "*She leans against the doorframe, arms crossed.* \"Hey, I was wondering when you'd show up.\" She smiles warmly and steps aside to let you in.",
                                    chatStyle: chatStyle
                                )
                                .font(.system(size: chatStyle.fontSize))
                            }
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
        .frame(width: 500, height: 580)
    }

    @ViewBuilder
    private func colorPicker(title: String, description: String, color: Binding<CodableColor>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 12, weight: .medium))
                    Text(description)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                Spacer()
                ColorPicker("", selection: Binding(
                    get: { Color(red: color.wrappedValue.r, green: color.wrappedValue.g, blue: color.wrappedValue.b, opacity: color.wrappedValue.a) },
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
    }
}
