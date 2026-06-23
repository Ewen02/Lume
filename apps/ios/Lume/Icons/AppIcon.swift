import SwiftUI

/// Catalogue centralisé des SF Symbols utilisés dans Lume.
///
/// Avantages :
/// - Un seul endroit pour changer une icône (pas de chaînes "flame.fill" éparpillées).
/// - Autocomplétion + sécurité de compilation (`AppIcon.streak` plutôt qu'une string).
///
/// Usage :
///   Image(appIcon: .streak)
///   AppIcon.streak.image.font(.title2)
///   Label("Aujourd'hui", appIcon: .today)
enum AppIcon: String {
    // MARK: Navigation

    case today = "house.fill"
    case workout = "dumbbell.fill"
    case progress = "chart.line.uptrend.xyaxis"
    case profile = "person.crop.circle"
    case person = "info.circle"
    case add = "plus"
    case minus

    // MARK: Dashboard

    case streak = "flame.fill"
    case calories = "flame.circle.fill"
    case water = "drop.fill"
    // Macros : un anneau coloré + label suffit. Symboles optionnels si besoin :
    case protein = "fork.knife"
    case carbs = "leaf.fill"
    case fat = "drop.circle.fill"

    // MARK: Capture

    case camera = "camera.fill"
    case barcode = "barcode.viewfinder"
    case label = "text.viewfinder"
    case gallery = "photo.on.rectangle"
    case viewfinder
    case warning = "exclamationmark.triangle"

    // MARK: Repas

    case breakfast = "sunrise.fill"
    case lunch = "sun.max.fill"
    case dinner = "moon.stars.fill"
    case snack = "takeoutbag.and.cup.and.straw.fill"

    // MARK: Communs

    case back = "chevron.left"
    case forward = "chevron.right"
    case minusCircle = "minus.circle.fill"
    case close = "xmark"
    case validate = "checkmark.circle.fill"
    case edit = "pencil"
    case more = "ellipsis"
    case trash
    case favorite = "star.fill"
    case favoriteOutline = "star"
    case lock = "lock.fill"
    case recents = "clock.arrow.circlepath"
    case settings = "gearshape.fill"
    case weight = "scalemass.fill"
    case search = "magnifyingglass"
    case wifiError = "wifi.exclamationmark"

    // MARK: Muscu (v2)

    case plates = "circle.grid.2x2"
    case restTimer = "timer"
    case pr = "trophy.fill"
    case addSet = "plus.circle.fill"
    case exercise = "figure.strengthtraining.traditional"
    case routine = "list.bullet.rectangle"
    case oneRepMax = "chart.bar.fill"

    /// Le nom SF Symbol brut, si besoin d'une string (ex. `.tabItem`).
    var systemName: String {
        rawValue
    }

    /// L'icône prête à styliser.
    var image: Image {
        Image(systemName: rawValue)
    }
}

// MARK: - Sucre syntaxique

extension Image {
    /// `Image(appIcon: .streak)`
    init(appIcon: AppIcon) {
        self.init(systemName: appIcon.systemName)
    }
}

extension Label where Title == Text, Icon == Image {
    /// `Label("Aujourd'hui", appIcon: .today)`
    init(_ title: String, appIcon: AppIcon) {
        self.init(title, systemImage: appIcon.systemName)
    }
}
