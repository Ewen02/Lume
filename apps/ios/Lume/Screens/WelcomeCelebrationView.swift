import SwiftUI

/// Célébration de fin d'onboarding : scelle le premier grand jalon d'activation par un moment
/// « bienvenue » chaleureux, juste avant d'entrer dans l'app (au lieu d'un basculement muet).
struct WelcomeCelebrationView: View {
    /// Prénom saisi (peut être vide) pour personnaliser l'accueil.
    let name: String
    /// Appelé quand l'utilisateur valide — l'appelant bascule alors dans l'app.
    var onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    private var greeting: LocalizedStringKey {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "Bienvenue dans Lume" : "Bienvenue, \(trimmed)"
    }

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            Image(appIcon: .calories)
                .lumeIcon(64, weight: .bold).foregroundStyle(LumeColor.protein)
                .scaleEffect(appeared ? 1 : 0.4)
                .rotationEffect(.degrees(appeared ? 0 : -20))

            VStack(spacing: Spacing.sm) {
                Text(greeting).font(.lumeTitle).foregroundStyle(LumeColor.ink)
                    .multilineTextAlignment(.center)
                Text("Tout est prêt. Photographie ton premier repas pour démarrer.")
                    .font(.lumeSubhead).foregroundStyle(LumeColor.muted)
                    .multilineTextAlignment(.center)
            }
            .scaleEffect(appeared ? 1 : 0.85)
            .opacity(appeared ? 1 : 0)

            Spacer()
            PrimaryButton(title: "C'est parti", icon: .validate) { onContinue() }
                .padding(.horizontal, Spacing.xl).padding(.bottom, Spacing.lg)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Spacing.xl)
        .background(LumeColor.cream.ignoresSafeArea())
        .presentationDetents([.large])
        .interactiveDismissDisabled()
        .onAppear { withAnimation(reduceMotion ? nil : LumeMotion.celebrate.delay(0.1)) { appeared = true } }
        .sensoryFeedback(.success, trigger: appeared)
    }
}

#Preview {
    WelcomeCelebrationView(name: "Ewen") {}
}
