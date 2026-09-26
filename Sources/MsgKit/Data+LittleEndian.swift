import Foundation

/// Helper di lettura little-endian su Data, con bounds check.
/// I file CFB/MAPI sono sempre little-endian.
extension Data {

    func readUInt16(at offset: Int) -> UInt16 {
        guard offset >= 0, offset + 2 <= count else { return 0 }
        let b0 = UInt16(self[startIndex + offset])
        let b1 = UInt16(self[startIndex + offset + 1])
        return b0 | (b1 << 8)
    }

    func readUInt32(at offset: Int) -> UInt32 {
        guard offset >= 0, offset + 4 <= count else { return 0 }
        var v: UInt32 = 0
        for i in 0..<4 {
            v |= UInt32(self[startIndex + offset + i]) << (8 * i)
        }
        return v
    }

    func readUInt64(at offset: Int) -> UInt64 {
        guard offset >= 0, offset + 8 <= count else { return 0 }
        var v: UInt64 = 0
        for i in 0..<8 {
            v |= UInt64(self[startIndex + offset + i]) << (8 * i)
        }
        return v
    }
}
