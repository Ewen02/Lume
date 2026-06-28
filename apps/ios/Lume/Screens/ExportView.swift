import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Export des données : CSV (journal lisible) + JSON (sauvegarde complète), via la feuille de partage.
/// + Import : restaurer une sauvegarde JSON (ex. nouvel appareil).
struct ExportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @Query(sort: \LoggedFood.date) private var foods: [LoggedFood]
    @Query(sort: \WeightSample.date) private var weights: [WeightSample]
    @Query(sort: \FavoriteFood.addedAt) private var favorites: [FavoriteFood]
    @Query(sort: \WorkoutSessionModel.date) private var sessions: [WorkoutSessionModel]
    @Query(sort: \RoutineModel.order) private var routines: [RoutineModel]
    @Query private var exercises: [ExerciseModel]
    @Query private var profiles: [ProfileRecord]
    @Query(sort: \FinanceTransaction.date) private var transactions: [FinanceTransaction]
    @Query private var recurring: [RecurringTransaction]
    @Query private var budgets: [CategoryBudget]

    @State private var error: String?
    /// État de l'import : sélection de fichier, confirmation (destructif), résultat.
    @State private var showImporter = false
    @State private var pendingBackup: Backup?
    @State private var restoreResult: DataExporter.RestoreSummary?

    /// Exercices ajoutés par l'utilisateur (le catalogue seedé n'est pas « tes » données).
    private var customExercises: [ExerciseModel] {
        exercises.filter(\.isCustom)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                summaryCard
                exportRow(title: "Journal alimentaire (CSV)",
                          subtitle: "\(foods.count) entrées · ouvrable dans Excel/Numbers",
                          icon: .calories, tint: LumeColor.carbs) { try foodCSVURL() }
                exportRow(title: "Poids (CSV)",
                          subtitle: "\(weights.count) mesures",
                          icon: .weight, tint: LumeColor.fat) { try weightCSVURL() }
                exportRow(title: "Transactions (CSV)",
                          subtitle: "\(transactions.count) entrées · dépenses & revenus",
                          icon: .money, tint: LumeColor.success) { try transactionsCSVURL() }
                exportRow(title: "Sauvegarde complète (JSON)",
                          subtitle: "Profil, repas, poids, favoris, séances, routines, exos, finances",
                          icon: .settings, tint: LumeColor.protein) { try backupJSONURL() }

                SectionHeader(title: "Restaurer")
                    .padding(.top, Spacing.sm)
                importRow

                if let error {
                    Text(error).font(.lumeFootnote).foregroundStyle(LumeColor.negative)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, Spacing.xl).padding(.top, Spacing.sm).padding(.bottom, Spacing.xxl)
        }
        .background(LumeColor.cream.ignoresSafeArea())
        .safeAreaInset(edge: .top) {
            TopBar(title: "Mes données", leading: .back, onLeading: { dismiss() })
                .padding(.horizontal, Spacing.xl).padding(.vertical, Spacing.sm).background(LumeColor.cream)
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
            handlePickedFile(result)
        }
        // Restauration destructive : on confirme avant de remplacer les données actuelles.
        .alert("Restaurer cette sauvegarde ?", isPresented: Binding(
            get: { pendingBackup != nil }, set: { if !$0 { pendingBackup = nil } }
        )) {
            Button("Restaurer", role: .destructive) { performRestore() }
            Button("Annuler", role: .cancel) { pendingBackup = nil }
        } message: {
            Text("Tes données actuelles (repas, poids, séances, finances…) seront remplacées par celles de la sauvegarde. Cette action est irréversible.")
        }
        .alert("Sauvegarde restaurée", isPresented: Binding(
            get: { restoreResult != nil }, set: { if !$0 { restoreResult = nil } }
        )) {
            Button("OK", role: .cancel) { restoreResult = nil; dismiss() }
        } message: {
            if let r = restoreResult {
                Text("\(r.total) éléments restaurés.")
            }
        }
    }

    /// Ligne « Importer une sauvegarde » : ouvre le sélecteur de fichiers (.json).
    private var importRow: some View {
        Button { showImporter = true } label: {
            LumeCard {
                HStack(spacing: Spacing.md) {
                    Image(appIcon: .gallery).lumeIcon(18, weight: .semibold).foregroundStyle(LumeColor.protein)
                        .frame(width: 40, height: 40).background(LumeColor.protein.opacity(0.14))
                        .clipShape(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Importer une sauvegarde").font(.lumeCallout).foregroundStyle(LumeColor.ink)
                        Text("Restaure un fichier JSON Lume (remplace tes données)")
                            .font(.lumeFootnote).foregroundStyle(LumeColor.muted)
                    }
                    Spacer()
                    Image(appIcon: .forward).lumeIcon(14, weight: .semibold).foregroundStyle(LumeColor.muted)
                }
            }
        }.buttonStyle(.lumePress)
    }

    // MARK: Import

    /// Lit le fichier choisi et décode le backup (sans encore toucher la base : on demande confirmation).
    private func handlePickedFile(_ result: Result<URL, Error>) {
        error = nil
        do {
            let url = try result.get()
            // Fichier hors sandbox : nécessite un accès sécurisé.
            let needsAccess = url.startAccessingSecurityScopedResource()
            defer { if needsAccess { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            pendingBackup = try DataExporter.decodeBackup(data)
        } catch is CocoaError {
            error = String(localized: "Impossible de lire ce fichier.")
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? String(localized: "Ce fichier n'est pas une sauvegarde Lume valide.")
        }
    }

    /// Restaure après confirmation utilisateur.
    private func performRestore() {
        guard let backup = pendingBackup else { return }
        pendingBackup = nil
        do {
            restoreResult = try DataExporter.restore(backup, into: ctx)
        } catch {
            self.error = String(localized: "La restauration a échoué. Tes données actuelles n'ont pas été modifiées.")
        }
    }

    private var summaryCard: some View {
        LumeCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Tes données restent sur ton appareil.").font(.lumeCallout).foregroundStyle(LumeColor.ink)
                Text("Exporte pour sauvegarder ou analyser ailleurs. Le partage passe par iOS (Fichiers, Mail…).")
                    .font(.lumeFootnote).foregroundStyle(LumeColor.muted)
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Chaque ligne génère son fichier et propose un ShareLink dessus. En cas d'échec d'écriture,
    /// la ligne reste visible (désactivée) et alimente le message d'erreur — pas de disparition muette.
    @ViewBuilder
    private func exportRow(title: String, subtitle: String, icon: AppIcon, tint: Color,
                           makeURL: () throws -> URL) -> some View
    {
        let result = Result { try makeURL() }
        let card = rowCard(title: title, subtitle: subtitle, icon: icon, tint: tint,
                           failed: (try? result.get()) == nil)
        switch result {
        case let .success(url):
            ShareLink(item: url) { card }.buttonStyle(.lumePress)
        case let .failure(err):
            // Visible mais inactif, et on remonte l'erreur (affichée plus bas).
            card.onAppear { error = "Export « \(title) » indisponible : \(err.localizedDescription)" }
        }
    }

    private func rowCard(title: String, subtitle: String, icon: AppIcon, tint: Color, failed: Bool) -> some View {
        LumeCard {
            HStack(spacing: Spacing.md) {
                Image(appIcon: icon).lumeIcon(18, weight: .semibold).foregroundStyle(tint)
                    .frame(width: 40, height: 40).background(tint.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.lumeCallout).foregroundStyle(LumeColor.ink)
                    Text(subtitle).font(.lumeFootnote).foregroundStyle(LumeColor.muted)
                }
                Spacer()
                Image(appIcon: failed ? .warning : .forward).lumeIcon(14, weight: .semibold)
                    .foregroundStyle(failed ? LumeColor.negative : LumeColor.muted)
            }
        }
        .opacity(failed ? 0.55 : 1)
    }

    // MARK: Génération des fichiers (dans le dossier temporaire)

    private func foodCSVURL() throws -> URL {
        try write(DataExporter.foodCSV(foods), to: "lume-journal.csv")
    }

    private func weightCSVURL() throws -> URL {
        try write(DataExporter.weightCSV(weights), to: "lume-poids.csv")
    }

    private func transactionsCSVURL() throws -> URL {
        try write(DataExporter.transactionsCSV(transactions), to: "lume-transactions.csv")
    }

    private func backupJSONURL() throws -> URL {
        let data = try DataExporter.backupJSON(profile: profiles.first, foods: foods,
                                               weights: weights, favorites: favorites, sessions: sessions,
                                               routines: routines, customExercises: customExercises,
                                               transactions: transactions, recurring: recurring, budgets: budgets)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("lume-sauvegarde.json")
        try data.write(to: url, options: .atomic)
        return url
    }

    private func write(_ string: String, to filename: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try string.data(using: .utf8)?.write(to: url, options: .atomic)
        return url
    }
}

#Preview { ExportView().modelContainer(LumeStore.preview) }
