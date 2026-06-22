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
    @State private var correcting: FoodItem?
    @State private var showFullImage = false
    private let onLogged: () -> Void

    /// Mode démo / preview : aliments fournis directement.
    init(detected: [FoodItem] = Mock.detected, onLogged: @escaping () -> Void = {}) {
        imageData = nil
        self.onLogged = onLogged
        _items = State(initialValue: detected)
        _phase = State(initialValue: .loaded)
    }

    /// Mode réel : analyse une photo via l'API.
    init(imageData: Data, onLogged: @escaping () -> Void = {}) {
        self.imageData = imageData
        self.onLogged = onLogged
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
        // Jusqu'à 2 tentatives : le backend Railway peut être en cold start au 1er appel.
        for attempt in 0 ..< 2 {
            do {
                let result = try await api.analyze(imageData: data)
                items = result
                per100g = Dictionary(uniqueKeysWithValues: result.map { ($0.id, basis($0)) })
                phase = result.isEmpty ? .failed : .loaded
                return
            } catch {
                if attempt == 0 {
                    try? await Task.sleep(nanoseconds: 1_500_000_000) // laisse le serveur se réveiller
                    continue
                }
                phase = .failed
            }
        }
    }

    private func addToJournal() {
        let meal = mealForNow()
        // Tous les aliments de ce scan partagent un même identifiant de repas → carte groupée.
        let groupID = UUID()
        // On ignore les aliments non résolus (macros à 0) pour ne pas polluer le journal.
        let kept = items.filter { $0.matched }
        guard !kept.isEmpty else { dismiss(); return }
        for it in kept {
            ctx.insert(LoggedFood(meal: meal, name: it.name, grams: it.grams,
                                  kcal: it.macros.kcal, protein: it.macros.protein,
                                  carbs: it.macros.carbs, fat: it.macros.fat,
                                  mealGroupID: groupID, mealTitle: nil))
        }
        let t = kept.reduce(Macros.zero) { $0 + $1.macros }
        Task { await health.logMeal(kcal: t.kcal, protein: t.protein, carbs: t.carbs, fat: t.fat) }
        added = true
        dismiss()
        onLogged()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                photo
                switch phase {
                case .loading: loadingCard
                case .failed: failedCard
                case .loaded:
                    totalCard.lumeEntrance(0)
                    SectionHeader(title: "Aliments détectés", actionTitle: "Ajouter", actionIcon: .add)
                        .lumeEntrance(1)
                    ForEach(Array($items.enumerated()), id: \.element.id) { idx, $item in
                        itemRow($item).lumeEntrance(2 + idx)
                    }
                }
            }
            .padding(.horizontal, Spacing.xl).padding(.bottom, Spacing.lg)
        }
        .background(LumeColor.cream.ignoresSafeArea())
        .safeAreaInset(edge: .top) {
            TopBar(title: "Analyse", leading: .back, trailing: .edit, onLeading: { dismiss() })
                .padding(.horizontal, Spacing.xl).padding(.vertical, Spacing.sm).background(LumeColor.cream)
        }
        .safeAreaInset(edge: .bottom) {
            // Bouton flottant : safeAreaInset réserve automatiquement la place dans le ScrollView
            // → la dernière carte n'est plus masquée.
            if phase == .loaded {
                PrimaryButton(title: "Ajouter au journal", icon: .validate) { addToJournal() }
                    .padding(.horizontal, Spacing.xl).padding(.top, Spacing.sm).padding(.bottom, Spacing.sm)
                    .background(.clear)
            }
        }
        .sensoryFeedback(.success, trigger: added)
        .task { if phase == .loading { await runAnalyze() } }
        .onAppear { captureBasisIfNeeded() }
        .sheet(item: $correcting) { item in
            FoodCorrectionView(query: item.name) { product in
                replace(item, with: product)
                correcting = nil
            }
        }
        .fullScreenCover(isPresented: $showFullImage) {
            if let ui = uiImage { ZoomableImageView(image: ui) }
        }
    }

    private var uiImage: UIImage? {
        guard let imageData else { return nil }
        return UIImage(data: imageData)
    }

    private var photo: some View {
        // La photo se réduit quand l'analyse charge ou échoue : elle ne doit pas dominer l'écran.
        let height: CGFloat = phase == .loaded ? 200 : 130
        return ZStack {
            RoundedRectangle(cornerRadius: Radius.xxl, style: .continuous).fill(LumeColor.placeholder)
            if let ui = uiImage {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: height)
                    .clipped()
                // Indice « agrandir » en bas à droite.
                Image(appIcon: .search)
                    .lumeIcon(14, weight: .bold).foregroundStyle(.white)
                    .padding(Spacing.sm)
                    .background(.black.opacity(0.35), in: Circle())
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(Spacing.sm)
            } else {
                Image(appIcon: .lunch).lumeIcon(44, weight: .semibold).foregroundStyle(LumeColor.placeholderTint)
            }
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: Radius.xxl, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture { if uiImage != nil { showFullImage = true } }
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
        let it = item.wrappedValue
        return HStack(spacing: Spacing.md) {
            // Nom tappable → correction manuelle (remplacer l'aliment mal reconnu).
            Button { correcting = it } label: {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: Spacing.xs) {
                        Text(it.name).font(.lumeCallout).foregroundStyle(LumeColor.ink)
                        Image(appIcon: .edit).lumeIcon(11, weight: .semibold).foregroundStyle(LumeColor.muted)
                    }
                    if !it.matched {
                        Text("Macros introuvables · touche pour corriger")
                            .font(.lumeFootnote).foregroundStyle(LumeColor.warning)
                    } else if it.isUncertain {
                        Text("À vérifier · \(it.macros.kcal) kcal")
                            .font(.lumeFootnote).foregroundStyle(LumeColor.warning)
                    } else {
                        Text("\(it.macros.kcal) kcal · P \(it.macros.protein) G \(it.macros.carbs) L \(it.macros.fat)")
                            .font(.lumeFootnote).foregroundStyle(LumeColor.muted)
                    }
                }
            }.buttonStyle(.plain)
            Spacer()
            PortionStepper(grams: grams)
        }
        .padding(.horizontal, Spacing.lg - 2).padding(.vertical, Spacing.md)
        .background(LumeColor.surface)
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .stroke(LumeColor.warning.opacity(it.isUncertain || !it.matched ? 0.5 : 0), lineWidth: 1.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .lumeShadow(.soft)
    }

    /// Remplace un aliment (ligne) par un produit choisi dans la recherche.
    private func replace(_ original: FoodItem, with product: ScannedProduct) {
        guard let idx = items.firstIndex(where: { $0.id == original.id }) else { return }
        let grams = items[idx].grams
        let scaled = product.per100g.scaled(Double(grams) / 100)
        items[idx].name = product.name
        items[idx].macros = scaled
        items[idx].matched = true
        items[idx].confidence = 1
        per100g[items[idx].id] = product.per100g
    }
}

