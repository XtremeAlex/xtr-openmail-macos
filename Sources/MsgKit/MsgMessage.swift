import Foundation

/// Un allegato estratto da un file .msg.
public struct MsgAttachment: Identifiable, Hashable, Sendable {
    public let id = UUID()
    public let fileName: String
    public let data: Data
    public var sizeDescription: String {
        ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)
    }
}

/// Rappresentazione di un messaggio Outlook .msg parsato.
public struct MsgMessage: Sendable {
    public var subject: String
    public var from: String
    public var to: String
    public var cc: String
    public var date: String
    public var body: String
    public var htmlBody: String?
    public var attachments: [MsgAttachment]

    public init(subject: String = "", from: String = "", to: String = "",
                cc: String = "", date: String = "", body: String = "",
                htmlBody: String? = nil, attachments: [MsgAttachment] = []) {
        self.subject = subject
        self.from = from
        self.to = to
        self.cc = cc
        self.date = date
        self.body = body
        self.htmlBody = htmlBody
        self.attachments = attachments
    }
}

/// Property tag MAPI usati (property ID a 16 bit).
enum MapiTag: String {
    case subject          = "0037"
    case senderName       = "0C1A"
    case senderEmail      = "0C1F"
    case displayTo        = "0E04"
    case displayCc        = "0E03"
    case body             = "1000"
    case bodyHtml         = "1013"
    case attachFilename   = "3707"   // long filename
    case attachFilenameS  = "3704"   // short filename
    case attachData       = "3701"   // attachment binary data
}

/// Property type MAPI (suffisso nello stream name).
enum MapiType: String {
    case string8   = "001E"   // PT_STRING8 (ANSI)
    case unicode   = "001F"   // PT_UNICODE (UTF-16LE)
    case binary    = "0102"   // PT_BINARY
}

/// Parser di alto livello: da un CompoundFileReader produce un MsgMessage.
public enum MsgParser {

    public enum ParseError: Error, CustomStringConvertible {
        case notMsg(String)
        public var description: String {
            switch self { case .notMsg(let m): return m }
        }
    }

    public static func parse(url: URL, maxFileSize: Int64 = CompoundFileReader.maxFileSize) throws -> MsgMessage {
        let reader = try CompoundFileReader(url: url, maxFileSize: maxFileSize)
        return parse(reader: reader)
    }

    public static func parse(data: Data) throws -> MsgMessage {
        let reader = try CompoundFileReader(data: data)
        return parse(reader: reader)
    }

    static func parse(reader: CompoundFileReader) -> MsgMessage {
        var msg = MsgMessage()

        msg.subject = readString(reader, tag: .subject) ?? ""
        let senderName = readString(reader, tag: .senderName) ?? ""
        let senderEmail = readString(reader, tag: .senderEmail) ?? ""
        msg.from = [senderName, senderEmail.isEmpty ? "" : "<\(senderEmail)>"]
            .filter { !$0.isEmpty }.joined(separator: " ")
        msg.to = readString(reader, tag: .displayTo) ?? ""
        msg.cc = readString(reader, tag: .displayCc) ?? ""
        msg.body = readString(reader, tag: .body) ?? ""
        msg.htmlBody = readHtml(reader)
        msg.attachments = readAttachments(reader)
        return msg
    }

    // MARK: - Helpers

    /// Prova prima unicode (001F), poi ANSI (001E).
    private static func readString(_ reader: CompoundFileReader, tag: MapiTag) -> String? {
        let uniName = "__substg1.0_\(tag.rawValue)\(MapiType.unicode.rawValue)"
        if let e = reader.directory.first(where: { $0.name == uniName }) {
            let d = reader.readStream(e)
            return String(data: d, encoding: .utf16LittleEndian)?.trimmingNulls()
        }
        let ansiName = "__substg1.0_\(tag.rawValue)\(MapiType.string8.rawValue)"
        if let e = reader.directory.first(where: { $0.name == ansiName }) {
            let d = reader.readStream(e)
            return String(data: d, encoding: .windowsCP1252)?.trimmingNulls()
                ?? String(data: d, encoding: .utf8)?.trimmingNulls()
        }
        return nil
    }

    private static func readHtml(_ reader: CompoundFileReader) -> String? {
        let binName = "__substg1.0_\(MapiTag.bodyHtml.rawValue)\(MapiType.binary.rawValue)"
        if let e = reader.directory.first(where: { $0.name == binName }) {
            let d = reader.readStream(e)
            return String(data: d, encoding: .utf8) ?? String(data: d, encoding: .windowsCP1252)
        }
        return nil
    }

    private static func readAttachments(_ reader: CompoundFileReader) -> [MsgAttachment] {
        var out: [MsgAttachment] = []
        // Gli allegati sono storage "__attach_version1.0_#NNNNNNNN".
        // Nel modello flat della directory cerchiamo gli stream dati/filename per prefisso.
        // Semplificazione: raccogliamo tutte le coppie filename+data trovate.
        let filenameLong = "__substg1.0_\(MapiTag.attachFilename.rawValue)"
        let filenameShort = "__substg1.0_\(MapiTag.attachFilenameS.rawValue)"
        let dataPrefix = "__substg1.0_\(MapiTag.attachData.rawValue)"

        let dataEntries = reader.directory.filter { $0.name.hasPrefix(dataPrefix) && $0.type == 2 }
        let nameEntries = reader.directory.filter {
            ($0.name.hasPrefix(filenameLong) || $0.name.hasPrefix(filenameShort)) && $0.type == 2
        }

        let names: [String] = nameEntries.compactMap {
            let d = reader.readStream($0)
            return String(data: d, encoding: .utf16LittleEndian)?.trimmingNulls()
                ?? String(data: d, encoding: .windowsCP1252)?.trimmingNulls()
        }

        for (i, entry) in dataEntries.enumerated() {
            let bytes = reader.readStream(entry)
            guard !bytes.isEmpty else { continue }
            let name = i < names.count ? names[i] : "allegato-\(i + 1).bin"
            out.append(MsgAttachment(fileName: name, data: bytes))
        }
        return out
    }
}

private extension String {
    func trimmingNulls() -> String {
        return replacingOccurrences(of: "\u{0}", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension String.Encoding {
    /// Fallback per testo legacy ANSI. isoLatin1 e sempre disponibile e copre
    /// la gran parte dei caratteri Windows-1252 usati nelle mail occidentali.
    static let windowsCP1252: String.Encoding = .isoLatin1
}
