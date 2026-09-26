import Foundation

/// Esporta un MsgMessage in vari formati, equivalente a MsgProcessor del progetto Java.
public enum MsgExporter {

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
    @discardableResult
    public static func exportFolder(_ msg: MsgMessage, named baseName: String, into directory: URL) throws -> URL {
        let folder = directory.appendingPathComponent(baseName, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let txtURL = folder.appendingPathComponent("mail.txt")
        try plainText(msg).data(using: .utf8)?.write(to: txtURL)

        for att in msg.attachments {
            let safeName = att.fileName.isEmpty ? "allegato.bin" : att.fileName
            let attURL = folder.appendingPathComponent(safeName)
            try att.data.write(to: attURL)
        }
        return folder
    }

    /// Salva un singolo allegato su disco.
    public static func saveAttachment(_ att: MsgAttachment, to url: URL) throws {
        try att.data.write(to: url)
    }
}
