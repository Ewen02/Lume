import SwiftData
import SwiftUI

struct ActiveSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @Environment(HealthManager.self) private var health
    @Query private var profiles: [ProfileRecord]
    /// Séances passées (pour afficher « la dernière fois » par exercice).
    @Query(sort: \WorkoutSessionModel.date, order: .reverse) private var pastSessions: [WorkoutSessionModel]

    let title: String
    @State private var sessions: [ExerciseSession]
    @State private var showRest = false
    @State private var showPlate = false
    @State private var showAddExercise = false
    @State private var startedAt = Date()
    @State private var finished = false
    @State private var summary: WorkoutSummary?
    /// Badges fraîchement débloqués par cette séance (affichés dans le récap).
    @State private var newBadges: [Badge] = []
    /// Records personnels battus pendant cette séance (nom d'exercice → nouveau 1RM).
    @State private var newPRs: [PRBeaten] = []
    /// Dernière durée de repos choisie (réutilisée d'une série à l'autre).
    @AppStorage("lume.restSeconds") private var restSeconds = 90
    /// Démarrage auto du repos quand on coche une série.
    @AppStorage("lume.autoRest") private var autoRest = true

    init(title: String = "Séance libre", prefill: [ExerciseSession] = []) {
        self.title = title
        _sessions = State(initialValue: prefill)
    }

    /// Détecte les records de 1RM battus : pour chaque exercice de la séance, compare son meilleur
    /// 1RM (séries effectuées) au record historique des séances passées.
    private func detectNewPRs() -> [PRBeaten] {
        var out: [PRBeaten] = []
        for sess in sessions {
            let current = sess.sets.filter { $0.reps > 0 }
                .map { OneRepMax.estimate(weight: $0.weight, reps: $0.reps) }.max() ?? 0
            guard current > 0 else { continue }
            let previousBest = pastSessions
                .flatMap { $0.orderedExercises.filter { $0.name == sess.exercise.name } }
                .map(\.bestOneRM).max() ?? 0
            if current > previousBest {
                out.append(PRBeaten(exercise: sess.exercise.name, oneRM: current, previous: previousBest))
            }
        }
        return out
    }

    private func finish() {
        // Records battus : calculés AVANT l'insertion (comparaison avec l'historique).
        newPRs = detectNewPRs()

        let model = WorkoutSessionModel(date: startedAt,
                                        durationSec: Int(Date().timeIntervalSince(startedAt)),
                                        title: title)
        ctx.insert(model)
        for (i, sess) in sessions.enumerated() {
            let logged = sess.sets.filter { $0.reps > 0 }
            guard !logged.isEmpty else { continue }
            let ex = LoggedExerciseModel(name: sess.exercise.name,
                                         muscleRaw: sess.exercise.primary.code,
                                         equipment: sess.exercise.equipment, order: i)
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

        // Réconcilie les badges (la séance vient d'être insérée → re-fetch frais inclus).
        try? ctx.save()
        let all = (try? ctx.fetch(FetchDescriptor<WorkoutSessionModel>())) ?? []
        let goal = profiles.first?.weeklyWorkoutGoal ?? 3
        newBadges = BadgeEvaluator.reconcile(sessions: all, goal: goal, context: ctx, date: end)

        finished = true
        // Récap gratifiant avant de fermer (volume, séries, meilleur 1RM, badges).
        summary = WorkoutSummary(from: sessions, durationSec: Int(end.timeIntervalSince(start)))
    }

    /// Stats live de la séance en cours.
    private var doneSetCount: Int {
        sessions.reduce(0) { $0 + $1.sets.filter(\.done).count }
    }

    private var liveVolume: Int {
        sessions.reduce(0) { acc, s in
            acc + s.sets.filter(\.done).reduce(0) { $0 + Int($1.weight) * $1.reps }
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    if sessions.isEmpty {
                        emptyState
                    } else {
                        ForEach($sessions) { $session in
                            ExerciseSessionCard(
                                session: $session,
                                onRemove: { withAnimation(LumeMotion.snappy) { sessions.removeAll { $0.id == session.id } } },
                                lastPerformance: LastPerformance.summary(for: session.exercise.name, in: pastSessions)
                            )
                        }
                        addExerciseButton
                    }
                }.padding(.horizontal, Spacing.xl).padding(.top, Spacing.sm).padding(.bottom, 150)
            }
            bottomBar
        }
        .background(LumeColor.cream.ignoresSafeArea())
        .safeAreaInset(edge: .top) { header }
        // Repos auto : ouvre le timer quand une série vient d'être cochée.
        .onChange(of: doneSetCount) { old, new in
            if autoRest, new > old, !showRest { showRest = true }
        }
        .sheet(isPresented: $showRest) {
            RestTimerView(seconds: restSeconds) { restSeconds = $0 }.presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showPlate) { PlateCalculatorView() }
        .sheet(isPresented: $showAddExercise) {
            ExercisePickerView { exercise in
                sessions.append(ExerciseSession(exercise: exercise,
                                                sets: [SetEntry(reps: 10, weight: 20, rpe: nil)]))
                showAddExercise = false
            }
        }
        .sheet(item: $summary) { s in
            WorkoutSummaryView(summary: s, newBadges: newBadges, newPRs: newPRs) { dismiss() }
        }
        .sensoryFeedback(.success, trigger: finished)
    }

    // MARK: En-tête riche (chrono live + stats)

    private var header: some View {
        VStack(spacing: Spacing.md) {
            HStack {
                Button { dismiss() } label: {
                    Image(appIcon: .close).lumeIcon(18, weight: .semibold).foregroundStyle(LumeColor.ink)
                        .frame(width: 40, height: 40).background(LumeColor.surface, in: Circle()).lumeShadow(.soft)
                }.buttonStyle(.lumePress)
                Spacer()
                VStack(spacing: 0) {
                    Text(title).font(.lumeCaption).foregroundStyle(LumeColor.muted)
                    // Chrono qui tourne réellement (rafraîchi chaque seconde).
                    TimelineView(.periodic(from: startedAt, by: 1)) { _ in
                        Text(elapsed).font(.lumeTitle).foregroundStyle(LumeColor.ink).monospacedDigit()
                    }
                }
                Spacer()
                Button { showRest = true } label: { RestTimerPill(seconds: restSeconds) }.buttonStyle(.lumePress)
            }
            if !sessions.isEmpty {
                HStack(spacing: Spacing.sm) {
                    liveStat(value: doneSetCount, label: doneSetCount > 1 ? "séries" : "série")
                    liveStat(value: liveVolume, label: "kg")
                    liveStat(value: sessions.count, label: sessions.count > 1 ? "exos" : "exo")
                }
                .animation(LumeMotion.snappy, value: doneSetCount)
                .animation(LumeMotion.snappy, value: liveVolume)
            }
        }
        .padding(.horizontal, Spacing.xl).padding(.top, Spacing.lg).padding(.bottom, Spacing.md)
        .background(LumeColor.cream)
    }

    private func liveStat(value: Int, label: String) -> some View {
        VStack(spacing: 1) {
            Text("\(value)").font(.lumeHeadline).foregroundStyle(LumeColor.ink).monospacedDigit()
                .contentTransition(.numericText(value: Double(value)))
            Text(label).font(.lumeCaption).foregroundStyle(LumeColor.muted)
        }
        .frame(maxWidth: .infinity).padding(.vertical, Spacing.sm)
        .background(LumeColor.surface, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
    }

    // MARK: État vide

    private var emptyState: some View {
        VStack(spacing: Spacing.lg) {
            Image(appIcon: .workout).lumeIcon(48, weight: .semibold).foregroundStyle(LumeColor.ink)
                .frame(width: 96, height: 96).background(LumeColor.surface, in: Circle()).lumeShadow(.soft)
            VStack(spacing: Spacing.xs) {
                Text("Ta séance est vide").font(.lumeTitle).foregroundStyle(LumeColor.ink)
                Text("Ajoute ton premier exercice pour commencer à enregistrer tes séries.")
                    .font(.lumeSubhead).foregroundStyle(LumeColor.muted).multilineTextAlignment(.center)
            }
            PrimaryButton(title: "Ajouter un exercice", icon: .add) { showAddExercise = true }
        }
        .frame(maxWidth: .infinity).padding(.top, Spacing.xxl * 2).padding(.horizontal, Spacing.sm)
    }

    private var addExerciseButton: some View {
        Button { showAddExercise = true } label: {
            HStack(spacing: Spacing.sm) {
                Image(appIcon: .add).lumeIcon(16, weight: .semibold)
                Text("Ajouter un exercice").font(.lumeCallout)
            }.foregroundStyle(LumeColor.ink).frame(maxWidth: .infinity).padding(.vertical, Spacing.md)
                .overlay(RoundedRectangle(cornerRadius: Radius.md).stroke(LumeColor.border, lineWidth: 1))
        }.buttonStyle(.lumePress)
    }

    // MARK: Barre du bas (outils flottants + terminer)

    private var bottomBar: some View {
        VStack(spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                toolButton(icon: .restTimer, label: "Repos") { showRest = true }
                toolButton(icon: .plates, label: "Disques") { showPlate = true }
            }
            PrimaryButton(title: "Terminer la séance", icon: .validate) { finish() }
                .disabled(doneSetCount == 0)
                .opacity(doneSetCount == 0 ? 0.5 : 1)
        }
        .padding(.horizontal, Spacing.xl).padding(.bottom, Spacing.sm)
    }

    private func toolButton(icon: AppIcon, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                Image(appIcon: icon).lumeIcon(15, weight: .semibold)
                Text(label).font(.lumeSubhead.weight(.semibold))
            }.foregroundStyle(LumeColor.ink).frame(maxWidth: .infinity).padding(.vertical, Spacing.sm + 2)
                .background(LumeColor.surface, in: Capsule()).lumeShadow(.soft)
        }.buttonStyle(.lumePress)
    }

    private var elapsed: String {
        let s = max(0, Int(Date().timeIntervalSince(startedAt)))
        return String(format: "%02d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
    }
}

#Preview { ActiveSessionView(prefill: Mock.activeSession).modelContainer(LumeStore.preview).environment(HealthManager.shared) }
