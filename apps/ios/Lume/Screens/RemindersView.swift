import SwiftData
import SwiftUI

/// Réglage des rappels (notifications locales) : repas + hydratation + séance.
/// Persiste dans `ProfileRecord` et (re)planifie via `NotificationManager`.
struct RemindersView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [ProfileRecord]

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                if let record = profiles.first {
                    RemindersForm(record: record)
                } else {
                    LumeEmptyState(icon: .warning, title: "Profil manquant",
                                   message: "Termine ton profil pour configurer les rappels.")
                }
            }
            .padding(.horizontal, Spacing.xl).padding(.top, Spacing.sm).padding(.bottom, Spacing.xxl)
        }
        .background(LumeColor.cream.ignoresSafeArea())
        .safeAreaInset(edge: .top) {
            TopBar(title: "Rappels", leading: .back, onLeading: { dismiss() })
                .padding(.horizontal, Spacing.xl).padding(.vertical, Spacing.sm).background(LumeColor.cream)
        }
    }
}

/// Formulaire lié au profil. `@Bindable` → muter une propriété rafraîchit la vue ET marque le contexte dirty.
private struct RemindersForm: View {
    @Environment(\.modelContext) private var ctx
    @Bindable var record: ProfileRecord
    @State private var authorized = false

    /// Jours de la semaine (calendrier Apple : 1 = dimanche). Affichés lun→dim.
    private let weekdays: [(code: Int, label: String)] = [
        (2, "L"), (3, "M"), (4, "M"), (5, "J"), (6, "V"), (7, "S"), (1, "D"),
    ]

    var body: some View {
        VStack(spacing: Spacing.lg) {
            mealCard
            waterCard
            workoutCard
            if !authorized {
                Text("Active les notifications dans Réglages pour recevoir tes rappels.")
                    .font(.lumeFootnote).foregroundStyle(LumeColor.muted)
                    .multilineTextAlignment(.center).padding(.horizontal, Spacing.xl)
            }
        }
        .task { authorized = await NotificationManager.isAuthorized() }
    }

    // MARK: Repas

