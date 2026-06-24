import SwiftData
import SwiftUI

/// Calendrier mensuel des séances : grille du mois, jours d'entraînement marqués d'une pastille
/// (couleur du groupe musculaire dominant). Navigation mois ±, tap un jour → détail de la séance.
struct WorkoutCalendarView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \WorkoutSessionModel.date, order: .reverse) private var sessions: [WorkoutSessionModel]

    @State private var monthOffset = 0
    @State private var routeSession: WorkoutSessionModel?
    @State private var appeared = false

    private let calendar = Calendar.current

    private var grid: MonthGrid {
        MonthGrid(month: Date(), calendar: calendar).adding(monthOffset)
    }

    /// Séances groupées par jour (début de jour).
    private var sessionsByDay: [Date: [WorkoutSessionModel]] {
        Dictionary(grouping: sessions) { calendar.startOfDay(for: $0.date) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                monthHeader
                weekdayHeader
                calendarGrid
                legend
            }
            .padding(.horizontal, Spacing.xl).padding(.top, Spacing.sm).padding(.bottom, Spacing.xxl)
        }
        .background(LumeColor.cream.ignoresSafeArea())
        .safeAreaInset(edge: .top) {
            TopBar(title: "Calendrier", leading: .back, onLeading: { dismiss() })
                .padding(.horizontal, Spacing.xl).padding(.vertical, Spacing.sm).background(LumeColor.cream)
        }
        .sheet(item: $routeSession) { SessionDetailView(session: $0) }
        .onAppear { withAnimation(LumeMotion.bouncy.delay(0.15)) { appeared = true } }
        .onChange(of: monthOffset) { _, _ in
            appeared = false
            withAnimation(LumeMotion.bouncy.delay(0.1)) { appeared = true }
        }
    }

    private var monthHeader: some View {
        HStack {
            Button { withAnimation(LumeMotion.snappy) { monthOffset -= 1 } } label: {
                Image(appIcon: .back).lumeIcon(16, weight: .semibold).foregroundStyle(LumeColor.ink)
                    .frame(width: 40, height: 40).background(LumeColor.surface, in: Circle()).lumeShadow(.soft)
            }.buttonStyle(.lumePress)
            Spacer()
            Text(grid.title).font(.lumeHeadline).foregroundStyle(LumeColor.ink)
            Spacer()
            Button { withAnimation(LumeMotion.snappy) { monthOffset += 1 } } label: {
                Image(appIcon: .forward).lumeIcon(16, weight: .semibold).foregroundStyle(LumeColor.ink)
                    .frame(width: 40, height: 40).background(LumeColor.surface, in: Circle()).lumeShadow(.soft)
            }.buttonStyle(.lumePress)
                .disabled(monthOffset >= 0)
                .opacity(monthOffset >= 0 ? 0.4 : 1)
        }
    }

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(Array(MonthGrid.weekdaySymbols.enumerated()), id: \.offset) { _, s in
                Text(s).font(.lumeCaption).foregroundStyle(LumeColor.muted).frame(maxWidth: .infinity)
            }
        }
    }

    private var calendarGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: Spacing.xs), count: 7)
        return LazyVGrid(columns: columns, spacing: Spacing.sm) {
            ForEach(Array(grid.days.enumerated()), id: \.offset) { _, day in
                if let day { dayCell(day) } else { Color.clear.frame(height: 44) }
            }
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let daySessions = sessionsByDay[calendar.startOfDay(for: day)] ?? []
        let isToday = calendar.isDateInToday(day)
        let tint = daySessions.isEmpty ? LumeColor.faint : dominantTint(daySessions)

        return Button {
            if let first = daySessions.first { routeSession = first }
        } label: {
            VStack(spacing: 4) {
                Text("\(calendar.component(.day, from: day))")
                    .font(.lumeFootnote).monospacedDigit()
                    .foregroundStyle(isToday ? LumeColor.ink : LumeColor.textSecondary)
                Circle()
                    .fill(daySessions.isEmpty ? Color.clear : tint)
                    .frame(width: 7, height: 7)
                    .scaleEffect(daySessions.isEmpty || appeared ? 1 : 0)
                    // Indicateur de jour à plusieurs séances.
                    .overlay(alignment: .topTrailing) {
                        if daySessions.count > 1 {
                            Text("\(daySessions.count)").font(.lumeMicro).foregroundStyle(LumeColor.muted)
                                .offset(x: 7, y: -4)
                        }
                    }
            }
            .frame(maxWidth: .infinity).frame(height: 44)
            .background(isToday ? LumeColor.faint : Color.clear, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
        }
        .buttonStyle(.lumePress)
        .disabled(daySessions.isEmpty)
    }

    private var legend: some View {
        LumeCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Groupes").font(.lumeFootnote).foregroundStyle(LumeColor.muted)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: Spacing.sm)], alignment: .leading, spacing: Spacing.sm) {
                    ForEach(MuscleGroup.allCases) { g in
                        HStack(spacing: Spacing.xs) {
                            Circle().fill(g.tint).frame(width: 8, height: 8)
                            Text(g.rawValue).font(.lumeCaption).foregroundStyle(LumeColor.textSecondary)
                        }
                    }
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Couleur dominante d'un jour = groupe musculaire le plus travaillé (par nombre de séries),
    /// toutes séances du jour confondues — plus représentatif que le 1er exercice.
    private func dominantTint(_ sessions: [WorkoutSessionModel]) -> Color {
        var setsByGroup: [MuscleGroup: Int] = [:]
        for session in sessions {
            for ex in session.orderedExercises {
                setsByGroup[ex.muscle, default: 0] += ex.orderedSets.count
            }
        }
        return setsByGroup.max { $0.value < $1.value }?.key.tint ?? LumeColor.ink
    }
}

#Preview { WorkoutCalendarView().modelContainer(LumeStore.preview) }
