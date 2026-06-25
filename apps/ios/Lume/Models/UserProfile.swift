import Foundation

enum Sex { case male, female }
enum ActivityLevel: CaseIterable {
    case sedentary, light, moderate, active, veryActive
    var factor: Double {
        switch self {
        case .sedentary: 1.2
        case .light: 1.375
        case .moderate: 1.55
        case .active: 1.725
        case .veryActive: 1.9
        }
    }

    var label: String {
        switch self {
        case .sedentary: "Sédentaire"
        case .light: "Légère"
        case .moderate: "Modérée"
        case .active: "Active"
        case .veryActive: "Très active"
        }
    }
}

enum Goal { case lose, maintain, gain
    /// Ajustement énergétique exprimé en **fraction du TDEE** (pas un kcal fixe) : un déficit
    /// proportionnel donne une vitesse de perte/prise cohérente quel que soit le gabarit.
    /// −15 % en perte, +10 % en prise — repères usuels et sûrs.
    var tdeeFactor: Double {
        switch self { case .lose: 0.85; case .maintain: 1.0; case .gain: 1.10 }
    }

    /// Cible protéique (g par kg de poids corporel), modulée selon l'objectif :
    /// sèche → plus de protéines pour préserver le muscle en déficit ; maintien → modéré.
    var proteinPerKg: Double {
        switch self { case .lose: 2.0; case .maintain: 1.6; case .gain: 1.8 }
    }

    var label: String {
        switch self { case .lose: "Perdre"; case .maintain: "Maintenir"; case .gain: "Prendre" }
    }
}

struct UserProfile {
    var name: String
    var sex: Sex
    var age: Int
    var heightCm: Int
    var weightKg: Double
    var activity: ActivityLevel
    var goal: Goal
    /// Objectif de poids en kg. `0` = non défini (le graphe Progrès masque la ligne d'objectif).
    var targetWeightKg: Double = 0
}
