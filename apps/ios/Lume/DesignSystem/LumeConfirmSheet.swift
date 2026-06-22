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

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Image(appIcon: icon)
                .lumeIcon(32, weight: .semibold).foregroundStyle(tint)
                .frame(width: 64, height: 64)
                .background(tint.opacity(0.12), in: Circle())
                .padding(.top, Spacing.xl)

            VStack(spacing: Spacing.xs) {
                Text(title).font(.lumeTitle3).foregroundStyle(LumeColor.ink)
                    .multilineTextAlignment(.center)
                Text(message).font(.lumeSubhead).foregroundStyle(LumeColor.muted)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Spacing.lg)

            Spacer(minLength: 0)

            VStack(spacing: Spacing.sm) {
                Button {
                    onConfirm()
                    dismiss()
                } label: {
                    Text(confirmTitle).font(.lumeCallout.weight(.semibold))
                        .foregroundStyle(LumeColor.surface)
                        .frame(maxWidth: .infinity).frame(height: 54)
                        .background(isDestructive ? LumeColor.negative : LumeColor.ink)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                }
                .buttonStyle(.lumePress)

                Button { dismiss() } label: {
                    Text("Annuler").font(.lumeCallout.weight(.semibold))
                        .foregroundStyle(LumeColor.ink)
                        .frame(maxWidth: .infinity).frame(height: 54)
                        .background(LumeColor.surface)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                }
                .buttonStyle(.lumePress)
            }
        }
        .padding(.horizontal, Spacing.xl).padding(.bottom, Spacing.xl)
        .frame(maxWidth: .infinity)
        .background(LumeColor.cream.ignoresSafeArea())
        .presentationDetents([.height(380)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(Radius.xxl)
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
