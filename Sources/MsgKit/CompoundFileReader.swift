import Foundation

/// Lettore minimale del formato Compound File Binary (CFB / OLE2),
/// il contenitore usato dai file .msg di Outlook.
///
/// Implementa solo cio che serve per navigare le directory e leggere gli stream:
/// header, FAT, mini-FAT, directory entries. Non supporta la scrittura.
public struct CompoundFileReader {

    public enum CFBError: Error, CustomStringConvertible {
        case tooSmall
        case badSignature
        case corrupted(String)
        case tooLarge(Int64)

        public var description: String {
            switch self {
            case .tooSmall: return "File troppo piccolo per essere un Compound File."
            case .badSignature: return "Firma CFB non valida (non e un file .msg valido)."
            case .corrupted(let m): return "File CFB corrotto: \(m)"
            case .tooLarge(let bytes):
                let size = ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
                return "File troppo grande (\(size)): il limite e' \(ByteCountFormatter.string(fromByteCount: CompoundFileReader.maxFileSize, countStyle: .file))."
            }
        }
    }

    /// Una entry della directory (storage o stream).
    public struct DirectoryEntry {
        public let name: String
        public let type: UInt8          // 1 = storage, 2 = stream, 5 = root
        public let startSector: UInt32
        public let size: UInt64
        public let leftSibling: UInt32
        public let rightSibling: UInt32
        public let child: UInt32
    }

    private let data: Data
    private let sectorSize: Int
    private let miniSectorSize: Int
    private let miniStreamCutoff: Int
    private var fat: [UInt32] = []
    private var miniFat: [UInt32] = []
    /// Mini-stream della root letto una sola volta: prima veniva riletto per ogni stream
    /// piccolo (proprieta', nomi allegati), con costo quadratico sui messaggi grandi.
    private var miniStream = Data()
    public private(set) var directory: [DirectoryEntry] = []

    private static let endOfChain: UInt32 = 0xFFFFFFFE

    /// Limite di dimensione per i file aperti da disco. Perche': il file viene letto tutto in
    /// memoria e un .msg reale supera raramente qualche decina di MB (Outlook/Exchange
    /// limitano gli allegati); un file enorme o malevolo non deve poter esaurire la RAM.
    public static let maxFileSize: Int64 = 256 * 1024 * 1024
    private static let freeSector: UInt32 = 0xFFFFFFFF

    public init(data: Data) throws {
        guard data.count >= 512 else { throw CFBError.tooSmall }
        // Firma CFB: D0 CF 11 E0 A1 B1 1A E1
        let sig: [UInt8] = [0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1]
        for i in 0..<8 where data[i] != sig[i] {
            throw CFBError.badSignature
        }
        self.data = data

        // Valori ammessi da [MS-CFB] 2.2: settori da 512 (v3) o 4096 byte (v4), mini-settori
        // da 64. Un header alterato con shift arbitrari produrrebbe dimensioni 0 o enormi e
        // cicli con range invalidi: meglio rifiutare subito il file come corrotto.
        let sectorShift = data.readUInt16(at: 30)
        guard sectorShift == 9 || sectorShift == 12 else {
            throw CFBError.corrupted("dimensione settore non valida (shift \(sectorShift))")
        }
        self.sectorSize = 1 << Int(sectorShift)
        let miniShift = data.readUInt16(at: 32)
        guard miniShift == 6 else {
            throw CFBError.corrupted("dimensione mini-settore non valida (shift \(miniShift))")
        }
        self.miniSectorSize = 1 << Int(miniShift)
        self.miniStreamCutoff = Int(data.readUInt32(at: 56))

        try buildFAT()
        try buildDirectory()
        try buildMiniFAT()
        miniStream = rootMiniStreamData()
    }

    public init(url: URL) throws {
        let values = try url.resourceValues(forKeys: [.fileSizeKey])
        if let size = values.fileSize, Int64(size) > Self.maxFileSize {
            throw CFBError.tooLarge(Int64(size))
        }
        // mappedIfSafe: il sistema pagina il file su richiesta invece di copiarlo tutto.
        try self.init(data: try Data(contentsOf: url, options: .mappedIfSafe))
    }

    // MARK: - FAT

    private func sectorOffset(_ sector: UInt32) -> Int {
        return (Int(sector) + 1) * sectorSize
    }

    private mutating func buildFAT() throws {
        let numFatSectors = Int(data.readUInt32(at: 44))
        var fatSectorIds: [UInt32] = []
        // I primi 109 DIFAT entries stanno nell'header a offset 76.
        for i in 0..<109 {
            let sid = data.readUInt32(at: 76 + i * 4)
            if sid == Self.freeSector { break }
            fatSectorIds.append(sid)
        }
        // DIFAT esteso (per file grandi) - segue la catena.
        var difatSector = data.readUInt32(at: 68)
        let difatCount = Int(data.readUInt32(at: 72))
        var guardCount = 0
        while difatSector != Self.endOfChain && difatSector != Self.freeSector && guardCount < difatCount + 1 {
            let base = sectorOffset(difatSector)
            let entriesPerSector = sectorSize / 4 - 1
            for i in 0..<entriesPerSector {
                let sid = data.readUInt32(at: base + i * 4)
                if sid == Self.freeSector { continue }
                fatSectorIds.append(sid)
            }
            difatSector = data.readUInt32(at: base + (sectorSize - 4))
            guardCount += 1
        }

        fat.reserveCapacity(numFatSectors * (sectorSize / 4))
        for sid in fatSectorIds {
            let base = sectorOffset(sid)
            for i in 0..<(sectorSize / 4) {
                fat.append(data.readUInt32(at: base + i * 4))
            }
        }
    }

