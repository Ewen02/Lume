import SwiftData
import SwiftUI

/// Détail d'une séance passée : exercices, séries (poids × reps · RPE), 1RM, et suppression.
struct SessionDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    let session: WorkoutSessionModel
    @State private var confirmDelete = false

    private var totalVolume: Int {
        session.orderedExercises.reduce(0) { acc, ex in
            acc + ex.orderedSets.reduce(0) { $0 + Int($1.weight) * $1.reps }
        }
    }

    private var setCount: Int {
        session.orderedExercises.reduce(0) { $0 + $1.orderedSets.count }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                header
                HStack(spacing: Spacing.md) {
                    StatTile(icon: .restTimer, tint: LumeColor.fat, value: "\(session.durationSec / 60)", label: "minutes")
                    StatTile(icon: .oneRepMax, tint: LumeColor.carbs, value: "\(totalVolume)", label: "kg soulevés")
                    StatTile(icon: .addSet, tint: LumeColor.success, value: "\(setCount)", label: setCount > 1 ? "séries" : "série")
                }
                ForEach(session.orderedExercises) { ex in exerciseCard(ex) }
            }
            .padding(.horizontal, Spacing.xl).padding(.top, Spacing.sm).padding(.bottom, Spacing.xxl)
        }
        .background(LumeColor.cream.ignoresSafeArea())
        .safeAreaInset(edge: .top) {
            TopBar(title: "Séance", leading: .back, trailing: .trash,
                   onLeading: { dismiss() }, onTrailing: { confirmDelete = true })
                .padding(.horizontal, Spacing.xl).padding(.vertical, Spacing.sm).background(LumeColor.cream)
        }
        .confirmationDialog("Supprimer cette séance ?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Supprimer", role: .destructive) {
                ctx.delete(session)
                dismiss()
            }
            Button("Annuler", role: .cancel) {}
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(session.title).font(.lumeDisplay).foregroundStyle(LumeColor.ink)
            Text(Formatters.relative(session.date)).font(.lumeSubhead).foregroundStyle(LumeColor.muted)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private func exerciseCard(_ ex: LoggedExerciseModel) -> some View {
        LumeCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(ex.name).font(.lumeHeadline).foregroundStyle(LumeColor.ink)
                        MusclePill(group: ex.muscle)
                    }
                    Spacer()
                    if ex.bestOneRM > 0 {
                        VStack(alignment: .trailing, spacing: 1) {
                            Text("\(ex.bestOneRM) kg").font(.lumeCallout.weight(.bold)).foregroundStyle(LumeColor.ink)
                            Text("1RM est.").font(.lumeCaption).foregroundStyle(LumeColor.muted)
                        }
                    }
                }
                ForEach(Array(ex.orderedSets.enumerated()), id: \.element.id) { i, set in
                    HStack {
                        Text("Série \(i + 1)").font(.lumeSubhead).foregroundStyle(LumeColor.textSecondary)
                        Spacer()
                        Text("\(set.weight.clean) kg × \(set.reps)" + (set.rpe.map { " · RPE \($0)" } ?? ""))
                            .font(.lumeCallout).foregroundStyle(LumeColor.ink).monospacedDigit()
                    }
                    if i < ex.orderedSets.count - 1 { Divider().background(LumeColor.border) }
                }
            }
        }
    }
}

#Preview {
    SessionDetailView(session: WorkoutSessionModel(date: Date(), durationSec: 2535, title: "Push"))
        .modelContainer(LumeStore.preview)
}
