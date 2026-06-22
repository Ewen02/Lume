import SwiftUI

/// Feuille d'édition du nom d'un repas, au design Lume.
struct MealRenameSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @FocusState private var focused: Bool
    var onSave: (String) -> Void

    init(currentName: String, onSave: @escaping (String) -> Void) {
        _name = State(initialValue: currentName)
        self.onSave = onSave
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            Image(appIcon: .edit)
                .lumeIcon(28, weight: .semibold).foregroundStyle(LumeColor.ink)
                .frame(width: 60, height: 60)
                .background(LumeColor.faint, in: Circle())
                .padding(.top, Spacing.xl).padding(.bottom, Spacing.lg)

            Text("Nom du repas").font(.lumeTitle).foregroundStyle(LumeColor.ink)
                .padding(.bottom, Spacing.lg)

            TextField("Ex. Burger maison", text: $name)
                .font(.lumeHeadline).foregroundStyle(LumeColor.ink)
                .multilineTextAlignment(.center)
                .focused($focused)
                .submitLabel(.done)
                .onSubmit { save() }
                .padding(.vertical, Spacing.md).padding(.horizontal, Spacing.lg)
                .background(LumeColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Radius.md).stroke(LumeColor.border, lineWidth: 1))
                .padding(.bottom, Spacing.xl)

            Button { save() } label: {
                Text("Enregistrer").font(.lumeCallout.weight(.bold))
                    .foregroundStyle(LumeColor.surface)
                    .frame(maxWidth: .infinity).frame(height: 56)
                    .background(canSave ? LumeColor.ink : LumeColor.muted)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            }
            .buttonStyle(.lumePress)
            .disabled(!canSave)
            .padding(.bottom, Spacing.sm)

            Button { dismiss() } label: {
                Text("Annuler").font(.lumeCallout.weight(.semibold))
                    .foregroundStyle(LumeColor.muted)
                    .frame(maxWidth: .infinity).frame(height: 48)
            }
            .buttonStyle(.lumePress)
        }
        .padding(.horizontal, Spacing.xl).padding(.bottom, Spacing.md)
        .frame(maxWidth: .infinity)
        .background(LumeColor.cream)
        .presentationDetents([.height(380)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(Radius.xxl + 6)
        .presentationBackground(LumeColor.cream)
        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { focused = true } }
    }

    private func save() {
        guard canSave else { return }
        onSave(name)
        dismiss()
    }
}

#Preview {
    Text("fond").sheet(isPresented: .constant(true)) {
        MealRenameSheet(currentName: "Repas scanné") { _ in }
    }
}
