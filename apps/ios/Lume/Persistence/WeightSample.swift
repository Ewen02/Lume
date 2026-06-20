import Foundation
import SwiftData

/// Échantillon de poids (cache local ; la source de vérité sera HealthKit).
@Model
final class WeightSample {
    var date: Date = Date()
    var kg: Double = 0
    init(date: Date = Date(), kg: Double) {
        self.date = date; self.kg = kg
    }
}
