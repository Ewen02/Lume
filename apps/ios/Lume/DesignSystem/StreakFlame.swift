import SwiftUI

/// Flamme animée dont la taille et l'intensité augmentent avec la longueur du streak.
/// Vacille en continu ; un palier de couleur/halo se débloque à mesure que la série monte.
struct StreakFlame: View {
    var streak: Int
    var size: CGFloat = 28
    var animated: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var flicker = false

    /// Échelle 0→1 selon le streak (plateau à 30 jours) → pilote taille et halo.
    private var intensity: CGFloat {
        min(CGFloat(streak) / 30, 1)
    }

    /// Couleur de la flamme : orange → rouge vif à mesure que la série monte.
    private var flameColor: Color {
        switch streak {
        case 0 ..< 3: LumeColor.warning
        case 3 ..< 7: LumeColor.carbs
        case 7 ..< 14: LumeColor.protein
        default: LumeColor.negative
        }
    }

    private var glowRadius: CGFloat {
        4 + intensity * 16
    }

    private var scale: CGFloat {
        1 + intensity * 0.5
    }

    var body: some View {
        Image(appIcon: .streak)
            .lumeIcon(size, weight: .bold)
            .foregroundStyle(
                LinearGradient(colors: [flameColor, flameColor.opacity(0.7)],
                               startPoint: .bottom, endPoint: .top)
            )
            .scaleEffect(scale * (flicker ? 1.06 : 0.97), anchor: .bottom)
            .shadow(color: flameColor.opacity(0.6), radius: flicker ? glowRadius : glowRadius * 0.6)
            .onAppear {
                guard animated, !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                    flicker = true
                }
            }
    }
}

#Preview {
    HStack(spacing: 30) {
        ForEach([1, 5, 10, 30], id: \.self) { s in
            VStack { StreakFlame(streak: s, size: 40); Text("\(s) j").font(.lumeCaption) }
        }
    }
    .padding(40).background(LumeColor.cream)
}