#Preview { AnalyzeView().modelContainer(LumeStore.preview).environment(HealthManager.shared) }

// MARK: - Image plein écran (zoom)

/// Affiche l'image du repas en plein écran avec pinch-to-zoom et fermeture.
struct ZoomableImageView: View {
    @Environment(\.dismiss) private var dismiss
    let image: UIImage
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .scaleEffect(scale)
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in scale = min(max(lastScale * value, 1), 4) }
                        .onEnded { _ in lastScale = scale }
                )
                .onTapGesture(count: 2) {
                    withAnimation(.snappy) { scale = scale > 1 ? 1 : 2; lastScale = scale }
                }
            Button { dismiss() } label: {
                Image(appIcon: .close).lumeIcon(18, weight: .semibold).foregroundStyle(.white)
                    .frame(width: 40, height: 40).background(.black.opacity(0.4), in: Circle())
            }
            .padding(Spacing.lg)
            .accessibilityLabel("Fermer")
        }
    }
}

// MARK: - Correction manuelle d'un aliment mal reconnu

/// Recherche un aliment dans la base et le renvoie pour remplacer une ligne mal reconnue.
struct FoodCorrectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.foodAPI) private var api
    @State private var query: String
    @State private var results: [ScannedProduct] = []
    @State private var loading = false
    let onPick: (ScannedProduct) -> Void

    init(query: String, onPick: @escaping (ScannedProduct) -> Void) {
        _query = State(initialValue: query)
        self.onPick = onPick
    }

    var body: some View {
        VStack(spacing: Spacing.md) {
            SearchBar(text: $query, placeholder: "Rechercher le bon aliment")
                .padding(.horizontal, Spacing.xl)
                .onSubmit { Task { await search() } }
            ScrollView {
                VStack(spacing: Spacing.sm) {
                    if loading {
                        LumeLoadingState(label: "Recherche…")
                    } else if results.isEmpty {
                        LumeEmptyState(icon: .search, title: "Aucun résultat",
                                       message: "Essaie un autre nom, en français ou en anglais.")
                    } else {
                        ForEach(results) { product in
                            FoodRow(name: product.name,
                                    detail: "\(product.per100g.kcal) kcal / 100 g",
                                    kcal: product.per100g.kcal,
                                    trailing: .validate) { onPick(product) }
                        }
                    }
                }.padding(.horizontal, Spacing.xl).padding(.bottom, Spacing.xxl)
            }
        }
        .background(LumeColor.cream.ignoresSafeArea())
        .safeAreaInset(edge: .top) {
            TopBar(title: "Corriger l'aliment", leading: .close, onLeading: { dismiss() })
                .padding(.horizontal, Spacing.xl).padding(.vertical, Spacing.sm).background(LumeColor.cream)
        }
        .task { await search() }
    }

    private func search() async {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { results = []; return }
        loading = true
        defer { loading = false }
        results = (try? await api.search(q)) ?? []
    }
}
