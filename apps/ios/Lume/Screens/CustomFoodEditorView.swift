import SwiftData
import SwiftUI

/// Création d'un aliment personnalisé (repas maison, plat de resto absent des bases) : nom + macros
/// pour 100 g. Persiste un `FavoriteFood` → l'aliment apparaît dans « Mes aliments » et coule dans le
/// flux journal habituel (aucun modèle dédié : un aliment custom EST un favori créé à la main).
struct CustomFoodEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx

    @State private var name = ""
    @State private var kcal = 0
    @State private var protein = 0
    @State private var carbs = 0
    @State private var fat = 0

    /// Repère de cohérence : kcal théoriques depuis les macros (4/4/9). Aide sans imposer.
    private var kcalFromMacros: Int { protein * 4 + carbs * 4 + fat * 9 }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }
    private var canSave: Bool { !trimmedName.isEmpty && kcal > 0 }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                LumeCard {
                    HStack {
                        Text("Nom").font(.lumeBodyMed).foregroundStyle(LumeColor.ink)
                        Spacer()
                        TextField("Ex. Burger maison", text: $name)
                            .multilineTextAlignment(.trailing)
                            .textInputAutocapitalization(.sentences)
                            .font(.lumeSubhead.weight(.semibold)).foregroundStyle(LumeColor.ink)
                    }
                }

                LumeCard {
                    VStack(spacing: Spacing.md) {
                        Text("Pour 100 g").font(.lumeFootnote).foregroundStyle(LumeColor.muted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        macroField("Calories", value: $kcal, unit: "kcal", tint: LumeColor.ink)
                        divider
                        macroField("Protéines", value: $protein, unit: "g", tint: LumeColor.protein)
                        divider
                        macroField("Glucides", value: $carbs, unit: "g", tint: LumeColor.carbs)
                        divider
                        macroField("Lipides", value: $fat, unit: "g", tint: LumeColor.fat)
                    }
                }

                // Indice de cohérence non bloquant : si l'écart kcal saisi / kcal des macros est notable.
                if kcalFromMacros > 0, abs(kcalFromMacros - kcal) > 30 {
                    LumeDisclaimer(text: "D'après les macros, ce serait plutôt ~\(kcalFromMacros) kcal. Vérifie tes valeurs.")
                }

                PrimaryButton(title: "Enregistrer l'aliment", icon: .validate) { save() }
                    .disabled(!canSave)
                    .opacity(canSave ? 1 : 0.5)
            }
            .padding(.horizontal, Spacing.xl).padding(.top, Spacing.sm).padding(.bottom, Spacing.xxl)
        }
        .background(LumeColor.cream.ignoresSafeArea())
        .safeAreaInset(edge: .top) {
            TopBar(title: "Nouvel aliment", leading: .close, onLeading: { dismiss() })
                .padding(.horizontal, Spacing.xl).padding(.vertical, Spacing.sm).background(LumeColor.cream)
        }
    }

    private var divider: some View {
        Rectangle().fill(LumeColor.border).frame(height: 1)
    }

    /// Ligne « libellé … [champ numérique] unité ». Saisie entière, clavier numérique.
    private func macroField(_ label: LocalizedStringKey, value: Binding<Int>, unit: LocalizedStringKey, tint: Color) -> some View {
        HStack {
            Text(label).font(.lumeBodyMed).foregroundStyle(tint)
            Spacer()
            TextField("0", value: value, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .font(.lumeSubhead.weight(.semibold)).foregroundStyle(LumeColor.ink).monospacedDigit()
                .fixedSize()
            Text(unit).font(.lumeFootnote).foregroundStyle(LumeColor.muted).frame(width: 34, alignment: .leading)
        }
    }

    private func save() {
        guard canSave else { return }
        ctx.insert(FavoriteFood(name: trimmedName,
                                per100g: Macros(kcal: kcal, protein: protein, carbs: carbs, fat: fat)))
        dismiss()
    }
}

#Preview { CustomFoodEditorView().modelContainer(LumeStore.preview) }
