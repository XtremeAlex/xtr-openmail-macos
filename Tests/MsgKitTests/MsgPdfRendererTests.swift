import PDFKit
import XCTest
@testable import MsgKit

/// Export PDF: documento valido, testo estraibile, impaginazione e metadati. Solo dati sintetici.
final class MsgPdfRendererTests: XCTestCase {

    func testPdfContainsHeadersBodyAndAttachmentNames() throws {
        let msg = MsgMessage(subject: "SAMPLE Oggetto", from: "mittente@example.invalid", to: "dest@example.invalid",
                             cc: "", date: "2026-01-01 10:00", body: "Corpo sintetico del messaggio",
                             attachments: [MsgAttachment(fileName: "../rapporto.pdf", data: Data("X".utf8))])
        let data = MsgPdfRenderer.render(msg)
        XCTAssertEqual(String(decoding: data.prefix(5), as: UTF8.self), "%PDF-")

        let doc = try XCTUnwrap(PDFDocument(data: data))
        XCTAssertEqual(doc.pageCount, 1)
        let text = try XCTUnwrap(doc.string)
        for expected in ["SAMPLE Oggetto", "mittente@example.invalid", "dest@example.invalid",
                         "Corpo sintetico del messaggio", "rapporto.pdf", "1 / 1"] {
            XCTAssertTrue(text.contains(expected), "manca \(expected) in \(text)")
        }
        // Il nome allegato e' mostrato ripulito, senza percorso.
        XCTAssertFalse(text.contains("../rapporto.pdf"))
        XCTAssertEqual(doc.documentAttributes?[PDFDocumentAttribute.titleAttribute] as? String, "SAMPLE Oggetto")
    }

    func testLongBodyIsPaginatedOnA4() throws {
        let body = (1...600).map { "Riga sintetica numero \($0)" }.joined(separator: "\n")
        let doc = try XCTUnwrap(PDFDocument(data: MsgPdfRenderer.render(MsgMessage(subject: "Lungo", body: body))))
        XCTAssertGreaterThan(doc.pageCount, 5)
        let page = try XCTUnwrap(doc.page(at: 0))
        XCTAssertEqual(page.bounds(for: .mediaBox).size.width, MsgPdfRenderer.pageSize.width, accuracy: 0.5)
        XCTAssertTrue(doc.page(at: doc.pageCount - 1)?.string?.contains("Riga sintetica numero 600") ?? false)
    }

    func testControlCharactersAreRemovedAndEmptyMessageStillRenders() throws {
        XCTAssertEqual(MsgPdfRenderer.clean("a\u{0}b\u{1B}c\r\nd", keepNewlines: true), "abc\nd")
        XCTAssertEqual(MsgPdfRenderer.clean("x\ny"), "xy")
        let doc = try XCTUnwrap(PDFDocument(data: MsgPdfRenderer.render(MsgMessage(subject: "", body: ""))))
        XCTAssertEqual(doc.pageCount, 1)
        XCTAssertTrue(doc.string?.contains("(senza oggetto)") ?? false)
    }
}
