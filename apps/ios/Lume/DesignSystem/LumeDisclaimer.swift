import SwiftUI

/// Avertissement discret (footnote + icône) pour les mentions légales/sécurité : disclaimer médical,
/// fiabilité de l'IA… Non bloquant, ton informatif. À placer en bas d'un écran ou sous un résultat.
struct LumeDisclaimer: View {
    var icon: AppIcon = .info
    var text: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(appIcon: icon).lumeIcon(13, weight: .semibold).foregroundStyle(LumeColor.muted)
                .padding(.top, 1)
            Text(text)
                .font(.lumeFootnote).foregroundStyle(LumeColor.muted)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.xs)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    VStack(spacing: Spacing.lg) {
        LumeDisclaimer(text: "Lume fournit des estimations à titre informatif et ne remplace pas un avis médical.")
        LumeDisclaimer(icon: .warning, text: "Les valeurs sont estimées par IA : vérifie-les avant d'ajouter.")
    }
    .padding()
    .background(LumeColor.cream)
}
