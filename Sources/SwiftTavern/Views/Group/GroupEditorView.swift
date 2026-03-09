import SwiftUI

/// Create or edit a group chat
struct GroupEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let appState: AppState
    let groupChatVM: GroupChatViewModel

    @State private var groupName = ""
    @State private var selectedMembers: Set<String> = []
    @State private var activationStrategy: GroupActivationStrategy = .natural

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New Group Chat")
                .font(.title2)

            TextField("Group Name", text: $groupName)
                .textFieldStyle(.roundedBorder)

            // Activation strategy
            Picker("Turn Order", selection: $activationStrategy) {
                ForEach(GroupActivationStrategy.allCases, id: \.self) { strategy in
                    Text(strategy.displayName).tag(strategy)
                }
            }

            // Character selection
            Text("Select Members")
                .font(.headline)

            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(appState.characters) { character in
                        HStack {
                            AvatarImageView(imageData: character.avatarData, name: character.card.data.name, size: 28)
                            Text(character.card.data.name)
                                .font(.system(size: 13))
                            Spacer()

                            if selectedMembers.contains(character.filename) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.accentColor)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectedMembers.contains(character.filename) {
                                selectedMembers.remove(character.filename)
                            } else {
                                selectedMembers.insert(character.filename)
                            }
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                    }
                }
            }
            .frame(maxHeight: 300)
            .background(Color(.controlBackgroundColor))
            .cornerRadius(8)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Create Group") {
                    groupChatVM.createGroup(
                        name: groupName,
                        members: Array(selectedMembers)
                    )
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(groupName.isEmpty || selectedMembers.count < 2)
            }
        }
        .padding(20)
        .frame(minWidth: 400, minHeight: 500)
    }
}
