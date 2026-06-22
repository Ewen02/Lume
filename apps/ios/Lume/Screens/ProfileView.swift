import SwiftData
import SwiftUI
import UIKit

struct ProfileView: View {
    @Query private var profiles: [ProfileRecord]
    @Environment(HealthManager.self) private var health
    @AppStorage("lume.useImperialUnits") private var useImperial = false
    @State private var user = "Ewen"
    @State private var showGoal = false
    @State private var showAbout = false

    private var record: ProfileRecord? {
        profiles.first
    }

    private var target: Macros {
        record.map { TDEECalculator.target($0.profile) } ?? Mock.target
    }

    private var goalLabel: String {
        (record?.profile.goal ?? .maintain).label.lowercased()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                headerCard
                Button { showGoal = true } label: { goalCard }.buttonStyle(.lumePress)
                settingsCard
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.top, Spacing.sm)
            .padding(.bottom, 130)
        }
        .background(LumeColor.cream)
        .safeAreaInset(edge: .top) {
            Text("Profil").font(.lumeDisplay).foregroundStyle(LumeColor.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.xl).padding(.vertical, Spacing.sm)
                .background(LumeColor.cream)
        }
        .onAppear { if let n = record?.name { user = n } }
        .sheet(isPresented: $showGoal) { GoalView() }
        .sheet(isPresented: $showAbout) { AboutView() }
    }

    private func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    private var headerCard: some View {
        LumeCard {
            VStack(spacing: Spacing.lg) {
                HStack(spacing: Spacing.lg) {
                    Text(String(user.prefix(1)))
                        .font(.lumeTitle).foregroundStyle(LumeColor.surface)
                        .frame(width: 60, height: 60).background(LumeColor.ink).clipShape(Circle())
                    VStack(alignment: .leading, spacing: 3) {
                        Text(user).font(.lumeTitle).foregroundStyle(LumeColor.ink)
                        Text("Objectif : \(goalLabel)").font(.lumeSubhead).foregroundStyle(LumeColor.muted)
                    }
                    Spacer()
                }
                // Bascule cosmétique : en local-first, 1 profil = 1 compte iCloud.
                HStack(spacing: Spacing.sm) {
                    ForEach(["Ewen", "Victoria"], id: \.self) { name in
                        let active = name == user
                        Text(name).font(.lumeSubhead.weight(.semibold))
                            .foregroundStyle(active ? LumeColor.surface : LumeColor.textSecondary)
                            .frame(maxWidth: .infinity).padding(.vertical, Spacing.sm + 2)
                            .background(active ? LumeColor.ink : LumeColor.cream)
                            .clipShape(Capsule())
                            .onTapGesture { withAnimation(LumeMotion.snappy) { user = name } }
                    }
                }
            }
        }
    }

    private var goalCard: some View {
        LumeCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack {
                    Text("Objectif quotidien").font(.lumeHeadline).foregroundStyle(LumeColor.ink)
                    Spacer()
                    Text("Modifier").font(.lumeSubhead.weight(.semibold)).foregroundStyle(LumeColor.muted)
                }
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(target.kcal)").font(.lumeNumberL).foregroundStyle(LumeColor.ink).monospacedDigit()
                    Text("kcal").font(.lumeHeadline).foregroundStyle(LumeColor.muted)
                }
                HStack(spacing: Spacing.sm) {
                    Chip(color: LumeColor.protein, text: "\(target.protein) g")
                    Chip(color: LumeColor.carbs, text: "\(target.carbs) g")
                    Chip(color: LumeColor.fat, text: "\(target.fat) g")
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var settingsCard: some View {
        LumeCard(padding: Spacing.xs) {
            VStack(spacing: 0) {
                Button { showGoal = true } label: {
                    SettingsRow(icon: .progress, tint: LumeColor.protein, title: "Objectif & calories")
                }.buttonStyle(.lumePress)
                divider
                Button { Task { await health.requestAuthorization() } } label: {
                    SettingsRow(icon: .weight, tint: LumeColor.success, title: "Apple Santé",
                                value: health.isAuthorized ? "Connecté" : "Connecter", showsChevron: false)
                }.buttonStyle(.lumePress)
                divider
                Button { withAnimation(LumeMotion.snappy) { useImperial.toggle() } } label: {
                    SettingsRow(icon: .settings, tint: LumeColor.fat, title: "Unités",
                                value: useImperial ? "lb · kcal" : "kg · kcal", showsChevron: false)
                }.buttonStyle(.lumePress)
                divider
                Button { openSystemSettings() } label: {
                    SettingsRow(icon: .recents, tint: LumeColor.carbs, title: "Rappels", value: "Réglages")
                }.buttonStyle(.lumePress)
                divider
                Button { showAbout = true } label: {
                    SettingsRow(icon: .person, tint: LumeColor.muted, title: "À propos", showsChevron: true)
                }.buttonStyle(.lumePress)
            }
        }
    }

    private var divider: some View {
        Rectangle().fill(LumeColor.border).frame(height: 1).padding(.leading, 56)
    }
}

#Preview { ProfileView().modelContainer(LumeStore.preview).environment(HealthManager.shared) }

// MARK: - À propos

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    private var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "Version \(v) (\(b))"
    }

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()
            Image(appIcon: .streak).lumeIcon(40, weight: .semibold).foregroundStyle(LumeColor.protein)
            Text("Lume").font(.lumeTitle).foregroundStyle(LumeColor.ink)
            Text("Suivi calories & macros par photo,\net carnet de muscu.")
                .font(.lumeSubhead).foregroundStyle(LumeColor.muted).multilineTextAlignment(.center)
            Text(version).font(.lumeFootnote).foregroundStyle(LumeColor.muted).monospacedDigit()
            Spacer()
            SecondaryButton(title: "Fermer") { dismiss() }
                .padding(.horizontal, Spacing.xl).padding(.bottom, Spacing.lg)
        }
        .frame(maxWidth: .infinity)
        .background(LumeColor.cream.ignoresSafeArea())
        .presentationDetents([.medium])
    }
}

#Preview("À propos") { AboutView() }
