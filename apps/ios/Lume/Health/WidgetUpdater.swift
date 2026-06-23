import Foundation
import WidgetKit

/// Côté app : met à jour le snapshot partagé et recharge les timelines du widget.
/// À appeler quand les chiffres du jour changent (ajout/suppression de repas, lancement).
enum WidgetUpdater {
    static func update(consumed: Macros, target: Macros) {
        let snapshot = WidgetSnapshot(
            kcal: consumed.kcal, targetKcal: target.kcal,
            protein: consumed.protein, targetProtein: target.protein,
            carbs: consumed.carbs, targetCarbs: target.carbs,
            fat: consumed.fat, targetFat: target.fat,
            updatedAt: Date()
        )
        WidgetStore.save(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
