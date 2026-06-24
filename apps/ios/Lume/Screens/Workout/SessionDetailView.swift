import SwiftData
import SwiftUI

/// Détail d'une séance passée : exercices, séries (poids × reps · RPE), 1RM, et suppression.
struct SessionDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @Query(sort: \WorkoutSessionModel.date, order: .reverse) private var allSessions: [WorkoutSessionModel]
    @AppStorage(WeightFormat.defaultsKey) private var useImperial = false
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

    private var comparison: SessionComparison {
        SessionComparison(session: session, allSessions: allSessions)
    }

    var body: some View {
        let cmp = comparison // calculé une seule fois par rendu
        return ScrollView {
            VStack(spacing: Spacing.lg) {
                header
                HStack(spacing: Spacing.md) {
                    StatTile(icon: .restTimer, tint: LumeColor.fat, value: "\(session.durationSec / 60)", label: "minutes")
                    StatTile(icon: .oneRepMax, tint: LumeColor.carbs, value: WeightFormat.load(totalVolume, imperial: useImperial), label: "soulevés")
                    StatTile(icon: .addSet, tint: LumeColor.success, value: "\(setCount)", label: setCount > 1 ? "séries" : "série")
                }
                if !session.note.isEmpty { noteCard }
                if cmp.hasComparison { comparisonCard(cmp) }
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

    private var noteCard: some View {
        LumeCard {
            HStack(alignment: .top, spacing: Spacing.md) {
                Image(appIcon: .edit).lumeIcon(14, weight: .semibold).foregroundStyle(LumeColor.muted)
                Text(session.note).font(.lumeSubhead).foregroundStyle(LumeColor.ink)
                Spacer(minLength: 0)
            }
        }
    }

    private func comparisonCard(_ c: SessionComparison) -> some View {
        LumeCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("vs séance précédente").font(.lumeFootnote).foregroundStyle(LumeColor.muted)
                // Volume.
                HStack {
                    Text("Volume").font(.lumeSubhead).foregroundStyle(LumeColor.textSecondary)
                    Spacer()
                    deltaLabel(convertLoad(c.volumeDelta), unit: WeightFormat.unit(imperial: useImperial))
                }
                // 1RM par exercice (limité aux 3 plus marquants).
                ForEach(c.oneRMDeltas.sorted { abs($0.delta) > abs($1.delta) }.prefix(3), id: \.exercise) { item in
                    HStack {
                        Text(item.exercise).font(.lumeSubhead).foregroundStyle(LumeColor.textSecondary).lineLimit(1)
                        Spacer()
                        deltaLabel(convertLoad(item.delta), unit: "\(WeightFormat.unit(imperial: useImperial)) 1RM")
                    }
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Convertit une charge (kg → unité d'affichage), en gardant le signe.
    private func convertLoad(_ kg: Int) -> Int {
        useImperial ? Int((Double(kg) * WeightFormat.lbPerKg).rounded()) : kg
    }

    /// Pastille de variation : verte si gain, rouge si baisse, neutre si égal.
    private func deltaLabel(_ delta: Int, unit: String) -> some View {
        let tint: Color = delta > 0 ? LumeColor.success : (delta < 0 ? LumeColor.negative : LumeColor.muted)
        let sign = delta > 0 ? "+" : ""
        return Text("\(sign)\(delta) \(unit)")
            .font(.lumeSubhead.weight(.semibold)).foregroundStyle(tint).monospacedDigit()
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
                            Text(WeightFormat.load(ex.bestOneRM, imperial: useImperial)).font(.lumeCallout.weight(.bold)).foregroundStyle(LumeColor.ink)
                            Text("1RM est.").font(.lumeCaption).foregroundStyle(LumeColor.muted)
                        }
                    }
                }
                ForEach(Array(ex.orderedSets.enumerated()), id: \.element.id) { i, set in
                    HStack {
                        Text("Série \(i + 1)").font(.lumeSubhead).foregroundStyle(LumeColor.textSecondary)
                        Spacer()
                        Text("\(WeightFormat.loadDecimal(set.weight, imperial: useImperial)) × \(set.reps)" + (set.rpe.map { " · RPE \($0)" } ?? ""))
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
