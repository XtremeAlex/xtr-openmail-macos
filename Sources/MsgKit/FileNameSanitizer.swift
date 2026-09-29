import Foundation

/// Normalizza i nomi file che arrivano dal contenuto del .msg (allegati, nome cartella).
///
/// Perche': il nome di un allegato e' un dato controllato da chi ha inviato la mail. Senza
/// pulizia un nome come `../../Library/LaunchAgents/x.plist` farebbe scrivere fuori dalla
/// cartella scelta (path traversal), e due allegati omonimi si sovrascriverebbero in silenzio.
public enum FileNameSanitizer {

    /// Lunghezza massima in byte UTF-8 di un componente di percorso su APFS/HFS+.
    static let maxBytes = 255

    /// Restituisce un nome di file singolo e sicuro (mai vuoto, mai un percorso).
    public static func sanitize(_ raw: String, fallback: String = "allegato.bin") -> String {
        // Solo l'ultimo componente: "/" e "\" (percorsi Windows negli allegati) sono separatori.
        let lastComponent = raw
            .split(whereSeparator: { $0 == "/" || $0 == "\\" })
            .last.map(String.init) ?? ""

        // Via caratteri di controllo e ":" (separatore storico di Finder).
        var cleaned = String(String.UnicodeScalarView(lastComponent.unicodeScalars.filter {
            !CharacterSet.controlCharacters.contains($0) && $0 != ":"
        }))
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        // Niente nomi nascosti o relativi (".", "..", ".bashrc"): il punto iniziale va tolto.
        while cleaned.hasPrefix(".") { cleaned.removeFirst() }
        cleaned = cleaned.trimmingCharacters(in: .whitespaces)

        if cleaned.isEmpty { cleaned = fallback }
        return truncate(cleaned)
    }

    /// Primo nome libero nella cartella: `nome.ext`, `nome (2).ext`, `nome (3).ext`, ...
    /// `taken` contiene i nomi gia' assegnati nella stessa esportazione (confronto
    /// senza distinzione di maiuscole, come il file system di default di macOS).
    public static func uniqueName(_ name: String, in directory: URL, taken: inout Set<String>,
                                  fileManager: FileManager = .default) -> String {
        let ext = (name as NSString).pathExtension
        let stem = (name as NSString).deletingPathExtension
        var candidate = name
        var n = 2
        while taken.contains(candidate.lowercased())
                || fileManager.fileExists(atPath: directory.appendingPathComponent(candidate).path) {
            let suffix = " (\(n))" + (ext.isEmpty ? "" : ".\(ext)")
            candidate = truncate(stem, reserving: suffix.utf8.count) + suffix
            n += 1
        }
        taken.insert(candidate.lowercased())
        return candidate
    }

    /// Tronca a `maxBytes` byte UTF-8 senza spezzare caratteri, preservando l'estensione.
    static func truncate(_ name: String, reserving extra: Int = 0) -> String {
        let limit = maxBytes - extra
        guard name.utf8.count > limit else { return name }
        let ext = extra == 0 ? (name as NSString).pathExtension : ""
        let tail = ext.isEmpty ? "" : "." + ext
        var stem = extra == 0 && !ext.isEmpty ? (name as NSString).deletingPathExtension : name
        while !stem.isEmpty && stem.utf8.count + tail.utf8.count > limit { stem.removeLast() }
        return stem + tail
    }
}
