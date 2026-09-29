import Foundation

/// Esporta un MsgMessage in vari formati, equivalente a MsgProcessor del progetto Java.
public enum MsgExporter {

    public enum ExportError: Error, CustomStringConvertible {
        case outsideDestination(String)

        public var description: String {
            switch self {
            case .outsideDestination(let name):
                return "Nome file non ammesso (uscirebbe dalla cartella di destinazione): \(name)"
            }
        }
    }

    /// Rappresentazione testuale degli header + body.
    public static func plainText(_ msg: MsgMessage) -> String {
        var s = ""
        s += "Subject: \(msg.subject)\n"
        s += "From: \(msg.from)\n"
        s += "To: \(msg.to)\n"
        if !msg.cc.isEmpty { s += "CC: \(msg.cc)\n" }
        if !msg.date.isEmpty { s += "Date: \(msg.date)\n" }
        s += "\n"
        s += msg.body
        return s
    }

    /// Scrive mail.txt + allegati in una cartella dedicata (come processMsgFile in Java).
    ///
    /// Regole di sicurezza: nome cartella e nomi degli allegati passano da
    /// `FileNameSanitizer` (niente path traversal), i file esistenti non vengono mai
    /// sovrascritti (suffisso " (2)") e ogni scrittura e' atomica, cosi' un errore a meta'
    /// non lascia file troncati.
    @discardableResult
    public static func exportFolder(_ msg: MsgMessage, named baseName: String, into directory: URL,
                                    fileManager: FileManager = .default) throws -> URL {
        var takenInParent = Set<String>()
        let folderName = FileNameSanitizer.uniqueName(
            FileNameSanitizer.sanitize(baseName, fallback: "mail"), in: directory, taken: &takenInParent,
            fileManager: fileManager)
        let folder = directory.appendingPathComponent(folderName, isDirectory: true)
        try ensureInside(folder, root: directory, name: folderName)
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)

        var taken: Set<String> = ["mail.txt"]
        let txtURL = folder.appendingPathComponent("mail.txt")
        try Data(plainText(msg).utf8).write(to: txtURL, options: .atomic)

        for att in msg.attachments {
            let safe = FileNameSanitizer.uniqueName(FileNameSanitizer.sanitize(att.fileName), in: folder,
                                                    taken: &taken, fileManager: fileManager)
            let attURL = folder.appendingPathComponent(safe)
            try ensureInside(attURL, root: folder, name: att.fileName)
            try att.data.write(to: attURL, options: .atomic)
        }
        return folder
    }

    /// Salva un singolo allegato su disco (URL scelto dall'utente con il pannello di sistema).
    public static func saveAttachment(_ att: MsgAttachment, to url: URL) throws {
        try att.data.write(to: url, options: .atomic)
    }

    /// Difesa in profondita': anche dopo la sanitizzazione il percorso finale deve restare
    /// dentro la radice scelta dall'utente (confronto su percorsi standardizzati).
    static func ensureInside(_ url: URL, root: URL, name: String) throws {
        let rootPath = root.standardizedFileURL.path
        let path = url.standardizedFileURL.path
        let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
        guard path.hasPrefix(prefix) else { throw ExportError.outsideDestination(name) }
    }
}
