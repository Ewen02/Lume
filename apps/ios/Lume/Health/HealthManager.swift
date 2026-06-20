import Foundation
import HealthKit
import Observation

/// Pont vers HealthKit : lit le poids (source de vérité du graphe Progrès) et
/// écrit l'énergie, les macros et l'eau quand l'utilisateur journalise.
/// iOS 17 — API async/await (HKSampleQueryDescriptor, requestAuthorization).
@Observable
@MainActor
final class HealthManager {
    static let shared = HealthManager()
    private init() {}

    private let store = HKHealthStore()
    var isAuthorized = false
    var latestWeightKg: Double?
    var weightSeries: [WeightEntry] = []

    var available: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    private let weightType = HKQuantityType(.bodyMass)
    private var shareTypes: Set<HKSampleType> {
        [HKQuantityType(.dietaryEnergyConsumed), HKQuantityType(.dietaryProtein),
         HKQuantityType(.dietaryCarbohydrates), HKQuantityType(.dietaryFatTotal),
         HKQuantityType(.dietaryWater), HKObjectType.workoutType()]
    }

    private var readTypes: Set<HKObjectType> {
        [weightType]
    }

    /// Demande l'autorisation puis charge le poids. Idempotent.
    func requestAuthorization() async {
        guard available else { return }
        do {
            try await store.requestAuthorization(toShare: shareTypes, read: readTypes)
            isAuthorized = true
            await refreshWeight()
        } catch {
            isAuthorized = false
        }
    }

    /// Recharge les 60 derniers échantillons de poids (ordre chronologique).
    func refreshWeight() async {
        guard available else { return }
        do {
            let predicate = HKSamplePredicate.quantitySample(type: weightType, predicate: nil)
            let descriptor = HKSampleQueryDescriptor(
                predicates: [predicate],
                sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)],
                limit: 60
            )
            let samples = try await descriptor.result(for: store)
            let series = samples
                .map { WeightEntry(date: $0.startDate, kg: $0.quantity.doubleValue(for: .gramUnit(with: .kilo))) }
                .sorted { $0.date < $1.date }
            weightSeries = series
            latestWeightKg = series.last?.kg
        } catch {
            // silencieux : le graphe retombe sur ses données de secours
        }
    }

    /// Écrit un repas comme corrélation alimentaire (énergie + macros) dans Santé.
    func logMeal(kcal: Int, protein: Int, carbs: Int, fat: Int, date: Date = Date()) async {
        guard available else { return }
        var samples: Set<HKSample> = []
        func add(_ id: HKQuantityTypeIdentifier, _ unit: HKUnit, _ value: Double) {
            guard value > 0 else { return }
            samples.insert(HKQuantitySample(type: HKQuantityType(id),
                                            quantity: HKQuantity(unit: unit, doubleValue: value),
                                            start: date, end: date))
        }
        add(.dietaryEnergyConsumed, .kilocalorie(), Double(kcal))
        add(.dietaryProtein, .gram(), Double(protein))
        add(.dietaryCarbohydrates, .gram(), Double(carbs))
        add(.dietaryFatTotal, .gram(), Double(fat))
        guard !samples.isEmpty else { return }
        let meal = HKCorrelation(type: HKCorrelationType(.food), start: date, end: date, objects: samples)
        try? await store.save(meal)
    }

    /// Écrit une prise d'eau (en millilitres).
    func logWater(milliliters: Double, date: Date = Date()) async {
        guard available, milliliters > 0 else { return }
        let sample = HKQuantitySample(type: HKQuantityType(.dietaryWater),
                                      quantity: HKQuantity(unit: .literUnit(with: .milli), doubleValue: milliliters),
                                      start: date, end: date)
        try? await store.save(sample)
    }

    /// Enregistre un poids saisi manuellement puis recharge la série.
    func saveWeight(kg: Double, date: Date = Date()) async {
        guard available, kg > 0 else { return }
        let sample = HKQuantitySample(type: weightType,
                                      quantity: HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: kg),
                                      start: date, end: date)
        do { try await store.save(sample); await refreshWeight() } catch {}
    }

    /// Enregistre une séance de musculation comme HKWorkout (musculation traditionnelle).
    func saveWorkout(start: Date, end: Date) async {
        guard available, end > start else { return }
        let config = HKWorkoutConfiguration()
        config.activityType = .traditionalStrengthTraining
        let builder = HKWorkoutBuilder(healthStore: store, configuration: config, device: .local())
        do {
            try await builder.beginCollection(at: start)
            try await builder.endCollection(at: end)
            _ = try await builder.finishWorkout()
        } catch {
            // silencieux
        }
    }
}
