import SwiftUI

// Componenti del tema 2AD: stessa resa di .btn, .btn--ghost, .card, .callout, .badge, .pill,
// .eyebrow, input, .theme-toggle, .site-header e .brand della web app
// (xtr-aeroport-edifact-spring-web, static/tool/css/app.css), riscritti in SwiftUI per restare
// nativi (focus, VoiceOver, tastiera). File identico in xtr-openmail-macos e
// xtr-toolkit-hosts-macos: usa solo API macOS 13 e aggiornalo in entrambi i progetti
// (scripts/check-theme-sync.sh verifica token e copie).

// MARK: - Pulsanti

/// `.btn` (primario rosso) e `.btn--ghost` (bordo --control, hover --accent-dim).
struct XtrButtonStyle: ButtonStyle {
    enum Kind { case primary, ghost }

    var kind: Kind = .primary
    var small = false
    /// Stato "in attesa": effetto lampada come `button[data-loading]` nel CSS.
    var isLoading = false

    func makeBody(configuration: Configuration) -> some View {
        XtrButtonBody(configuration: configuration, kind: kind, small: small, isLoading: isLoading)
    }
}

private struct XtrButtonBody: View {
    let configuration: ButtonStyle.Configuration
    let kind: XtrButtonStyle.Kind
    let small: Bool
    let isLoading: Bool

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.isFocused) private var isFocused
    @State private var hovering = false

    var body: some View {
        configuration.label
            // .btn: 600 .76rem mono (≈12pt), .btn--small .68rem (≈11pt); spaziatura .06em
            .font(Theme.mono(small ? 11 : 12, weight: .semibold))
            .textCase(.uppercase)
            .tracking(0.7)
            .lineLimit(1)
            .foregroundStyle(kind == .primary ? Color.white : Theme.text)
            .padding(.horizontal, small ? 12 : 18)
            .padding(.vertical, small ? 5 : 9)
            // min-height 40px / 32px come nel CSS
            .frame(minHeight: small ? 32 : 40)
            .background(background)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusControl)
                    .strokeBorder(borderColor, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusControl))
            .contentShape(RoundedRectangle(cornerRadius: Theme.radiusControl))
            .lampEffect(isLoading)
            // :focus-visible { outline: 2px solid accent; outline-offset: 2px }
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusControl + 2)
                    .strokeBorder(Theme.accent, lineWidth: 2)
                    .padding(-4)
                    .opacity(isFocused ? 1 : 0)
            )
            // Nel CSS i pulsanti disabilitati non sono sbiaditi (solo cursore): su macOS non c'e'
            // un cursore da cambiare, quindi un'attenuazione leggera comunica lo stato.
            .opacity(isEnabled || isLoading ? 1 : 0.6)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: hovering)
            .onHover { hovering = $0 && isEnabled }
            // aria-busy="true" della web app
            .accessibilityValue(isLoading ? Text("in corso") : Text(""))
            .accessibilityAddTraits(isLoading ? .updatesFrequently : [])
    }

    private var background: Color {
        switch kind {
        case .primary: return hovering ? Theme.buttonHover : Theme.button
        case .ghost: return hovering ? Theme.accentDim : .clear
        }
    }

    private var borderColor: Color {
        switch kind {
        case .primary: return hovering ? Theme.buttonHover : Theme.button
        case .ghost: return hovering ? Theme.accent : Theme.control
        }
    }
}

/// Curva dei keyframes `lamp` della web app (1,4 s, ease-in-out):
/// 0% .72 · 18% .9 · 50% 1.3 (alone pieno) · 62% 1.18 · 100% .72.
enum LampCurve {
    static let period: Double = 1.4
    private static let brightness: [(Double, Double)] = [(0, 0.72), (0.18, 0.9), (0.5, 1.3), (0.62, 1.18), (1, 0.72)]

    /// Fase 0...1 del ciclo all'istante dato.
    static func phase(at date: Date) -> Double {
        let t = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period)
        return t / period
    }

    /// Luminosita' moltiplicativa (filter: brightness) alla fase data.
    static func brightness(at phase: Double) -> Double {
        for i in 1..<brightness.count where phase <= brightness[i].0 {
            let (p0, v0) = brightness[i - 1], (p1, v1) = brightness[i]
            let local = (phase - p0) / (p1 - p0)
            let eased = local * local * (3 - 2 * local)   // ease-in-out fra due keyframes
            return v0 + (v1 - v0) * eased
        }
        return brightness[0].1
    }

    /// Intensita' dell'alone: 0 a 0% e 100%, piena al 50% (box-shadow interpolato).
    static func glow(at phase: Double) -> Double {
        let d = phase <= 0.5 ? phase / 0.5 : (1 - phase) / 0.5
        return d * d * (3 - 2 * d)
    }

    /// Saturazione: .9 a riposo, 1.1 al culmine.
    static func saturation(at phase: Double) -> Double { 0.9 + 0.2 * glow(at: phase) }
}

