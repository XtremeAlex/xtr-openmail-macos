import XCTest
@testable import MsgKit

final class MsgKitTests: XCTestCase {

    func testRejectsNonCFBData() {
        let junk = Data("questo non e un file msg".utf8)
        XCTAssertThrowsError(try MsgParser.parse(data: junk)) { error in
            XCTAssertTrue(error is CompoundFileReader.CFBError)
        }
    }

    func testRejectsTooSmallData() {
        let tiny = Data([0xD0, 0xCF, 0x11, 0xE0])
        XCTAssertThrowsError(try CompoundFileReader(data: tiny))
    }

    func testLittleEndianReads() {
        let data = Data([0x01, 0x00, 0x00, 0x00, 0xFF, 0xFF])
        XCTAssertEqual(data.readUInt32(at: 0), 1)
        XCTAssertEqual(data.readUInt16(at: 4), 0xFFFF)
        // bounds check: leggere oltre non deve crashare
        XCTAssertEqual(data.readUInt32(at: 100), 0)
    }

    func testPlainTextExportContainsHeaders() {
        let msg = MsgMessage(subject: "Ciao", from: "a@b.it", to: "c@d.it",
                             cc: "", date: "", body: "Corpo del messaggio")
        let txt = MsgExporter.plainText(msg)
        XCTAssertTrue(txt.contains("Subject: Ciao"))
        XCTAssertTrue(txt.contains("From: a@b.it"))
        XCTAssertTrue(txt.contains("Corpo del messaggio"))
    }
}


/// Hardening per uso aziendale: nomi allegati ostili, header CFB alterati, export sicuro.
/// Solo dati sintetici.
final class MsgKitHardeningTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("msgkit-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testSanitizeStripsPathsAndHiddenPrefixes() {
        XCTAssertEqual(FileNameSanitizer.sanitize("../../Library/LaunchAgents/x.plist"), "x.plist")
        XCTAssertEqual(FileNameSanitizer.sanitize("C:\\Users\\sample\\doc.pdf"), "doc.pdf")
        XCTAssertEqual(FileNameSanitizer.sanitize(".bashrc"), "bashrc")
        XCTAssertEqual(FileNameSanitizer.sanitize(".."), "allegato.bin")
        XCTAssertEqual(FileNameSanitizer.sanitize(""), "allegato.bin")
        XCTAssertEqual(FileNameSanitizer.sanitize("a\u{0}b\u{7}:c.txt"), "abc.txt")
    }

    func testSanitizeTruncatesKeepingExtension() {
        let long = String(repeating: "à", count: 300) + ".pdf"
        let out = FileNameSanitizer.sanitize(long)
        XCTAssertLessThanOrEqual(out.utf8.count, 255)
        XCTAssertTrue(out.hasSuffix(".pdf"))
    }

    func testExportFolderKeepsFilesInsideAndDoesNotOverwrite() throws {
        let payload = Data("SAMPLE".utf8)
        let msg = MsgMessage(subject: "Test", body: "Corpo", attachments: [
            MsgAttachment(fileName: "../../evil.txt", data: payload),
            MsgAttachment(fileName: "report.pdf", data: payload),
            MsgAttachment(fileName: "REPORT.pdf", data: payload),
            MsgAttachment(fileName: "mail.txt", data: payload)
        ])

        let folder = try MsgExporter.exportFolder(msg, named: "../sample", into: tempDir)
        XCTAssertEqual(folder.deletingLastPathComponent().standardizedFileURL, tempDir.standardizedFileURL)
        XCTAssertEqual(folder.lastPathComponent, "sample")

        let names = Set(try FileManager.default.contentsOfDirectory(atPath: folder.path))
        XCTAssertEqual(names, ["mail.txt", "evil.txt", "report.pdf", "REPORT (2).pdf", "mail (2).txt"])
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: tempDir.deletingLastPathComponent().appendingPathComponent("evil.txt").path))

        // Seconda esportazione con lo stesso nome: nuova cartella, la prima resta intatta.
        let second = try MsgExporter.exportFolder(msg, named: "sample", into: tempDir)
        XCTAssertEqual(second.lastPathComponent, "sample (2)")
    }

    func testRejectsInvalidSectorShift() {
        var header = Data(count: 512)
        let sig: [UInt8] = [0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1]
        header.replaceSubrange(0..<8, with: sig)
        header[30] = 0xFF   // shift assurdo: prima produceva dimensioni di settore invalide
        header[32] = 6
        XCTAssertThrowsError(try CompoundFileReader(data: header)) { error in
            guard case CompoundFileReader.CFBError.corrupted = error else {
                return XCTFail("atteso .corrupted, ottenuto \(error)")
            }
        }
    }

    func testEmptyValidHeaderParsesWithoutCrashing() throws {
        // Header v3 minimale senza FAT ne' directory: nessun crash, messaggio vuoto.
        var header = Data(count: 512)
        let sig: [UInt8] = [0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1]
        header.replaceSubrange(0..<8, with: sig)
        header[30] = 9
        header[32] = 6
        for offset in [48, 60, 68] {   // directory, mini-FAT, DIFAT: fine catena
            header.replaceSubrange(offset..<(offset + 4), with: [0xFE, 0xFF, 0xFF, 0xFF])
        }
        for i in 0..<109 {
            let o = 76 + i * 4
            header.replaceSubrange(o..<(o + 4), with: [0xFF, 0xFF, 0xFF, 0xFF])
        }
        let msg = try MsgParser.parse(data: header)
        XCTAssertEqual(msg.subject, "")
        XCTAssertTrue(msg.attachments.isEmpty)
    }
}
