import SwiftUI

/// Écran « Confidentialité & conditions » : politique de confidentialité + conditions d'utilisation,
/// lisibles hors ligne (aucune dépendance réseau). Obligatoire pour une app santé qui accède à la
/// caméra et envoie une photo à un service tiers ; complète l'URL déclarée dans App Store Connect.
struct LegalView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var section: Section = .privacy

    private enum Section: Hashable { case privacy, terms }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $section) {
                Text("Confidentialité").tag(Section.privacy)
                Text("Conditions").tag(Section.terms)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, Spacing.xl)
            .padding(.bottom, Spacing.sm)

            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    switch section {
                    case .privacy: privacyContent
                    case .terms: termsContent
                    }
                }
                .padding(.horizontal, Spacing.xl)
                .padding(.bottom, Spacing.xxl)
            }
        }
        .background(LumeColor.cream.ignoresSafeArea())
        .safeAreaInset(edge: .top) {
            TopBar(title: "Confidentialité & conditions", leading: .close, onLeading: { dismiss() })
                .padding(.horizontal, Spacing.xl).padding(.vertical, Spacing.sm).background(LumeColor.cream)
        }
    }

    // MARK: Confidentialité

    private var privacyContent: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            para("Lume respecte ta vie privée. Cette politique explique quelles données l'app traite, comment, et tes droits.")

            head("Données qui restent sur ton appareil")
            para("Ton journal alimentaire, ton poids, tes séances, ton budget, ton profil et tes réglages sont enregistrés localement sur ton appareil (et, si tu l'actives, synchronisés via ton compte iCloud privé). Nous n'y avons pas accès.")

            head("Photos de repas")
            para("Quand tu analyses un repas par photo, l'image est envoyée à notre service pour reconnaître les aliments. La reconnaissance s'appuie sur un fournisseur d'IA tiers (Anthropic). L'image sert uniquement à cette analyse et n'est pas utilisée pour t'identifier ni à des fins publicitaires.")

            head("Données de santé (Apple Santé)")
            para("Avec ton autorisation, Lume lit ton poids et ton activité, et écrit tes repas, ton eau et tes séances dans Apple Santé. Ces données restent sur ton appareil / dans Apple Santé et ne sont jamais envoyées à nos serveurs.")

            head("Aucun pistage")
            para("Lume ne contient ni publicité, ni traceur, ni SDK d'analyse tiers. Nous ne vendons aucune donnée et ne te suivons pas entre les apps.")

            head("Tes droits")
            para("Tu peux exporter toutes tes données (Profil → Exporter mes données) et tout effacer à tout moment (Profil → Effacer mes données). La suppression est définitive et inclut les données écrites dans Apple Santé.")

            head("Contact")
            para("Pour toute question sur tes données : \(LegalView.contactEmail).")
        }
    }

    // MARK: Conditions

    private var termsContent: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            para("En utilisant Lume, tu acceptes les conditions ci-dessous.")

            head("Usage informatif, pas un avis médical")
            para("Lume fournit des estimations de calories, de macronutriments et d'objectifs à titre informatif et de bien-être. Elles ne constituent pas un avis médical, un diagnostic ni un traitement. Consulte un professionnel de santé avant tout changement important d'alimentation, d'activité ou de poids, surtout en cas de condition médicale, de grossesse ou de trouble alimentaire.")

            head("Fiabilité de l'analyse par IA")
            para("La reconnaissance des aliments et l'estimation des portions reposent sur une IA qui peut se tromper. Vérifie et corrige toujours les valeurs proposées avant de les enregistrer. Tu restes responsable de l'exactitude de ton journal.")

            head("Tes responsabilités")
            para("Tu t'engages à utiliser l'app pour ton usage personnel et à fournir des informations exactes pour le calcul de tes objectifs.")

            head("Limitation de responsabilité")
            para("Lume est fourni « en l'état », sans garantie d'exactitude des estimations. Dans les limites permises par la loi, nous déclinons toute responsabilité pour les décisions prises sur la base des informations de l'app.")

            head("Évolution des conditions")
            para("Ces conditions peuvent évoluer avec les mises à jour de l'app. La version en vigueur est celle présentée ici.")
        }
    }

    // MARK: Helpers de mise en page

    private func head(_ t: LocalizedStringKey) -> some View {
        Text(t).font(.lumeHeadline).foregroundStyle(LumeColor.ink)
    }

    private func para(_ t: LocalizedStringKey) -> some View {
        Text(t).font(.lumeSubhead).foregroundStyle(LumeColor.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Adresse de contact (alignée sur celle du support dans le Profil).
    static let contactEmail = "ewen@favikon.com"
}

#Preview { LegalView() }