/// Effetto "lampada": il pulsante resta identico e "respira" (si scalda e si raffredda).
/// Con "Riduci movimento" nessuna animazione, come `prefers-reduced-motion` nel CSS.
private struct LampEffect: ViewModifier {
    let active: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if active && !reduceMotion {
            TimelineView(.animation) { context in
                let phase = LampCurve.phase(at: context.date)
                let glow = LampCurve.glow(at: phase)
                content
                    // SwiftUI .brightness e' additiva: la scala 0.6 approssima il filtro moltiplicativo
                    .brightness((LampCurve.brightness(at: phase) - 1) * 0.6)
                    .saturation(LampCurve.saturation(at: phase))
                    .shadow(color: Theme.lampGlow.opacity(glow), radius: 5)
                    .shadow(color: Theme.button.opacity(0.3 * glow), radius: 14)
            }
        } else {
            content
        }
    }
}

extension View {
    func lampEffect(_ active: Bool) -> some View { modifier(LampEffect(active: active)) }
}

/// `.theme-toggle`: pulsante tondo 38pt che cicla Sistema → Chiaro → Scuro.
struct ThemeToggleButton: View {
    @Binding var preference: String
    var disabled = false
    @State private var hovering = false

    var body: some View {
        let current = AppearancePreference(rawValue: preference) ?? .system
        Button {
            let all = AppearancePreference.allCases
            let next = all[(all.firstIndex(of: current)! + 1) % all.count]
            preference = next.rawValue
        } label: {
            Image(systemName: current.symbol)
                .font(.system(size: 14, weight: .medium))
                .frame(width: 38, height: 38)
                .foregroundStyle(hovering ? Theme.accentText : Theme.textMuted)
                .background(Theme.bgAlt, in: Circle())
                .overlay(Circle().strokeBorder(hovering ? Theme.accent : Theme.border))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .onHover { hovering = $0 && !disabled }
        .help(disabled ? "Tema impostato dall'amministratore" : "Tema: \(current.label)")
        .accessibilityLabel("Tema")
        .accessibilityValue(current.label)
    }
}

// MARK: - Superfici

/// `.card` / `.panel`: fondo --bg-alt, bordo 1px --border, raggio 14; `error` = `.card--error`.
struct CardModifier: ViewModifier {
    var padding: CGFloat = Theme.s5
    var error = false

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(error ? Theme.accent.opacity(0.07) : .clear)
            .background(Theme.bgAlt)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
            .overlay(RoundedRectangle(cornerRadius: Theme.radiusLarge)
                .strokeBorder(error ? Theme.accent : Theme.border))
    }
}

extension View {
    func card(padding: CGFloat = Theme.s5, error: Bool = false) -> some View {
        modifier(CardModifier(padding: padding, error: error))
    }

    /// `.empty-state`: bordo tratteggiato, raggio grande, accento quando e' un bersaglio di drop.
    func emptyState(targeted: Bool = false) -> some View {
        padding(Theme.s6)
            .background(targeted ? Theme.accentDim : .clear, in: RoundedRectangle(cornerRadius: Theme.radiusLarge))
            .overlay(RoundedRectangle(cornerRadius: Theme.radiusLarge)
                .strokeBorder(targeted ? Theme.accent : Theme.border, style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
    }

    /// `.site-header`: fondo --header-bg traslucido con sfocatura e bordo inferiore.
    func headerBar() -> some View {
        frame(minHeight: Theme.headerHeight)
            .background(Theme.headerBg)
            .background(.ultraThinMaterial)
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.border).frame(height: 1) }
    }

    /// Pannello sollevato (`--shadow`), per popover e fogli modali.
    func raised() -> some View {
        shadow(color: Theme.shadow, radius: Theme.shadowRadius, y: Theme.shadowY)
    }
}

/// `.callout`: bordo 1px, bordo sinistro 3px colorato per tipo, raggio solo a destra.
/// Solo `alert` ha il fondo tinto (6% accento), come nel CSS.
struct Callout<Content: View>: View {
    enum Kind { case neutral, info, warn, alert, ok }

    let kind: Kind
    @ViewBuilder var content: Content

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Rectangle().fill(color).frame(width: 3)
            VStack(alignment: .leading, spacing: Theme.s1) { content }
                .padding(.vertical, Theme.s4)
                .padding(.horizontal, Theme.s5 - 3)
            Spacer(minLength: 0)
        }
        .background(kind == .alert ? Theme.accent.opacity(0.06) : .clear)
        .background(Theme.bgAlt)
        .clipShape(UnevenCorners(radius: Theme.radius))
        .overlay(UnevenCorners(radius: Theme.radius).stroke(Theme.border, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }

    private var color: Color {
        switch kind {
        case .neutral: return Theme.textMuted
        case .info: return Theme.info
        case .warn: return Theme.warn
        case .alert: return Theme.accent
        case .ok: return Theme.ok
        }
    }
}

