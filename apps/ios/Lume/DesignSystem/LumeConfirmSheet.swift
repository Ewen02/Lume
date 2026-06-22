import SwiftUI

/// Feuille de confirmation au design Lume (alternative au confirmationDialog natif).
/// Présentée par le bas, fond crème, action destructive claire + annulation.
struct LumeConfirmSheet: View {
    @Environment(\.dismiss) private var dismiss
    var icon: AppIcon
    var tint: Color
    var title: String
    var message: String
    var confirmTitle: String
    var isDestructive: Bool = true
    var onConfirm: () -> Void

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            // Icône en pastille, légère apparition.
            Image(appIcon: icon)
                .lumeIcon(30, weight: .semibold).foregroundStyle(tint)
                .frame(width: 60, height: 60)
                .background(tint.opacity(0.14), in: Circle())
                .overlay(Circle().stroke(tint.opacity(0.18), lineWidth: 1))
                .scaleEffect(appeared ? 1 : 0.6)
                .padding(.top, Spacing.xl)
                .padding(.bottom, Spacing.lg)

            Text(title).font(.lumeTitle).foregroundStyle(LumeColor.ink)
                .multilineTextAlignment(.center)
                .padding(.bottom, Spacing.xs)
            Text(message).font(.lumeSubhead).foregroundStyle(LumeColor.muted)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.horizontal, Spacing.md)
                .padding(.bottom, Spacing.xl)

            // Action principale : pleine largeur, bien visible.
            Button {
                onConfirm()
                dismiss()
            } label: {
                Text(confirmTitle).font(.lumeCallout.weight(.bold))
                    .foregroundStyle(LumeColor.surface)
                    .frame(maxWidth: .infinity).frame(height: 56)
                    .background(isDestructive ? LumeColor.negative : LumeColor.ink)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
                    .shadow(color: (isDestructive ? LumeColor.negative : LumeColor.ink).opacity(0.25),
                            radius: 12, y: 6)
            }
            .buttonStyle(.lumePress)
            .padding(.bottom, Spacing.sm)

            // Annulation : discrète (texte seul), ne concurrence pas l'action principale.
            Button { dismiss() } label: {
                Text("Annuler").font(.lumeCallout.weight(.semibold))
                    .foregroundStyle(LumeColor.muted)
                    .frame(maxWidth: .infinity).frame(height: 48)
            }
            .buttonStyle(.lumePress)
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.bottom, Spacing.md)
        .frame(maxWidth: .infinity)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(LumeColor.cream)
        // Hauteur ajustée au contenu (court) — plus de grand trou vide.
        .presentationDetents([.height(360)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(Radius.xxl + 6)
        .presentationBackground(LumeColor.cream)
        .onAppear { withAnimation(LumeMotion.celebrate) { appeared = true } }
    }
}

#Preview {
    Text("fond").sheet(isPresented: .constant(true)) {
        LumeConfirmSheet(icon: .minusCircle, tint: LumeColor.negative,
                         title: "Supprimer ce repas ?",
                         message: "4 aliments seront retirés du journal.",
                         confirmTitle: "Supprimer le repas") {}
    }
}
