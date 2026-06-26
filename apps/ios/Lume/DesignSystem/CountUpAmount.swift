import SwiftUI

/// Montant (centimes) qui « monte » de 0 à la cible à l'apparition, et se ré-anime quand la cible
/// change. Interpole la VALEUR via `animatableData` (la String n'est pas animable). Reduce Motion
/// respecté (apparition immédiate, sans animation).
///
/// `animatesOnChange` : si `false`, un changement de cible SAUTE à la nouvelle valeur sans count-up.
/// À utiliser quand la cible change pour une raison non « événementielle » (ex. navigation entre mois) :
/// rejouer un count-up de 0 donnerait un effet « slot-machine » sans rapport avec une vraie variation.
/// L'apparition initiale s'anime toujours (sauf Reduce Motion).
struct CountUpAmount: View {
    var targetCents: Int
    var font: Font = .lumeNumberL
    var tint: Color = LumeColor.ink
    var showSign: Bool = false
    var animatesOnChange: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var value: Double = 0

    var body: some View {
        AmountText(cents: value, font: font, tint: tint, showSign: showSign)
            .onAppear { animate(to: targetCents, animated: true) }
            .onChange(of: targetCents) { _, new in animate(to: new, animated: animatesOnChange) }
    }

    private func animate(to target: Int, animated: Bool) {
        if reduceMotion || !animated { value = Double(target) }
        else { withAnimation(.easeOut(duration: 0.6)) { value = Double(target) } }
    }

    private struct AmountText: View, Animatable {
        var cents: Double
        var font: Font
        var tint: Color
        var showSign: Bool
        var animatableData: Double {
            get { cents }
            set { cents = newValue }
        }

        var body: some View {
            Text(Money.format(Int(cents.rounded()), showSign: showSign))
                .font(font).foregroundStyle(tint).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.6)
        }
    }
}

#Preview {
    VStack(spacing: Spacing.lg) {
        CountUpAmount(targetCents: 162_000)
        CountUpAmount(targetCents: 86000, font: .lumeNumberXL, tint: LumeColor.success, showSign: true)
    }
    .padding()
    .background(LumeColor.cream)
}
