import SwiftUI

// Componenti del tema 2AD: stessa resa di .btn, .btn--ghost, .card, .callout, .badge e
// .brand della web app, riscritti in SwiftUI per restare nativi (focus, VoiceOver, tastiera).

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
    @State private var hovering = false

    var body: some View {
        configuration.label
            .font(Theme.mono(small ? 10.5 : 11.5, weight: .semibold))
            .textCase(.uppercase)
            .tracking(0.7)
            .foregroundStyle(kind == .primary ? Color.white : Theme.text)
            .padding(.horizontal, small ? 12 : 18)
            .frame(minHeight: small ? 28 : 34)
            .background(background)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusControl)
                    .strokeBorder(borderColor, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusControl))
            .contentShape(RoundedRectangle(cornerRadius: Theme.radiusControl))
            .lampEffect(isLoading)
            // Nel CSS i pulsanti disabilitati non sono sbiaditi (solo cursore): qui una lieve
            // attenuazione serve comunque a macOS per comunicare lo stato senza puntatore.
            .opacity(isEnabled || isLoading ? 1 : 0.55)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: hovering)
            .onHover { hovering = $0 && isEnabled }
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

/// Effetto "lampada" (keyframes `lamp`, 1,4 s): luminosita' da .72 a 1,3 con bagliore caldo.
/// Con "Riduci movimento" attivo resta un bagliore fisso, come `prefers-reduced-motion` nel CSS.
private struct LampEffect: ViewModifier {
    let active: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lit = false

    func body(content: Content) -> some View {
        content
            .brightness(active ? (lit ? 0.12 : -0.14) : 0)
            .saturation(active ? (lit ? 1.1 : 0.9) : 1)
            .shadow(color: active && lit ? Theme.lampWarm.opacity(0.55) : .clear, radius: 5)
            .shadow(color: active && lit ? Theme.button.opacity(0.35) : .clear, radius: 14)
            .onAppear { update() }
            .onChange(of: active) { _ in update() }
    }

    private func update() {
        guard active else {
            lit = false
            return
        }
        if reduceMotion {
            lit = true
        } else {
            // Mezzo ciclo 0,7 s con autoreverse = periodo 1,4 s della web app.
            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) { lit = true }
        }
    }
}

extension View {
    func lampEffect(_ active: Bool) -> some View { modifier(LampEffect(active: active)) }
}

// MARK: - Superfici

/// `.card` / `.panel`: fondo --bg-alt, bordo 1px --border, raggio 14.
struct CardModifier: ViewModifier {
    var padding: CGFloat = Theme.s5

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Theme.bgAlt, in: RoundedRectangle(cornerRadius: Theme.radiusLarge))
            .overlay(RoundedRectangle(cornerRadius: Theme.radiusLarge).strokeBorder(Theme.border))
    }
}

extension View {
    func card(padding: CGFloat = Theme.s5) -> some View { modifier(CardModifier(padding: padding)) }
}

/// `.callout`: bordo sinistro di 3 px colorato per tipo, raggio solo a destra.
struct Callout<Content: View>: View {
    enum Kind { case info, warn, alert, ok }

    let kind: Kind
    @ViewBuilder var content: Content

    var body: some View {
        HStack(alignment: .top, spacing: Theme.s3) {
            Rectangle().fill(color).frame(width: 3)
            VStack(alignment: .leading, spacing: Theme.s1) { content }
                .padding(.vertical, Theme.s3)
                .padding(.trailing, Theme.s4)
            Spacer(minLength: 0)
        }
        .background(color.opacity(kind == .alert ? 0.06 : 0.05))
        .background(Theme.bgAlt)
        .clipShape(UnevenCorners(radius: Theme.radius))
        .accessibilityElement(children: .combine)
    }

    private var color: Color {
        switch kind {
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

// MARK: - Testi

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
            .foregroundStyle(accent ? Theme.accentText : Theme.textMuted)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .overlay(Capsule().strokeBorder(accent ? Theme.accent : Theme.border))
    }
}

/// `.pill--trust`: pillola verde "vetro" con punto luminoso (es. "Solo locale").
struct TrustPill: View {
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(Theme.ok).frame(width: 6, height: 6)
                .shadow(color: Theme.ok, radius: 3)
            Text(text).font(Theme.mono(10.5)).textCase(.uppercase).tracking(0.8)
        }
        .foregroundStyle(Theme.ok)
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(Theme.ok.opacity(0.09), in: Capsule())
        .overlay(Capsule().strokeBorder(Theme.ok.opacity(0.38)))
    }
}

/// `.brand`: nome in mono minuscolo seguito dal punto rosso.
struct BrandMark: View {
    let name: String
    var size: CGFloat = 15

    var body: some View {
        (Text(name).foregroundColor(Theme.text) + Text(".").foregroundColor(Theme.accent))
            .font(.system(size: size, weight: .semibold, design: .monospaced))
            .tracking(0.3)
            .accessibilityLabel(name)
    }
}
