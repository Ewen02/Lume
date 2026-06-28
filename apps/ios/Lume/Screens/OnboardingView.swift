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
    /// Modules optionnels choisis ici (la nutrition est le cœur, toujours active).
    @AppStorage(ModuleSettings.workoutKey) private var workoutEnabled = ModuleSettings.defaultEnabled
    @AppStorage(ModuleSettings.financeKey) private var financeEnabled = ModuleSettings.defaultEnabled

    var onFinish: () -> Void = {}

    private let lastStep = 4
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
                infos.tag(1)
                goal.tag(2)
                modules.tag(3)
                permissions.tag(4)
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

            PrimaryButton(title: step < lastStep ? "Continuer" : "Commencer",
                          icon: step < lastStep ? nil : .validate)
            {
                if step < lastStep { withAnimation { step += 1 } } else { finish() }
            }
            .disabled(step == 1 && trimmedName.isEmpty)
            .opacity(step == 1 && trimmedName.isEmpty ? 0.5 : 1)
            .padding(.horizontal, Spacing.xl).padding(.bottom, Spacing.lg)

            if step == lastStep {
                Button("Plus tard") { finish() }
                    .font(.lumeSubhead).foregroundStyle(LumeColor.muted)
                    .padding(.bottom, Spacing.sm)
            }
        }
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

    // MARK: Étape 1 — profil (modifiable)

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

    // MARK: Étape 2 — objectif

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

    // MARK: Étape 3 — modules (Muscu / Finance optionnels)

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

    // MARK: Étape 4 — permissions

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

    private func stepTitle(_ t: String, _ s: String) -> some View {
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
