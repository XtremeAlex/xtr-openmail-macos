import Foundation

/// Politica aziendale dell'app, letta dalle preferenze (anche imposte via MDM con un
/// profilo di configurazione sul dominio dell'app).
///
/// Perche' in MsgKit: e' logica pura (nessuna UI), quindi si prova con XCTest; l'app la
/// costruisce da `UserDefaults` e la passa al parser e alla vista.
public struct MsgPolicy: Equatable, Sendable {

    /// Chiavi delle preferenze (documentate nel README, sezione "Distribuzione aziendale").
    public enum Key {
        public static let maxFileSizeMB = "MaxFileSizeMB"
        public static let disableAttachmentExport = "DisableAttachmentExport"
        public static let disableFolderExport = "DisableFolderExport"
    }

    /// Limiti accettati per `MaxFileSizeMB`: sotto 1 MB nessun .msg reale si aprirebbe,
    /// oltre 1 GB il file letto in memoria metterebbe a rischio il Mac.
    public static let allowedSizeMB: ClosedRange<Int> = 1...1024
    public static let defaultSizeMB = Int(CompoundFileReader.maxFileSize / (1024 * 1024))

    public var maxFileSizeMB: Int
    public var attachmentExportAllowed: Bool
    public var folderExportAllowed: Bool

    public init(maxFileSizeMB: Int = MsgPolicy.defaultSizeMB, attachmentExportAllowed: Bool = true,
                folderExportAllowed: Bool = true) {
        self.maxFileSizeMB = min(max(maxFileSizeMB, Self.allowedSizeMB.lowerBound), Self.allowedSizeMB.upperBound)
        self.attachmentExportAllowed = attachmentExportAllowed
        self.folderExportAllowed = folderExportAllowed
    }

    public var maxFileSizeBytes: Int64 { Int64(maxFileSizeMB) * 1024 * 1024 }

    /// Costruzione tollerante da un dizionario di preferenze: valori mancanti o di tipo
    /// errato ricadono sui default invece di bloccare l'avvio.
    public static func from(_ values: [String: Any]) -> MsgPolicy {
        let size: Int
        switch values[Key.maxFileSizeMB] {
        case let n as Int: size = n
        case let n as NSNumber: size = n.intValue
        case let s as String: size = Int(s.trimmingCharacters(in: .whitespaces)) ?? defaultSizeMB
        default: size = defaultSizeMB
        }
        return MsgPolicy(maxFileSizeMB: size,
                         attachmentExportAllowed: !bool(values[Key.disableAttachmentExport]),
                         folderExportAllowed: !bool(values[Key.disableFolderExport]))
    }

    /// Politica corrente da `UserDefaults` (MDM compreso).
    public static func current(_ defaults: UserDefaults = .standard) -> MsgPolicy {
        from(defaults.dictionaryRepresentation())
    }

    private static func bool(_ value: Any?) -> Bool {
        switch value {
        case let b as Bool: return b
        case let n as NSNumber: return n.boolValue
        case let s as String: return ["1", "true", "yes", "si"].contains(s.lowercased())
        default: return false
        }
    }
}
