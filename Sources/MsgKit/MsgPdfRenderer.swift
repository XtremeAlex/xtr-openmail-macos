import CoreGraphics
import CoreText
import Foundation

/// Export PDF del messaggio (header, corpo testo, elenco allegati), come la versione Java.
///
/// Perche' CoreText e non WebKit/AppKit: resta in MsgKit (niente UI, testabile con XCTest),
/// non interpreta HTML ne' carica risorse remote (nessun pixel di tracciamento, nessuna rete)
/// e produce un documento adatto all'archiviazione. Il corpo HTML non viene reso: si usa il
/// corpo testo, lo stesso dell'export TXT.
public enum MsgPdfRenderer {

    /// A4 in punti tipografici.
    public static let pageSize = CGSize(width: 595.28, height: 841.89)
    static let margin: CGFloat = 50
    static let footerHeight: CGFloat = 24

    /// Limite di pagine: un corpo patologico (es. megabyte di testo) non deve generare un PDF
    /// ingestibile. Oltre il limite il testo e' troncato e lo si segnala nell'ultima pagina.
    public static let maxPages = 500

    public static func render(_ msg: MsgMessage, creator: String = "xtr-openmail-macos") -> Data {
        let text = attributedText(msg)
        let frameRect = CGRect(x: margin, y: margin + footerHeight,
                               width: pageSize.width - 2 * margin,
                               height: pageSize.height - 2 * margin - footerHeight)

        // Prima passata: impaginazione (intervalli di testo per pagina), cosi' il pie' di
        // pagina puo' mostrare "n / totale".
        let framesetter = CTFramesetterCreateWithAttributedString(text)
        let path = CGPath(rect: frameRect, transform: nil)
        let length = CFAttributedStringGetLength(text)
        var ranges: [CFRange] = []
        var start = 0
        while start < length && ranges.count < maxPages {
            let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: start, length: 0), path, nil)
            let visible = CTFrameGetVisibleStringRange(frame)
            guard visible.length > 0 else { break } // riga piu' alta della pagina: evita loop infinito
            ranges.append(visible)
            start += visible.length
        }
        if ranges.isEmpty { ranges.append(CFRange(location: 0, length: 0)) }
        let truncated = start < length

        let data = NSMutableData()
        var mediaBox = CGRect(origin: .zero, size: pageSize)
        let info: [CFString: Any] = [
            kCGPDFContextTitle: msg.subject.isEmpty ? "Messaggio" : msg.subject,
            kCGPDFContextCreator: creator
        ]
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let ctx = CGContext(consumer: consumer, mediaBox: &mediaBox, info as CFDictionary) else {
            return Data()
        }
        for (index, range) in ranges.enumerated() {
            ctx.beginPDFPage(nil)
            let frame = CTFramesetterCreateFrame(framesetter, range, path, nil)
            CTFrameDraw(frame, ctx)
            var footer = "\(index + 1) / \(ranges.count)"
            if truncated && index == ranges.count - 1 {
                footer = "Testo troncato dopo \(maxPages) pagine — " + footer
            }
            drawFooter(footer, in: ctx)
            ctx.endPDFPage()
        }
        ctx.closePDF()
        return data as Data
    }

    // MARK: - Contenuto

    static func attributedText(_ msg: MsgMessage) -> CFAttributedString {
        let out = CFAttributedStringCreateMutable(nil, 0)!
        let bold = CTFontCreateWithName("Helvetica-Bold" as CFString, 10, nil)
        let regular = CTFontCreateWithName("Helvetica" as CFString, 10, nil)
        let title = CTFontCreateWithName("Helvetica-Bold" as CFString, 15, nil)
        let muted = CGColor(gray: 0.35, alpha: 1)
        let black = CGColor(gray: 0, alpha: 1)

        func append(_ s: String, _ font: CTFont, _ color: CGColor = black) {
            let attrs: [CFString: Any] = [kCTFontAttributeName: font, kCTForegroundColorAttributeName: color]
            let piece = CFAttributedStringCreate(nil, s as CFString, attrs as CFDictionary)!
            CFAttributedStringReplaceAttributedString(out, CFRange(location: CFAttributedStringGetLength(out), length: 0), piece)
        }

        append((msg.subject.isEmpty ? "(senza oggetto)" : msg.subject) + "\n\n", title)
        for (label, value) in [("Da", msg.from), ("A", msg.to), ("CC", msg.cc), ("Data", msg.date)] where !value.isEmpty {
            append(label + ": ", bold, muted)
            append(clean(value) + "\n", regular)
        }
        if !msg.attachments.isEmpty {
            append("Allegati: ", bold, muted)
            append(msg.attachments.map { "\(FileNameSanitizer.sanitize($0.fileName)) (\($0.sizeDescription))" }
                .joined(separator: ", ") + "\n", regular)
        }
        append("\n", regular)
        append(clean(msg.body, keepNewlines: true), regular)
        return out
    }

    /// Toglie i caratteri di controllo (tranne a capo e tab nel corpo): il contenuto viene dal
    /// mittente e non deve alterare l'impaginazione.
    static func clean(_ s: String, keepNewlines: Bool = false) -> String {
        let normalized = s.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        return String(String.UnicodeScalarView(normalized.unicodeScalars.filter { u in
            if keepNewlines && (u == "\n" || u == "\t") { return true }
            return !CharacterSet.controlCharacters.contains(u)
        }))
    }

    private static func drawFooter(_ text: String, in ctx: CGContext) {
        let font = CTFontCreateWithName("Helvetica" as CFString, 8, nil)
        let attrs: [CFString: Any] = [kCTFontAttributeName: font,
                                      kCTForegroundColorAttributeName: CGColor(gray: 0.45, alpha: 1)]
        let line = CTLineCreateWithAttributedString(CFAttributedStringCreate(nil, text as CFString, attrs as CFDictionary)!)
        let width = CTLineGetTypographicBounds(line, nil, nil, nil)
        ctx.textPosition = CGPoint(x: pageSize.width - margin - CGFloat(width), y: margin)
        CTLineDraw(line, ctx)
    }
}
