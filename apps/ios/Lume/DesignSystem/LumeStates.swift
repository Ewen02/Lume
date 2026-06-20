import SwiftUI

/// État vide homogène (liste ou écran sans contenu).
struct LumeEmptyState: View {
    var icon: AppIcon
    var title: String
    var message: String? = nil
    var body: some View {
        VStack(spacing: Spacing.sm) {
            Image(appIcon: icon).lumeIcon(28, weight: .semibold).foregroundStyle(LumeColor.muted)
            Text(title).font(.lumeCallout).foregroundStyle(LumeColor.textSecondary)
            if let message {
                Text(message).font(.lumeFootnote).foregroundStyle(LumeColor.muted)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity).padding(.vertical, Spacing.xxl)
    }
}

/// État de chargement homogène.
struct LumeLoadingState: View {
    var label: String = "Chargement…"
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
    var title: String = "Une erreur est survenue"
    var message: String? = nil
    var retry: (() -> Void)? = nil
    var body: some View {
        LumeCard(padding: Spacing.xxl, radius: Radius.xxl) {
            VStack(spacing: Spacing.md) {
                Image(systemName: "wifi.exclamationmark").lumeIcon(28, weight: .regular).foregroundStyle(LumeColor.muted)
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
