import SwiftData
import SwiftUI

struct RoutineDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var matches: [RoutineModel]
    @State private var start = false
    @State private var showEdit = false

    /// Routine (snapshot d'entrée) + lookup du modèle persistant par id pour l'édition/rafraîchissement.
    private let fallback: Routine

    init(routine: Routine) {
        fallback = routine
        let rid = routine.id
        _matches = Query(filter: #Predicate<RoutineModel> { $0.id == rid })
    }

    /// Le modèle persistant si trouvé (permet l'édition), sinon nil (preview/Mock).
    private var model: RoutineModel? {
        matches.first
    }

    /// Données affichées : le modèle à jour si présent, sinon le snapshot d'entrée.
    private var routine: Routine {
        model?.asRoutine ?? fallback
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(routine.name).font(.lumeDisplay).foregroundStyle(LumeColor.ink)
                        Text(routine.muscles).font(.lumeSubhead).foregroundStyle(LumeColor.muted)
                    }.frame(maxWidth: .infinity, alignment: .leading)

                    ForEach(routine.exercises) { ex in
                        HStack(spacing: Spacing.md) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(ex.exercise.name).font(.lumeCallout).foregroundStyle(LumeColor.ink)
                                MusclePill(group: ex.exercise.primary)
                            }
                            Spacer()
                            Text("\(ex.targetSets) × \(ex.targetReps)")
                                .font(.lumeSubhead.weight(.semibold)).foregroundStyle(LumeColor.textSecondary)
                        }
                        .padding(Spacing.lg - 2)
                        .background(LumeColor.surface)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
                        .lumeShadow(.soft)
                    }
                }.padding(.horizontal, Spacing.xl).padding(.bottom, 100)
            }
            PrimaryButton(title: "Démarrer la séance", icon: .workout) { start = true }
                .padding(.horizontal, Spacing.xl).padding(.bottom, Spacing.sm)
        }
        .background(LumeColor.cream.ignoresSafeArea())
        .safeAreaInset(edge: .top) {
            // Bouton « éditer » seulement si la routine est persistée (pas en preview/Mock).
            TopBar(title: "Routine", leading: .back, trailing: model != nil ? .edit : nil,
                   onLeading: { dismiss() }, onTrailing: { showEdit = true })
                .padding(.horizontal, Spacing.xl).padding(.vertical, Spacing.sm).background(LumeColor.cream)
        }
        .sheet(isPresented: $start) {
            ActiveSessionView(title: routine.name, prefill: routine.emptySession)
        }
        .sheet(isPresented: $showEdit) {
            if let model { RoutineEditorView(editing: model) }
        }
    }
}

#Preview { RoutineDetailView(routine: Mock.pushRoutine).modelContainer(LumeStore.preview) }
