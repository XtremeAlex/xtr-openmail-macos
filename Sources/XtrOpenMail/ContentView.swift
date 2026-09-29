import SwiftUI
import MsgKit
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var vm: MessageViewModel
    @State private var showingImporter = false
    @State private var showingTxtExporter = false
    @State private var dropTargeted = false

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 280, ideal: 320)
        } detail: {
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.bg)
        }
        .tint(Theme.accent)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                BrandMark(name: "openmail")
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingImporter = true
                } label: {
                    Label("Apri .msg", systemImage: "envelope.open")
                }
                // ⌘O e' definito nel menu File (un solo punto, niente scorciatoie in conflitto).
                .help("Apri un file .msg di Outlook (⌘O)")
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
            vm.reportExportResult(result)
        }
        .onReceive(NotificationCenter.default.publisher(for: .openMsgRequested)) { _ in
            showingImporter = true
        }
    }

    // MARK: - Sidebar (header)

    private var sidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.s4) {
                if let msg = vm.message {
                    VStack(alignment: .leading, spacing: Theme.s2) {
                        MonoLabel("Oggetto", color: Theme.accentText)
                        Text(msg.subject.isEmpty ? "(senza oggetto)" : msg.subject)
                            .font(Theme.heading(17))
                            .foregroundStyle(Theme.text)
                            .textSelection(.enabled)
                    }

                    VStack(alignment: .leading, spacing: Theme.s3) {
                        field("Da", msg.from)
                        field("A", msg.to)
                        if !msg.cc.isEmpty { field("CC", msg.cc) }
                        if !msg.date.isEmpty { field("Data", msg.date) }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card(padding: Theme.s4)

                    if !msg.attachments.isEmpty { attachments(msg.attachments) }

                    exportButtons
                } else {
                    VStack(alignment: .leading, spacing: Theme.s2) {
                        MonoLabel("Nessun messaggio")
                        Text("Apri un file .msg per vederne intestazioni e allegati.")
                            .font(.callout)
                            .foregroundStyle(Theme.textMuted)
                    }
                }
                TrustPill(text: "Solo locale · nessun server")
                    .help("Il file viene letto solo sul Mac: nessuna connessione di rete.")
            }
            .padding(Theme.s4)
        }
        .background(Theme.bgAlt)
    }

    private func attachments(_ list: [MsgAttachment]) -> some View {
        VStack(alignment: .leading, spacing: Theme.s2) {
            HStack {
                MonoLabel("Allegati")
                Badge(text: "\(list.count)", accent: true)
            }
            VStack(spacing: 0) {
                ForEach(Array(list.enumerated()), id: \.element.id) { index, att in
                    HStack(spacing: Theme.s3) {
                        Image(systemName: "paperclip").foregroundStyle(Theme.accentText)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(att.fileName.isEmpty ? "(senza nome)" : att.fileName)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .foregroundStyle(Theme.text)
                            Text(att.sizeDescription).font(Theme.mono(10.5)).foregroundStyle(Theme.textMuted)
                        }
                        Spacer()
                        Button {
                            saveAttachment(att)
                        } label: { Image(systemName: "square.and.arrow.down") }
                        .buttonStyle(.borderless)
                        .foregroundStyle(Theme.text)
                        .help("Salva allegato")
                        .accessibilityLabel("Salva \(att.fileName)")
                    }
                    .padding(.vertical, Theme.s2)
                    .padding(.horizontal, Theme.s3)
                    .background(index.isMultiple(of: 2) ? Color.clear : Theme.text.opacity(0.025))
                    if index < list.count - 1 { Divider().overlay(Theme.border) }
                }
            }
            .background(Theme.bgAlt, in: RoundedRectangle(cornerRadius: Theme.radiusLarge))
            .overlay(RoundedRectangle(cornerRadius: Theme.radiusLarge).strokeBorder(Theme.border))
        }
    }

    private var exportButtons: some View {
        VStack(spacing: Theme.s2) {
            Button {
                showingTxtExporter = true
            } label: {
                Label("Esporta TXT", systemImage: "doc.text").frame(maxWidth: .infinity)
            }
            .buttonStyle(XtrButtonStyle(kind: .ghost))
            .keyboardShortcut("e", modifiers: [.command, .shift])

            Button {
                exportFolder()
            } label: {
                Label(vm.isExporting ? "Esportazione..." : "Esporta cartella", systemImage: "folder")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(XtrButtonStyle(kind: .primary, isLoading: vm.isExporting))
            .disabled(vm.isExporting)
            .accessibilityHint("Crea una cartella con mail.txt e tutti gli allegati")
        }
        .disabled(vm.message == nil)
    }

    // MARK: - Detail (body)

    @ViewBuilder
    private var detail: some View {
        if vm.isLoading {
            VStack(spacing: Theme.s4) {
                ProgressView().controlSize(.large)
                MonoLabel("Apertura in corso")
            }
        } else if vm.message == nil, let err = vm.errorText {
            VStack(spacing: Theme.s4) {
                Callout(kind: .alert) {
                    MonoLabel("Impossibile aprire il file", color: Theme.accentText)
                    Text(err).font(.callout).foregroundStyle(Theme.text).textSelection(.enabled)
                }
                .frame(maxWidth: 520)
                Button("Apri un altro file") { showingImporter = true }
                    .buttonStyle(XtrButtonStyle(kind: .ghost))
            }
            .padding(Theme.s6)
            .dropDestination(msgType: msgType, targeted: $dropTargeted, open: vm.open(url:))
        } else if let msg = vm.message {
            VStack(alignment: .leading, spacing: 0) {
                if let notice = vm.noticeText {
                    Callout(kind: .ok) { Text(notice).font(.callout).foregroundStyle(Theme.text) }
                        .padding([.horizontal, .top], Theme.s4)
                }
                if let err = vm.errorText {
                    Callout(kind: .alert) { Text(err).font(.callout).foregroundStyle(Theme.text) }
                        .padding([.horizontal, .top], Theme.s4)
                }
                ScrollView {
                    Text(msg.body.isEmpty ? "(corpo vuoto)" : msg.body)
                        .font(.body)
                        .foregroundStyle(Theme.text)
                        .lineSpacing(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding(Theme.s5)
                }
            }
            .dropDestination(msgType: msgType, targeted: $dropTargeted, open: vm.open(url:))
        } else {
            emptyState
        }
    }

    private var emptyState: some View {
        VStack(spacing: Theme.s4) {
            MonoLabel("Visualizzatore .msg", color: Theme.accentText)
            Text("Apri un file di Outlook")
                .font(Theme.heading(26))
                .foregroundStyle(Theme.text)
            Text("Trascina qui un file .msg o usa ⌘O. Il file resta sul tuo Mac.")
                .foregroundStyle(Theme.textMuted)
            Button {
                showingImporter = true
            } label: {
                Label("Apri .msg", systemImage: "envelope.open")
            }
            .buttonStyle(XtrButtonStyle(kind: .primary))
            .padding(.top, Theme.s2)
        }
        .padding(Theme.s6)
        .frame(maxWidth: 560)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusLarge)
                .strokeBorder(dropTargeted ? Theme.accent : Theme.border,
                              style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
        )
        .background(dropTargeted ? Theme.accentDim : Color.clear,
                    in: RoundedRectangle(cornerRadius: Theme.radiusLarge))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .dropDestination(msgType: msgType, targeted: $dropTargeted, open: vm.open(url:))
    }

    private func field(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            MonoLabel(label)
            Text(value.isEmpty ? "-" : value)
                .foregroundStyle(Theme.text)
                .textSelection(.enabled)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Actions

    private var exportBaseName: String {
        let base = (vm.fileName as NSString).deletingPathExtension
        return base.isEmpty ? "mail" : base
    }

    private func saveAttachment(_ att: MsgAttachment) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = FileNameSanitizer.sanitize(att.fileName)
        if panel.runModal() == .OK, let url = panel.url {
            vm.saveAttachment(att, to: url)
        }
    }

    private func exportFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Esporta qui"
        if panel.runModal() == .OK, let url = panel.url {
            vm.exportFolder(to: url)
        }
    }

    private var msgType: UTType {
        UTType(filenameExtension: "msg") ?? .data
    }
}

private extension View {
    /// Drag & drop di un .msg su qualunque stato della finestra (non solo quello vuoto).
    func dropDestination(msgType: UTType, targeted: Binding<Bool>,
                         open: @escaping @MainActor (URL) -> Void) -> some View {
        onDrop(of: [.fileURL], isTargeted: targeted) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url, url.pathExtension.lowercased() == "msg" else { return }
                DispatchQueue.main.async { open(url) }
            }
            return true
        }
    }
}

extension Notification.Name {
    /// Comando di menu "Apri..." inoltrato alla finestra attiva.
    static let openMsgRequested = Notification.Name("com.xtremealex.openmail.openRequested")
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
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}