    private var mealCard: some View {
        LumeCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Toggle(isOn: toggle(\.mealRemindersOn)) {
                    Text("Rappels de repas").font(.lumeHeadline).foregroundStyle(LumeColor.ink)
                }.tint(LumeColor.ink)

                if record.mealRemindersOn {
                    Text("Heures de rappel quotidiennes").font(.lumeFootnote).foregroundStyle(LumeColor.muted)
                    ForEach(Array(record.mealReminderMinutes.enumerated()), id: \.offset) { idx, _ in
                        HStack {
                            DatePicker("", selection: mealTimeBinding(idx), displayedComponents: .hourAndMinute)
                                .labelsHidden()
                            Spacer()
                            if record.mealReminderMinutes.count > 1 {
                                Button { removeMealTime(idx) } label: {
                                    Image(appIcon: .minusCircle).lumeIcon(20).foregroundStyle(LumeColor.muted)
                                }.buttonStyle(.lumePress)
                            }
                        }
                    }
                    if record.mealReminderMinutes.count < 5 {
                        Button { addMealTime() } label: {
                            HStack(spacing: Spacing.sm) {
                                Image(appIcon: .add).lumeIcon(14, weight: .semibold)
                                Text("Ajouter une heure").font(.lumeSubhead)
                            }.foregroundStyle(LumeColor.ink)
                        }.buttonStyle(.lumePress)
                    }
                }
            }
        }
    }

    // MARK: Hydratation

    private var waterCard: some View {
        LumeCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Toggle(isOn: toggle(\.waterRemindersOn)) {
                    Text("Rappel d'hydratation").font(.lumeHeadline).foregroundStyle(LumeColor.ink)
                }.tint(LumeColor.ink)

                if record.waterRemindersOn {
                    HStack {
                        Text("De").font(.lumeSubhead).foregroundStyle(LumeColor.ink)
                        DatePicker("", selection: waterBinding(isStart: true), displayedComponents: .hourAndMinute)
                            .labelsHidden()
                        Text("à").font(.lumeSubhead).foregroundStyle(LumeColor.ink)
                        DatePicker("", selection: waterBinding(isStart: false), displayedComponents: .hourAndMinute)
                            .labelsHidden()
                    }
                    HStack {
                        Text("Toutes les").font(.lumeSubhead).foregroundStyle(LumeColor.ink)
                        Spacer()
                        Stepper("\(record.waterReminderIntervalHours) h",
                                value: Binding(
                                    get: { record.waterReminderIntervalHours },
                                    set: { record.waterReminderIntervalHours = min(6, max(1, $0)); apply() }
                                ), in: 1 ... 6)
                            .font(.lumeSubhead.weight(.semibold)).foregroundStyle(LumeColor.ink).fixedSize()
                    }
                }
            }
        }
    }

    // MARK: Séance

    private var workoutCard: some View {
        LumeCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Toggle(isOn: toggle(\.workoutRemindersOn)) {
                    Text("Rappel de séance").font(.lumeHeadline).foregroundStyle(LumeColor.ink)
                }.tint(LumeColor.ink)

                if record.workoutRemindersOn {
                    Text("Jours").font(.lumeFootnote).foregroundStyle(LumeColor.muted)
                    HStack(spacing: Spacing.xs) {
                        ForEach(weekdays, id: \.code) { day in
                            let active = record.workoutReminderWeekdays.contains(day.code)
                            Text(day.label).font(.lumeSubhead.weight(.semibold))
                                .foregroundStyle(active ? LumeColor.surface : LumeColor.textSecondary)
                                .frame(maxWidth: .infinity).frame(height: 40)
                                .background(active ? LumeColor.ink : LumeColor.cream)
                                .clipShape(Circle())
                                .onTapGesture { withAnimation(LumeMotion.snappy) { toggleWorkoutDay(day.code) } }
                        }
                    }
                    HStack {
                        Text("Heure").font(.lumeSubhead).foregroundStyle(LumeColor.ink)
                        Spacer()
                        DatePicker("", selection: workoutTimeBinding, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                    }
                }
            }
        }
    }

    // MARK: Bindings

    /// Toggle d'activation : demande l'autorisation à l'allumage, persiste et replanifie.
    private func toggle(_ keyPath: ReferenceWritableKeyPath<ProfileRecord, Bool>) -> Binding<Bool> {
        Binding(
            get: { record[keyPath: keyPath] },
            set: { on in
                Task {
                    if on { await ensureAuthorized() }
                    record[keyPath: keyPath] = on && authorized
                    apply()
                }
            }
        )
    }

    private func mealTimeBinding(_ idx: Int) -> Binding<Date> {
        Binding(
            get: { Self.date(fromMinutes: record.mealReminderMinutes[safe: idx] ?? 720) },
            set: { newDate in
                guard idx < record.mealReminderMinutes.count else { return }
                record.mealReminderMinutes[idx] = Self.minutes(from: newDate)
                apply()
            }
        )
    }

    private var workoutTimeBinding: Binding<Date> {
        Binding(
            get: { Self.date(fromMinutes: record.workoutReminderMinute) },
            set: { record.workoutReminderMinute = Self.minutes(from: $0); apply() }
        )
    }

    private func waterBinding(isStart: Bool) -> Binding<Date> {
        Binding(
            get: { Self.date(fromMinutes: isStart ? record.waterReminderStartMinute : record.waterReminderEndMinute) },
            set: { newDate in
                let m = Self.minutes(from: newDate)
                if isStart { record.waterReminderStartMinute = m } else { record.waterReminderEndMinute = m }
                apply()
            }
        )
    }

    // MARK: Actions

    private func toggleWorkoutDay(_ code: Int) {
        if let i = record.workoutReminderWeekdays.firstIndex(of: code) {
            record.workoutReminderWeekdays.remove(at: i)
        } else {
            record.workoutReminderWeekdays.append(code)
        }
        apply()
    }

    private func addMealTime() {
        record.mealReminderMinutes.append(1080) // 18h par défaut
        apply()
    }

    private func removeMealTime(_ idx: Int) {
        guard idx < record.mealReminderMinutes.count else { return }
        record.mealReminderMinutes.remove(at: idx)
        apply()
    }

    private func ensureAuthorized() async {
        if await NotificationManager.isAuthorized() { authorized = true; return }
        authorized = await Permissions.requestNotifications()
    }

    private func apply() {
        try? ctx.save()
        let r = record
        Task { await NotificationManager.reschedule(from: r) }
    }

    // MARK: Helpers minutes ↔ Date (seule l'heure compte)

    private static func date(fromMinutes m: Int) -> Date {
        Calendar.current.date(bySettingHour: m / 60, minute: m % 60, second: 0, of: Date()) ?? Date()
    }

    private static func minutes(from date: Date) -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#Preview { RemindersView().modelContainer(LumeStore.preview) }
