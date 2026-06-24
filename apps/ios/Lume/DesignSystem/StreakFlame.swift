import SwiftUI

/// Flamme animée vivante : vacille de façon organique, son dégradé/halo/taille s'intensifient
/// avec la série, et des étincelles montent pour les gros streaks.
struct StreakFlame: View {
    var streak: Int
    var size: CGFloat = 28
    var animated: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Échelle 0→1 selon le streak (plateau à 21 jours) → pilote taille, halo, étincelles.
    private var intensity: CGFloat {
        min(CGFloat(max(streak, 0)) / 21, 1)
    }

    // Pointes de flamme (highlights décoratifs du dégradé, hors palette sémantique).
    private static let flameTipHot = Color(hex: 0xFFD24A)
    private static let flameTipWarm = Color(hex: 0xFFC857)

    /// Dégradé de feu : base chaude (rouge/orange) → pointe jaune, qui s'intensifie avec la série.
    private var fireGradient: LinearGradient {
        let base: Color = switch streak {
        case 0 ..< 3: LumeColor.warning
        case 3 ..< 7: LumeColor.carbs
        case 7 ..< 14: LumeColor.protein
        default: LumeColor.negative
        }
        let tip = streak >= 7 ? Self.flameTipHot : Self.flameTipWarm
        return LinearGradient(colors: [base, base.opacity(0.95), tip],
                              startPoint: .bottom, endPoint: .top)
    }

    private var glowColor: Color {
        streak >= 14 ? LumeColor.negative : LumeColor.protein
    }

    var body: some View {
        if animated, !reduceMotion {
            TimelineView(.animation) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                flame(at: t)
            }
        } else {
            flame(at: 0)
        }
    }

    @ViewBuilder
    private func flame(at t: TimeInterval) -> some View {
        // Vacillement organique : 2 sinusoïdes désynchronisées (taille + bascule).
        let breathe = 1 + 0.06 * sin(t * 6.2) + 0.03 * sin(t * 11.0)
        let sway = 2.5 * sin(t * 4.0)
        let glowPulse = 0.5 + 0.5 * (0.5 + 0.5 * sin(t * 5.0))
        let baseScale = 1 + intensity * 0.45

        ZStack {
            // Étincelles qui montent (pour les séries établies).
            if streak >= 7 {
                ForEach(0 ..< 3, id: \.self) { i in
                    spark(index: i, t: t)
                }
            }
            Image(appIcon: .streak)
                .lumeIcon(size, weight: .bold)
                .foregroundStyle(fireGradient)
                .scaleEffect(x: baseScale * (2 - breathe), y: baseScale * breathe, anchor: .bottom)
                .rotationEffect(.degrees(sway), anchor: .bottom)
                .shadow(color: glowColor.opacity(0.5 + intensity * 0.3),
                        radius: (4 + intensity * 14) * glowPulse)
        }
    }

    /// Une étincelle qui s'élève en boucle (timing décalé par index).
    private func spark(index: Int, t: TimeInterval) -> some View {
        let period = 1.6
        let phase = (t / period + Double(index) * 0.33).truncatingRemainder(dividingBy: 1)
        let rise = CGFloat(phase) // 0 (bas) → 1 (haut)
        let xJitter = sin((t + Double(index)) * 3) * size * 0.18
        return Circle()
            .fill(Self.flameTipHot)
            .frame(width: size * 0.1, height: size * 0.1)
            .offset(x: xJitter, y: -size * 0.4 - rise * size * 0.9)
            .opacity((1 - rise) * 0.9)
    }
}

#Preview {
    HStack(spacing: 30) {
        ForEach([1, 5, 10, 30], id: \.self) { s in
            VStack { StreakFlame(streak: s, size: 44); Text("\(s) j").font(.lumeCaption) }
        }
    }
    .padding(40).background(LumeColor.cream)
}
