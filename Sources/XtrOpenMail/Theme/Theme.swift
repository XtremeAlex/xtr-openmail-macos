import SwiftUI
import AppKit

/// Design token del tema "2AD", allineati a `static/tool/css/app.css` della web app
/// xtr-aeroport-edifact-spring-web (scuro di default, override chiaro).
///
/// Perche' token centralizzati: le due modalita' e tutti i componenti leggono gli stessi
/// valori, cosi' un aggiornamento del tema web si riporta qui cambiando un solo file.
/// I colori sono dinamici (NSColor con provider): seguono l'aspetto effettivo della finestra,
/// compreso quello forzato da `AppearancePreference`.
enum Theme {

    // MARK: Colori (scuro / chiaro, come --token in app.css)

    static let bg          = Color(dark: 0x0A0A0A, light: 0xFFFFFF)
    static let bgAlt       = Color(dark: 0x111111, light: 0xF5F5F5)
    static let surface     = Color(dark: 0x1A1A1A, light: 0xEBEBEB)
    static let surface2    = Color(dark: 0x232323, light: 0xE2E2E2)
    static let border      = Color(dark: 0x2A2A2A, light: 0xE2E2E2)
    static let control     = Color(dark: 0x5E5E5E, light: 0x8A8A8A)
    static let text        = Color(dark: 0xE5E5E5, light: 0x0A0A0A)
    static let textMuted   = Color(dark: 0x8F8F8F, light: 0x5C5C5C)
    static let accent      = Color(hex: 0xFF3B30)
    static let accentText  = Color(dark: 0xFF5147, light: 0xD70015)
    static let accentDim   = Color(darkRGBA: (0xFF3B30, 0.15), lightRGBA: (0xFF3B30, 0.10))
    static let button      = Color(dark: 0xE0241A, light: 0xD70015)
    static let buttonHover = Color(dark: 0xC11D14, light: 0xB50012)
    static let ok          = Color(dark: 0x30D158, light: 0x1A7F37)
    static let warn        = Color(dark: 0xFFD60A, light: 0x8A6100)
    static let info        = Color(dark: 0x5AC8FA, light: 0x0A6CBF)
    static let codeBg      = Color(dark: 0x0D0D0D, light: 0xF7F7F7)
    static let codeText    = Color(dark: 0xD9D9D9, light: 0x1A1A1A)
    /// Warm orange usato dal bagliore del pulsante "lampada" (#ffb347 nel CSS).
    static let lampWarm    = Color(hex: 0xFFB347)
    /// Alone interno della lampada: `color-mix(in srgb, var(--btn) 70%, #ffb347)`.
    static let lampGlow    = Color(dark: mix(0xE0241A, 0xFFB347, 0.7), light: mix(0xD70015, 0xFFB347, 0.7))

    // Fogli (schede frammento), header traslucido e ombra dei pannelli sollevati.
    static let paper       = Color(dark: 0x1D1D1D, light: 0xFFFFFF)
    static let paperActive = Color(dark: 0x282828, light: 0xFFFFFF)
    static let paperBack   = Color(dark: 0x151515, light: 0xECECEC)
    static let headerBg    = Color(darkRGBA: (0x0A0A0A, 0.86), lightRGBA: (0xFFFFFF, 0.88))
    /// `--shadow: 0 18px 50px rgba(0,0,0,.45 | .14)`.
    static let shadow      = Color(darkRGBA: (0x000000, 0.45), lightRGBA: (0x000000, 0.14))
    static let shadowRadius: CGFloat = 25
    static let shadowY: CGFloat = 18

    // MARK: Forme e spaziature (--r-*, --s*)

    static let radiusSmall: CGFloat = 6
    static let radius: CGFloat = 10
    static let radiusLarge: CGFloat = 14
    static let radiusControl: CGFloat = 8

    static let s1: CGFloat = 4
    static let s2: CGFloat = 8
    static let s3: CGFloat = 12
    static let s4: CGFloat = 16
    static let s5: CGFloat = 24
    static let s6: CGFloat = 32
    static let s7: CGFloat = 48
    static let s8: CGFloat = 72

    /// Altezza della barra superiore (`--header-h`).
    static let headerHeight: CGFloat = 64

    // MARK: Tipografia
    //
    // La web app usa Space Grotesk e JetBrains Mono self-hosted; qui si usano i fallback
    // dichiarati nello stesso CSS (-apple-system e SF Mono) per non distribuire font di terzi
    // nel bundle e restare coerenti con l'aspetto nativo di macOS.

    /// Etichetta mono maiuscola (.label del CSS: 500 .7rem, spaziatura .08em).
    static func monoLabel(_ size: CGFloat = 11) -> Font {
        .system(size: size, weight: .medium, design: .monospaced)
    }

    static func mono(_ size: CGFloat = 13, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    static func heading(_ size: CGFloat = 20) -> Font {
        .system(size: size, weight: .bold)
    }

    /// Miscela sRGB di due colori come `color-mix(in srgb, a p, b)`.
    static func mix(_ a: UInt32, _ b: UInt32, _ p: Double) -> UInt32 {
        func channel(_ shift: UInt32) -> UInt32 {
            let ca = Double((a >> shift) & 0xFF), cb = Double((b >> shift) & 0xFF)
            return UInt32((ca * p + cb * (1 - p)).rounded()) << shift
        }
        return channel(16) | channel(8) | channel(0)
    }
}

// MARK: - Preferenza di aspetto

/// Sistema / Chiaro / Scuro, come il toggle della web app (chiave `theme` in localStorage).
/// Il default e' "sistema": in un contesto aziendale l'app deve rispettare l'impostazione
/// gestita del Mac, lasciando all'utente la scelta esplicita.
enum AppearancePreference: String, CaseIterable, Identifiable {
    case system, light, dark

    static let storageKey = "theme"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "Sistema"
        case .light: return "Chiaro"
        case .dark: return "Scuro"
        }
    }

    /// `true` se il tema e' imposto da un profilo di configurazione (MDM): i selettori si
    /// disattivano invece di offrire una scelta che il sistema ignorerebbe.
    static var isManaged: Bool { UserDefaults.standard.objectIsForced(forKey: storageKey) }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

// MARK: - Helper colore

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(nsColor: NSColor(hex: hex, alpha: alpha))
    }

    /// Colore dinamico: risolto in base all'aspetto (scuro/chiaro) della vista che lo disegna.
    init(dark: UInt32, light: UInt32) {
        self.init(darkRGBA: (dark, 1), lightRGBA: (light, 1))
    }

    init(darkRGBA: (UInt32, Double), lightRGBA: (UInt32, Double)) {
        let provider: (NSAppearance) -> NSColor = { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let (hex, alpha) = isDark ? darkRGBA : lightRGBA
            return NSColor(hex: hex, alpha: alpha)
        }
        self.init(nsColor: NSColor(name: nil, dynamicProvider: provider))
    }
}

extension NSColor {
    convenience init(hex: UInt32, alpha: Double) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: CGFloat(alpha))
    }
}
