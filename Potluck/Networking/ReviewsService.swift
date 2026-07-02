import Foundation

// MARK: - Website review models
// Reviews are served by the potluckhub.io website (same origin as checkout, NOT the
// api subdomain) and return plain JSON objects — no {success, data} envelope.

/// A single review as returned by the website reviews API.
struct WebReview: Decodable, Identifiable, Hashable {
    let id: String
    let authorName: String
    let rating: Int
    let title: String?
    let body: String
    let createdAt: String?
    let verifiedBooking: Bool?

    /// Adapts a website review into the app's `Review` model so it renders
    /// through the existing `ReviewCard` UI unchanged.
    var asReview: Review {
        let parts = authorName.split(separator: " ", maxSplits: 1)
        let first = parts.first.map(String.init) ?? authorName
        let last = parts.count > 1 ? String(parts[1]) : ""
        return Review(
            id: id,
            rating: rating,
            title: title,
            comment: body,
            chefResponse: nil,
            createdAt: createdAt,
            customer: ReviewUser(id: id, firstName: first, lastName: last, avatarUrl: nil),
            menu: nil
        )
    }
}

/// GET /api/reviews?chefId={id} response.
struct ReviewsResponse: Decodable {
    let reviews: [WebReview]
    let total: Int
    let average: Double
}

/// POST /api/reviews request body.
struct CreateReviewRequest: Encodable {
    let chefId: String
    let authorName: String
    let authorEmail: String?
    let rating: Int
    let title: String?
    let body: String
    let platform: String        // always "ios"
}

/// POST /api/reviews 201 response — the created review.
struct CreateReviewResponse: Decodable {
    let review: WebReview
}

/// Non-2xx review responses carry {"error": "message"}.
private struct ReviewsErrorBody: Decodable {
    let error: String?
}

// MARK: - Service

/// Client for the website reviews API. No auth header is needed for these endpoints.
enum ReviewsService {
    /// Reviews live on the marketing/web app, not api.potluckhub.io —
    /// same base as `CheckoutService.checkoutBase`.
    static let reviewsBase = CheckoutService.checkoutBase

    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        config.waitsForConnectivity = true
        // Freshly submitted reviews must show up immediately — never cache.
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        config.urlCache = nil
        return URLSession(configuration: config)
    }()

    /// Fetches all reviews for a chef, plus the total count and average rating.
    static func reviews(chefId: String) async throws -> ReviewsResponse {
        var components = URLComponents(
            url: reviewsBase.appendingPathComponent("reviews"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [URLQueryItem(name: "chefId", value: chefId)]
        var req = URLRequest(url: components.url!)
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        return try await send(req)
    }

    /// Submits a new review; returns the created review on 201.
    static func submit(_ body: CreateReviewRequest) async throws -> WebReview {
        var req = URLRequest(url: reviewsBase.appendingPathComponent("reviews"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.httpBody = try JSONEncoder().encode(body)
        let response: CreateReviewResponse = try await send(req)
        return response.review
    }

    private static func send<T: Decodable>(_ request: URLRequest) async throws -> T {
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
        guard (200..<300).contains(http.statusCode) else {
            let message = (try? JSONDecoder().decode(ReviewsErrorBody.self, from: data))?.error
            throw APIError.server(message ?? "Request failed (\(http.statusCode)).")
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decoding(String(describing: error))
        }
    }
}
