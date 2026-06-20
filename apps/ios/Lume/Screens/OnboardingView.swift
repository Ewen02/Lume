import SwiftData
import SwiftUI

struct OnboardingView: View {
    @Environment(\.modelContext) private var ctx
    @Environment(HealthManager.self) private var health
    @Query private var profiles: [ProfileRecord]

    @State private var step = 0
    @State private var profile = Mock.profile
    @State private var cameraGranted = Permissions.cameraGranted
    @State private var notifGranted = false

    var onFinish: () -> Void = {}

    private let lastStep = 3
    private var target: Macros {
        TDEECalculator.target(profile)
    }

    private func finish() {
        if let r = profiles.first { r.update(from: profile) }
        else { ctx.insert(ProfileRecord(from: profile)) }
        onFinish()
    }

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $step) {
                welcome.tag(0)
                infos.tag(1)
                goal.tag(2)
                permissions.tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.snappy, value: step)

            HStack(spacing: Spacing.sm) {
                ForEach(0 ... lastStep, id: \.self) { i in
                    Capsule().fill(i == step ? LumeColor.ink : LumeColor.border)
                        .frame(width: i == step ? 22 : 7, height: 7)
                        .animation(.snappy, value: step)
                }
            }.padding(.bottom, Spacing.lg)

            PrimaryButton(title: step < lastStep ? "Continuer" : "Commencer",
                          icon: step < lastStep ? nil : .validate)
            {
                if step < lastStep { withAnimation { step += 1 } } else { finish() }
            }
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
                        Text("Sexe").font(.lumeBodyMed).foregroundStyle(LumeColor.ink)
                        Spacer()
                        Picker("", selection: $profile.sex) {
                            Text("Homme").tag(Sex.male); Text("Femme").tag(Sex.female)
                        }.pickerStyle(.segmented).labelsHidden().fixedSize()
                    }
                    stepper("Âge", "\(profile.age) ans", { profile.age = max(14, profile.age - 1) }, { profile.age = min(100, profile.age + 1) })
                    stepper("Taille", "\(profile.heightCm) cm", { profile.heightCm = max(120, profile.heightCm - 1) }, { profile.heightCm = min(230, profile.heightCm + 1) })
                    stepper("Poids", String(format: "%.1f kg", profile.weightKg), { profile.weightKg = max(35, profile.weightKg - 0.5) }, { profile.weightKg = min(250, profile.weightKg + 0.5) })
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

    // MARK: Étape 3 — permissions

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
