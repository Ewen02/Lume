import SwiftData
import SwiftUI

/// Export des données : CSV (journal lisible) + JSON (sauvegarde complète), via la feuille de partage.
struct ExportView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \LoggedFood.date) private var foods: [LoggedFood]
    @Query(sort: \WeightSample.date) private var weights: [WeightSample]
    @Query(sort: \FavoriteFood.addedAt) private var favorites: [FavoriteFood]
    @Query(sort: \WorkoutSessionModel.date) private var sessions: [WorkoutSessionModel]
    @Query private var profiles: [ProfileRecord]

    @State private var error: String?

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
                exportRow(title: "Sauvegarde complète (JSON)",
                          subtitle: "Profil, repas, poids, favoris, séances",
                          icon: .settings, tint: LumeColor.protein) { try backupJSONURL() }

                if let error {
                    Text(error).font(.lumeFootnote).foregroundStyle(LumeColor.negative)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, Spacing.xl).padding(.top, Spacing.sm).padding(.bottom, Spacing.xxl)
        }
        .background(LumeColor.cream.ignoresSafeArea())
        .safeAreaInset(edge: .top) {
            TopBar(title: "Exporter mes données", leading: .back, onLeading: { dismiss() })
                .padding(.horizontal, Spacing.xl).padding(.vertical, Spacing.sm).background(LumeColor.cream)
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

    /// Chaque ligne génère son fichier à la demande et propose un ShareLink dessus.
    @ViewBuilder
    private func exportRow(title: String, subtitle: String, icon: AppIcon, tint: Color,
                           makeURL: @escaping () throws -> URL) -> some View
    {
        if let url = try? makeURL() {
            ShareLink(item: url) {
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
                        Image(appIcon: .forward).lumeIcon(14, weight: .semibold).foregroundStyle(LumeColor.muted)
                    }
                }
            }.buttonStyle(.lumePress)
        }
    }

    // MARK: Génération des fichiers (dans le dossier temporaire)

    private func foodCSVURL() throws -> URL {
        try write(DataExporter.foodCSV(foods), to: "lume-journal.csv")
    }

    private func weightCSVURL() throws -> URL {
        try write(DataExporter.weightCSV(weights), to: "lume-poids.csv")
    }

    private func backupJSONURL() throws -> URL {
        let data = try DataExporter.backupJSON(profile: profiles.first, foods: foods,
                                               weights: weights, favorites: favorites, sessions: sessions)
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
