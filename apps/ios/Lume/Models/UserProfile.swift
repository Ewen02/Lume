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
    var kcalDelta: Int {
        switch self { case .lose: -400; case .maintain: 0; case .gain: 350 }
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
}