/// Raggio solo sui due angoli di destra (0 10px 10px 0 nel CSS), compatibile macOS 13.
struct UnevenCorners: Shape {
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let r = min(radius, rect.height / 2, rect.width / 2)
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        p.addArc(center: CGPoint(x: rect.maxX - r, y: rect.minY + r), radius: r,
                 startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        p.addArc(center: CGPoint(x: rect.maxX - r, y: rect.maxY - r), radius: r,
                 startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Campi di testo

/// `input` della web app: mono .85rem, min-height 40, bordo --control, raggio 8;
/// a fuoco bordo accento con alone 3px --accent-dim; bordo accento se il valore non e' valido.
struct ThemedFieldModifier: ViewModifier {
    var invalid = false
    var compact = false
    @FocusState private var focused: Bool

    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .font(Theme.mono(compact ? 12.5 : 13.5))
            .foregroundStyle(Theme.text)
            .focused($focused)
            .padding(.horizontal, compact ? 10 : 13)
            .padding(.vertical, compact ? 6 : 9)
            .frame(minHeight: compact ? 32 : 40)
            .background(Theme.bg, in: RoundedRectangle(cornerRadius: Theme.radiusControl))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusControl)
                    .strokeBorder(invalid || focused ? Theme.accent : Theme.control)
            )
            .background(
                RoundedRectangle(cornerRadius: Theme.radiusControl + 3)
                    .fill(Theme.accentDim)
                    .padding(-3)
                    .opacity(focused ? 1 : 0)
            )
            .animation(.easeOut(duration: 0.15), value: focused)
    }
}

extension View {
    func themedField(invalid: Bool = false, compact: Bool = true) -> some View {
        modifier(ThemedFieldModifier(invalid: invalid, compact: compact))
    }
}

// MARK: - Testi

/// `.eyebrow`: sopratitolo mono maiuscolo in --accent-text, spaziatura .16em.
struct Eyebrow: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.system(size: 11.5, weight: .medium, design: .monospaced))
            .textCase(.uppercase)
            .tracking(1.85)
            .foregroundStyle(Theme.accentText)
            .accessibilityAddTraits(.isHeader)
    }
}

/// `.label`: mono maiuscolo, spaziatura larga, colore attenuato.
struct MonoLabel: View {
    let text: String
    var color: Color = Theme.textMuted

    init(_ text: String, color: Color = Theme.textMuted) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text)
            .font(Theme.monoLabel())
            .textCase(.uppercase)
            .tracking(0.9)
            .foregroundStyle(color)
    }
}

/// `.badge`: pillola mono con bordo; variante `accent` come `.badge--warn`.
struct Badge: View {
    let text: String
    var accent = false

    var body: some View {
        Text(text)
            .font(Theme.mono(10.5))
            .lineLimit(1)
            .fixedSize()
            .foregroundStyle(accent ? Theme.accentText : Theme.textMuted)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .overlay(Capsule().strokeBorder(accent ? Theme.accent : Theme.border))
    }
}

/// `.pill`: etichetta mono maiuscola in capsula con bordo.
struct Pill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Theme.mono(10.5))
            .textCase(.uppercase)
            .tracking(0.9)
            .lineLimit(1)
            .fixedSize()
            .foregroundStyle(Theme.textMuted)
            .padding(.horizontal, 13)
            .padding(.vertical, 5)
            .overlay(Capsule().strokeBorder(Theme.border))
    }
}

/// `.pill--trust`: pillola verde "vetro" con punto luminoso (es. "Solo locale").
struct TrustPill: View {
    let text: String

    var body: some View {
        HStack(spacing: 7) {
            Circle().fill(Theme.ok).frame(width: 6, height: 6)
                .shadow(color: Theme.ok, radius: 3)
            Text(text).font(Theme.mono(10.5)).textCase(.uppercase).tracking(0.8)
        }
        .foregroundStyle(Theme.ok)
        .padding(.horizontal, 13)
        .padding(.vertical, 5)
        .background(Theme.ok.opacity(0.09), in: Capsule())
        .overlay(Capsule().strokeBorder(Theme.ok.opacity(0.38)))
        .shadow(color: Theme.ok.opacity(0.10), radius: 7, y: 4)
    }
}

/// `.brand`: nome in mono seguito dal punto rosso (600 1.1rem, spaziatura .02em).
struct BrandMark: View {
    let name: String
    var size: CGFloat = 17.5

    var body: some View {
        (Text(name).foregroundColor(Theme.text) + Text(".").foregroundColor(Theme.accent))
            .font(.system(size: size, weight: .semibold, design: .monospaced))
            .tracking(size * 0.02)
            .accessibilityLabel(name)
    }
}

// MARK: - Aspetto: simbolo del toggle

extension AppearancePreference {
    /// Icona del `.theme-toggle` (luna, sole o automatico).
    var symbol: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max"
        case .dark: return "moon"
        }
    }
}
