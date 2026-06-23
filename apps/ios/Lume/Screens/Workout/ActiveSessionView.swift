import SwiftData
import SwiftUI

struct ActiveSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @Environment(HealthManager.self) private var health

    let title: String
    @State private var sessions: [ExerciseSession]
    @State private var showRest = false
    @State private var showPlate = false
    @State private var showAddExercise = false
    @State private var startedAt = Date()
    @State private var finished = false
    @State private var summary: WorkoutSummary?

    init(title: String = "Séance libre", prefill: [ExerciseSession] = []) {
        self.title = title
        _sessions = State(initialValue: prefill)
    }

    private func finish() {
        let model = WorkoutSessionModel(date: startedAt,
                                        durationSec: Int(Date().timeIntervalSince(startedAt)),
                                        title: title)
        ctx.insert(model)
        for (i, sess) in sessions.enumerated() {
            let logged = sess.sets.filter { $0.reps > 0 }
            guard !logged.isEmpty else { continue }
            let ex = LoggedExerciseModel(name: sess.exercise.name,
                                         muscleRaw: sess.exercise.primary.code, order: i)
            ex.session = model
            ctx.insert(ex)
            for (j, set) in logged.enumerated() {
                let m = LoggedSetModel(reps: set.reps, weight: set.weight, rpe: set.rpe, order: j)
                m.exercise = ex
                ctx.insert(m)
            }
        }
        let start = startedAt, end = Date()
        Task { await health.saveWorkout(start: start, end: end) }
        finished = true
        // Récap gratifiant avant de fermer (volume, séries, meilleur 1RM).
        summary = WorkoutSummary(from: sessions, durationSec: Int(end.timeIntervalSince(start)))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    ForEach($sessions) { $session in
                        ExerciseSessionCard(session: $session)
                    }
                    Button { showAddExercise = true } label: {
                        HStack(spacing: Spacing.sm) {
                            Image(appIcon: .add).lumeIcon(16, weight: .semibold)
                            Text("Ajouter un exercice").font(.lumeCallout)
                        }.foregroundStyle(LumeColor.ink).frame(maxWidth: .infinity).padding(.vertical, Spacing.md)
                            .overlay(RoundedRectangle(cornerRadius: Radius.md).stroke(LumeColor.border, lineWidth: 1))
                    }.buttonStyle(.lumePress)
                    Button { showPlate = true } label: {
                        HStack(spacing: Spacing.sm) {
                            Image(appIcon: .plates).lumeIcon(16, weight: .semibold)
                            Text("Calculateur de disques").font(.lumeCallout)
                        }.foregroundStyle(LumeColor.ink).frame(maxWidth: .infinity).padding(.vertical, Spacing.md)
                            .overlay(RoundedRectangle(cornerRadius: Radius.md).stroke(LumeColor.border, lineWidth: 1))
                    }.buttonStyle(.lumePress)
                }.padding(.horizontal, Spacing.xl).padding(.bottom, 110)
            }
            PrimaryButton(title: "Terminer la séance", icon: .validate) { finish() }
                .padding(.horizontal, Spacing.xl).padding(.bottom, Spacing.sm)
        }
        .background(LumeColor.cream.ignoresSafeArea())
        .safeAreaInset(edge: .top) {
            HStack {
                Button { dismiss() } label: {
                    Image(appIcon: .close).lumeIcon(18, weight: .semibold).foregroundStyle(LumeColor.ink)
                        .frame(width: 40, height: 40).background(LumeColor.surface).clipShape(Circle()).lumeShadow(.soft)
                }.buttonStyle(.lumePress)
                Spacer()
                VStack(spacing: 0) {
                    Text(title).font(.lumeCaption).foregroundStyle(LumeColor.muted)
                    Text(elapsed).font(.lumeHeadline).foregroundStyle(LumeColor.ink).monospacedDigit()
                }
                Spacer()
                Button { showRest = true } label: { RestTimerPill(seconds: 84) }.buttonStyle(.lumePress)
            }
            .padding(.horizontal, Spacing.xl).padding(.vertical, Spacing.sm).background(LumeColor.cream)
        }
        .sheet(isPresented: $showRest) { RestTimerView().presentationDetents([.medium]) }
        .sheet(isPresented: $showPlate) { PlateCalculatorView() }
        .sheet(isPresented: $showAddExercise) {
            ExercisePickerView { exercise in
                sessions.append(ExerciseSession(exercise: exercise,
                                                sets: [SetEntry(reps: 10, weight: 20, rpe: nil)]))
                showAddExercise = false
            }
        }
        .sheet(item: $summary) { s in
            WorkoutSummaryView(summary: s) { dismiss() }
        }
        .sensoryFeedback(.success, trigger: finished)
    }

    private var elapsed: String {
        let s = max(0, Int(Date().timeIntervalSince(startedAt)))
        return String(format: "%02d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
    }
}

#Preview { ActiveSessionView(prefill: Mock.activeSession).modelContainer(LumeStore.preview).environment(HealthManager.shared) }
