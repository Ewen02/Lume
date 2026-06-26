import SwiftUI

/// Barre de progression d'onboarding : barre pleine épaisse + compteur « Étape X sur N ».
/// Le remplissage s'anime à chaque changement d'étape (Reduce Motion respecté via l'appelant).
struct OnboardingProgress: View {
    /// Index de l'étape courante (1...total). 0 = avant la 1re étape comptée.
    var step: Int
    var total: Int

    private var fraction: Double {
        guard total > 0 else { return 0 }
        return min(1, max(0, Double(step) / Double(total)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Étape \(min(step, total)) sur \(total)")
                .font(.lumeFootnote).foregroundStyle(LumeColor.muted)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(LumeColor.faint)
                    Capsule().fill(LumeColor.ink)
                        .frame(width: fraction * geo.size.width)
                }
            }
            .frame(height: 10)
        }
    }
}

#Preview {
    VStack(spacing: Spacing.xl) {
        OnboardingProgress(step: 1, total: 6)
        OnboardingProgress(step: 3, total: 6)
        OnboardingProgress(step: 6, total: 6)
    }
    .padding()
    .background(LumeColor.cream)
}
