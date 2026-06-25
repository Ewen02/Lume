import PhotosUI
import SwiftData
import SwiftUI

struct ProfileView: View {
    @Query private var profiles: [ProfileRecord]
    @Environment(HealthManager.self) private var health
    @AppStorage(WeightFormat.defaultsKey) private var useImperial = false
    @Environment(\.modelContext) private var ctx
    @State private var showGoal = false
    @State private var showAbout = false
    @State private var showName = false
    @State private var showReminders = false
    @State private var showExport = false
    @State private var showBadges = false
    @State private var showResetConfirm = false
    @State private var showHealthUnavailable = false
    @State private var showEmailCopied = false
    @State private var photoItem: PhotosPickerItem?

    private static let supportEmail = "ewen@favikon.com"

    private var record: ProfileRecord? {
        profiles.first
    }

    private var displayName: String {
        let name = record?.name.trimmingCharacters(in: .whitespaces) ?? ""
        return name.isEmpty ? "Toi" : name
    }

    /// Calories actives mesurées par Santé aujourd'hui (`nil` si non autorisé/indispo) —
    /// même source que l'écran Aujourd'hui, pour afficher exactement la même cible.
    private var activeKcal: Int? {
        health.isAuthorized && health.activeEnergyToday > 0 ? health.activeEnergyToday : nil
    }

    /// Cible affichée : **identique à celle d'Aujourd'hui** via `EnergyBudget`.
    /// - Santé inactif (cas actuel, « Bientôt ») → cible complète (TDEE + objectif).
    /// - Santé actif → cible au repos + activité réelle (dynamique).
    /// On ne montre plus une cible « au repos » seule, qui divergeait des autres écrans.
    private var baseTarget: Macros {
        guard let p = record?.profile else { return TDEECalculator.defaultTarget }
        return EnergyBudget.target(p, activeKcal: activeKcal, healthAuthorized: health.isAuthorized)
    }

    /// La cible affichée inclut-elle l'activité réelle (mode dynamique Santé) ?
    private var isDynamicTarget: Bool {
        EnergyBudget.isDynamic(activeKcal: activeKcal, healthAuthorized: health.isAuthorized)
    }

    private var goalLabel: String {
        (record?.profile.goal ?? .maintain).label.lowercased()
    }

    /// HealthKit n'est entitlé que sur un compte Apple Developer payant (cf. Lume.entitlements).
    /// Sur le build actuel (compte gratuit, entitlements vidés), l'autorisation échoue toujours :
    /// on présente alors la ligne en « Bientôt » (désactivée) plutôt qu'un « Connecter » trompeur.
    private var healthConnectable: Bool {
        health.isAuthorized || health.entitled
    }

    private var healthValue: String {
        if health.isAuthorized { return "Connecté" }
        return health.entitled ? "Connecter" : "Bientôt"
    }

    /// Connecte Apple Santé ; si indisponible (compte gratuit), prévient l'utilisateur.
    private func connectHealth() {
        Task {
            await health.requestAuthorization()
            if !health.isAuthorized { showHealthUnavailable = true }
        }
    }

