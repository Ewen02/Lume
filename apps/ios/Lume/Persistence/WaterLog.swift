import Foundation
import SwiftData

/// Compteur de verres d'eau pour un jour donné.
@Model
final class WaterLog {
    var day: Date = Date()
    var glasses: Int = 0
    init(day: Date = Date(), glasses: Int = 0) {
        self.day = day; self.glasses = glasses
    }
}
