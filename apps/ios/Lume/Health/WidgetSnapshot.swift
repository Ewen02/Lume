import Foundation

/// Snapshot léger des chiffres du jour, partagé entre l'app et le widget via App Group.
/// L'app l'écrit quand le journal change ; le widget le lit (il ne touche pas SwiftData).
struct WidgetSnapshot: Codable {
    var kcal: Int
    var targetKcal: Int
    var protein: Int
    var targetProtein: Int
    var carbs: Int
    var targetCarbs: Int
    var fat: Int
    var targetFat: Int
    var updatedAt: Date

    static let empty = WidgetSnapshot(kcal: 0, targetKcal: 2400, protein: 0, targetProtein: 150,
                                      carbs: 0, targetCarbs: 270, fat: 0, targetFat: 80,
                                      updatedAt: Date(timeIntervalSince1970: 0))
}

/// Lecture/écriture du snapshot dans le conteneur App Group partagé.
/// ⚠️ Le `suiteName` doit correspondre à l'App Group activé sur l'app ET le widget (voir Widget-setup.md).
enum WidgetStore {
    /// Identifiant de l'App Group. À adapter au tien si le bundle diffère.
    static let appGroup = "group.com.lume.shared"
    private static let key = "lume.widget.snapshot"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroup)
    }

    static func save(_ snapshot: WidgetSnapshot) {
        guard let defaults, let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: key)
    }

    static func load() -> WidgetSnapshot {
        guard let defaults,
              let data = defaults.data(forKey: key),
              let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
        else { return .empty }
        return snapshot
    }
}
