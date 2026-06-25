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

    // MARK: Lectures Santé (peuplées par refreshAll)

    /// Consommation du jour saisie HORS Lume (autres apps), pour compléter le total local.
    var externalToday: Macros = .zero
    /// Eau du jour saisie hors Lume (millilitres).
    var externalWaterMl: Double = 0
    /// Pas du jour (toutes sources : capteurs / Apple Watch).
    var stepsToday: Int = 0
    /// Calories actives brûlées aujourd'hui (toutes sources) — pour la cible dynamique.
    var activeEnergyToday: Int = 0
    /// Séances récentes importées de Santé (lecture seule).
    var externalWorkouts: [ExternalWorkout] = []
    /// Séries 30 j pour les graphes d'activité de Progrès.
    var stepsSeries: [DayValue] = []
    var activeEnergySeries: [DayValue] = []

    var available: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    /// L'app a-t-elle l'entitlement HealthKit ? `isHealthDataAvailable()` reste `true` sur device
    /// même sans entitlement (le matériel est capable) ; seul l'entitlement détermine si la
    /// demande d'autorisation peut aboutir. On ne l'introspecte PAS au runtime (API non fiable) :
    /// on se cale sur un flag de compilation `HEALTHKIT_ENABLED`, posé dans les « Active Compilation
    /// Conditions » du target en même temps qu'on restaure Lume.entitlements (compte payant).
    /// Sur le build actuel (compte gratuit, entitlements vidés), le flag est absent → `false`,
    /// et l'UI présente Santé en « Bientôt » plutôt qu'en « Connecter » trompeur.
    var entitled: Bool {
        #if HEALTHKIT_ENABLED
            return available
        #else
            return false
        #endif
    }

    private let weightType = HKQuantityType(.bodyMass)
    private let energyType = HKQuantityType(.dietaryEnergyConsumed)
    private let proteinType = HKQuantityType(.dietaryProtein)
    private let carbsType = HKQuantityType(.dietaryCarbohydrates)
    private let fatType = HKQuantityType(.dietaryFatTotal)
    private let waterType = HKQuantityType(.dietaryWater)
    private let stepType = HKQuantityType(.stepCount)
    private let activeEnergyType = HKQuantityType(.activeEnergyBurned)

    private var shareTypes: Set<HKSampleType> {
        [energyType, proteinType, carbsType, fatType, waterType, HKObjectType.workoutType()]
    }

    private var readTypes: Set<HKObjectType> {
        [weightType, energyType, proteinType, carbsType, fatType, waterType,
         stepType, activeEnergyType, HKObjectType.workoutType()]
    }

    /// Demande l'autorisation puis charge toutes les lectures. Idempotent.
    func requestAuthorization() async {
        guard available else { return }
        do {
            try await store.requestAuthorization(toShare: shareTypes, read: readTypes)
            isAuthorized = true
            await refreshAll()
        } catch {
            isAuthorized = false
        }
    }

    /// Recharge toutes les lectures Santé (poids + conso/eau externes + activité + séances).
    /// Les sources Lume sont résolues d'abord (exclusion anti-double-comptage), puis les
    /// lectures — indépendantes — tournent en parallèle.
    func refreshAll() async {
        guard available else { return }
        await resolveLumeSources(force: true) // re-résout : de nouvelles sources Lume ont pu apparaître
        async let weight: Void = refreshWeight()
        async let diet: Void = refreshDietToday()
        async let water: Void = refreshWaterToday()
        async let activity: Void = refreshActivityToday()
        async let series: Void = refreshActivitySeries()
        async let workouts: Void = refreshExternalWorkouts()
        _ = await (weight, diet, water, activity, series, workouts)
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

    // MARK: - Lectures conso/activité

    /// Sources HealthKit appartenant à Lume (résolues par bundle identifier), mises en cache.
    /// `HKSource.default()` n'identifie PAS de façon fiable les échantillons écrits par l'app ;
    /// on résout donc les vraies sources de l'app via une HKSourceQuery, pour les exclure à la lecture.
    private var lumeSources: Set<HKSource> = []
    private var sourcesResolved = false

    /// Trouve les sources dont le bundle identifier correspond à l'app courante. On interroge
    /// **chaque** type que Lume écrit (énergie, eau ET séances) : un utilisateur qui ne loggue
    /// qu'un seul de ces types n'apparaîtrait pas dans les sources des autres → sans cette union,
    /// son eau serait recomptée ou ses séances échapperaient à la suppression au reset.
    /// Idempotent : ne re-résout pas une fois fait.
    /// Appelé en tête de chaque lecture qui exclut Lume, pour garantir l'exclusion quel que soit
    /// l'ordre d'appel (une vue peut rafraîchir l'eau/les séances avant `refreshAll`).
    private func resolveLumeSources(force: Bool = false) async {
        guard force || !sourcesResolved else { return }
        let bundleID = Bundle.main.bundleIdentifier
        var mine: Set<HKSource> = []
        let types: [HKSampleType] = [energyType, waterType, HKObjectType.workoutType()]
        for type in types {
            let found = await withCheckedContinuation { (cont: CheckedContinuation<Set<HKSource>, Never>) in
                let query = HKSourceQuery(sampleType: type, samplePredicate: nil) { _, sources, _ in
                    cont.resume(returning: Set((sources ?? []).filter { $0.bundleIdentifier == bundleID }))
                }
                store.execute(query)
            }
            mine.formUnion(found)
        }
        lumeSources = mine
        sourcesResolved = true
    }

    /// Prédicat d'exclusion des échantillons écrits par Lume (vide si sources non résolues → n'exclut rien).
    private func excludingLumePredicate() -> NSPredicate? {
        guard !lumeSources.isEmpty else { return nil }
        let fromLume = HKQuery.predicateForObjects(from: lumeSources)
        return NSCompoundPredicate(notPredicateWithSubpredicate: fromLume)
    }

    /// Prédicat « aujourd'hui, hors échantillons écrits par Lume » (anti double-comptage).
    private func todayExcludingLume() -> NSPredicate {
        let start = Calendar.current.startOfDay(for: Date())
        let datePred = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
        guard let notLume = excludingLumePredicate() else { return datePred }
        return NSCompoundPredicate(andPredicateWithSubpredicates: [datePred, notLume])
    }

    /// Somme cumulée d'un type quantitatif sur un prédicat (0 si indispo/non autorisé).
    private func sum(_ type: HKQuantityType, unit: HKUnit, predicate: NSPredicate) async -> Double {
        do {
            let descriptor = HKStatisticsQueryDescriptor(
                predicate: .quantitySample(type: type, predicate: predicate),
                options: .cumulativeSum
            )
            let stats = try await descriptor.result(for: store)
            return stats?.sumQuantity()?.doubleValue(for: unit) ?? 0
        } catch {
            return 0
        }
    }

    /// Conso du jour saisie hors Lume (énergie + macros).
    func refreshDietToday() async {
        guard available else { return }
        await resolveLumeSources()
        let pred = todayExcludingLume()
        // Les 4 sommes sont indépendantes → en parallèle.
        async let kcal = sum(energyType, unit: .kilocalorie(), predicate: pred)
        async let protein = sum(proteinType, unit: .gram(), predicate: pred)
        async let carbs = sum(carbsType, unit: .gram(), predicate: pred)
        async let fat = sum(fatType, unit: .gram(), predicate: pred)
        externalToday = await Macros(kcal: Int(kcal.rounded()), protein: Int(protein.rounded()),
                                     carbs: Int(carbs.rounded()), fat: Int(fat.rounded()))
    }

    /// Eau du jour saisie hors Lume (millilitres).
    func refreshWaterToday() async {
        guard available else { return }
        await resolveLumeSources()
        externalWaterMl = await sum(waterType, unit: .literUnit(with: .milli), predicate: todayExcludingLume())
    }

    /// Pas + calories actives du jour (toutes sources — la dépense ne vient pas de Lume).
    func refreshActivityToday() async {
        guard available else { return }
        let start = Calendar.current.startOfDay(for: Date())
        let datePred = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
        async let steps = sum(stepType, unit: .count(), predicate: datePred)
        async let active = sum(activeEnergyType, unit: .kilocalorie(), predicate: datePred)
        stepsToday = Int(await steps.rounded())
        activeEnergyToday = Int(await active.rounded())
    }

    /// Séries 30 j (pas/jour, calories actives/jour) pour les graphes de Progrès.
    func refreshActivitySeries() async {
        guard available else { return }
        let cal = Calendar.current
        let start = cal.date(byAdding: .day, value: -29, to: cal.startOfDay(for: Date())) ?? Date()
        stepsSeries = await dailySeries(stepType, unit: .count(), since: start).map {
            DayValue(date: $0.date, value: Int($0.value.rounded()))
        }
        activeEnergySeries = await dailySeries(activeEnergyType, unit: .kilocalorie(), since: start).map {
            DayValue(date: $0.date, value: Int($0.value.rounded()))
        }
    }

    /// Collection statistique par jour (somme) d'un type sur une fenêtre.
    private func dailySeries(_ type: HKQuantityType, unit: HKUnit, since start: Date) async -> [(date: Date, value: Double)] {
        do {
            let descriptor = HKStatisticsCollectionQueryDescriptor(
                predicate: .quantitySample(type: type, predicate: HKQuery.predicateForSamples(withStart: start, end: Date())),
                options: .cumulativeSum,
                anchorDate: Calendar.current.startOfDay(for: start),
                intervalComponents: DateComponents(day: 1)
            )
            let collection = try await descriptor.result(for: store)
            var out: [(Date, Double)] = []
            collection.enumerateStatistics(from: start, to: Date()) { stats, _ in
                out.append((stats.startDate, stats.sumQuantity()?.doubleValue(for: unit) ?? 0))
            }
            return out.map { (date: $0.0, value: $0.1) }
        } catch {
            return []
        }
    }

    /// Séances récentes (30 j) importées de Santé, hors Lume — lecture seule.
    func refreshExternalWorkouts() async {
        guard available else { return }
        await resolveLumeSources()
        let cal = Calendar.current
        let start = cal.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let datePred = HKQuery.predicateForSamples(withStart: start, end: Date())
        let pred: NSPredicate
        if let notLume = excludingLumePredicate() {
            pred = NSCompoundPredicate(andPredicateWithSubpredicates: [datePred, notLume])
        } else {
            pred = datePred
        }
        do {
            let descriptor = HKSampleQueryDescriptor(
                predicates: [.workout(pred)],
                sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)],
                limit: 10
            )
            let workouts = try await descriptor.result(for: store)
            externalWorkouts = workouts.map { w in
                let kcal = w.statistics(for: activeEnergyType)?.sumQuantity()?.doubleValue(for: .kilocalorie())
                return ExternalWorkout(date: w.startDate,
                                       durationSec: Int(w.duration),
                                       kcal: kcal.map { Int($0.rounded()) },
                                       type: Self.label(for: w.workoutActivityType))
            }
        } catch {
            externalWorkouts = []
        }
    }

    /// Libellé court (français) pour les types d'activité les plus courants.
    private static func label(for type: HKWorkoutActivityType) -> String {
        switch type {
        case .running: "Course"
        case .walking: "Marche"
        case .cycling: "Vélo"
        case .traditionalStrengthTraining, .functionalStrengthTraining: "Muscu"
        case .highIntensityIntervalTraining: "HIIT"
        case .swimming: "Natation"
        case .yoga: "Yoga"
        default: "Séance"
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

    /// Retire ~`milliliters` d'eau écrite par Lume aujourd'hui (supprime les échantillons les plus
    /// récents jusqu'à atteindre la quantité). Sans ça, baisser le compteur dans l'app laisserait
    /// l'eau dans Santé (sur-comptage côté Apple Santé et autres apps).
    func removeWater(milliliters: Double, date: Date = Date()) async {
        guard available, milliliters > 0 else { return }
        await resolveLumeSources()
        guard let notLume = excludingLumePredicate() else { return } // sources Lume inconnues → rien à retirer
        let onlyLume = NSCompoundPredicate(notPredicateWithSubpredicate: notLume)
        let start = Calendar.current.startOfDay(for: date)
        let datePred = HKQuery.predicateForSamples(withStart: start, end: date, options: .strictStartDate)
        let pred = NSCompoundPredicate(andPredicateWithSubpredicates: [datePred, onlyLume])
        let samples = await waterSamples(predicate: pred)
        var remaining = milliliters
        for s in samples { // plus récents d'abord
            let ml = s.quantity.doubleValue(for: .literUnit(with: .milli))
            // On ne peut pas retirer une fraction d'échantillon : on s'arrête avant d'en supprimer
            // un qui dépasserait nettement la cible (borne l'erreur de sur-suppression).
            if ml > remaining + 1 { break }
            try? await store.delete(s)
            remaining -= ml
            if remaining <= 1 { break }
        }
    }

    /// Échantillons d'eau (dietaryWater) du prédicat, du plus récent au plus ancien.
    private func waterSamples(predicate: NSPredicate) async -> [HKQuantitySample] {
        await withCheckedContinuation { (cont: CheckedContinuation<[HKQuantitySample], Never>) in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(sampleType: waterType, predicate: predicate,
                                      limit: HKObjectQueryNoLimit, sortDescriptors: [sort])
            { _, results, _ in
                cont.resume(returning: (results as? [HKQuantitySample]) ?? [])
            }
            store.execute(query)
        }
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

    /// Supprime de Santé toutes les données ÉCRITES PAR LUME (poids, séances), pour un « effacer
    /// mes données » honnête. On ne touche qu'aux échantillons de nos sources : les données d'autres
    /// apps restent intactes. Sans ça, le poids relu depuis Santé repeuplerait la série après reset.
    func deleteLumeData() async {
        guard available else { return }
        await resolveLumeSources()
        guard let notLume = excludingLumePredicate() else { return } // sources Lume inconnues → rien à supprimer
        let onlyLume = NSCompoundPredicate(notPredicateWithSubpredicate: notLume)
        try? await store.deleteObjects(of: weightType, predicate: onlyLume)
        try? await store.deleteObjects(of: HKObjectType.workoutType(), predicate: onlyLume)
        // Recharge les séries dépendantes pour refléter la suppression immédiatement.
        await refreshWeight()
    }
}
