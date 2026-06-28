import SwiftUI

/// Célébration plein écran de l'objectif de poids atteint — le sommet émotionnel de l'app.
/// Met en scène le delta parcouru (« −8 kg »), la durée du chemin et un message, avec une
/// médaille animée et un retour haptique synchronisé sur l'apparition (pas un simple burst).
struct WeightGoalCelebrationView: View {
    @Environment(\.dismiss) private var dismiss

    /// Poids de départ et poids cible atteint (kg), pour afficher le delta réellement parcouru.
    let startKg: Double
    let targetKg: Double
    /// Nombre de jours entre la première pesée et l'atteinte de l'objectif (0 si inconnu).
    let journeyDays: Int
    /// Affichage impérial (lb) si l'utilisateur l'a choisi.
    var imperial: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    /// Variation parcourue, signée (négative en perte, positive en prise).
    private var deltaKg: Double { targetKg - startKg }

    /// Libellé du delta (« −8 kg » / « +4 kg ») dans l'unité de l'utilisateur.
    private var deltaLabel: String {
        let sign = deltaKg <= 0 ? "−" : "+"
        return sign + WeightFormat.body(abs(deltaKg), imperial: imperial, decimals: 1)
    }

    private var journeyLabel: String? {
        guard journeyDays > 0 else { return nil }
        return String(localized: "en \(journeyDays) jours")
    }

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            // Médaille animée à l'apparition (scale + rotation), comme le récap de séance.
            Image(appIcon: .pr)
                .lumeIcon(64, weight: .bold).foregroundStyle(LumeColor.success)
                .scaleEffect(appeared ? 1 : 0.4)
                .rotationEffect(.degrees(appeared ? 0 : -25))

            VStack(spacing: Spacing.xs) {
                Text("Objectif atteint 🎉").font(.lumeTitle).foregroundStyle(LumeColor.ink)
                Text("Tu as atteint ton poids cible.").font(.lumeSubhead).foregroundStyle(LumeColor.muted)
            }

            // Le chiffre fort : le chemin parcouru.
            VStack(spacing: Spacing.xs) {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                    Text(deltaLabel).font(.lumeNumberXL).foregroundStyle(LumeColor.success).monospacedDigit()
                }
                if let journeyLabel {
                    Text(journeyLabel).font(.lumeSubhead).foregroundStyle(LumeColor.muted)
                }
            }
            .scaleEffect(appeared ? 1 : 0.8)

            // Récap départ → cible.
            HStack(spacing: Spacing.md) {
                StatTile(icon: .weight, tint: LumeColor.muted,
                         value: WeightFormat.body(startKg, imperial: imperial, decimals: 0), label: "Départ")
                StatTile(icon: .validate, tint: LumeColor.success,
                         value: WeightFormat.body(targetKg, imperial: imperial, decimals: 0), label: "Objectif")
            }
            .scaleEffect(appeared ? 1 : 0.8)

            Spacer()
            PrimaryButton(title: "Continuer", icon: .validate) { dismiss() }
                .padding(.horizontal, Spacing.xl).padding(.bottom, Spacing.lg)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Spacing.xl)
        .background(LumeColor.cream.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(Radius.xxl + 6)
        .onAppear { withAnimation(reduceMotion ? nil : LumeMotion.celebrate.delay(0.1)) { appeared = true } }
        // Haptique synchronisée sur l'animation (et non sur un booléen externe désynchronisé).
        .sensoryFeedback(.success, trigger: appeared)
    }
}

#Preview {
    WeightGoalCelebrationView(startKg: 82, targetKg: 74, journeyDays: 96)
}
