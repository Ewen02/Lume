import SwiftData
import SwiftUI

struct ProfileView: View {
    @Query private var profiles: [ProfileRecord]
    @Environment(HealthManager.self) private var health
    @AppStorage("lume.useImperialUnits") private var useImperial = false
    @Environment(\.modelContext) private var ctx
    @State private var showGoal = false
    @State private var showAbout = false
    @State private var showName = false
    @State private var showReminders = false
    @State private var showExport = false
    @State private var showBadges = false

    private var record: ProfileRecord? {
        profiles.first
    }

    private var displayName: String {
        let name = record?.name.trimmingCharacters(in: .whitespaces) ?? ""
        return name.isEmpty ? "Toi" : name
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
        .sheet(isPresented: $showGoal) { GoalView() }
        .sheet(isPresented: $showAbout) { AboutView() }
        .sheet(isPresented: $showName) {
            NameEditView(initial: record?.name ?? "") { newName in
                if let r = record { r.name = newName }
                else { ctx.insert(ProfileRecord(name: newName)) }
            }
        }
        .sheet(isPresented: $showReminders) { RemindersView() }
        .sheet(isPresented: $showBadges) { BadgesView(domain: .nutrition) }
        .sheet(isPresented: $showExport) { ExportView() }
    }

    private var headerCard: some View {
        LumeCard {
            HStack(spacing: Spacing.lg) {
                Text(String(displayName.prefix(1)))
                    .font(.lumeTitle).foregroundStyle(LumeColor.surface)
                    .frame(width: 60, height: 60).background(LumeColor.ink).clipShape(Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(displayName).font(.lumeTitle).foregroundStyle(LumeColor.ink)
                    Text("Objectif : \(goalLabel)").font(.lumeSubhead).foregroundStyle(LumeColor.muted)
                }
                Spacer()
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
                Button { showName = true } label: {
                    SettingsRow(icon: .person, tint: LumeColor.ink, title: "Prénom", value: displayName)
                }.buttonStyle(.lumePress)
                divider
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
                Button { showReminders = true } label: {
                    SettingsRow(icon: .recents, tint: LumeColor.carbs, title: "Rappels")
                }.buttonStyle(.lumePress)
                divider
                Button { showBadges = true } label: {
                    SettingsRow(icon: .pr, tint: LumeColor.warning, title: "Récompenses nutrition")
                }.buttonStyle(.lumePress)
                divider
                Button { showExport = true } label: {
                    SettingsRow(icon: .gallery, tint: LumeColor.success, title: "Exporter mes données")
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

// MARK: - Édition du prénom

struct NameEditView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    let onSave: (String) -> Void

    init(initial: String, onSave: @escaping (String) -> Void) {
        _name = State(initialValue: initial)
        self.onSave = onSave
    }

    private var trimmed: String {
        name.trimmingCharacters(in: .whitespaces)
    }

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()
            Text("Ton prénom").font(.lumeTitle).foregroundStyle(LumeColor.ink)
            LumeCard {
                TextField("Prénom", text: $name)
                    .multilineTextAlignment(.center)
                    .textInputAutocapitalization(.words)
                    .font(.lumeHeadline).foregroundStyle(LumeColor.ink)
            }.padding(.horizontal, Spacing.xl)
            Spacer()
            PrimaryButton(title: "Enregistrer", icon: .validate) {
                onSave(trimmed)
                dismiss()
            }
            .disabled(trimmed.isEmpty)
            .opacity(trimmed.isEmpty ? 0.5 : 1)
            .padding(.horizontal, Spacing.xl).padding(.bottom, Spacing.lg)
        }
        .frame(maxWidth: .infinity)
        .background(LumeColor.cream.ignoresSafeArea())
        .presentationDetents([.medium])
    }
}

#Preview("Prénom") { NameEditView(initial: "Ewen") { _ in } }
