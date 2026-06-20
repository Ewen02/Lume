import Foundation

/// Estimation du 1RM (charge max théorique sur 1 rép).
enum OneRepMax {
    static func epley(weight: Double, reps: Int) -> Double {
        reps <= 1 ? weight : weight * (1 + Double(reps) / 30)
    }

    static func brzycki(weight: Double, reps: Int) -> Double {
        reps <= 1 ? weight : weight * 36 / (37 - Double(reps))
    }

    /// Moyenne des deux formules, arrondie.
    static func estimate(weight: Double, reps: Int) -> Int {
        Int(((epley(weight: weight, reps: reps) + brzycki(weight: weight, reps: reps)) / 2).rounded())
    }
}
