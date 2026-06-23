import SwiftData
import SwiftUI

struct WorkoutHomeView: View {
    @Environment(\.modelContext) private var ctx
    @Query(sort: \WorkoutSessionModel.date, order: .reverse) private var sessions: [WorkoutSessionModel]
    @Query(sort: \RoutineModel.order) private var routineModels: [RoutineModel]

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

        var id: String {
            switch self {
            case .startSession: "start"
            case let .routine(r): "routine-\(r.id)"
            case let .session(s): "session-\(s.id)"
            case .allRoutines: "all"
            case .records: "records"
            case .library: "library"
            case .newRoutine: "new"
            }
        }
    }

    @State private var route: Route?

    /// Vrais records (1RM estimé). Vide tant qu'aucune séance — pas de chiffres inventés.
    private var topRecords: [PersonalRecord] {
        Array(WorkoutStats.topPRs(from: sessions).prefix(2))
    }

    private var week: WeekTraining {
        WorkoutStats.lastSevenDays(from: sessions)
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

                if week.sessions > 0 {
                    weekSummary.lumeEntrance(1)
                }

                if !sessions.isEmpty {
                    SectionHeader(title: "Séances récentes").lumeEntrance(2)
                    ForEach(Array(sessions.prefix(3).enumerated()), id: \.element.id) { idx, s in
                        recentRow(s).lumeEntrance(3 + idx)
                    }
                }

                routinesSection.lumeEntrance(4)
                libraryLink.lumeEntrance(5)
                recordsSection.lumeEntrance(6)
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
            }
        }
    }

    // MARK: Démarrer

    private var startCard: some View {
        Button { route = .startSession } label: {
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
        }.buttonStyle(.lumePress)
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
                    Text("\(Formatters.relative(s.date)) · \(count) exo\(count > 1 ? "s" : "") · \(mins) min")
                        .font(.lumeFootnote).foregroundStyle(LumeColor.muted)
                }
                Spacer()
                Image(appIcon: .forward).lumeIcon(14, weight: .semibold).foregroundStyle(LumeColor.muted)
            }
            .padding(Spacing.lg - 2).background(LumeColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)).lumeShadow(.soft)
        }.buttonStyle(.lumePress)
    }
}

#Preview { WorkoutHomeView().modelContainer(LumeStore.preview).environment(HealthManager.shared) }
