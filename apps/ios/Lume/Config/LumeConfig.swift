import Foundation

/// Configuration runtime de l'app. Surchargeable via clés Info.plist
/// (`LUME_API_BASE_URL`, `LUME_API_TOKEN`) pour ne pas committer d'URL/jeton.
enum LumeConfig {
    /// URL de base de l'API (sans slash final).
    static var apiBaseURL: String {
        let raw = (Bundle.main.object(forInfoDictionaryKey: "LUME_API_BASE_URL") as? String)
            ?? "http://localhost:3000"
        return raw.hasSuffix("/") ? String(raw.dropLast()) : raw
    }

    /// Jeton Bearer attendu par le serveur (doit matcher API_TOKEN côté NestJS).
    static var apiToken: String {
        (Bundle.main.object(forInfoDictionaryKey: "LUME_API_TOKEN") as? String) ?? "change-me"
    }
}
