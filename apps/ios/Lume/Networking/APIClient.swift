import Foundation
import SwiftUI
import UIKit

extension Macros {
    /// Mise à l'échelle (ex. depuis des valeurs pour 100 g).
    func scaled(_ f: Double) -> Macros {
        func r(_ n: Int) -> Int {
            Int((Double(n) * f).rounded())
        }
        return Macros(kcal: r(kcal), protein: r(protein), carbs: r(carbs), fat: r(fat))
    }
}

/// Produit résolu via code-barres ou recherche (macros pour 100 g).
struct ScannedProduct: Identifiable, Equatable {
    var name: String
    var code: String
    var source: String
    var per100g: Macros
    var id: String {
        "\(code)|\(name)"
    }

    static let sample = ScannedProduct(name: "Muesli croustillant", code: "3017620422003",
                                       source: "OpenFoodFacts",
                                       per100g: Macros(kcal: 450, protein: 8, carbs: 62, fat: 11))
}

enum APIError: LocalizedError {
    case badURL, http(Int), decoding, unauthorized, offline

    var errorDescription: String? {
        switch self {
        case .badURL: "Configuration de l'app invalide."
        case .unauthorized: "Accès refusé par le serveur."
        case .offline: "Pas de connexion internet."
        case let .http(c) where c == 429: "Trop de requêtes. Réessaie dans un instant."
        case let .http(c) where (400 ..< 500).contains(c): "Requête invalide."
        case .http: "Le serveur est momentanément indisponible."
        case .decoding: "Réponse du serveur illisible."
        }
    }

    /// Une nouvelle tentative a-t-elle du sens ? (non sur une erreur client 4xx définitive).
    var isRetriable: Bool {
        switch self {
        case .offline: true
        case let .http(c): c >= 500 || c == 429 || c < 0
        case .badURL, .unauthorized, .decoding: false
        }
    }
}

/// Résultat d'une analyse photo : aliments détectés + nom du plat global (si reconnu).
struct AnalyzedMeal {
    var dish: String?
    var items: [FoodItem]
    /// Vrai si le serveur a renvoyé un repas de démonstration (vision indisponible côté backend)
    /// plutôt qu'une vraie analyse. L'UI doit le signaler avant d'enregistrer ces macros.
    var degraded: Bool = false
}

/// Abstraction réseau injectable (permet un faux client en tests/preview).
protocol FoodAPI {
    func analyze(imageData: Data) async throws -> AnalyzedMeal
    func barcode(_ code: String) async throws -> ScannedProduct?
    func search(_ q: String) async throws -> [ScannedProduct]
}

