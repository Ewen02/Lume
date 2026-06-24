import SwiftData
import SwiftUI

/// Accueil muscu au 1er passage : laisse l'utilisateur choisir comment démarrer
/// (routines types / créer la sienne / partir à vide). Évite tout seed « en douce ».
struct WorkoutSetupView: View {
    @Environment(\.modelContext) private var ctx
    @Query private var routines: [RoutineModel]
    /// Bascule à true quand l'utilisateur a fait son choix (gère l'affichage côté WorkoutHomeView).
    @Binding var done: Bool
    @State private var showEditor = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Image(appIcon: .workout).lumeIcon(40, weight: .semibold).foregroundStyle(LumeColor.ink)
                        .padding(.bottom, Spacing.sm)
                    Text("Bienvenue dans Muscu").font(.lumeTitle).foregroundStyle(LumeColor.ink)
                    Text("Comment veux-tu démarrer ?").font(.lumeSubhead).foregroundStyle(LumeColor.muted)
                }
                .padding(.top, Spacing.xl)

                optionCard(icon: .routine, tint: LumeColor.protein,
                           title: "Routines types",
                           subtitle: "Push · Pull · Legs, prêtes à l'emploi et modifiables")
                {
                    seedDefaultRoutines(ctx)
                    finish()
                }

                optionCard(icon: .add, tint: LumeColor.success,
                           title: "Créer ma routine",
                           subtitle: "Compose ta première routine à partir de la bibliothèque")
                {
                    showEditor = true
                }

                optionCard(icon: .workout, tint: LumeColor.muted,
                           title: "Commencer à vide",
                           subtitle: "Lance des séances libres, crée tes routines plus tard")
                {
                    finish()
                }
            }
            .padding(.horizontal, Spacing.xl).padding(.bottom, Spacing.xxl)
        }
        .background(LumeColor.cream.ignoresSafeArea())
        .safeAreaInset(edge: .top) {
            Text("Muscu").font(.lumeDisplay).foregroundStyle(LumeColor.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.xl).padding(.vertical, Spacing.sm).background(LumeColor.cream)
        }
        // On ne quitte le setup que si une routine a VRAIMENT été créée (pas si on annule l'éditeur).
        .sheet(isPresented: $showEditor, onDismiss: { if !routines.isEmpty { finish() } }) { RoutineEditorView() }
    }

    private func finish() {
        withAnimation(LumeMotion.smooth) { done = true }
    }

    private func optionCard(icon: AppIcon, tint: Color, title: String, subtitle: String,
                            action: @escaping () -> Void) -> some View
    {
        Button(action: action) {
            LumeCard {
                HStack(spacing: Spacing.md) {
                    Image(appIcon: icon).lumeIcon(20, weight: .semibold).foregroundStyle(tint)
                        .frame(width: 48, height: 48).background(tint.opacity(0.14))
                        .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title).font(.lumeHeadline).foregroundStyle(LumeColor.ink)
                        Text(subtitle).font(.lumeFootnote).foregroundStyle(LumeColor.muted)
                    }
                    Spacer()
                    Image(appIcon: .forward).lumeIcon(14, weight: .semibold).foregroundStyle(LumeColor.muted)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
        }.buttonStyle(.lumePress)
    }
}

#Preview {
    WorkoutSetupView(done: .constant(false)).modelContainer(LumeStore.preview)
}
