import Foundation
import MsgKit
import UniformTypeIdentifiers

/// Stato osservabile della UI: gestisce apertura, parsing ed export dei .msg.
@MainActor
final class MessageViewModel: ObservableObject {
    @Published var message: MsgMessage?
    @Published var fileName: String = ""
    @Published var errorText: String?
    @Published var isLoading = false

    func open(url: URL) {
        isLoading = true
        errorText = nil
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
        do {
            let parsed = try MsgParser.parse(url: url)
            self.message = parsed
            self.fileName = url.lastPathComponent
        } catch {
            self.message = nil
            self.errorText = "\(error)"
        }
        isLoading = false
    }

    func exportText(to url: URL) {
        guard let msg = message else { return }
        do {
            try MsgExporter.plainText(msg).data(using: .utf8)?.write(to: url)
        } catch {
            errorText = "Export TXT fallito: \(error)"
        }
    }

    func exportFolder(to directory: URL) {
        guard let msg = message else { return }
        let base = (fileName as NSString).deletingPathExtension
        do {
            _ = try MsgExporter.exportFolder(msg, named: base.isEmpty ? "mail" : base, into: directory)
        } catch {
            errorText = "Export cartella fallito: \(error)"
        }
    }

    func saveAttachment(_ att: MsgAttachment, to url: URL) {
        do {
            try MsgExporter.saveAttachment(att, to: url)
        } catch {
            errorText = "Salvataggio allegato fallito: \(error)"
        }
    }
}