/// Client HTTP de l'API Lume (bearer statique).
struct APIClient: FoodAPI {
    static let shared = APIClient()

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        // L'analyse vision (Claude + image) peut être lente : laisser de la marge.
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 90
        return URLSession(configuration: config)
    }()

    // MARK: DTOs

    private struct MacrosDTO: Decodable {
        let kcal: Int; let protein: Int; let carbs: Int; let fat: Int
        var model: Macros {
            Macros(kcal: kcal, protein: protein, carbs: carbs, fat: fat)
        }
    }

    private struct AnalyzedItemDTO: Decodable {
        let name: String; let grams: Int; let macros: MacrosDTO
        /// Base exacte pour 100 g renvoyée par le serveur (`null` si aliment non trouvé).
        let per100g: MacrosDTO?
        let matched: Bool?
        let confidence: Double?
    }

    private struct AnalyzeResponse: Decodable { let dish: String?; let items: [AnalyzedItemDTO]; let degraded: Bool? }
    private struct FoodDTO: Decodable { let name: String; let per100g: MacrosDTO; let source: String; let barcode: String? }
    private struct BarcodeResponse: Decodable { let product: FoodDTO? }
    private struct SearchResponse: Decodable { let results: [FoodDTO] }

    // MARK: Plomberie

    private func makeRequest(_ path: String, method: String = "GET", body: Data? = nil) throws -> URLRequest {
        guard let url = URL(string: "\(LumeConfig.apiBaseURL)/\(path)") else { throw APIError.badURL }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("Bearer \(LumeConfig.apiToken)", forHTTPHeaderField: "Authorization")
        if let body {
            req.httpBody = body
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return req
    }

    private func send<T: Decodable>(_ req: URLRequest, as _: T.Type) async throws -> T {
        let data: Data, resp: URLResponse
        do {
            (data, resp) = try await session.data(for: req)
        } catch let err as URLError where err.code == .notConnectedToInternet || err.code == .networkConnectionLost {
            throw APIError.offline
        }
        guard let http = resp as? HTTPURLResponse else { throw APIError.http(-1) }
        if http.statusCode == 401 { throw APIError.unauthorized }
        guard (200 ..< 300).contains(http.statusCode) else { throw APIError.http(http.statusCode) }
        do { return try JSONDecoder().decode(T.self, from: data) }
        catch { throw APIError.decoding }
    }

    // MARK: Endpoints

    private struct ChallengeResponse: Decodable { let challenge: String }

    /// GET /attest/challenge — challenge App Attest à usage unique (utilisé seulement si App Attest actif).
    private func fetchChallenge() async throws -> String {
        let req = try makeRequest("attest/challenge")
        return try await send(req, as: ChallengeResponse.self).challenge
    }

    /// POST /analyze — image base64 → repas analysé (nom du plat + aliments, macros déterministes côté serveur).
    func analyze(imageData: Data) async throws -> AnalyzedMeal {
        // Redimensionne avant envoi : upload + analyse Claude bien plus rapides, précision conservée.
        let payload = Self.downscaledJPEG(imageData) ?? imageData
        // Data URL complète : le serveur (et Claude vision) attend le préfixe data:image/jpeg;base64,
        let dataURL = "data:image/jpeg;base64,\(payload.base64EncodedString())"
        let body = try JSONSerialization.data(withJSONObject: ["image": dataURL])
        var req = try makeRequest("analyze", method: "POST", body: body)
        // App Attest (si actif) : prouve que l'appel vient d'une vraie instance de l'app. Inactif par
        // défaut (simulateur / compte gratuit) → en-têtes vides, requête inchangée.
        let attestHeaders = await AppAttestManager.attestationHeaders { try await self.fetchChallenge() }
        for (k, v) in attestHeaders {
            req.setValue(v, forHTTPHeaderField: k)
        }
        let res = try await send(req, as: AnalyzeResponse.self)
        let items = res.items.map { FoodItem(name: $0.name, grams: $0.grams, macros: $0.macros.model,
                                             per100g: $0.per100g?.model,
                                             matched: $0.matched ?? true, confidence: $0.confidence ?? 1) }
        return AnalyzedMeal(dish: res.dish, items: items, degraded: res.degraded ?? false)
    }

    /// Réduit l'image à ~1024 px de côté max et la recompresse en JPEG (≈ quelques centaines de Ko).
    private static func downscaledJPEG(_ data: Data, maxSide: CGFloat = 1024) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let longest = max(image.size.width, image.size.height)
        let scale = longest > maxSide ? maxSide / longest : 1
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resized.jpegData(compressionQuality: 0.7)
    }

    /// GET /foods/barcode/:code
    func barcode(_ code: String) async throws -> ScannedProduct? {
        let req = try makeRequest("foods/barcode/\(code)")
        let res = try await send(req, as: BarcodeResponse.self)
        guard let p = res.product else { return nil }
        return ScannedProduct(name: p.name, code: p.barcode ?? code, source: p.source, per100g: p.per100g.model)
    }

    /// GET /foods/search?q=
    func search(_ q: String) async throws -> [ScannedProduct] {
        let escaped = q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? q
        let req = try makeRequest("foods/search?q=\(escaped)")
        let res = try await send(req, as: SearchResponse.self)
        return res.results.map { ScannedProduct(name: $0.name, code: $0.barcode ?? "", source: $0.source, per100g: $0.per100g.model) }
    }
}

// MARK: - Injection via l'environnement

private struct FoodAPIKey: EnvironmentKey {
    static let defaultValue: any FoodAPI = APIClient.shared
}

extension EnvironmentValues {
    var foodAPI: any FoodAPI {
        get { self[FoodAPIKey.self] }
        set { self[FoodAPIKey.self] = newValue }
    }
}
