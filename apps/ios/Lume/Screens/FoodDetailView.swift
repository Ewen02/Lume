import SwiftData
import SwiftUI

struct FoodDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @Query private var favorites: [FavoriteFood]
    @State private var grams: Int
    @State private var meal: MealType
    @State private var added = false
    @State private var favToggled = false
    private let base: FoodItem
    /// `true` quand l'aliment n'est pas encore au journal (recherche/favoris) → bouton d'ajout.
    /// `false` en consultation d'une entrée déjà loggée (depuis Aujourd'hui) → modifier/supprimer.
    private let canAddToJournal: Bool
    /// Entrée du journal en cours de consultation (permet de la modifier ou la supprimer).
    private let entry: LoggedFood?

    init(food: FoodItem = Mock.foods[0], meal: MealType = .snack, canAddToJournal: Bool = true) {
        base = food
        _meal = State(initialValue: meal)
        self.canAddToJournal = canAddToJournal
        entry = nil
        _grams = State(initialValue: food.grams)
    }

    /// Ouvre une entrée déjà journalisée pour la modifier ou la supprimer.
    init(entry: LoggedFood) {
        base = FoodItem(name: entry.name, grams: entry.grams, macros: entry.macros)
        _meal = State(initialValue: entry.meal)
        canAddToJournal = false
        self.entry = entry
        _grams = State(initialValue: entry.grams)
    }

    /// macros recalculées au prorata des grammes
    private var factor: Double {
        Double(grams) / Double(max(base.grams, 1))
    }

    private func sc(_ v: Int) -> Int {
        Int((Double(v) * factor).rounded())
    }

    private var scaledMacros: Macros {
        Macros(kcal: sc(base.macros.kcal), protein: sc(base.macros.protein),
               carbs: sc(base.macros.carbs), fat: sc(base.macros.fat))
    }

    private func addToJournal() {
        let m = scaledMacros
        ctx.insert(LoggedFood(meal: meal, name: base.name, grams: grams,
                              kcal: m.kcal, protein: m.protein, carbs: m.carbs, fat: m.fat))
        added = true
        dismiss()
    }

    /// Enregistre la nouvelle portion + le créneau sur l'entrée du journal existante.
    private func saveChanges() {
        guard let entry else { return }
        let m = scaledMacros
        entry.grams = grams
        entry.mealRaw = meal.rawValue
        entry.kcal = m.kcal; entry.protein = m.protein; entry.carbs = m.carbs; entry.fat = m.fat
        added = true
        dismiss()
    }

    private func deleteEntry() {
        guard let entry else { return }
        ctx.delete(entry)
        dismiss()
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    LumeCard(padding: Spacing.xxl, radius: Radius.xxl) {
                        VStack(spacing: Spacing.md) {
                            Text(base.name).font(.lumeTitle).foregroundStyle(LumeColor.ink)
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text("\(sc(base.macros.kcal))").font(.lumeNumberXL).foregroundStyle(LumeColor.ink).monospacedDigit()
                                Text("kcal").font(.lumeHeadline).foregroundStyle(LumeColor.muted)
                            }
                            PortionStepper(grams: $grams)
                        }.frame(maxWidth: .infinity)
                    }
                    LumeCard {
                        VStack(spacing: Spacing.lg) {
                            macroLine("Protéines", sc(base.macros.protein), LumeColor.protein)
                            macroLine("Glucides", sc(base.macros.carbs), LumeColor.carbs)
                            macroLine("Lipides", sc(base.macros.fat), LumeColor.fat)
                        }
                    }
                    mealPicker
                }.padding(.horizontal, Spacing.xl).padding(.bottom, 100)
            }
            if canAddToJournal {
                PrimaryButton(title: "Ajouter au journal", icon: .add) { addToJournal() }
                    .padding(.horizontal, Spacing.xl).padding(.bottom, Spacing.sm)
            } else if entry != nil {
                // Entrée déjà au journal : modifier la portion ou supprimer.
                HStack(spacing: Spacing.md) {
                    SecondaryButton(title: "Supprimer", icon: .minusCircle) { deleteEntry() }
                    PrimaryButton(title: "Enregistrer", icon: .validate) { saveChanges() }
                }
                .padding(.horizontal, Spacing.xl).padding(.bottom, Spacing.sm)
            } else {
                SecondaryButton(title: "Fermer") { dismiss() }
                    .padding(.horizontal, Spacing.xl).padding(.bottom, Spacing.sm)
            }
        }
        .background(LumeColor.cream.ignoresSafeArea())
        .sensoryFeedback(.success, trigger: added)
        .sensoryFeedback(.impact(weight: .light), trigger: favToggled)
        .safeAreaInset(edge: .top) {
            TopBar(title: "Aliment", leading: .back,
                   trailing: isFavorite ? .favorite : .favoriteOutline,
                   onLeading: { dismiss() }, onTrailing: { toggleFavorite() })
                .padding(.horizontal, Spacing.xl).padding(.vertical, Spacing.sm).background(LumeColor.cream)
        }
    }

    /// Macros ramenées à 100 g (base de référence d'un favori).
    private var per100g: Macros {
        base.macros.scaled(100.0 / Double(max(base.grams, 1)))
    }

    private var isFavorite: Bool {
        favorites.contains { $0.name.lowercased() == base.name.lowercased() }
    }

    private func toggleFavorite() {
        favToggled.toggle()
        if let existing = favorites.first(where: { $0.name.lowercased() == base.name.lowercased() }) {
            ctx.delete(existing)
        } else {
            ctx.insert(FavoriteFood(name: base.name, per100g: per100g))
        }
    }

    /// Sélecteur de créneau (petit-déj / déj / dîner / collation).
    private var mealPicker: some View {
        LumeCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Repas").font(.lumeFootnote).foregroundStyle(LumeColor.muted)
                HStack(spacing: Spacing.sm) {
                    ForEach(MealType.allCases) { type in
                        let active = type == meal
                        Button { withAnimation(LumeMotion.snappy) { meal = type } } label: {
                            VStack(spacing: 4) {
                                Image(appIcon: type.icon).lumeIcon(16, weight: .semibold)
                                    .foregroundStyle(active ? LumeColor.surface : type.tint)
                                Text(type.title).font(.lumeCaption).lineLimit(1).minimumScaleFactor(0.7)
                                    .foregroundStyle(active ? LumeColor.surface : LumeColor.textSecondary)
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, Spacing.sm)
                            .background(active ? type.tint : LumeColor.cream, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                        }.buttonStyle(.lumePress)
                    }
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func macroLine(_ label: String, _ grams: Int, _ color: Color) -> some View {
        HStack(spacing: Spacing.md) {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(label).font(.lumeBodyMed).foregroundStyle(LumeColor.ink)
            Spacer()
            Text("\(grams) g").font(.lumeCallout).foregroundStyle(LumeColor.textSecondary).monospacedDigit()
        }
    }
}

#Preview { FoodDetailView().modelContainer(LumeStore.preview) }
