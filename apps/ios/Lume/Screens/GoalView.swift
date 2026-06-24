import SwiftData
import SwiftUI

struct GoalView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @Query private var profiles: [ProfileRecord]
    @Environment(HealthManager.self) private var health
    @AppStorage(WeightFormat.defaultsKey) private var useImperial = false
    @State private var profile = Mock.profile
    @State private var loaded = false

    private var target: Macros {
        TDEECalculator.target(profile)
    }

    /// Pas de saisie du poids (0,5 kg en métrique, ≈1 lb en impérial), exprimé en kg.
    private var step: Double {
        WeightFormat.stepKg(imperial: useImperial)
    }

    private func save() {
        if let r = profiles.first { r.update(from: profile) }
        else { ctx.insert(ProfileRecord(from: profile)) }
        dismiss()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                targetCard
                formCard
                PrimaryButton(title: "Enregistrer l'objectif", icon: .validate) { save() }
            }
            .padding(.horizontal, Spacing.xl).padding(.bottom, Spacing.xxl)
        }
        .background(LumeColor.cream.ignoresSafeArea())
        .safeAreaInset(edge: .top) {
            TopBar(title: "Objectif", leading: .back, onLeading: { dismiss() })
                .padding(.horizontal, Spacing.xl).padding(.vertical, Spacing.sm).background(LumeColor.cream)
        }
        .onAppear { if !loaded { if let r = profiles.first { profile = r.profile }; loaded = true } }
        .task { await health.requestAuthorization(); if let kg = health.latestWeightKg { profile.weightKg = (kg * 2).rounded() / 2 } }
    }

    private var targetCard: some View {
        LumeCard(padding: Spacing.xxl, radius: Radius.xxl) {
            VStack(spacing: Spacing.md) {
                Text("Cible quotidienne calculée").font(.lumeSubhead).foregroundStyle(LumeColor.muted)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(target.kcal)").font(.lumeNumberXL).foregroundStyle(LumeColor.ink).monospacedDigit()
                    Text("kcal").font(.lumeHeadline).foregroundStyle(LumeColor.muted)
                }
                HStack(spacing: Spacing.sm) {
                    Chip(color: LumeColor.protein, text: "P \(target.protein) g")
                    Chip(color: LumeColor.carbs, text: "G \(target.carbs) g")
                    Chip(color: LumeColor.fat, text: "L \(target.fat) g")
                }
            }.frame(maxWidth: .infinity)
        }
    }

    private var formCard: some View {
        LumeCard {
            VStack(spacing: Spacing.lg) {
                rowPicker(title: "Sexe") {
                    Picker("", selection: $profile.sex) {
                        Text("Homme").tag(Sex.male); Text("Femme").tag(Sex.female)
                    }.pickerStyle(.segmented).labelsHidden()
                }
                stepperRow(title: "Âge", value: "\(profile.age) ans") { profile.age = max(14, profile.age - 1) } plus: { profile.age += 1 }
                stepperRow(title: "Taille", value: "\(profile.heightCm) cm") { profile.heightCm -= 1 } plus: { profile.heightCm += 1 }
                stepperRow(title: "Poids", value: WeightFormat.body(profile.weightKg, imperial: useImperial)) { profile.weightKg -= step } plus: { profile.weightKg += step }
                stepperRow(title: "Objectif de poids",
                           value: profile.targetWeightKg > 0 ? WeightFormat.body(profile.targetWeightKg, imperial: useImperial) : "—",
                           minus: { profile.targetWeightKg = profile.targetWeightKg > 0 ? max(0, profile.targetWeightKg - step) : 0 },
                           plus: { profile.targetWeightKg = profile.targetWeightKg > 0 ? min(250, profile.targetWeightKg + step) : (profile.weightKg * 2).rounded() / 2 })
                rowPicker(title: "Activité") {
                    Picker("", selection: $profile.activity) {
                        ForEach(ActivityLevel.allCases, id: \.self) { Text($0.label).tag($0) }
                    }.tint(LumeColor.ink)
                }
                rowPicker(title: "Objectif") {
                    Picker("", selection: $profile.goal) {
                        Text("Perdre").tag(Goal.lose); Text("Maintenir").tag(Goal.maintain); Text("Prendre").tag(Goal.gain)
                    }.pickerStyle(.segmented).labelsHidden()
                }
            }
        }
    }

    private func rowPicker<V: View>(title: String, @ViewBuilder control: () -> V) -> some View {
        HStack { Text(title).font(.lumeBodyMed).foregroundStyle(LumeColor.ink); Spacer(); control().fixedSize() }
    }

    private func stepperRow(title: String, value: String, minus: @escaping () -> Void, plus: @escaping () -> Void) -> some View {
        HStack {
            Text(title).font(.lumeBodyMed).foregroundStyle(LumeColor.ink)
            Spacer()
            HStack(spacing: Spacing.md) {
                RoundIconButton(icon: .minus, action: minus)
                Text(value).font(.lumeSubhead.weight(.semibold)).foregroundStyle(LumeColor.ink).monospacedDigit().frame(minWidth: 64)
                RoundIconButton(icon: .add, filled: true, action: plus)
            }
        }
    }
}

#Preview { GoalView().modelContainer(LumeStore.preview).environment(HealthManager.shared) }
