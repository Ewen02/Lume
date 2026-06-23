import SwiftUI
import WidgetKit

/// Point d'entrée de l'extension widget.
/// ⚠️ Cible séparée à créer dans Xcode (File ▸ New ▸ Target ▸ Widget Extension). Voir Widget-setup.md.
@main
struct LumeWidgetBundle: WidgetBundle {
    var body: some Widget {
        LumeCaloriesWidget()
    }
}
