import Foundation

/// Ag katmani, test edilebilmesi icin soyutlandi.
public protocol LocalizationTransport: Sendable {
    func get(_ url: URL) async throws -> (Data, HTTPURLResponse)
}

/// Varsayilan tasima: URLSession.
public struct URLSessionTransport: LocalizationTransport {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func get(_ url: URL) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(Copydeck.userAgent, forHTTPHeaderField: "User-Agent")
        // Paket icerigi degismez oldugu icin ara katman cache'i sorun degil,
        // ama manifest her zaman taze olmali.
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw LocalizationError.httpStatus(-1)
        }

        return (data, http)
    }
}

/// Yalnizca ag. Cache, dogrulama ve karar verme burada degil.
struct LocalizationClient: Sendable {
    let baseURL: URL
    let projectKey: String
    let transport: LocalizationTransport

    private var decoder: JSONDecoder { JSONDecoder() }

    func fetchManifest() async throws -> LocalizationManifest {
        let url = baseURL
            .appendingPathComponent("api/sdk/v1/projects")
            .appendingPathComponent(projectKey)
            .appendingPathComponent("manifest")

        let (data, response) = try await transport.get(url)

        guard response.statusCode == 200 else {
            throw LocalizationError.httpStatus(response.statusCode)
        }

        do {
            return try decoder.decode(LocalizationManifest.self, from: data)
        } catch {
            throw LocalizationError.decodingFailed
        }
    }

    /// Test Mode oturumunun hali.
    ///
    /// Token burada kimlik yerine geciyor: sahadaki cihazin kullanicisi yok,
    /// elinde yalnizca QR'dan okudugu deger var. Token yalnizca taslak
    /// okumaya yariyor, hicbir seyi degistiremiyor.
    func fetchPreview(token: String) async throws -> PreviewState {
        let url = baseURL
            .appendingPathComponent("api/sdk/v1/preview")
            .appendingPathComponent(token)

        let (data, response) = try await transport.get(url)

        guard response.statusCode == 200 else {
            throw LocalizationError.httpStatus(response.statusCode)
        }

        do {
            return try decoder.decode(PreviewState.self, from: data)
        } catch {
            throw LocalizationError.decodingFailed
        }
    }

    func fetchBundle(release: Int, locale: String) async throws -> LocalizationBundle {
        let url = baseURL
            .appendingPathComponent("api/sdk/v1/projects")
            .appendingPathComponent(projectKey)
            .appendingPathComponent("releases")
            .appendingPathComponent(String(release))
            .appendingPathComponent(locale)

        let (data, response) = try await transport.get(url)

        guard response.statusCode == 200 else {
            throw LocalizationError.httpStatus(response.statusCode)
        }

        do {
            return try decoder.decode(LocalizationBundle.self, from: data)
        } catch {
            throw LocalizationError.decodingFailed
        }
    }
}
