import XCTest
@testable import MsgKit

/// Politica aziendale (MDM): valori tolleranti, limiti applicati, dimensione rispettata dal parser.
final class MsgPolicyTests: XCTestCase {

    func testDefaultsWhenNothingIsConfigured() {
        let policy = MsgPolicy.from([:])
        XCTAssertEqual(policy.maxFileSizeMB, MsgPolicy.defaultSizeMB)
        XCTAssertTrue(policy.attachmentExportAllowed)
        XCTAssertTrue(policy.folderExportAllowed)
    }

    func testValuesFromProfileAreParsedAndClamped() {
        XCTAssertEqual(MsgPolicy.from([MsgPolicy.Key.maxFileSizeMB: 20]).maxFileSizeMB, 20)
        XCTAssertEqual(MsgPolicy.from([MsgPolicy.Key.maxFileSizeMB: NSNumber(value: 64)]).maxFileSizeMB, 64)
        XCTAssertEqual(MsgPolicy.from([MsgPolicy.Key.maxFileSizeMB: " 32 "]).maxFileSizeMB, 32)
        XCTAssertEqual(MsgPolicy.from([MsgPolicy.Key.maxFileSizeMB: 0]).maxFileSizeMB, 1, "mai sotto 1 MB")
        XCTAssertEqual(MsgPolicy.from([MsgPolicy.Key.maxFileSizeMB: 99_999]).maxFileSizeMB, 1024, "mai oltre 1 GB")
        XCTAssertEqual(MsgPolicy.from([MsgPolicy.Key.maxFileSizeMB: "boh"]).maxFileSizeMB, MsgPolicy.defaultSizeMB)
    }

    func testExportSwitches() {
        let policy = MsgPolicy.from([MsgPolicy.Key.disableAttachmentExport: true,
                                     MsgPolicy.Key.disableFolderExport: "yes"])
        XCTAssertFalse(policy.attachmentExportAllowed)
        XCTAssertFalse(policy.folderExportAllowed)
        XCTAssertTrue(MsgPolicy.from([MsgPolicy.Key.disableAttachmentExport: NSNumber(value: false)])
            .attachmentExportAllowed)
    }

    func testParserRejectsFilesAboveThePolicyLimit() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("grande.msg")
        try Data(count: 2 * 1024 * 1024).write(to: url)
        let policy = MsgPolicy(maxFileSizeMB: 1)
        XCTAssertThrowsError(try MsgParser.parse(url: url, maxFileSize: policy.maxFileSizeBytes)) { error in
            guard case CompoundFileReader.CFBError.tooLarge = error else {
                return XCTFail("atteso .tooLarge, ottenuto \(error)")
            }
        }
    }
}
