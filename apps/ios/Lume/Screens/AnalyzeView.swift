import SwiftData
import SwiftUI
import UIKit

struct AnalyzeView: View {
    enum Phase { case loading, loaded, failed }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @Environment(HealthManager.self) private var health
    @Environment(\.foodAPI) private var api

    let imageData: Data?
    @State private var items: [FoodItem]
    @State private var phase: Phase
    @State private var added = false
    @State private var per100g: [UUID: Macros] = [:]

    /// Mode démo / preview : aliments fournis directement.
    init(detected: [FoodItem] = Mock.detected) {
        imageData = nil
        _items = State(initialValue: detected)
        _phase = State(initialValue: .loaded)
    }

    /// Mode réel : analyse une photo via l'API.
    init(imageData: Data) {
        self.imageData = imageData
        _items = State(initialValue: [])
        _phase = State(initialValue: .loading)
    }

    private var total: Macros {
        items.reduce(.zero) { $0 + $1.macros }
    }

    /// Macros ramenées à 100 g (base pour recalculer à l'édition de portion).
    private func basis(_ it: FoodItem) -> Macros {
        it.macros.scaled(100.0 / Double(max(it.grams, 1)))
    }

    private func captureBasisIfNeeded() {
        guard per100g.isEmpty, !items.isEmpty else { return }
        per100g = Dictionary(uniqueKeysWithValues: items.map { ($0.id, basis($0)) })
    }

    private func mealForNow() -> MealType {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5 ..< 11: .breakfast
        case 11 ..< 15: .lunch
        case 18 ..< 23: .dinner
        default: .snack
        }
    }

    private func runAnalyze() async {
        guard let data = imageData else { return }
        phase = .loading
        do {
            let result = try await api.analyze(imageData: data)
            items = result
            per100g = Dictionary(uniqueKeysWithValues: result.map { ($0.id, basis($0)) })
            phase = result.isEmpty ? .failed : .loaded
        } catch {
            phase = .failed
        }
    }

    private func addToJournal() {
        let meal = mealForNow()
        for it in items {
            ctx.insert(LoggedFood(meal: meal, name: it.name, grams: it.grams,
                                  kcal: it.macros.kcal, protein: it.macros.protein,
                                  carbs: it.macros.carbs, fat: it.macros.fat))
        }
        let t = total
        Task { await health.logMeal(kcal: t.kcal, protein: t.protein, carbs: t.carbs, fat: t.fat) }
        added = true
        dismiss()
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    photo
                    switch phase {
                    case .loading: loadingCard
                    case .failed: failedCard
                    case .loaded:
                        totalCard
                        SectionHeader(title: "Aliments détectés", actionTitle: "Ajouter", actionIcon: .add)
                        ForEach($items) { $item in itemRow($item) }
                    }
                }
                .padding(.horizontal, Spacing.xl).padding(.bottom, 100)
            }
            if phase == .loaded {
                PrimaryButton(title: "Ajouter au journal", icon: .validate) { addToJournal() }
                    .padding(.horizontal, Spacing.xl).padding(.bottom, Spacing.sm)
            }
        }
        .background(LumeColor.cream.ignoresSafeArea())
        .safeAreaInset(edge: .top) {
            TopBar(title: "Analyse", leading: .back, trailing: .edit, onLeading: { dismiss() })
                .padding(.horizontal, Spacing.xl).padding(.vertical, Spacing.sm).background(LumeColor.cream)
        }
        .sensoryFeedback(.success, trigger: added)
        .task { if phase == .loading { await runAnalyze() } }
        .onAppear { captureBasisIfNeeded() }
    }

    private var photo: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Radius.xxl, style: .continuous).fill(LumeColor.placeholder)
            if let imageData, let ui = UIImage(data: imageData) {
                Image(uiImage: ui).resizable().scaledToFill()
            } else {
                Image(appIcon: .lunch).lumeIcon(44, weight: .semibold).foregroundStyle(LumeColor.placeholderTint)
            }
        }
        // La photo se réduit quand l'analyse charge ou échoue : elle ne doit pas dominer l'écran.
        .frame(height: phase == .loaded ? 190 : 130)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: Radius.xxl, style: .continuous))
        .animation(.snappy, value: phase)
    }

    private var loadingCard: some View {
        LumeLoadingState(label: "Analyse du repas en cours…")
    }

    private var failedCard: some View {
        LumeErrorState(title: "Analyse impossible",
                       message: "Vérifie ta connexion et l'URL de l'API.",
                       retry: { Task { await runAnalyze() } })
    }

    private var totalCard: some View {
        LumeCard(radius: Radius.xxl) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Total du repas").font(.lumeSubhead).foregroundStyle(LumeColor.muted)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(total.kcal)").font(.lumeNumberL).foregroundStyle(LumeColor.ink).monospacedDigit()
                    Text("kcal").font(.lumeHeadline).foregroundStyle(LumeColor.muted)
                }
                HStack(spacing: Spacing.sm) {
                    Chip(color: LumeColor.protein, text: "\(total.protein) g")
                    Chip(color: LumeColor.carbs, text: "\(total.carbs) g")
                    Chip(color: LumeColor.fat, text: "\(total.fat) g")
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func itemRow(_ item: Binding<FoodItem>) -> some View {
        let grams = Binding<Int>(
            get: { item.wrappedValue.grams },
            set: { newValue in
                let g = max(1, newValue)
                item.wrappedValue.grams = g
                if let base = per100g[item.wrappedValue.id] {
                    item.wrappedValue.macros = base.scaled(Double(g) / 100)
                }
            }
        )
        return HStack(spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: 3) {
                Text(item.wrappedValue.name).font(.lumeCallout).foregroundStyle(LumeColor.ink)
                if item.wrappedValue.matched {
                    Text("\(item.wrappedValue.macros.kcal) kcal · P \(item.wrappedValue.macros.protein) G \(item.wrappedValue.macros.carbs) L \(item.wrappedValue.macros.fat)")
                        .font(.lumeFootnote).foregroundStyle(LumeColor.muted)
                } else {
                    Text("Macros introuvables").font(.lumeFootnote).foregroundStyle(LumeColor.warning)
                }
            }
            Spacer()
            PortionStepper(grams: grams)
        }
        .padding(.horizontal, Spacing.lg - 2).padding(.vertical, Spacing.md)
        .background(LumeColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .lumeShadow(.soft)
    }
}

#Preview { AnalyzeView().modelContainer(LumeStore.preview).environment(HealthManager.shared) }
