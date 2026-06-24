import SwiftData
import SwiftUI

/// Calendrier mensuel des repas (historique illimité) : chaque jour montre un anneau de calories
/// vs objectif. Navigation mois, tap un jour → ses repas (DayMealsView).
struct MealCalendarView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \LoggedFood.date) private var foods: [LoggedFood]
    @Query private var profiles: [ProfileRecord]

    @State private var monthOffset = 0
    @State private var routeDay: DayRoute?
    @State private var appeared = false

    private let calendar = Calendar.current

    private struct DayRoute: Identifiable { let id = UUID(); let day: Date }

    private var grid: MonthGrid {
        MonthGrid(month: Date(), calendar: calendar).adding(monthOffset)
    }

    private var targetKcal: Int {
        profiles.first.map { TDEECalculator.target($0.profile).kcal } ?? TDEECalculator.defaultTarget.kcal
    }

    /// Calories par jour (début de jour → kcal).
    private var kcalByDay: [Date: Int] {
        var out: [Date: Int] = [:]
        for f in foods {
            out[calendar.startOfDay(for: f.date), default: 0] += f.kcal
        }
        return out
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                monthHeader
                weekdayHeader
                calendarGrid
            }
            .padding(.horizontal, Spacing.xl).padding(.top, Spacing.sm).padding(.bottom, Spacing.xxl)
        }
        .background(LumeColor.cream.ignoresSafeArea())
        .safeAreaInset(edge: .top) {
            TopBar(title: "Historique", leading: .back, onLeading: { dismiss() })
                .padding(.horizontal, Spacing.xl).padding(.vertical, Spacing.sm).background(LumeColor.cream)
        }
        .sheet(item: $routeDay) { DayMealsView(day: $0.day) }
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
                if let day { dayCell(day) } else { Color.clear.frame(height: 48) }
            }
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let kcal = kcalByDay[calendar.startOfDay(for: day)] ?? 0
        let isToday = calendar.isDateInToday(day)
        let progress = targetKcal > 0 ? min(1, Double(kcal) / Double(targetKcal)) : 0

        return Button { if kcal > 0 { routeDay = DayRoute(day: day) } } label: {
            ZStack {
                if kcal > 0 {
                    Circle().stroke(LumeColor.faint, lineWidth: 3)
                    Circle().trim(from: 0, to: appeared ? progress : 0)
                        .stroke(LumeColor.protein, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                Text("\(calendar.component(.day, from: day))")
                    .font(.lumeCaption).monospacedDigit()
                    .foregroundStyle(isToday ? LumeColor.ink : LumeColor.textSecondary)
            }
            .frame(width: 36, height: 36)
            .frame(maxWidth: .infinity).frame(height: 48)
            .background(isToday ? LumeColor.faint : Color.clear, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
        }
        .buttonStyle(.lumePress)
        .disabled(kcal == 0)
    }
}

#Preview { MealCalendarView().modelContainer(LumeStore.preview) }