    private mutating func buildMiniFAT() throws {
        var sector = data.readUInt32(at: 60)     // primo mini-FAT sector
        var guardCount = 0
        let maxSectors = fat.count + 1
        while sector != Self.endOfChain && sector != Self.freeSector && guardCount < maxSectors {
            let base = sectorOffset(sector)
            for i in 0..<(sectorSize / 4) {
                miniFat.append(data.readUInt32(at: base + i * 4))
            }
            sector = nextInFAT(sector)
            guardCount += 1
        }
    }

    private func nextInFAT(_ sector: UInt32) -> UInt32 {
        guard Int(sector) < fat.count else { return Self.endOfChain }
        return fat[Int(sector)]
    }

    // MARK: - Directory

    private mutating func buildDirectory() throws {
        var sector = data.readUInt32(at: 48)     // primo directory sector
        var raw = Data()
        var guardCount = 0
        let maxSectors = fat.count + 1
        while sector != Self.endOfChain && sector != Self.freeSector && guardCount < maxSectors {
            let base = sectorOffset(sector)
            guard base + sectorSize <= data.count else { throw CFBError.corrupted("directory oltre EOF") }
            raw.append(data.subdata(in: base..<(base + sectorSize)))
            sector = nextInFAT(sector)
            guardCount += 1
        }

        let entrySize = 128
        let count = raw.count / entrySize
        for i in 0..<count {
            let off = i * entrySize
            // Il campo nome e' di 64 byte: un valore maggiore (file alterato) leggerebbe dentro
            // i campi successivi o oltre il buffer.
            let nameLen = min(Int(raw.readUInt16(at: off + 64)), 64)
            guard nameLen >= 2 else {
                directory.append(DirectoryEntry(name: "", type: 0, startSector: 0, size: 0,
                                                leftSibling: Self.freeSector, rightSibling: Self.freeSector, child: Self.freeSector))
                continue
            }
            // Nome in UTF-16LE, nameLen include il terminatore.
            let nameData = raw.subdata(in: (off)..<(off + nameLen - 2))
            let name = String(data: nameData, encoding: .utf16LittleEndian) ?? ""
            let type = raw[off + 66]
            let entry = DirectoryEntry(
                name: name,
                type: type,
                startSector: raw.readUInt32(at: off + 116),
                size: raw.readUInt64(at: off + 120),
                leftSibling: raw.readUInt32(at: off + 68),
                rightSibling: raw.readUInt32(at: off + 72),
                child: raw.readUInt32(at: off + 76)
            )
            directory.append(entry)
        }
    }

    // MARK: - Lettura stream

    /// Legge il contenuto di uno stream a partire dalla sua directory entry.
    public func readStream(_ entry: DirectoryEntry) -> Data {
        // La dimensione dichiarata e' un UInt64 del file: Int(...) andrebbe in crash oltre
        // Int.max e Data(capacity:) allocherebbe memoria arbitraria. Nessuno stream puo'
        // essere piu' grande del file che lo contiene.
        let size = Int(min(entry.size, UInt64(data.count)))
        if entry.size < UInt64(miniStreamCutoff) && entry.type != 5 {
            return readMiniStream(startSector: entry.startSector, size: size)
        } else {
            return readNormalStream(startSector: entry.startSector, size: size)
        }
    }

    private func readNormalStream(startSector: UInt32, size: Int) -> Data {
        var out = Data(capacity: size)
        var sector = startSector
        var guardCount = 0
        let maxSectors = fat.count + 1
        while sector != Self.endOfChain && sector != Self.freeSector && out.count < size && guardCount < maxSectors {
            let base = sectorOffset(sector)
            let take = min(sectorSize, size - out.count)
            if base + take <= data.count {
                out.append(data.subdata(in: base..<(base + take)))
            }
            sector = nextInFAT(sector)
            guardCount += 1
        }
        return out
    }

    /// Root storage: il mini-stream e memorizzato nella catena della root entry.
    private func rootMiniStreamData() -> Data {
        guard let root = directory.first(where: { $0.type == 5 }) else { return Data() }
        return readNormalStream(startSector: root.startSector, size: Int(min(root.size, UInt64(data.count))))
    }

    private func readMiniStream(startSector: UInt32, size: Int) -> Data {
        let mini = miniStream
        var out = Data(capacity: size)
        var sector = startSector
        var guardCount = 0
        let maxSectors = miniFat.count + 1
        while sector != Self.endOfChain && sector != Self.freeSector && out.count < size && guardCount < maxSectors {
            let base = Int(sector) * miniSectorSize
            let take = min(miniSectorSize, size - out.count)
            if base + take <= mini.count {
                out.append(mini.subdata(in: base..<(base + take)))
            }
            sector = Int(sector) < miniFat.count ? miniFat[Int(sector)] : Self.endOfChain
            guardCount += 1
        }
        return out
    }
}
