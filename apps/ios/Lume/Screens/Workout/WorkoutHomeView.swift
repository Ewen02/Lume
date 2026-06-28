import SwiftData
import SwiftUI

struct WorkoutHomeView: View {
    @Environment(\.modelContext) private var ctx
    @Environment(HealthManager.self) private var health
    @Query(sort: \WorkoutSessionModel.date, order: .reverse) private var sessions: [WorkoutSessionModel]
    @Query(sort: \RoutineModel.order) private var routineModels: [RoutineModel]
    @Query private var profiles: [ProfileRecord]

    /// Onboarding muscu : tant que l'utilisateur n'a pas choisi comment démarrer, on l'affiche.
    @AppStorage("lume.workoutSetupDone") private var setupDone = false

    /// Une seule destination présentée à la fois : SwiftUI n'autorise qu'UN `.sheet` par niveau de vue.
    private enum Route: Identifiable {
        case startSession
        case routine(Routine)
        case session(WorkoutSessionModel)
        case allRoutines
        case records
        case library
        case newRoutine
        case calendar
        case badges
        case streak

        var id: String {
            switch self {
            case .startSession: "start"
            case let .routine(r): "routine-\(r.id)"
            case let .session(s): "session-\(s.id)"
            case .allRoutines: "all"
            case .records: "records"
            case .library: "library"
            case .newRoutine: "new"
            case .calendar: "calendar"
            case .badges: "badges"
            case .streak: "streak"
            }
        }
    }

    @State private var route: Route?
    @State private var showStartChoice = false
    /// Palier de série hebdo fraîchement franchi à fêter (sheet dédiée, découplée de `route`).
    @State private var celebrateWeeklyStreak: WeeklyStreakCelebration?

    /// Wrapper Identifiable pour présenter la flamme hebdo proactivement via `.sheet(item:)`.
    private struct WeeklyStreakCelebration: Identifiable {
        let threshold: Int
        var id: Int { threshold }
    }

    /// Vrais records (1RM estimé). Vide tant qu'aucune séance — pas de chiffres inventés.
    private var topRecords: [PersonalRecord] {
        Array(WorkoutStats.topPRs(from: sessions).prefix(2))
    }

    private var week: WeekTraining {
        WorkoutStats.lastSevenDays(from: sessions)
    }

    private var goal: Int {
        profiles.first?.weeklyWorkoutGoal ?? 3
    }

    private var streak: Int {
        WorkoutStreak.currentStreak(from: sessions.map(\.date), goal: goal)
    }

    private var streakRecord: Int {
        WorkoutStreak.longestStreak(from: sessions.map(\.date), goal: goal)
    }

    private var sessionsThisWeek: Int {
        WorkoutStreak.sessionsThisWeek(from: sessions.map(\.date))
    }

    var body: some View {
        Group {
            if setupDone || !routineModels.isEmpty || !sessions.isEmpty {
                home
            } else {
                WorkoutSetupView(done: $setupDone)
            }
        }
    }

    private var home: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                startCard.lumeEntrance(0)
                engagementCard.lumeEntrance(1)
                quickAccess.lumeEntrance(2)

                if week.sessions > 0 {
                    weekSummary.lumeEntrance(3)
                }

                if !sessions.isEmpty {
                    SectionHeader(title: "Séances récentes") { route = .calendar }.lumeEntrance(4)
                    ForEach(Array(sessions.prefix(3).enumerated()), id: \.element.id) { idx, s in
                        recentRow(s).lumeEntrance(5 + idx)
                    }
                }

                if !health.externalWorkouts.isEmpty {
                    SectionHeader(title: "Depuis Santé").lumeEntrance(5)
                    ForEach(Array(health.externalWorkouts.prefix(3))) { w in
                        externalWorkoutRow(w).lumeEntrance(6)
                    }
                }

