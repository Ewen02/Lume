import SwiftData
import SwiftUI

struct OnboardingView: View {
    @Environment(\.modelContext) private var ctx
    @Environment(HealthManager.self) private var health
    @Query private var profiles: [ProfileRecord]
    @AppStorage(WeightFormat.defaultsKey) private var useImperial = false

    @State private var step = 0
    /// Valeurs de départ neutres (prénom vide → saisi à l'étape profil).
    @State private var profile = UserProfile(name: "", sex: .male, age: 25, heightCm: 175,
                                             weightKg: 70, activity: .moderate, goal: .maintain)
    @State private var cameraGranted = Permissions.cameraGranted
    @State private var notifGranted = false
    /// Affiche l'écran Confidentialité & conditions depuis la mention de consentement.
    @State private var showLegal = false
    /// Pilote l'animation de révélation de la démo « aha » (étape 1).
    @State private var demoRevealed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Modules optionnels choisis ici (la nutrition est le cœur, toujours active).
    @AppStorage(ModuleSettings.workoutKey) private var workoutEnabled = ModuleSettings.defaultEnabled
    @AppStorage(ModuleSettings.financeKey) private var financeEnabled = ModuleSettings.defaultEnabled

    var onFinish: () -> Void = {}

    private let lastStep = 5
    /// Index de l'étape « profil » (saisie du prénom) — sert au gate du bouton Continuer.
    private let profileStep = 2
    private var target: Macros {
        TDEECalculator.target(profile)
    }

    private var trimmedName: String {
        profile.name.trimmingCharacters(in: .whitespaces)
    }

