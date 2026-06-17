import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case server(String)
    case decoding(String)
    case unauthorized
    case network(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid request."
        case .server(let m): return m
        case .decoding(let m): return "Could not read the server response. \(m)"
        case .unauthorized: return "Please sign in to continue."
        case .network(let m): return m
        }
    }
}

/// Thin async/await wrapper around the Potluck REST API.
final class APIClient {
    static let shared = APIClient()

    let baseURL = URL(string: "https://api.potluckhub.io/api/v1")!
    private let session: URLSession

    /// Set by AuthManager whenever the access token changes.
    var accessToken: String?

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        config.waitsForConnectivity = true
        // Always hit the live marketplace — never serve a stale cached response. A chef's
        // newly published menu / updated availability must appear on the app immediately.
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        config.urlCache = nil
        self.session = URLSession(configuration: config)
    }

    // MARK: Request building

    private func makeRequest(
        _ method: String,
        path: String,
        query: [URLQueryItem] = [],
        body: Encodable? = nil,
        authenticated: Bool = false
    ) throws -> URLRequest {
        var components = URLComponents(
            url: baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        )
        if !query.isEmpty { components?.queryItems = query }
        guard let url = components?.url else { throw APIError.invalidURL }

        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        if let body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONEncoder().encode(AnyEncodable(body))
        }
        if authenticated, let token = accessToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return req
    }

    // MARK: Core send

    @discardableResult
    func send<T: Decodable>(
        _ method: String,
        _ path: String,
        query: [URLQueryItem] = [],
        body: Encodable? = nil,
        authenticated: Bool = false,
        as type: T.Type = T.self
    ) async throws -> T {
        let request = try makeRequest(method, path: path, query: query, body: body, authenticated: authenticated)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.network("Network error. Check your connection and try again.")
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.network("No response from server.")
        }

        if http.statusCode == 401 { throw APIError.unauthorized }

        let decoder = JSONDecoder()
        do {
            let envelope = try decoder.decode(APIEnvelope<T>.self, from: data)
            if envelope.success, let value = envelope.data {
                return value
            }
            let message = envelope.error?.message ?? "Something went wrong (\(http.statusCode))."
            throw APIError.server(message)
        } catch let apiErr as APIError {
            throw apiErr
        } catch {
            if (200..<300).contains(http.statusCode) {
                throw APIError.decoding(String(describing: error))
            }
            throw APIError.server("Request failed (\(http.statusCode)).")
        }
    }
}

/// Type-erasing wrapper so callers can pass any Encodable as a request body.
struct AnyEncodable: Encodable {
    private let encodeFunc: (Encoder) throws -> Void
    init(_ wrapped: Encodable) { self.encodeFunc = wrapped.encode }
    func encode(to encoder: Encoder) throws { try encodeFunc(encoder) }
}
