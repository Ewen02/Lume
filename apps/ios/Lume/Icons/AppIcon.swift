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
    case steps = "figure.walk"
    case activeEnergy = "flame"
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
    case info = "info.circle.fill"

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
    case calendar
    case recents = "clock.arrow.circlepath"
    case settings = "gearshape.fill"
    case weight = "scalemass.fill"
    case search = "magnifyingglass"
    case wifiError = "wifi.exclamationmark"
    case envelope = "envelope.fill"

    // MARK: Finance (v3 — module Argent)

    case money = "banknote.fill"
    case wallet = "wallet.pass.fill"
    case creditcard = "creditcard.fill"
    case pie = "chart.pie.fill"
    case incomeArrow = "arrow.down.left"
    case expenseArrow = "arrow.up.right"
    case recurring = "arrow.triangle.2.circlepath"
    case receipt = "doc.text.fill" // scan ticket (phase ultérieure)
    // Catégories de dépenses
    case food = "carrot.fill"
    case restaurant = "fork.knife.circle.fill"
    case transport = "car.fill"
    case housing = "house.circle.fill"
    case home = "cart.fill"
    case health = "cross.case.fill"
    case leisure = "gamecontroller.fill"
    case subscription = "repeat.circle.fill"
    case shopping = "bag.fill"
    case category = "square.grid.2x2.fill"
    case salary = "eurosign.circle.fill"
    case savings = "banknote"

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
