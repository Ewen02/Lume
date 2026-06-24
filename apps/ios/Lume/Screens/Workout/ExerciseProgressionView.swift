import SwiftData
import SwiftUI

struct ExerciseProgressionView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(WeightFormat.defaultsKey) private var useImperial = false
    @Query(sort: \WorkoutSessionModel.date) private var sessions: [WorkoutSessionModel]

    let exerciseName: String
    init(exerciseName: String = "Développé couché") {
        self.exerciseName = exerciseName
    }

    /// Points 1RM réels (un par séance contenant l'exercice). Aucun repli : vide si pas de données.
    private var data: [PRPoint] {
        sessions.compactMap { sess -> PRPoint? in
            guard let ex = sess.orderedExercises.first(where: { $0.name == exerciseName }), ex.bestOneRM > 0
            else { return nil }
            return PRPoint(date: sess.date, oneRM: Double(ex.bestOneRM))
        }.sorted { $0.date < $1.date }
    }

    /// Points 1RM en points de graphe (pour InteractiveLineChart : scrub + axe + valeur).
    private var oneRMPoints: [ChartPoint] {
        data.map { ChartPoint(date: $0.date, value: Int($0.oneRM.rounded())) }
    }

    /// Dernières séries réellement enregistrées pour cet exercice (vide si aucune).
    private var lastSets: [String] {
        guard let ex = sessions.sorted(by: { $0.date > $1.date })
            .compactMap({ $0.orderedExercises.first(where: { $0.name == exerciseName }) }).first
        else { return [] }
        return ex.orderedSets.map { s in
            "\(WeightFormat.loadDecimal(s.weight, imperial: useImperial)) × \(s.reps)" + (s.rpe.map { " · RPE \($0)" } ?? "")
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(exerciseName).font(.lumeDisplay).foregroundStyle(LumeColor.ink)
                    Text("Progression du 1RM estimé").font(.lumeSubhead).foregroundStyle(LumeColor.muted)
                }.frame(maxWidth: .infinity, alignment: .leading)

                if data.count >= 2 {
                    chartContent
                } else {
                    LumeEmptyState(icon: .oneRepMax, title: "Pas encore de données",
                                   message: "Enregistre au moins 2 séances avec « \(exerciseName) » pour voir ta courbe de progression.")
                        .padding(.top, Spacing.xl)
                }
            }.padding(.horizontal, Spacing.xl).padding(.bottom, Spacing.xxl)
        }
        .background(LumeColor.cream.ignoresSafeArea())
        .safeAreaInset(edge: .top) {
            TopBar(title: "Progression", leading: .back, onLeading: { dismiss() })
                .padding(.horizontal, Spacing.xl).padding(.vertical, Spacing.sm).background(LumeColor.cream)
        }
    }

    @ViewBuilder
    private var chartContent: some View {
        if let first = data.first, let last = data.last {
            HStack(spacing: Spacing.md) {
                StatTile(icon: .pr, tint: LumeColor.protein, value: WeightFormat.load(Int(last.oneRM), imperial: useImperial), label: "1RM actuel")
                StatTile(icon: .progress, tint: LumeColor.success,
                         value: "+" + WeightFormat.load(Int(last.oneRM - first.oneRM), imperial: useImperial), label: "Depuis le début")
            }
        }

        LumeCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Courbe 1RM").font(.lumeHeadline).foregroundStyle(LumeColor.ink)
                InteractiveLineChart(points: oneRMPoints,
                                     format: { WeightFormat.load($0, imperial: useImperial) })
                    .accessibilityLabel("Progression du 1RM estimé")
            }.frame(maxWidth: .infinity, alignment: .leading)
        }

        if !lastSets.isEmpty {
            SectionHeader(title: "Dernières séries")
            ForEach(lastSets, id: \.self) { s in
                HStack {
                    Text(s).font(.lumeCallout).foregroundStyle(LumeColor.ink)
                    Spacer()
                }
                .padding(Spacing.lg - 2).background(LumeColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)).lumeShadow(.soft)
            }
        }
    }
}

#Preview { ExerciseProgressionView().modelContainer(LumeStore.preview) }
