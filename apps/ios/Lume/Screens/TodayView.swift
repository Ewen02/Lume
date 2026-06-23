import SwiftData
import SwiftUI

struct TodayView: View {
    @Environment(\.modelContext) private var ctx
    @Query private var allFoods: [LoggedFood] // borné aux 7 derniers jours
    @Query private var waterLogs: [WaterLog] // borné au jour courant
    @Query private var profiles: [ProfileRecord]
    /// Léger : sert uniquement au calcul du streak (jours consécutifs avec repas).
    @Query(sort: \LoggedFood.date, order: .reverse) private var streakFoods: [LoggedFood]

    private let cal = Calendar.current
    @State private var showWater = false
    @State private var showSearch = false
    @State private var showCalendar = false
    @State private var routeEntry: LoggedFood?
    @State private var selectedDay = Calendar.current.startOfDay(for: Date())
    @State private var expanded: Set<String> = []
    @State private var mealToDelete: DeletableMeal?
    @State private var mealToRename: DeletableMeal?
    @State private var didDelete = false
    @State private var showStreak = false
    @State private var highlight = false
    /// Badges nutrition fraîchement débloqués (affichés en célébration).
    @State private var celebrateBadges: [Badge] = []

    /// Repas en attente de confirmation de suppression.
    private struct DeletableMeal: Identifiable {
        let id: String
        let title: String
        let foods: [LoggedFood]
    }

    private var isToday: Bool {
        cal.isDateInToday(selectedDay)
    }

    /// Change de valeur quand un repas vient d'être ajouté → déclenche l'animation de mise en valeur.
    var highlightTrigger: UUID = .init()

