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
    /// Exercice en attente de confirmation de retrait (évite la perte accidentelle en pleine séance).
    @State private var exerciseToRemove: ExerciseSession?
    @State private var startedAt = Date()
    @State private var finished = false
    @State private var summary: WorkoutSummary?
    /// Note libre de la séance (ressenti, douleur…).
    @State private var note = ""
    /// Badges fraîchement débloqués par cette séance (affichés dans le récap).
    @State private var newBadges: [Badge] = []
    /// Records personnels battus pendant cette séance (nom d'exercice → nouveau 1RM).
    @State private var newPRs: [PRBeaten] = []
    /// Dernière durée de repos choisie (réutilisée d'une série à l'autre).
    @AppStorage("lume.restSeconds") private var restSeconds = 90
    /// Démarrage auto du repos quand on coche une série.
    @AppStorage("lume.autoRest") private var autoRest = true
    @AppStorage(WeightFormat.defaultsKey) private var useImperial = false

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

    /// Une série compte si elle a des répétitions (la coche `done` n'est qu'un confort visuel).
    /// Critère unique partout : live, persistance, récap, PR, badges.
    private func loggedSets(_ session: ExerciseSession) -> [SetEntry] {
        session.sets.filter { $0.reps > 0 }
    }

    /// Exercices ayant au moins une série remplie — base de la persistance et du gate Terminer.
    private var loggedExercises: [ExerciseSession] {
        sessions.filter { !loggedSets($0).isEmpty }
    }

    private func finish() {
        // Garde-fou : aucune série remplie → pas de séance fantôme persistée.
        let exercises = loggedExercises
        guard !exercises.isEmpty else { return }

        // Records battus : calculés AVANT l'insertion (comparaison avec l'historique).
        newPRs = detectNewPRs()

        let start = startedAt, end = Date()
        let model = WorkoutSessionModel(date: start,
                                        durationSec: Int(end.timeIntervalSince(start)),
                                        title: title,
                                        note: note.trimmingCharacters(in: .whitespacesAndNewlines))
        ctx.insert(model)
        for (i, sess) in exercises.enumerated() {
            let ex = LoggedExerciseModel(name: sess.exercise.name,
                                         muscleRaw: sess.exercise.primary.code,
                                         equipment: sess.exercise.equipment, order: i)
            ex.session = model
            ctx.insert(ex)
            for (j, set) in loggedSets(sess).enumerated() {
                let m = LoggedSetModel(reps: set.reps, weight: set.weight, rpe: set.rpe, order: j)
                m.exercise = ex
                ctx.insert(m)
            }
        }
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

    /// Stats live de la séance en cours — basées sur `reps>0` (cohérent avec le récap).
    private var doneSetCount: Int {
        sessions.reduce(0) { $0 + loggedSets($1).count }
    }

    private var liveVolume: Int {
        sessions.reduce(0) { acc, s in
            acc + loggedSets(s).reduce(0) { $0 + Int($1.weight) * $1.reps }
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
                                onRemove: { exerciseToRemove = session },
                                lastPerformance: LastPerformance.summary(for: session.exercise.name, in: pastSessions)
                            )
                        }
                        addExerciseButton
                        noteField
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
        .confirmationDialog("Retirer cet exercice ?",
                            isPresented: Binding(get: { exerciseToRemove != nil },
                                                 set: { if !$0 { exerciseToRemove = nil } }),
                            titleVisibility: .visible)
        {
            Button("Retirer", role: .destructive) {
                if let ex = exerciseToRemove {
                    withAnimation(LumeMotion.snappy) { sessions.removeAll { $0.id == ex.id } }
                }
                exerciseToRemove = nil
            }
            Button("Annuler", role: .cancel) { exerciseToRemove = nil }
        } message: {
            Text(exerciseToRemove.map { "« \($0.exercise.name) » et ses séries seront retirés de la séance." } ?? "")
        }
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
                    liveStat(value: useImperial ? Int((Double(liveVolume) * WeightFormat.lbPerKg).rounded()) : liveVolume,
                             label: WeightFormat.unit(imperial: useImperial))
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

    private var noteField: some View {
        LumeCard {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Note de séance").font(.lumeFootnote).foregroundStyle(LumeColor.muted)
                TextField("Ressenti, douleur, remarque…", text: $note, axis: .vertical)
                    .font(.lumeSubhead).foregroundStyle(LumeColor.ink)
                    .lineLimit(1 ... 4)
            }
        }
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