    /// Charge la photo choisie et la persiste dans le profil.
    private func loadPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self) {
                if let r = record { r.avatarData = data }
                else { let r = ProfileRecord(); r.avatarData = data; ctx.insert(r) }
            }
        }
    }

    /// Efface toutes les données utilisateur (avec confirmation préalable). Profil et réglages
    /// sont conservés ; le catalogue d'exercices seedé l'est aussi (données de référence, pas
    /// « tes » données). Le reste — y compris favoris, routines, exos custom et les données
    /// écrites par Lume dans Santé — est supprimé pour tenir la promesse « tout effacer ».
    private func resetAllData() {
        try? ctx.delete(model: LoggedFood.self)
        try? ctx.delete(model: WaterLog.self)
        try? ctx.delete(model: WeightSample.self)
        try? ctx.delete(model: WorkoutSessionModel.self)
        try? ctx.delete(model: BadgeUnlock.self)
        try? ctx.delete(model: FavoriteFood.self)
        try? ctx.delete(model: RoutineModel.self) // cascade → RoutineExerciseModel
        // Exercices : on ne retire que ceux ajoutés par l'utilisateur (le catalogue seedé reste).
        try? ctx.delete(model: ExerciseModel.self, where: #Predicate { $0.isCustom })
        // Données écrites par Lume dans Santé (poids, séances), sinon le poids se repeuplerait.
        Task { await health.deleteLumeData() }
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
        .onChange(of: photoItem) { _, item in loadPhoto(item) }
        .alert("Apple Santé indisponible", isPresented: $showHealthUnavailable) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("La synchronisation Santé nécessite un compte Apple Developer (la fonctionnalité est désactivée sur ce build). Tes données restent enregistrées dans Lume.")
        }
        .alert("Adresse copiée", isPresented: $showEmailCopied) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Aucune app mail n'est configurée. Écris-nous à \(Self.supportEmail) (adresse copiée dans le presse-papier).")
        }
        .alert("Effacer toutes les données ?", isPresented: $showResetConfirm) {
            Button("Tout effacer", role: .destructive) { resetAllData() }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Repas, eau, poids, séances, routines, favoris et récompenses seront supprimés (y compris dans Apple Santé). Ton profil et tes réglages sont conservés. Action irréversible.")
        }
    }

    private var headerCard: some View {
        LumeCard {
            HStack(spacing: Spacing.lg) {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    avatar
                }.buttonStyle(.lumePress)
                VStack(alignment: .leading, spacing: 3) {
                    Text(displayName).font(.lumeTitle).foregroundStyle(LumeColor.ink)
                    Text("Objectif : \(goalLabel)").font(.lumeSubhead).foregroundStyle(LumeColor.muted)
                }
                Spacer()
            }
        }
    }

    @ViewBuilder private var avatar: some View {
        if let data = record?.avatarData, let img = UIImage(data: data) {
            Image(uiImage: img).resizable().scaledToFill()
                .frame(width: 60, height: 60).clipShape(Circle())
        } else {
            Text(String(displayName.prefix(1)))
                .font(.lumeTitle).foregroundStyle(LumeColor.surface)
                .frame(width: 60, height: 60).background(LumeColor.ink).clipShape(Circle())
                .overlay(alignment: .bottomTrailing) {
                    Image(appIcon: .camera).lumeIcon(11, weight: .bold).foregroundStyle(LumeColor.ink)
                        .padding(5).background(LumeColor.surface, in: Circle()).lumeShadow(.soft)
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
                HStack(alignment: .firstTextBaseline, spacing: Spacing.xs + 2) {
                    Text("\(baseTarget.kcal)").font(.lumeNumberL).foregroundStyle(LumeColor.ink).monospacedDigit()
                    Text("kcal").font(.lumeHeadline).foregroundStyle(LumeColor.muted)
                }
                HStack(spacing: Spacing.sm) {
                    Chip(color: LumeColor.protein, text: "\(baseTarget.protein) g")
                    Chip(color: LumeColor.carbs, text: "\(baseTarget.carbs) g")
                    Chip(color: LumeColor.fat, text: "\(baseTarget.fat) g")
                }
                // Le libellé reflète la cible RÉELLEMENT affichée (identique à Aujourd'hui), pas une
                // promesse : on ne mentionne l'ajout d'activité que si Santé l'alimente vraiment.
                Text(isDynamicTarget ? "Cible au repos · ton activité du jour s'y ajoute"
                    : "Cible quotidienne · activité incluse (estimée)")
                    .font(.lumeFootnote).foregroundStyle(LumeColor.muted)
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var settingsCard: some View {
        LumeCard(padding: Spacing.xs) {
            VStack(spacing: 0) {
                Button { showName = true } label: {
                    SettingsRow(icon: .profile, tint: LumeColor.ink, title: "Prénom", value: displayName)
                }.buttonStyle(.lumePress)
                divider
                Button { showGoal = true } label: {
                    SettingsRow(icon: .progress, tint: LumeColor.protein, title: "Objectif & calories")
                }.buttonStyle(.lumePress)
                divider
                Button { connectHealth() } label: {
                    SettingsRow(icon: .weight, tint: LumeColor.success, title: "Apple Santé",
                                value: healthValue, showsChevron: false)
                }
                .buttonStyle(.lumePress)
                .disabled(!healthConnectable)
                .opacity(healthConnectable ? 1 : 0.5)
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
                Button { contactSupport() } label: {
                    SettingsRow(icon: .envelope, tint: LumeColor.fat, title: "Nous contacter", showsChevron: true)
                }.buttonStyle(.lumePress)
                divider
                Button { showAbout = true } label: {
                    SettingsRow(icon: .person, tint: LumeColor.muted, title: "À propos", showsChevron: true)
                }.buttonStyle(.lumePress)
                divider
                Button { showResetConfirm = true } label: {
                    SettingsRow(icon: .trash, tint: LumeColor.negative, title: "Effacer mes données", showsChevron: false)
                }.buttonStyle(.lumePress)
            }
        }
    }

    /// Ouvre l'app Mail avec un brouillon pré-rempli (feedback / bug). Si aucune app mail ne peut
    /// l'ouvrir (compte mail absent, simulateur), on copie l'adresse et on prévient — pas de silence.
    private func contactSupport() {
        let subject = "Lume — retour".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let url = URL(string: "mailto:\(Self.supportEmail)?subject=\(subject)") else {
            copyEmailFallback(); return
        }
        UIApplication.shared.open(url) { success in
            if !success { copyEmailFallback() }
        }
    }

    private func copyEmailFallback() {
        UIPasteboard.general.string = Self.supportEmail
        showEmailCopied = true
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
