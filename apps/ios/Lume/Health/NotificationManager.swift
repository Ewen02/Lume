import Foundation
import UserNotifications

/// Planifie les rappels locaux (repas à heures fixes + séance muscu certains jours).
/// Source de configuration : `ProfileRecord`. Idempotent : on annule puis on replanifie.
@MainActor
enum NotificationManager {
    private static let center = UNUserNotificationCenter.current()

    /// Préfixes d'identifiants pour ne ré-annuler que NOS rappels.
    private enum ID {
        static let meal = "lume.reminder.meal."
        static let workout = "lume.reminder.workout."
        static let water = "lume.reminder.water."
    }

    /// Autorisation accordée ? (sans la redemander)
    static func isAuthorized() async -> Bool {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
    }

    /// (Re)planifie tous les rappels depuis la config du profil. À appeler après tout changement de réglage.
    static func reschedule(from profile: ProfileRecord) async {
        await cancelAll()
        guard await isAuthorized() else { return }

        if profile.mealRemindersOn {
            for (i, minute) in profile.mealReminderMinutes.enumerated() {
                schedule(id: ID.meal + "\(i)",
                         title: "Lume",
                         body: mealBody(at: minute),
                         minute: minute,
                         weekday: nil)
            }
        }

        if profile.workoutRemindersOn {
            for weekday in profile.workoutReminderWeekdays {
                schedule(id: ID.workout + "\(weekday)",
                         title: "Séance du jour 💪",
                         body: "C'est l'heure de bouger. Lance ta séance sur Lume.",
                         minute: profile.workoutReminderMinute,
                         weekday: weekday)
            }
        }

        if profile.waterRemindersOn {
            for (i, minute) in waterMinutes(for: profile).enumerated() {
                schedule(id: ID.water + "\(i)",
                         title: "Hydratation 💧",
                         body: "Pense à boire un verre d'eau.",
                         minute: minute,
                         weekday: nil)
            }
        }
    }

    /// Heures de rappel d'hydratation : de start à end par pas de `intervalHours`.
    private static func waterMinutes(for p: ProfileRecord) -> [Int] {
        let step = max(1, p.waterReminderIntervalHours) * 60
        guard p.waterReminderEndMinute > p.waterReminderStartMinute else { return [] }
        var out: [Int] = []
        var m = p.waterReminderStartMinute
        while m <= p.waterReminderEndMinute, out.count < 12 {
            out.append(m); m += step
        }
        return out
    }

    /// Annule uniquement les rappels Lume (repas, hydratation, séance).
    static func cancelAll() async {
        let pending = await center.pendingNotificationRequests()
        let ours = pending.map(\.identifier).filter {
            $0.hasPrefix(ID.meal) || $0.hasPrefix(ID.workout) || $0.hasPrefix(ID.water)
        }
        center.removePendingNotificationRequests(withIdentifiers: ours)
    }

    // MARK: - Minuteur de repos

    private static let restID = "lume.rest.timer"

    /// Notifie la fin du repos dans `seconds` (survit à l'app en arrière-plan / fermée).
    static func scheduleRestEnd(in seconds: Int) {
        cancelRestEnd()
        guard seconds > 0 else { return }
        let content = UNMutableNotificationContent()
        content.title = "Repos terminé"
        content.body = "C'est reparti — série suivante 💪"
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(seconds), repeats: false)
        center.add(UNNotificationRequest(identifier: restID, content: content, trigger: trigger))
    }

    /// Annule la notification de repos (repos passé / ajusté).
    static func cancelRestEnd() {
        center.removePendingNotificationRequests(withIdentifiers: [restID])
    }

    // MARK: - Privé

    /// Planifie une notification répétitive. `weekday == nil` → tous les jours à `minute`.
    private static func schedule(id: String, title: String, body: String, minute: Int, weekday: Int?) {
        var comps = DateComponents()
        comps.hour = minute / 60
        comps.minute = minute % 60
        if let weekday { comps.weekday = weekday }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        center.add(request)
    }

    private static func mealBody(at minute: Int) -> String {
        switch minute / 60 {
        case ..<11: "N'oublie pas de logger ton petit-déjeuner."
        case 11 ..< 15: "Pense à logger ton déjeuner 🍽️"
        case 15 ..< 18: "Une collation ? Note-la sur Lume."
        default: "Pense à logger ton dîner avant de te coucher."
        }
    }
}
