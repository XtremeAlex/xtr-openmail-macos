import Foundation
import MsgKit
import OSLog
import UniformTypeIdentifiers

/// Stato osservabile della UI: gestisce apertura, parsing ed export dei .msg.
@MainActor
final class MessageViewModel: ObservableObject {
    @Published var message: MsgMessage?
    @Published var fileName: String = ""
    @Published var errorText: String?
    /// Esito dell'ultima operazione riuscita (export), mostrato come callout verde.
    @Published var noticeText: String?
    @Published var isLoading = false
    @Published var isExporting = false

    /// Log unificato di sistema (Console.app, `log stream --predicate 'subsystem == ...'`).
    /// Perche': in azienda il supporto deve poter diagnosticare senza chiedere il file.
    /// Nomi file e percorsi sono `.private`: non compaiono nei log raccolti da MDM.
    private let log = Logger(subsystem: "com.xtremealex.openmail", category: "message")

    /// Evita che un'apertura lenta sovrascriva il risultato di una successiva.
    private var openGeneration = 0

    /// Politica aziendale (limite dimensione, export consentiti), anche impostata via MDM.
    let policy: MsgPolicy

    init(policy: MsgPolicy = .current()) {
        self.policy = policy
        log.info("Politica: limite \(policy.maxFileSizeMB) MB, allegati \(policy.attachmentExportAllowed ? "si" : "no"), cartella \(policy.folderExportAllowed ? "si" : "no")")
    }

    func open(url: URL) {
        isLoading = true
        errorText = nil
        noticeText = nil
        openGeneration += 1
        let generation = openGeneration
        log.info("Apertura file \(url.lastPathComponent, privacy: .private)")

        // Il parsing gira fuori dal main thread: un .msg con molti allegati non blocca la UI.
        let maxBytes = policy.maxFileSizeBytes
        Task.detached(priority: .userInitiated) {
            let didAccess = url.startAccessingSecurityScopedResource()
            defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
            let result = Result { try MsgParser.parse(url: url, maxFileSize: maxBytes) }
            await MainActor.run { [weak self] in
                guard let self, generation == self.openGeneration else { return }
                switch result {
                case .success(let parsed):
                    self.message = parsed
                    self.fileName = url.lastPathComponent
                    self.log.info("File aperto: \(parsed.attachments.count) allegati")
                case .failure(let error):
                    self.message = nil
                    self.fileName = ""
                    self.errorText = "\(error)"
                    // .private: gli errori di Foundation includono il percorso del file.
                    self.log.error("Apertura fallita: \(String(describing: error), privacy: .private)")
                }
                self.isLoading = false
            }
        }
    }

    func exportText(to url: URL) {
        guard let msg = message else { return }
        do {
            try Data(MsgExporter.plainText(msg).utf8).write(to: url, options: .atomic)
            noticeText = "Esportato \(url.lastPathComponent)"
        } catch {
            report("Export TXT fallito", error)
        }
    }

    func exportFolder(to directory: URL) {
        guard let msg = message else { return }
        guard policy.folderExportAllowed else {
            errorText = "Export della cartella disattivato dall'amministratore."
            return
        }
        let base = (fileName as NSString).deletingPathExtension
        isExporting = true
        errorText = nil
        noticeText = nil
        Task.detached(priority: .userInitiated) {
            let didAccess = directory.startAccessingSecurityScopedResource()
            defer { if didAccess { directory.stopAccessingSecurityScopedResource() } }
            let result = Result {
                try MsgExporter.exportFolder(msg, named: base.isEmpty ? "mail" : base, into: directory)
            }
            await MainActor.run { [weak self] in
                guard let self else { return }
                switch result {
                case .success(let folder):
                    self.noticeText = "Esportato in \(folder.lastPathComponent)"
                case .failure(let error):
                    self.report("Export cartella fallito", error)
                }
                self.isExporting = false
            }
        }
    }

    func saveAttachment(_ att: MsgAttachment, to url: URL) {
        guard policy.attachmentExportAllowed else {
            errorText = "Salvataggio degli allegati disattivato dall'amministratore."
            return
        }
        do {
            try MsgExporter.saveAttachment(att, to: url)
            noticeText = "Salvato \(url.lastPathComponent)"
        } catch {
            report("Salvataggio allegato fallito", error)
        }
    }

    func reportExportResult(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url): noticeText = "Esportato \(url.lastPathComponent)"
        case .failure(let error): report("Export TXT fallito", error)
        }
    }

    private func report(_ context: String, _ error: Error) {
        errorText = "\(context): \(error.localizedDescription)"
        log.error("\(context, privacy: .public): \(String(describing: error), privacy: .private)")
    }
}
