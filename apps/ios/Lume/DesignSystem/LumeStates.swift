import SwiftUI

/// État vide homogène (liste ou écran sans contenu), avec action optionnelle (CTA).
struct LumeEmptyState: View {
    var icon: AppIcon
    var title: LocalizedStringKey
    var message: LocalizedStringKey? = nil
    /// Bouton d'action optionnel (titre + closure) : un état vide actionnable plutôt qu'un cul-de-sac.
    var actionTitle: LocalizedStringKey? = nil
    var action: (() -> Void)? = nil
    var body: some View {
        VStack(spacing: Spacing.sm) {
            Image(appIcon: icon).lumeIcon(28, weight: .semibold).foregroundStyle(LumeColor.muted)
            Text(title).font(.lumeCallout).foregroundStyle(LumeColor.textSecondary)
            if let message {
                Text(message).font(.lumeFootnote).foregroundStyle(LumeColor.muted)
                    .multilineTextAlignment(.center)
            }
            if let actionTitle, let action {
                PrimaryButton(title: actionTitle, icon: .add, action: action)
                    .padding(.top, Spacing.sm).padding(.horizontal, Spacing.xl)
            }
        }
        .frame(maxWidth: .infinity).padding(.vertical, Spacing.xxl)
    }
}

/// État de chargement homogène.
struct LumeLoadingState: View {
    var label: LocalizedStringKey = "Chargement…"
    var body: some View {
        LumeCard(padding: Spacing.xxl, radius: Radius.xxl) {
            VStack(spacing: Spacing.md) {
                ProgressView().controlSize(.large)
                Text(label).font(.lumeSubhead).foregroundStyle(LumeColor.muted)
            }.frame(maxWidth: .infinity)
        }
    }
}

/// État d'erreur homogène, avec action de réessai optionnelle.
struct LumeErrorState: View {
    var title: LocalizedStringKey = "Une erreur est survenue"
    var message: String? = nil
    var retry: (() -> Void)? = nil
    var body: some View {
        LumeCard(padding: Spacing.xxl, radius: Radius.xxl) {
            VStack(spacing: Spacing.md) {
                Image(appIcon: .wifiError).lumeIcon(28, weight: .regular).foregroundStyle(LumeColor.muted)
                Text(title).font(.lumeCallout).foregroundStyle(LumeColor.ink)
                if let message {
                    Text(message).font(.lumeFootnote).foregroundStyle(LumeColor.muted)
                        .multilineTextAlignment(.center)
                }
                if let retry { SecondaryButton(title: "Réessayer", action: retry) }
            }.frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Skeleton (chargement à la forme du contenu)

/// Effet de balayage lumineux (shimmer) appliqué à un placeholder.
private struct ShimmerModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = -1
    func body(content: Content) -> some View {
        content.overlay(
            GeometryReader { geo in
                if !reduceMotion {
                    // Reflet adaptatif : un balayage blanc tranche trop sur un squelette sombre.
                    // En dark, un reflet plus doux (gris chaud translucide) reste subtil.
                    LinearGradient(colors: [.clear, Color(light: 0xFFFFFF, dark: 0x55524C).opacity(0.5), .clear],
                                   startPoint: .leading, endPoint: .trailing)
                        .frame(width: geo.size.width * 0.6)
                        .offset(x: phase * geo.size.width * 1.6)
                        .onAppear {
                            withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
                                phase = 1
                            }
                        }
                }
            }
        )
        .clipped()
    }
}

private extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

/// Ligne fantôme imitant une carte d'aliment, affichée pendant le chargement.
struct LumeSkeletonRow: View {
    var body: some View {
        HStack(spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                bar(width: 150, height: 14)
                bar(width: 90, height: 10)
            }
            Spacer()
            bar(width: 54, height: 14)
        }
        .padding(.horizontal, Spacing.lg - 2).padding(.vertical, Spacing.md + 2)
        .background(LumeColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .lumeShadow(.soft)
        .shimmer()
    }

    private func bar(width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: height / 2, style: .continuous)
            .fill(LumeColor.faint)
            .frame(width: width, height: height)
    }
}

/// Plusieurs lignes fantômes empilées (liste en cours de chargement).
struct LumeSkeletonList: View {
    var count: Int = 4
    var body: some View {
        VStack(spacing: Spacing.md) {
            ForEach(0 ..< count, id: \.self) { _ in LumeSkeletonRow() }
        }
    }
}