                routinesSection.lumeEntrance(6)
                libraryLink.lumeEntrance(7)
                recordsSection.lumeEntrance(8)
            }
            .padding(.horizontal, Spacing.xl).padding(.top, Spacing.sm).padding(.bottom, 130)
        }
        .background(LumeColor.cream)
        .safeAreaInset(edge: .top) {
            Text("Muscu").font(.lumeDisplay).foregroundStyle(LumeColor.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.xl).padding(.vertical, Spacing.sm).background(LumeColor.cream)
        }
        .sheet(item: $route) { dest in
            switch dest {
            case .startSession: ActiveSessionView()
            case let .routine(r): RoutineDetailView(routine: r)
            case let .session(s): SessionDetailView(session: s)
            case .allRoutines: RoutineListView()
            case .records: PRHistoryView()
            case .library: ExerciseLibraryView()
            case .newRoutine: RoutineEditorView()
            case .calendar: WorkoutCalendarView()
            case .badges: BadgesView()
            case .streak: WorkoutStreakDetailView(streak: streak, record: streakRecord, goal: goal)
            }
        }
        // Rattrape les badges déjà mérités (séances enregistrées avant l'arrivée du système).
        .task { BadgeEvaluator.reconcile(sessions: sessions, goal: goal, context: ctx) }
        // Charge les séances importées de Santé (lecture seule).
        .task { await health.refreshExternalWorkouts() }
        // Franchissement d'un palier de série hebdo (2/4/12 sem.) : la grande flamme s'ouvre seule
        // au retour sur l'écran après une séance qui fait passer un cap. Une fois par palier (ledger).
        // Sheet DÉDIÉE (pas `route`) pour ne pas entrer en conflit avec la navigation, et marquage
        // au moment de l'affichage effectif (pas du déclencheur) → jamais « consommée » sans être vue.
        .onChange(of: streak) { _, _ in presentStreakMilestoneIfCrossed() }
        .onAppear { presentStreakMilestoneIfCrossed() }
        .sheet(item: $celebrateWeeklyStreak) { celebration in
            WorkoutStreakDetailView(streak: streak, record: streakRecord, goal: goal)
                .onAppear {
                    CelebrationLedger.markFired(
                        StreakMilestone.ledgerID(domain: "workout", threshold: celebration.threshold))
                }
        }
    }

    /// Détecte un palier hebdo (2/4/12) fraîchement franchi et programme la flamme proactive.
    private func presentStreakMilestoneIfCrossed() {
        guard celebrateWeeklyStreak == nil, let threshold = StreakMilestone.crossed(
            streak: streak, thresholds: StreakMilestone.workout,
            alreadyFired: { CelebrationLedger.hasFired(StreakMilestone.ledgerID(domain: "workout", threshold: $0)) }
        ) else { return }
        celebrateWeeklyStreak = WeeklyStreakCelebration(threshold: threshold)
    }

    // MARK: Engagement (flamme + objectif de la semaine)

    private var engagementCard: some View {
        LumeCard {
            HStack(spacing: Spacing.lg) {
                // Flamme de série hebdo (tap → détail).
                Button { route = .streak } label: {
                    VStack(spacing: 2) {
                        StreakFlame(streak: streak, size: 40).frame(height: 56)
                        Text(streak > 0 ? "\(streak) sem." : "—")
                            .font(.lumeCaption.weight(.semibold)).foregroundStyle(LumeColor.ink).monospacedDigit()
                        Text("Série").font(.lumeCaption).foregroundStyle(LumeColor.muted)
                    }
                }.buttonStyle(.lumePress)

                Divider().frame(height: 60).overlay(LumeColor.border)

                // Anneau d'objectif de séances cette semaine.
                ProgressRing(progress: goal > 0 ? min(1, Double(sessionsThisWeek) / Double(goal)) : 0,
                             color: LumeColor.protein, lineWidth: 8)
                {
                    VStack(spacing: 0) {
                        Text("\(sessionsThisWeek)/\(goal)").font(.lumeCallout.weight(.bold))
                            .foregroundStyle(LumeColor.ink).monospacedDigit()
                    }
                }.frame(width: 60, height: 60)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Objectif de la semaine").font(.lumeSubhead.weight(.semibold)).foregroundStyle(LumeColor.ink)
                    Text(sessionsThisWeek >= goal ? "Objectif atteint 💪" : "\(max(0, goal - sessionsThisWeek)) séance(s) restante(s)")
                        .font(.lumeFootnote).foregroundStyle(LumeColor.muted)
                }
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: Accès rapide (calendrier / récompenses)

    private var quickAccess: some View {
        HStack(spacing: Spacing.md) {
            quickTile(icon: .recents, tint: LumeColor.fat, title: "Calendrier") { route = .calendar }
            quickTile(icon: .pr, tint: LumeColor.warning, title: "Récompenses") { route = .badges }
        }
    }

    private func quickTile(icon: AppIcon, tint: Color, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                Image(appIcon: icon).lumeIcon(16, weight: .semibold).foregroundStyle(tint)
                    .frame(width: 36, height: 36).background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                Text(title).font(.lumeCallout).foregroundStyle(LumeColor.ink)
                Spacer()
            }
            .padding(Spacing.md).frame(maxWidth: .infinity)
            .background(LumeColor.surface).clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)).lumeShadow(.soft)
        }.buttonStyle(.lumePress)
    }

    // MARK: Démarrer

    private var startCard: some View {
        Button {
            // Avec des routines : on propose le choix (libre ou routine). Sinon séance libre directe.
            if routineModels.isEmpty { route = .startSession } else { showStartChoice = true }
        } label: {
            HStack(spacing: Spacing.md) {
                Image(appIcon: .workout).lumeIcon(24, weight: .semibold)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Démarrer une séance").font(.lumeHeadline)
                    Text("Séance libre ou depuis une routine").font(.lumeFootnote).opacity(0.7)
                }
                Spacer()
                Image(appIcon: .add).lumeIcon(20, weight: .bold)
            }
            .foregroundStyle(LumeColor.surface)
            .padding(Spacing.xl)
            .background(LumeColor.ink)
            .clipShape(RoundedRectangle(cornerRadius: Radius.xxl, style: .continuous))
            .lumeShadow(.card)
        }
        .buttonStyle(.lumePress)
        .confirmationDialog("Démarrer une séance", isPresented: $showStartChoice, titleVisibility: .visible) {
            Button("Séance libre") { route = .startSession }
            ForEach(routineModels) { model in
                Button(model.name) { route = .routine(model.asRoutine) }
            }
        }
    }

    // MARK: Résumé de la semaine

    private var weekSummary: some View {
        LumeCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Cette semaine").font(.lumeHeadline).foregroundStyle(LumeColor.ink)
                HStack(spacing: Spacing.lg) {
                    summaryMetric(value: "\(week.sessions)", label: week.sessions > 1 ? "séances" : "séance")
                    summaryMetric(value: "\(week.volumeKg)", label: "kg soulevés")
                    summaryMetric(value: "\(week.minutes)", label: "minutes")
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func summaryMetric(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.lumeTitle).foregroundStyle(LumeColor.ink).monospacedDigit()
            Text(label).font(.lumeCaption).foregroundStyle(LumeColor.muted)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Routines

    @ViewBuilder
    private var routinesSection: some View {
        SectionHeader(title: "Mes routines",
                      actionTitle: routineModels.isEmpty ? "Nouvelle" : "Tout voir",
                      actionIcon: routineModels.isEmpty ? .add : nil)
        {
            route = routineModels.isEmpty ? .newRoutine : .allRoutines
        }
        if routineModels.isEmpty {
            emptyRoutines
        } else {
            ForEach(routineModels) { model in
                RoutineCard(routine: model.asRoutine) { route = .routine(model.asRoutine) }
                    .contextMenu {
                        Button(role: .destructive) { ctx.delete(model) } label: {
                            Label("Supprimer", systemImage: "trash")
                        }
                    }
            }
        }
    }

    private var emptyRoutines: some View {
        Button { route = .newRoutine } label: {
            VStack(spacing: Spacing.sm) {
                Image(appIcon: .add).lumeIcon(20, weight: .semibold).foregroundStyle(LumeColor.ink)
                Text("Crée ta première routine").font(.lumeCallout).foregroundStyle(LumeColor.ink)
                Text("Compose-la depuis la bibliothèque d'exercices.")
                    .font(.lumeFootnote).foregroundStyle(LumeColor.muted).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity).padding(.vertical, Spacing.xl)
            .background(LumeColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(LumeColor.border, style: StrokeStyle(lineWidth: 1, dash: [5])))
        }.buttonStyle(.lumePress)
    }

    private var libraryLink: some View {
        Button { route = .library } label: {
            HStack(spacing: Spacing.md) {
                Image(appIcon: .exercise).lumeIcon(18, weight: .semibold).foregroundStyle(LumeColor.ink)
                    .frame(width: 44, height: 44).background(LumeColor.faint)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                Text("Bibliothèque d'exercices").font(.lumeCallout).foregroundStyle(LumeColor.ink)
                Spacer()
                Image(appIcon: .forward).lumeIcon(14, weight: .semibold).foregroundStyle(LumeColor.muted)
            }
            .padding(Spacing.lg - 2).background(LumeColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)).lumeShadow(.soft)
        }.buttonStyle(.lumePress)
    }

    // MARK: Records

    @ViewBuilder
    private var recordsSection: some View {
        SectionHeader(title: "Records") { if !topRecords.isEmpty { route = .records } }
        if topRecords.isEmpty {
            HStack(spacing: Spacing.md) {
                Image(appIcon: .pr).lumeIcon(20, weight: .semibold).foregroundStyle(LumeColor.muted)
                    .frame(width: 44, height: 44).background(LumeColor.faint)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                Text("Tes records apparaîtront après ta première séance.")
                    .font(.lumeFootnote).foregroundStyle(LumeColor.muted)
                Spacer()
            }
            .padding(Spacing.lg - 2).background(LumeColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)).lumeShadow(.soft)
        } else {
            HStack(spacing: Spacing.md) {
                ForEach(Array(topRecords.enumerated()), id: \.element.id) { idx, pr in
                    Button { route = .records } label: {
                        StatTile(icon: .pr,
                                 tint: idx == 0 ? LumeColor.protein : LumeColor.success,
                                 value: "\(pr.oneRM) kg",
                                 label: pr.exercise)
                    }.buttonStyle(.lumePress)
                }
            }
        }
    }

    private func recentRow(_ s: WorkoutSessionModel) -> some View {
        let count = s.orderedExercises.count
        let mins = s.durationSec / 60
        return Button { route = .session(s) } label: {
            HStack(spacing: Spacing.md) {
                Image(appIcon: .workout).lumeIcon(18, weight: .semibold).foregroundStyle(LumeColor.fat)
                    .frame(width: 44, height: 44).background(LumeColor.fat.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(s.title).font(.lumeCallout).foregroundStyle(LumeColor.ink)
                    Text("\(Formatters.relative(s.date)) · \(count) exos · \(mins) min")
                        .font(.lumeFootnote).foregroundStyle(LumeColor.muted)
                }
                Spacer()
                Image(appIcon: .forward).lumeIcon(14, weight: .semibold).foregroundStyle(LumeColor.muted)
            }
            .padding(Spacing.lg - 2).background(LumeColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)).lumeShadow(.soft)
        }.buttonStyle(.lumePress)
    }

    /// Séance importée de Santé : lecture seule (pas d'édition), badge « Santé ».
    private func externalWorkoutRow(_ w: ExternalWorkout) -> some View {
        HStack(spacing: Spacing.md) {
            Image(appIcon: .workout).lumeIcon(18, weight: .semibold).foregroundStyle(LumeColor.success)
                .frame(width: 44, height: 44).background(LumeColor.success.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: Spacing.sm) {
                    Text(w.type).font(.lumeCallout).foregroundStyle(LumeColor.ink)
                    Chip(color: LumeColor.success, text: "Santé")
                }
                Text("\(Formatters.relative(w.date)) · \(w.durationLabel)\(w.kcal.map { " · \($0) kcal" } ?? "")")
                    .font(.lumeFootnote).foregroundStyle(LumeColor.muted)
            }
            Spacer()
        }
        .padding(Spacing.lg - 2).background(LumeColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)).lumeShadow(.soft)
    }
}

#Preview { WorkoutHomeView().modelContainer(LumeStore.preview).environment(HealthManager.shared) }
