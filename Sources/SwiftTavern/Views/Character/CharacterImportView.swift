import SwiftUI
import UniformTypeIdentifiers

/// File importer wrapper for character PNG cards
struct CharacterImportView: ViewModifier {
    @Binding var isPresented: Bool
    let onImport: (URL) -> Void

    func body(content: Content) -> some View {
        content
            .fileImporter(
                isPresented: $isPresented,
                allowedContentTypes: [.png],
                allowsMultipleSelection: false
            ) { result in
                if case .success(let urls) = result, let url = urls.first {
                    onImport(url)
                }
            }
    }
}

extension View {
    func characterImporter(isPresented: Binding<Bool>, onImport: @escaping (URL) -> Void) -> some View {
        modifier(CharacterImportView(isPresented: isPresented, onImport: onImport))
    }
}