    init(highlightTrigger: UUID = UUID()) {
        self.highlightTrigger = highlightTrigger
        let c = Calendar.current
        let dayStart = c.startOfDay(for: Date())
        let weekStart = c.date(byAdding: .day, value: -6, to: dayStart)!
        _allFoods = Query(filter: #Predicate<LoggedFood> { $0.date >= weekStart },
                          sort: \LoggedFood.date, order: .reverse)
        _waterLogs = Query(filter: #Predicate<WaterLog> { $0.day >= dayStart }, sort: \WaterLog.day, order: .reverse)
    }

    private var target: Macros {
        profiles.first.map { TDEECalculator.target($0.profile) } ?? Mock.target
    }

    private var streak: Int {
        StreakCalculator.currentStreak(from: streakFoods.map(\.date))
    }

    private var streakRecord: Int {
        StreakCalculator.longestStreak(from: streakFoods.map(\.date))
    }

    /// Repas du jour SÉLECTIONNÉ (aujourd'hui par défaut, ou un jour passé de la semaine).
    private var dayFoods: [LoggedFood] {
        allFoods.filter { cal.isDate($0.date, inSameDayAs: selectedDay) }
    }

    private var consumed: Macros {
        dayFoods.reduce(.zero) { $0 + $1.macros }
    }

    /// Macros consommées AUJOURD'HUI (pour le widget, indépendant du jour sélectionné).
    private var todayConsumed: Macros {
        allFoods.filter { cal.isDateInToday($0.date) }.reduce(.zero) { $0 + $1.macros }
    }

    /// L'eau n'est chargée que pour aujourd'hui (la query est bornée au jour courant).
    private var water: Int {
        guard isToday else { return 0 }
        return waterLogs.first { cal.isDate($0.day, inSameDayAs: Date()) }?.glasses ?? 0
    }

    private struct WeekDay: Identifiable {
        let id = UUID()
        let date: Date
        let letter: String
        let dayNumber: Int
        let progress: Double
        let isToday: Bool
        let isSelected: Bool
    }

    private var week: [WeekDay] {
        let letters = ["D", "L", "M", "M", "J", "V", "S"]
        let today0 = cal.startOfDay(for: Date())
        return (0 ..< 7).reversed().map { offset in
            let day = cal.date(byAdding: .day, value: -offset, to: today0)!
            let kcal = allFoods.filter { cal.isDate($0.date, inSameDayAs: day) }.reduce(0) { $0 + $1.kcal }
            let wd = cal.component(.weekday, from: day)
            return WeekDay(date: day, letter: letters[wd - 1], dayNumber: cal.component(.day, from: day),
                           progress: min(1.0, Double(kcal) / Double(max(target.kcal, 1))),
                           isToday: offset == 0, isSelected: cal.isDate(day, inSameDayAs: selectedDay))
        }
    }

    /// Un bloc affiché dans « Repas du jour » : soit un repas scanné (plusieurs aliments),
    /// soit un créneau d'aliments ajoutés isolément.
    private struct DayGroup: Identifiable {
        let id: String
        let title: String
        let icon: AppIcon
        let tint: Color
        let foods: [LoggedFood]
        /// `true` pour un repas scanné (carte repliable avec macros), `false` pour un créneau d'ajouts isolés.
        let isScannedMeal: Bool
        var kcal: Int {
            foods.reduce(0) { $0 + $1.kcal }
        }

        var macros: Macros {
            foods.reduce(.zero) { $0 + $1.macros }
        }
    }

    private var dayGroups: [DayGroup] {
        var groups: [DayGroup] = []
        // 1) Repas scannés : un bloc par mealGroupID (ordre d'apparition).
        var seenGroups = Set<UUID>()
        for food in dayFoods {
            guard let gid = food.mealGroupID, !seenGroups.contains(gid) else { continue }
            seenGroups.insert(gid)
            let foods = dayFoods.filter { $0.mealGroupID == gid }
            let type = foods.first?.meal ?? .snack
            let title = foods.first?.mealTitle ?? "Repas scanné · \(type.title)"
            groups.append(DayGroup(id: gid.uuidString, title: title,
                                   icon: .camera, tint: type.tint, foods: foods, isScannedMeal: true))
        }
        // 2) Aliments isolés (sans groupe) : regroupés par créneau.
        for type in MealType.allCases {
            let foods = dayFoods.filter { $0.meal == type && $0.mealGroupID == nil }
            if !foods.isEmpty {
                groups.append(DayGroup(id: "meal-\(type.rawValue)", title: type.title,
                                       icon: type.icon, tint: type.tint, foods: foods, isScannedMeal: false))
            }
        }
        return groups
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                header.lumeEntrance(0)
                HStack { ForEach(Array(week.enumerated()), id: \.element.id) { i, d in
                    Button {
                        withAnimation(LumeMotion.smooth) { selectedDay = d.date }
                    } label: {
                        DayRing(letter: d.letter, day: d.dayNumber, progress: d.progress,
                                isToday: d.isToday, isSelected: d.isSelected)
                    }
                    .buttonStyle(.lumePress)
                    if i < week.count - 1 { Spacer() }
                } }
                .lumeEntrance(1)
                .sensoryFeedback(.selection, trigger: selectedDay)
                CalorieCard(consumed: consumed.kcal, goal: target.kcal)
                    .scaleEffect(highlight ? 1.04 : 1)
                    .shadow(color: LumeColor.protein.opacity(highlight ? 0.45 : 0), radius: highlight ? 18 : 0)
                    .lumeEntrance(2)
                HStack(spacing: Spacing.md) {
                    MacroCard(letter: "P", value: consumed.protein, goal: target.protein, color: LumeColor.protein, label: "Protéines")
                    MacroCard(letter: "G", value: consumed.carbs, goal: target.carbs, color: LumeColor.carbs, label: "Glucides")
                    MacroCard(letter: "L", value: consumed.fat, goal: target.fat, color: LumeColor.fat, label: "Lipides")
                }
                .lumeEntrance(3)
                Button { showWater = true } label: { WaterTracker(filled: water) }
                    .buttonStyle(.lumePress)
                    .lumeEntrance(4)
                SectionHeader(title: "Repas du jour").lumeEntrance(5)
                if dayGroups.isEmpty {
                    emptyState.lumeEntrance(6)
                } else {
                    ForEach(Array(dayGroups.enumerated()), id: \.element.id) { idx, group in
                        mealGroup(group)
                            .lumeEntrance(6 + idx)
                            // Suppression : la carte rétrécit et s'efface (collapse).
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .top)),
                                removal: .scale(scale: 0.8).combined(with: .opacity)
                            ))
                    }
                }
            }
            .padding(.horizontal, Spacing.xl).padding(.top, Spacing.sm).padding(.bottom, 130)
            .animation(LumeMotion.snappy, value: dayFoods.count)
        }
        .background(LumeColor.cream)
        .onChange(of: highlightTrigger) { _, _ in
            withAnimation(LumeMotion.celebrate) { highlight = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                withAnimation(LumeMotion.smooth) { highlight = false }
            }
            // Un repas vient d'être logué : vérifie les badges nutrition à débloquer.
            let fresh = BadgeEvaluator.reconcileNutrition(foods: streakFoods, target: target, context: ctx)
            if !fresh.isEmpty { celebrateBadges = fresh }
        }
        // Tient le widget (calories+macros du jour) à jour.
        .task(id: todayConsumed) { WidgetUpdater.update(consumed: todayConsumed, target: target) }
        // Rattrape les badges nutrition déjà mérités (sans célébration au lancement).
        .task { BadgeEvaluator.reconcileNutrition(foods: streakFoods, target: target, context: ctx) }
        .sheet(isPresented: Binding(get: { !celebrateBadges.isEmpty }, set: { if !$0 { celebrateBadges = [] } })) {
            BadgeCelebrationView(badges: celebrateBadges) { celebrateBadges = [] }
        }
        .sheet(isPresented: $showWater) { WaterDetailView() }
        .sheet(isPresented: $showSearch) { SearchView() }
        .sheet(isPresented: $showCalendar) { MealCalendarView() }
        .sheet(item: $routeEntry) { FoodDetailView(entry: $0) }
        .sheet(item: $mealToDelete) { meal in
            let n = meal.foods.count
            LumeConfirmSheet(icon: .minusCircle, tint: LumeColor.negative,
                             title: "Supprimer ce repas ?",
                             message: "« \(meal.title) » et ses \(n) aliment\(n > 1 ? "s" : "") seront retirés du journal.",
                             confirmTitle: "Supprimer le repas") { confirmDelete(meal) }
        }
        .sensoryFeedback(.success, trigger: didDelete)
        .sheet(isPresented: $showStreak) {
            StreakDetailView(streak: streak, record: streakRecord)
        }
        .sheet(item: $mealToRename) { meal in
            MealRenameSheet(currentName: meal.title) { newName in
                rename(meal, to: newName)
            }
        }
    }

    private func rename(_ meal: DeletableMeal, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        withAnimation(LumeMotion.snappy) {
            for food in meal.foods {
                food.mealTitle = trimmed
            }
        }
    }

    private func confirmDelete(_ meal: DeletableMeal) {
        mealToDelete = nil
        // Laisse la feuille se fermer, puis anime la disparition de la carte.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(LumeMotion.bouncy) {
                for food in meal.foods {
                    ctx.delete(food)
                }
            }
            didDelete.toggle()
        }
    }

    @ViewBuilder
    private func mealGroup(_ group: DayGroup) -> some View {
        if group.isScannedMeal {
            scannedMealCard(group)
        } else {
            // Créneau d'ajouts isolés : en-tête léger + lignes (toujours visibles).
            VStack(alignment: .leading, spacing: Spacing.sm) {
                groupHeaderLabel(group)
                ForEach(group.foods) { food in foodLine(food) }
            }
        }
    }

    /// Carte synthétique d'un repas scanné : nom + total + chips P/G/L, repliable au tap.
    private func scannedMealCard(_ group: DayGroup) -> some View {
        let isOpen = expanded.contains(group.id)
        return VStack(spacing: 0) {
            HStack(alignment: .top, spacing: Spacing.sm) {
                Button {
                    withAnimation(LumeMotion.bouncy) {
                        if isOpen { expanded.remove(group.id) } else { expanded.insert(group.id) }
                    }
                } label: {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        HStack(spacing: Spacing.sm) {
                            Image(appIcon: group.icon).lumeIcon(16, weight: .semibold).foregroundStyle(group.tint)
                            Text(group.title).font(.lumeHeadline).foregroundStyle(LumeColor.ink).lineLimit(1)
                            Spacer()
                            Text("\(group.kcal) kcal").font(.lumeCallout.weight(.bold))
                                .foregroundStyle(LumeColor.ink).monospacedDigit()
                            Image(appIcon: .forward)
                                .lumeIcon(13, weight: .bold).foregroundStyle(LumeColor.muted)
                                .rotationEffect(.degrees(isOpen ? 90 : 0)) // chevron qui pivote en douceur
                        }
                        HStack(spacing: Spacing.sm) {
                            Chip(color: LumeColor.protein, text: "P \(group.macros.protein) g")
                            Chip(color: LumeColor.carbs, text: "G \(group.macros.carbs) g")
                            Chip(color: LumeColor.fat, text: "L \(group.macros.fat) g")
                        }
                    }
                }
                .buttonStyle(.lumePress)

                // Menu d'actions : accessible sans déplier la carte.
                Menu {
                    Button { requestRename(group) } label: { Label("Renommer", systemImage: "pencil") }
                    Button(role: .destructive) { requestDelete(group) } label: {
                        Label("Supprimer le repas", systemImage: "trash")
                    }
                } label: {
                    Image(appIcon: .more).lumeIcon(16, weight: .bold).foregroundStyle(LumeColor.muted)
                        .frame(width: 30, height: 30).contentShape(Rectangle())
                }
            }

            // Dépliement : les ingrédients se révèlent en cascade (stagger), avec un
            // masquage propre par hauteur (clipped) pour éviter tout chevauchement saccadé.
            VStack(spacing: Spacing.sm) {
                Divider().background(LumeColor.border).padding(.vertical, Spacing.xs)
                ForEach(Array(group.foods.enumerated()), id: \.element.id) { idx, food in
                    foodLine(food)
                        .opacity(isOpen ? 1 : 0)
                        .offset(y: isOpen ? 0 : -8)
                        .animation(LumeMotion.smooth.delay(isOpen ? Double(idx) * 0.05 : 0), value: isOpen)
                }
            }
            .padding(.top, Spacing.sm)
            .frame(maxHeight: isOpen ? .infinity : 0, alignment: .top)
            .opacity(isOpen ? 1 : 0)
            .clipped()
        }
        .padding(Spacing.lg)
        .background(LumeColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .lumeShadow(.soft)
        .animation(LumeMotion.bouncy, value: isOpen)
        .contextMenu {
            Button { requestRename(group) } label: {
                Label("Renommer", systemImage: "pencil")
            }
            Button(role: .destructive) { requestDelete(group) } label: {
                Label("Supprimer le repas", systemImage: "trash")
            }
        }
    }

    /// Prépare la confirmation de suppression d'un repas (groupe d'aliments).
    private func requestDelete(_ group: DayGroup) {
        mealToDelete = DeletableMeal(id: group.id, title: group.title, foods: group.foods)
    }

    private func requestRename(_ group: DayGroup) {
        mealToRename = DeletableMeal(id: group.id, title: group.title, foods: group.foods)
    }

    private func groupHeaderLabel(_ group: DayGroup) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(appIcon: group.icon).lumeIcon(15, weight: .semibold).foregroundStyle(group.tint)
            Text(group.title).font(.lumeSubhead.weight(.semibold)).foregroundStyle(LumeColor.ink).lineLimit(1)
            Spacer()
            Text("\(group.kcal) kcal")
                .font(.lumeFootnote.weight(.semibold)).foregroundStyle(LumeColor.muted).monospacedDigit()
        }
        .padding(.horizontal, Spacing.xs)
    }

    private func foodLine(_ food: LoggedFood) -> some View {
        FoodRow(name: food.name,
                detail: "\(food.grams) g · P \(food.protein) G \(food.carbs) L \(food.fat)",
                kcal: food.kcal, trailing: .forward) { routeEntry = food }
            .onTapGesture { routeEntry = food }
    }

    private var header: some View {
        HStack(spacing: Spacing.sm) {
            // Sur un jour passé : flèche pour revenir à aujourd'hui.
            if !isToday {
                Button { withAnimation(LumeMotion.smooth) { selectedDay = cal.startOfDay(for: Date()) } } label: {
                    Image(appIcon: .back).lumeIcon(18, weight: .semibold).foregroundStyle(LumeColor.ink)
                        .frame(width: 40, height: 40).background(LumeColor.surface).clipShape(Circle()).lumeShadow(.soft)
                }
                .buttonStyle(.lumePress)
                .accessibilityLabel("Revenir à aujourd'hui")
                .transition(.move(edge: .leading).combined(with: .opacity))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(Formatters.dayMonthFR.string(from: selectedDay).capitalized)
                    .font(.lumeSubhead).foregroundStyle(LumeColor.muted)
                Text(isToday ? "Aujourd'hui" : "Historique")
                    .font(.lumeDisplay).foregroundStyle(LumeColor.ink)
                    .contentTransition(.opacity)
            }
            Spacer()
            if isToday, streak > 0 {
                Button { showStreak = true } label: { StreakPill(days: streak) }
                    .buttonStyle(.lumePress)
                    .accessibilityLabel("Série de \(streak) jours")
            }
            Button { showCalendar = true } label: {
                Image(appIcon: .recents).lumeIcon(20, weight: .semibold).foregroundStyle(LumeColor.ink)
                    .frame(width: 40, height: 40).background(LumeColor.surface).clipShape(Circle()).lumeShadow(.soft)
            }
            .buttonStyle(.lumePress)
            .accessibilityLabel("Historique")
            Button { showSearch = true } label: {
                Image(appIcon: .search).lumeIcon(20, weight: .semibold).foregroundStyle(LumeColor.ink)
                    .frame(width: 40, height: 40).background(LumeColor.surface).clipShape(Circle()).lumeShadow(.soft)
            }
            .buttonStyle(.lumePress)
            .accessibilityLabel("Rechercher un aliment")
        }
    }

    private var emptyState: some View {
        LumeEmptyState(icon: .camera,
                       title: isToday ? "Aucun repas aujourd'hui" : "Aucun repas ce jour-là",
                       message: isToday ? "Touche + pour scanner ton premier plat" : nil)
    }
}

#Preview { TodayView().modelContainer(LumeStore.preview) }
