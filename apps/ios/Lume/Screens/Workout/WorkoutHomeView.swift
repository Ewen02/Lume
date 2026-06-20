import SwiftData
import SwiftUI

struct WorkoutHomeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @Query(sort: \WorkoutSessionModel.date, order: .reverse) private var sessions: [WorkoutSessionModel]
    @Query(sort: \RoutineModel.order) private var routineModels: [RoutineModel]
    @State private var startSession = false
    @State private var routeRoutine: Routine?
    @State private var showRoutines = false
    @State private var showPR = false
    @State private var showLibrary = false
    private var routines: [Routine] {
        routineModels.isEmpty ? Mock.routines : routineModels.map(\.asRoutine)
    }

    /// Les 2 meilleurs records réels (1RM estimé). Repli démo si aucune séance.
    private var topRecords: [PersonalRecord] {
        let real = WorkoutStats.topPRs(from: sessions)
        return Array((real.isEmpty ? Mock.topRecords : real).prefix(2))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                Button { startSession = true } label: {
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
                    .lumeEntrance(0)

                if !sessions.isEmpty {
                    SectionHeader(title: "Séances récentes").lumeEntrance(1)
                    ForEach(Array(sessions.prefix(3).enumerated()), id: \.element.id) { idx, s in recentRow(s).lumeEntrance(2 + idx) }
                }

                SectionHeader(title: "Mes routines", actionTitle: "Tout voir") { showRoutines = true }.lumeEntrance(2)
                ForEach(Array(routines.enumerated()), id: \.element.id) { idx, r in
                    Button { routeRoutine = r } label: { RoutineCard(routine: r) }
                        .buttonStyle(.lumePress).lumeEntrance(3 + idx)
                }

                Button { showLibrary = true } label: {
                    HStack(spacing: Spacing.md) {
                        Image(appIcon: .workout).lumeIcon(18, weight: .semibold).foregroundStyle(LumeColor.ink)
                            .frame(width: 44, height: 44).background(LumeColor.faint)
                            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                        Text("Bibliothèque d'exercices").font(.lumeCallout).foregroundStyle(LumeColor.ink)
                        Spacer()
                        Image(appIcon: .forward).lumeIcon(14, weight: .semibold).foregroundStyle(LumeColor.muted)
                    }
                    .padding(Spacing.lg - 2).background(LumeColor.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)).lumeShadow(.soft)
                }.buttonStyle(.lumePress).lumeEntrance(4)

                if !topRecords.isEmpty {
                    SectionHeader(title: "Records").lumeEntrance(5)
                    HStack(spacing: Spacing.md) {
                        ForEach(Array(topRecords.enumerated()), id: \.element.id) { idx, pr in
                            Button { showPR = true } label: {
                                StatTile(icon: .pr,
                                         tint: idx == 0 ? LumeColor.protein : LumeColor.success,
                                         value: "\(pr.oneRM) kg",
                                         label: pr.exercise)
                            }.buttonStyle(.lumePress)
                        }
                    }
                    .lumeEntrance(5)
                }
            }
            .padding(.horizontal, Spacing.xl).padding(.top, Spacing.sm).padding(.bottom, 130)
        }
        .background(LumeColor.cream)
        .safeAreaInset(edge: .top) {
            Text("Muscu").font(.lumeDisplay).foregroundStyle(LumeColor.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.xl).padding(.vertical, Spacing.sm).background(LumeColor.cream)
        }
        .sheet(isPresented: $startSession) { ActiveSessionView() }
        .sheet(item: $routeRoutine) { RoutineDetailView(routine: $0) }
        .sheet(isPresented: $showRoutines) { RoutineListView() }
        .sheet(isPresented: $showPR) { PRHistoryView() }
        .sheet(isPresented: $showLibrary) { ExerciseLibraryView() }
        .onAppear { seedDefaultRoutinesIfNeeded(ctx) }
    }

    private func recentRow(_ s: WorkoutSessionModel) -> some View {
        let count = s.orderedExercises.count
        let mins = s.durationSec / 60
        return HStack(spacing: Spacing.md) {
            Image(appIcon: .workout).lumeIcon(18, weight: .semibold).foregroundStyle(LumeColor.fat)
                .frame(width: 44, height: 44).background(LumeColor.fat.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(s.title).font(.lumeCallout).foregroundStyle(LumeColor.ink)
                Text("\(Formatters.relative(s.date)) · \(count) exo\(count > 1 ? "s" : "") · \(mins) min")
                    .font(.lumeFootnote).foregroundStyle(LumeColor.muted)
            }
            Spacer()
        }
        .padding(Spacing.lg - 2).background(LumeColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)).lumeShadow(.soft)
    }
}

#Preview { WorkoutHomeView().modelContainer(LumeStore.preview).environment(HealthManager.shared) }
