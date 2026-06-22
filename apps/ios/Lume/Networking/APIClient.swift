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
    case badURL, http(Int), decoding, unauthorized
    var errorDescription: String? {
        switch self {
        case .badURL: "URL invalide."
        case .unauthorized: "Jeton invalide (401)."
        case let .http(c): "Erreur serveur (\(c))."
        case .decoding: "Réponse illisible."
        }
    }
}

/// Abstraction réseau injectable (permet un faux client en tests/preview).
protocol FoodAPI {
    func analyze(imageData: Data) async throws -> [FoodItem]
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
        let matched: Bool?
        let confidence: Double?
    }

    private struct AnalyzeResponse: Decodable { let items: [AnalyzedItemDTO] }
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
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw APIError.http(-1) }
        if http.statusCode == 401 { throw APIError.unauthorized }
        guard (200 ..< 300).contains(http.statusCode) else { throw APIError.http(http.statusCode) }
        do { return try JSONDecoder().decode(T.self, from: data) }
        catch { throw APIError.decoding }
    }

    // MARK: Endpoints

    /// POST /analyze — image base64 → aliments détectés (macros déterministes côté serveur).
    func analyze(imageData: Data) async throws -> [FoodItem] {
        // Redimensionne avant envoi : upload + analyse Claude bien plus rapides, précision conservée.
        let payload = Self.downscaledJPEG(imageData) ?? imageData
        let body = try JSONSerialization.data(withJSONObject: ["image": payload.base64EncodedString()])
        let req = try makeRequest("analyze", method: "POST", body: body)
        let res = try await send(req, as: AnalyzeResponse.self)
        return res.items.map { FoodItem(name: $0.name, grams: $0.grams, macros: $0.macros.model,
                                        matched: $0.matched ?? true, confidence: $0.confidence ?? 1) }
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
