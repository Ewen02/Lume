import Foundation
import SwiftData

/// Profil persistant de l'utilisateur (sert au calcul TDEE → cibles macros).
/// Un seul enregistrement par store (= par compte iCloud, modèle local-first).
@Model
final class ProfileRecord {
    var name: String = "Ewen"
    var sexRaw: String = "male"
    var age: Int = 24
    var heightCm: Int = 178
    var weightKg: Double = 74
    var activityRaw: String = "moderate"
    var goalRaw: String = "maintain"

    init(name: String = "Ewen", sexRaw: String = "male", age: Int = 24, heightCm: Int = 178,
         weightKg: Double = 74, activityRaw: String = "moderate", goalRaw: String = "maintain")
    {
        self.name = name; self.sexRaw = sexRaw; self.age = age; self.heightCm = heightCm
        self.weightKg = weightKg; self.activityRaw = activityRaw; self.goalRaw = goalRaw
    }

    convenience init(from p: UserProfile) {
        self.init(name: p.name, sexRaw: p.sex == .male ? "male" : "female", age: p.age,
                  heightCm: p.heightCm, weightKg: p.weightKg,
                  activityRaw: Self.raw(p.activity), goalRaw: Self.raw(p.goal))
    }

    func update(from p: UserProfile) {
        name = p.name; sexRaw = p.sex == .male ? "male" : "female"; age = p.age
        heightCm = p.heightCm; weightKg = p.weightKg
        activityRaw = Self.raw(p.activity); goalRaw = Self.raw(p.goal)
    }

    var profile: UserProfile {
        UserProfile(name: name, sex: sexRaw == "female" ? .female : .male, age: age,
                    heightCm: heightCm, weightKg: weightKg,
                    activity: Self.activity(activityRaw), goal: Self.goal(goalRaw))
    }

    /// Mapping enum <-> string (les enums n'ont pas de rawValue stockable)
    static func raw(_ a: ActivityLevel) -> String {
        switch a { case .sedentary: "sedentary"; case .light: "light"; case .moderate: "moderate"; case .active: "active"; case .veryActive: "veryActive" }
    }

    static func activity(_ s: String) -> ActivityLevel {
        switch s { case "sedentary": .sedentary; case "light": .light; case "active": .active; case "veryActive": .veryActive; default: .moderate }
    }

    static func raw(_ g: Goal) -> String {
        switch g { case .lose: "lose"; case .maintain: "maintain"; case .gain: "gain" }
    }

    static func goal(_ s: String) -> Goal {
        switch s { case "lose": .lose; case "gain": .gain; default: .maintain }
    }
}