    private func finish() {
        var saved = profile
        saved.name = trimmedName
        if let r = profiles.first { r.update(from: saved) }
        else {
            ctx.insert(ProfileRecord(from: saved))
            // 1er point de poids réel : le graphe Progrès démarre avec une vraie donnée
            // (pas de courbe de démo) dès la fin de l'onboarding.
            if saved.weightKg > 0 {
                ctx.insert(WeightSample(date: Date(), kg: saved.weightKg))
                Task { await health.saveWeight(kg: saved.weightKg) }
            }
        }
        onFinish()
    }

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $step) {
                welcome.tag(0)
                ahaDemo.tag(1)
                infos.tag(2)
                goal.tag(3)
                modules.tag(4)
                permissions.tag(5)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(LumeMotion.snappy, value: step)

            HStack(spacing: Spacing.sm) {
                ForEach(0 ... lastStep, id: \.self) { i in
                    Capsule().fill(i == step ? LumeColor.ink : LumeColor.border)
                        .frame(width: i == step ? 22 : 7, height: 7)
                        .animation(LumeMotion.snappy, value: step)
                }
            }.padding(.bottom, Spacing.lg)

            // Mention de consentement (dernière étape) : continuer vaut acceptation.
            if step == lastStep {
                Button { showLegal = true } label: {
                    Text("En continuant, tu acceptes nos conditions et notre politique de confidentialité.")
                        .font(.lumeFootnote).foregroundStyle(LumeColor.muted)
                        .underline().multilineTextAlignment(.center)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, Spacing.xl).padding(.bottom, Spacing.sm)
            }

            PrimaryButton(title: step < lastStep ? "Continuer" : "Commencer",
                          icon: step < lastStep ? nil : .validate)
            {
                if step < lastStep { withAnimation { step += 1 } } else { finish() }
            }
            .disabled(step == profileStep && trimmedName.isEmpty)
            .opacity(step == profileStep && trimmedName.isEmpty ? 0.5 : 1)
            .padding(.horizontal, Spacing.xl).padding(.bottom, Spacing.lg)

            if step == lastStep {
                Button("Plus tard") { finish() }
                    .font(.lumeSubhead).foregroundStyle(LumeColor.muted)
                    .padding(.bottom, Spacing.sm)
            }
        }
        .sheet(isPresented: $showLegal) { LegalView() }
        .background(LumeColor.cream.ignoresSafeArea())
        .sensoryFeedback(.selection, trigger: step)
    }

    // MARK: Étape 0 — bienvenue

    private var welcome: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()
            Image(appIcon: .calories).lumeIcon(64, weight: .semibold).foregroundStyle(LumeColor.protein)
            Text("Lume").font(.system(size: 44, weight: .heavy)).foregroundStyle(LumeColor.ink)
            Text("Photographie ton repas.\nLume compte les calories pour toi.")
                .multilineTextAlignment(.center).font(.lumeBody).foregroundStyle(LumeColor.textSecondary)
            Spacer()
        }.padding(.horizontal, Spacing.xxl)
    }

    // MARK: Étape 1 — démo « aha » (montrer la valeur avant de demander quoi que ce soit)

    /// Aliments de démo révélés un à un (effet « Lume vient d'analyser ta photo »).
    private var demoFoods: [FoodItem] { Mock.detected }
    private var demoTotal: Macros { demoFoods.reduce(.zero) { $0 + $1.macros } }

    private var ahaDemo: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            stepTitle("Voilà ce que Lume voit", "Une photo de ton repas suffit.")

            LumeCard(radius: Radius.xxl) {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    // Faux « aperçu photo » : une bande colorée évoquant l'assiette.
                    ZStack {
                        RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                            .fill(LumeColor.placeholder)
                            .frame(height: 96)
                        Image(appIcon: .lunch).lumeIcon(34, weight: .semibold).foregroundStyle(LumeColor.placeholderTint)
                    }

                    // Total calories qui s'anime (compteur).
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(demoRevealed ? "\(demoTotal.kcal)" : "0")
                            .font(.lumeNumberL).foregroundStyle(LumeColor.ink).monospacedDigit()
                            .contentTransition(.numericText(value: Double(demoRevealed ? demoTotal.kcal : 0)))
                        Text("kcal").font(.lumeHeadline).foregroundStyle(LumeColor.muted)
                    }
                    HStack(spacing: Spacing.sm) {
                        Chip(color: LumeColor.protein, text: "P \(demoTotal.protein)")
                        Chip(color: LumeColor.carbs, text: "G \(demoTotal.carbs)")
                        Chip(color: LumeColor.fat, text: "L \(demoTotal.fat)")
                    }

                    Divider().background(LumeColor.border)

                    // Aliments détectés, apparition décalée.
                    ForEach(Array(demoFoods.enumerated()), id: \.element.id) { idx, food in
                        HStack {
                            // Aliments de démo : on les localise (clés au catalogue) pour un aha EN propre.
                            Text(LocalizedStringKey(food.name)).font(.lumeCallout).foregroundStyle(LumeColor.ink)
                            Spacer()
                            Text("\(food.macros.kcal) kcal").font(.lumeFootnote).foregroundStyle(LumeColor.muted).monospacedDigit()
                        }
                        .opacity(demoRevealed ? 1 : 0)
                        .offset(y: demoRevealed ? 0 : 8)
                        .animation(reduceMotion ? nil : LumeMotion.smooth.delay(0.15 * Double(idx + 1)), value: demoRevealed)
                    }
                }
            }

            Text("Les valeurs sont estimées : tu peux toujours les corriger.")
                .font(.lumeFootnote).foregroundStyle(LumeColor.muted)
            Spacer()
        }
        .padding(.horizontal, Spacing.xl).padding(.top, Spacing.xxl)
        .onAppear {
            // Déclenche la révélation à l'arrivée sur l'étape (et la rejoue si on y revient).
            demoRevealed = false
            withAnimation(reduceMotion ? nil : LumeMotion.snappy.delay(0.2)) { demoRevealed = true }
        }
    }

    // MARK: Étape 2 — profil (modifiable)

    private var infos: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            stepTitle("Parle-nous de toi", "Pour calculer ton objectif.")
            LumeCard {
                VStack(spacing: Spacing.lg) {
                    HStack {
                        Text("Prénom").font(.lumeBodyMed).foregroundStyle(LumeColor.ink)
                        Spacer()
                        TextField("Ton prénom", text: $profile.name)
                            .multilineTextAlignment(.trailing)
                            .textInputAutocapitalization(.words)
                            .font(.lumeSubhead.weight(.semibold)).foregroundStyle(LumeColor.ink)
                    }
                    HStack {
                        Text("Sexe").font(.lumeBodyMed).foregroundStyle(LumeColor.ink)
                        Spacer()
                        Picker("", selection: $profile.sex) {
                            Text("Homme").tag(Sex.male); Text("Femme").tag(Sex.female)
                        }.pickerStyle(.segmented).labelsHidden().fixedSize()
                    }
                    stepper("Âge", "\(profile.age) ans", { profile.age = max(14, profile.age - 1) }, { profile.age = min(100, profile.age + 1) })
                    stepper("Taille", "\(profile.heightCm) cm", { profile.heightCm = max(120, profile.heightCm - 1) }, { profile.heightCm = min(230, profile.heightCm + 1) })
                    stepper("Poids", WeightFormat.body(profile.weightKg, imperial: useImperial), { profile.weightKg = max(35, profile.weightKg - WeightFormat.stepKg(imperial: useImperial)) }, { profile.weightKg = min(250, profile.weightKg + WeightFormat.stepKg(imperial: useImperial)) })
                    HStack {
                        Text("Activité").font(.lumeBodyMed).foregroundStyle(LumeColor.ink)
                        Spacer()
                        Picker("", selection: $profile.activity) {
                            ForEach(ActivityLevel.allCases, id: \.self) { Text($0.label).tag($0) }
                        }.tint(LumeColor.ink)
                    }
                }
            }
            Spacer()
        }.padding(.horizontal, Spacing.xl).padding(.top, Spacing.xxl)
    }

    // MARK: Étape 3 — objectif

    private var goal: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            stepTitle("Ton objectif", "On en déduit tes cibles.")
            Picker("", selection: $profile.goal) {
                Text("Perdre").tag(Goal.lose); Text("Maintenir").tag(Goal.maintain); Text("Prendre").tag(Goal.gain)
            }.pickerStyle(.segmented).labelsHidden()
            LumeCard(padding: Spacing.xxl, radius: Radius.xxl) {
                VStack(spacing: Spacing.md) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(target.kcal)").font(.lumeNumberXL).foregroundStyle(LumeColor.ink).monospacedDigit()
                        Text("kcal / jour").font(.lumeHeadline).foregroundStyle(LumeColor.muted)
                    }
                    HStack(spacing: Spacing.sm) {
                        Chip(color: LumeColor.protein, text: "P \(target.protein)")
                        Chip(color: LumeColor.carbs, text: "G \(target.carbs)")
                        Chip(color: LumeColor.fat, text: "L \(target.fat)")
                    }
                }.frame(maxWidth: .infinity)
            }
            Spacer()
        }.padding(.horizontal, Spacing.xl).padding(.top, Spacing.xxl)
    }

    // MARK: Étape 4 — modules (Muscu / Finance optionnels)

    private var modules: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            stepTitle("Que veux-tu suivre ?", "Tu pourras changer d'avis plus tard.")
            VStack(spacing: Spacing.md) {
                moduleRow(.calories, LumeColor.protein, "Nutrition", "Calories et macros par photo",
                          locked: true, on: .constant(true))
                moduleRow(.workout, LumeColor.ink, "Muscu", "Séances, routines, records",
                          locked: false, on: $workoutEnabled)
                moduleRow(.wallet, LumeColor.success, "Budget", "Dépenses, budgets, récurrentes",
                          locked: false, on: $financeEnabled)
            }
            Spacer()
        }.padding(.horizontal, Spacing.xl).padding(.top, Spacing.xxl)
    }

    private func moduleRow(_ icon: AppIcon, _ tint: Color, _ title: String, _ subtitle: String,
                           locked: Bool, on: Binding<Bool>) -> some View
    {
        LumeCard {
            HStack(spacing: Spacing.md) {
                Image(appIcon: icon).lumeIcon(20).foregroundStyle(tint)
                    .frame(width: 44, height: 44).background(tint.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.lumeCallout).foregroundStyle(LumeColor.ink)
                    Text(locked ? "Toujours actif" : subtitle).font(.lumeFootnote).foregroundStyle(LumeColor.muted)
                }
                Spacer()
                if locked {
                    Image(appIcon: .validate).lumeIcon(20).foregroundStyle(LumeColor.success)
                } else {
                    Toggle("", isOn: on).labelsHidden().tint(LumeColor.ink)
                }
            }
        }
    }

    // MARK: Étape 5 — permissions

    private var permissions: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            stepTitle("Autorisations", "Pour que Lume fonctionne pleinement.")
            VStack(spacing: Spacing.md) {
                permissionRow(.weight, LumeColor.success, "Apple Santé", "Poids, énergie, séances",
                              granted: health.isAuthorized) { Task { await health.requestAuthorization() } }
                permissionRow(.camera, LumeColor.fat, "Caméra", "Scanner et photographier tes repas",
                              granted: cameraGranted) { Task { cameraGranted = await Permissions.requestCamera() } }
                permissionRow(.streak, LumeColor.warning, "Notifications", "Rappels (optionnel)",
                              granted: notifGranted) { Task { notifGranted = await Permissions.requestNotifications() } }
            }
            Spacer()
        }.padding(.horizontal, Spacing.xl).padding(.top, Spacing.xxl)
    }

    // MARK: Helpers

    private func stepTitle(_ t: LocalizedStringKey, _ s: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(t).font(.lumeDisplay).foregroundStyle(LumeColor.ink)
            Text(s).font(.lumeSubhead).foregroundStyle(LumeColor.muted)
        }
    }

    private func stepper(_ t: String, _ v: String, _ minus: @escaping () -> Void, _ plus: @escaping () -> Void) -> some View {
        HStack {
            Text(t).font(.lumeBodyMed).foregroundStyle(LumeColor.ink)
            Spacer()
            HStack(spacing: Spacing.md) {
                RoundIconButton(icon: .minus, action: minus)
                Text(v).font(.lumeSubhead.weight(.semibold)).foregroundStyle(LumeColor.ink).monospacedDigit().frame(minWidth: 70)
                RoundIconButton(icon: .add, filled: true, action: plus)
            }
        }
    }

    private func permissionRow(_ icon: AppIcon, _ tint: Color, _ title: String, _ subtitle: String,
                               granted: Bool, action: @escaping () -> Void) -> some View
    {
        LumeCard {
            HStack(spacing: Spacing.md) {
                Image(appIcon: icon).lumeIcon(20).foregroundStyle(tint)
                    .frame(width: 44, height: 44).background(tint.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.lumeCallout).foregroundStyle(LumeColor.ink)
                    Text(subtitle).font(.lumeFootnote).foregroundStyle(LumeColor.muted)
                }
                Spacer()
                if granted {
                    Image(appIcon: .validate).lumeIcon(20).foregroundStyle(LumeColor.success)
                } else {
                    Button("Autoriser", action: action)
                        .font(.lumeSubhead.weight(.semibold)).foregroundStyle(LumeColor.surface)
                        .padding(.horizontal, Spacing.md).padding(.vertical, Spacing.sm)
                        .background(LumeColor.ink).clipShape(Capsule())
                }
            }
        }
    }
}

#Preview { OnboardingView().modelContainer(LumeStore.preview).environment(HealthManager.shared) }
