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
            }
            .padding(20)

            Divider()

            ScrollView {
                PersonaSettingsView(viewModel: personaVM)
                    .padding(20)
            }
        }
        .fileImporter(
            isPresented: $personaVM.showingImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                personaVM.importPersonas(from: url)
            }
        }
    }
}
