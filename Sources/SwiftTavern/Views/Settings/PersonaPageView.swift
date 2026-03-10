import SwiftUI

/// Full-page Personas view shown in the detail pane
struct PersonaPageView: View {
    @Bindable var personaVM: PersonaViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Personas")
                    .font(.title2.bold())

                Spacer()

                Button(action: { personaVM.showingImporter = true }) {
                    Label("Import", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button(action: { personaVM.exportAllPersonas() }) {
                    Label("Export All", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            Divider()

            ScrollView {
                PersonaSettingsView(viewModel: personaVM)
                    .padding(20)
            }
        }
    }
}
