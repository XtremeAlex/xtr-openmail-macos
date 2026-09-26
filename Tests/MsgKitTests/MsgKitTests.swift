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
