import SwiftUI
import UniformTypeIdentifiers

/// Escolha de som: padrão, sons embutidos e áudios importados do aparelho. Tocar numa linha
/// toca uma prévia.
struct SoundPickerView: View {
    @Binding var soundID: String
    @Environment(\.palette) private var palette

    @State private var player = AlarmSoundPlayer()
    @State private var importing = false
    @State private var importedFiles: [String] = []
    @State private var errorMessage: String?

    private let catalog = SoundCatalog.shared

    var body: some View {
        List {
            Section("Sons do app") {
                row(id: SoundReference.systemDefault.id, title: "Padrão")
                ForEach(catalog.builtIn) { sound in
                    row(id: SoundReference.builtIn(sound.name).id, title: sound.displayName)
                }
            }

            Section {
                ForEach(importedFiles, id: \.self) { file in
                    row(id: SoundReference.imported(file).id,
                        title: catalog.displayName(for: .imported(file)))
                }
                .onDelete(perform: deleteImported)
                Button {
                    importing = true
                } label: {
                    Label("Importar áudio do aparelho", systemImage: "square.and.arrow.down")
                }
            } header: {
                Text("Importados")
            } footer: {
                Text("Arquivos de áudio (m4a, mp3, wav, caf). Eles ficam guardados só dentro do app.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(palette.background)
        .navigationTitle("Som")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(isPresented: $importing, allowedContentTypes: [.audio]) { result in
            switch result {
            case .success(let url):
                do {
                    let reference = try catalog.importSound(from: url)
                    refreshImported()
                    soundID = reference.id
                    preview(reference.id)
                } catch {
                    errorMessage = "Não foi possível importar este áudio."
                }
            case .failure:
                errorMessage = "Não foi possível abrir o arquivo."
            }
        }
        .alert("Erro", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .onAppear(perform: refreshImported)
        .onDisappear { player.stop() }
    }

    private func row(id: String, title: String) -> some View {
        Button {
            soundID = id
            preview(id)
        } label: {
            HStack {
                Text(title).foregroundStyle(.primary)
                Spacer()
                if soundID == id {
                    Image(systemName: "checkmark").foregroundStyle(palette.accent)
                }
            }
        }
        .listRowBackground(palette.surface)
    }

    private func preview(_ id: String) {
        player.start(soundID: id, fadeInSeconds: 0)
        Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            if soundID == id { player.stop() }
        }
    }

    private func refreshImported() {
        let dir = catalog.importedSoundsDirectory
        let files = (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
        importedFiles = files.filter { $0.contains("__") }.sorted()
    }

    private func deleteImported(at offsets: IndexSet) {
        for index in offsets {
            let file = importedFiles[index]
            let reference = SoundReference.imported(file)
            catalog.deleteImportedSound(reference)
            if soundID == reference.id { soundID = SoundReference.defaultID }
        }
        refreshImported()
    }
}
