import SwiftUI
import MsgKit
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var vm = MessageViewModel()
    @State private var showingImporter = false
    @State private var showingTxtExporter = false

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingImporter = true
                } label: {
                    Label("Apri .msg", systemImage: "envelope.open")
                }
            }
        }
        .fileImporter(isPresented: $showingImporter,
                      allowedContentTypes: [msgType],
                      allowsMultipleSelection: false) { result in
            if case .success(let urls) = result, let url = urls.first {
                vm.open(url: url)
            }
        }
        .fileExporter(isPresented: $showingTxtExporter,
                      document: TextDocument(text: vm.message.map { MsgExporter.plainText($0) } ?? ""),
                      contentType: .plainText,
                      defaultFilename: exportBaseName) { result in
            // gestito dal document
            _ = result
        }
    }

    // MARK: - Sidebar (header)

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let msg = vm.message {
                Text(msg.subject.isEmpty ? "(senza oggetto)" : msg.subject)
                    .font(.headline)
                    .textSelection(.enabled)
                Divider()
                field("Da", msg.from)
                field("A", msg.to)
                if !msg.cc.isEmpty { field("CC", msg.cc) }
                if !msg.date.isEmpty { field("Data", msg.date) }

                if !msg.attachments.isEmpty {
                    Divider()
                    Text("Allegati (\(msg.attachments.count))").font(.subheadline).bold()
                    ForEach(msg.attachments) { att in
                        HStack {
                            Image(systemName: "paperclip")
                            VStack(alignment: .leading) {
                                Text(att.fileName).lineLimit(1)
                                Text(att.sizeDescription).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button {
                                saveAttachment(att)
                            } label: { Image(systemName: "square.and.arrow.down") }
                            .buttonStyle(.borderless)
                        }
                    }
                }
                Spacer()
                exportButtons
            } else {
                Text("Nessun messaggio aperto")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(minWidth: 260)
    }

    private var exportButtons: some View {
        VStack(spacing: 8) {
            Button {
                showingTxtExporter = true
            } label: {
                Label("Esporta come TXT", systemImage: "doc.text")
                    .frame(maxWidth: .infinity)
            }
            Button {
                exportFolder()
            } label: {
                Label("Esporta cartella (TXT + allegati)", systemImage: "folder")
                    .frame(maxWidth: .infinity)
            }
        }
        .disabled(vm.message == nil)
    }

    // MARK: - Detail (body)

    private var detail: some View {
        Group {
            if vm.isLoading {
                ProgressView("Apertura in corso...")
            } else if let err = vm.errorText {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle").font(.largeTitle).foregroundStyle(.orange)
                    Text("Impossibile aprire il file").font(.headline)
                    Text(err).font(.caption).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center).padding(.horizontal)
                }
            } else if let msg = vm.message {
                ScrollView {
                    Text(msg.body.isEmpty ? "(corpo vuoto)" : msg.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding()
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "envelope").font(.system(size: 48)).foregroundStyle(.secondary)
                    Text("Apri un file .msg di Outlook").font(.title3)
                    Text("Usa il pulsante in alto a destra o trascina un file qui.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onDrop(of: [msgType], isTargeted: nil) { providers in
                    handleDrop(providers)
                }
            }
        }
    }

    private func field(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value.isEmpty ? "-" : value).textSelection(.enabled)
        }
    }

    // MARK: - Actions

    private var exportBaseName: String {
        let base = (vm.fileName as NSString).deletingPathExtension
        return base.isEmpty ? "mail" : base
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        _ = provider.loadObject(ofClass: URL.self) { url, _ in
            if let url { DispatchQueue.main.async { vm.open(url: url) } }
        }
        return true
    }

    private func saveAttachment(_ att: MsgAttachment) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = att.fileName
        if panel.runModal() == .OK, let url = panel.url {
            vm.saveAttachment(att, to: url)
        }
    }

    private func exportFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.prompt = "Esporta qui"
        if panel.runModal() == .OK, let url = panel.url {
            vm.exportFolder(to: url)
        }
    }

    private var msgType: UTType {
        UTType(filenameExtension: "msg") ?? .data
    }
}

/// Document leggero per l'export TXT tramite fileExporter.
struct TextDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }
    var text: String
    init(text: String) { self.text = text }
    init(configuration: ReadConfiguration) throws {
        if let d = configuration.file.regularFileContents { text = String(data: d, encoding: .utf8) ?? "" }
        else { text = "" }
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: text.data(using: .utf8) ?? Data())
    }
}
