import CryptoKit
import Foundation
#if canImport(DeviceCheck)
    import DeviceCheck
#endif

/// Pont App Attest : prouve au backend que l'appel vient d'une vraie instance de l'app (clé
/// Secure Enclave), pour que le jeton API extrait du binaire ne suffise pas à taper `/analyze`.
///
/// **Gaté** : actif uniquement si l'appareil le supporte (`isSupported`, faux au simulateur) ET si le
/// flag de compilation `APP_ATTEST_ENABLED` est posé (nécessite un compte Apple Developer payant +
/// la capability App Attest). Sinon, `attestationHeaders()` renvoie `[:]` → le `/analyze` part comme
/// avant, sans en-tête d'attestation. Le serveur, lui aussi gaté par flag, laisse alors passer.
@MainActor
enum AppAttestManager {
    /// Clé `@AppStorage`-able : le keyId généré une fois par installation (persisté).
    private static let keyIdDefaultsKey = "lume.appAttest.keyId"

    /// Vrai si App Attest est réellement utilisable ici (device compatible + flag activé).
    static var isActive: Bool {
        #if APP_ATTEST_ENABLED && canImport(DeviceCheck)
            return DCAppAttestService.shared.isSupported
        #else
            return false
        #endif
    }

    /// En-têtes d'attestation à joindre à `/analyze`. Vide si App Attest est inactif (cas par défaut).
    /// - Parameter challengeProvider: récupère un challenge à usage unique auprès du serveur.
    static func attestationHeaders(challengeProvider: () async throws -> String) async -> [String: String] {
        guard isActive else { return [:] }
        #if APP_ATTEST_ENABLED && canImport(DeviceCheck)
            do {
                let challenge = try await challengeProvider()
                let keyId = try await ensureKey()
                let service = DCAppAttestService.shared
                // L'attestation signe le hash du challenge (clientDataHash). Le serveur vérifie
                // nonce = SHA-256(authData ‖ SHA-256(challenge)) (cf. AppAttestGuard côté serveur).
                guard let challengeData = challenge.data(using: .utf8) else { return [:] }
                let hash = Data(SHA256.hash(data: challengeData))
                let attestation = try await service.attestKey(keyId, clientDataHash: hash)
                return [
                    "X-App-Attest-Challenge": challenge,
                    "X-App-Attest-Object": attestation.base64EncodedString(),
                    "X-App-Attest-KeyId": keyId,
                ]
            } catch {
                // Échec d'attestation : on n'ajoute pas d'en-tête. Le serveur (flag ON) refusera —
                // c'est volontaire (pas d'attestation valide = pas d'accès), mais on ne crashe pas.
                #if DEBUG
                    print("App Attest échec : \(error)")
                #endif
                return [:]
            }
        #else
            return [:]
        #endif
    }

    #if APP_ATTEST_ENABLED && canImport(DeviceCheck)
        /// Récupère le keyId persisté ou en génère un nouveau (première installation).
        private static func ensureKey() async throws -> String {
            if let existing = UserDefaults.standard.string(forKey: keyIdDefaultsKey) { return existing }
            let keyId = try await DCAppAttestService.shared.generateKey()
            UserDefaults.standard.set(keyId, forKey: keyIdDefaultsKey)
            return keyId
        }
    #endif
}
