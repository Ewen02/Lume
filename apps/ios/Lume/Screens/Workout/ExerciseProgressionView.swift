import Charts
import SwiftData
import SwiftUI

struct ExerciseProgressionView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \WorkoutSessionModel.date) private var sessions: [WorkoutSessionModel]

    let exerciseName: String
    init(exerciseName: String = "Développé couché") {
        self.exerciseName = exerciseName
    }

    /// Points 1RM réels (un par séance contenant l'exercice) ; repli démo si < 2 points.
    private var data: [PRPoint] {
        let real = sessions.compactMap { sess -> PRPoint? in
            guard let ex = sess.orderedExercises.first(where: { $0.name == exerciseName }), ex.bestOneRM > 0
            else { return nil }
            return PRPoint(date: sess.date, oneRM: Double(ex.bestOneRM))
        }.sorted { $0.date < $1.date }
        return real.count >= 2 ? real : Mock.benchPR
    }

    private var lastSets: [String] {
        guard let ex = sessions.sorted(by: { $0.date > $1.date })
            .compactMap({ $0.orderedExercises.first(where: { $0.name == exerciseName }) }).first
        else { return ["75 kg × 8 · RPE 9", "70 kg × 10 · RPE 8", "60 kg × 12 · RPE 7"] }
        return ex.orderedSets.map { s in
            "\(Int(s.weight)) kg × \(s.reps)" + (s.rpe.map { " · RPE \($0)" } ?? "")
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(exerciseName).font(.lumeDisplay).foregroundStyle(LumeColor.ink)
                    Text("Progression du 1RM estimé").font(.lumeSubhead).foregroundStyle(LumeColor.muted)
                }.frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: Spacing.md) {
                    StatTile(icon: .pr, tint: LumeColor.protein, value: "\(Int(data.last!.oneRM)) kg", label: "1RM actuel")
                    StatTile(icon: .progress, tint: LumeColor.success,
                             value: "+\(Int(data.last!.oneRM - data.first!.oneRM)) kg", label: "Depuis le début")
                }

                LumeCard {
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        Text("Courbe 1RM").font(.lumeHeadline).foregroundStyle(LumeColor.ink)
                        Chart(data) { p in
                            AreaMark(x: .value("Date", p.date), y: .value("kg", p.oneRM))
                                .interpolationMethod(.catmullRom)
                                .foregroundStyle(LinearGradient(colors: [LumeColor.protein.opacity(0.2), .clear], startPoint: .top, endPoint: .bottom))
                            LineMark(x: .value("Date", p.date), y: .value("kg", p.oneRM))
                                .interpolationMethod(.catmullRom)
                                .foregroundStyle(LumeColor.protein).lineStyle(.init(lineWidth: 2.5))
                        }
                        .chartYScale(domain: (data.map(\.oneRM).min()! - 4) ... (data.map(\.oneRM).max()! + 4))
                        .chartXAxis(.hidden)
                        .frame(height: 180)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }

                SectionHeader(title: "Dernières séries")
                ForEach(lastSets, id: \.self) { s in
                    HStack {
                        Text(s).font(.lumeCallout).foregroundStyle(LumeColor.ink)
                        Spacer()
                        Text("récent").font(.lumeFootnote).foregroundStyle(LumeColor.muted)
                    }
                    .padding(Spacing.lg - 2).background(LumeColor.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)).lumeShadow(.soft)
                }
            }.padding(.horizontal, Spacing.xl).padding(.bottom, Spacing.xxl)
        }
        .background(LumeColor.cream.ignoresSafeArea())
        .safeAreaInset(edge: .top) {
            TopBar(title: "Progression", leading: .back, onLeading: { dismiss() })
                .padding(.horizontal, Spacing.xl).padding(.vertical, Spacing.sm).background(LumeColor.cream)
        }
    }
}

#Preview { ExerciseProgressionView().modelContainer(LumeStore.preview) }
