import Foundation

// MARK: - Checkout models
// The checkout backend is the potluckhub.io website (NOT the api subdomain) and
// returns plain JSON objects — no {success, data} envelope.

/// Payment providers offered at checkout.
enum CheckoutProvider: String, CaseIterable, Identifiable, Codable {
    case stripe, paypal, hitpay

    var id: String { rawValue }

    var title: String {
        switch self {
        case .stripe: return "Credit / Debit Card"
        case .paypal: return "PayPal"
        case .hitpay: return "PayNow / Card"
        }
    }

    var subtitle: String? {
        switch self {
        case .stripe: return "Powered by Stripe"
        case .paypal: return "Pay with your PayPal account"
        case .hitpay: return "Powered by HitPay"
        }
    }

    var systemImage: String {
        switch self {
        case .stripe: return "creditcard"
        case .paypal: return "p.circle"
        case .hitpay: return "qrcode"
        }
    }
}

/// POST /api/checkout request body.
struct CheckoutRequest: Codable {
    let menuId: String
    let guests: Int
    let scheduledDate: String   // "YYYY-MM-DD"
    let scheduledTime: String   // "HH:mm"
    let specialRequests: String?
    let customerName: String
    let customerEmail: String
    let customerPhone: String?
    let provider: String        // "stripe" | "paypal" | "hitpay"
    let platform: String        // always "ios"
}

/// Amounts are integer cents (SGD), same convention as `Menu.price`.
struct CheckoutAmount: Codable, Hashable {
    let subtotal: Int
    let platformFee: Int
    let total: Int
    let currency: String
}

/// POST /api/checkout response — the created order plus the hosted-payment redirect.
struct CheckoutOrder: Codable, Hashable {
    let orderId: String
    let orderNumber: String
    let amount: CheckoutAmount
    let redirectUrl: String
}

/// GET /api/checkout/{orderId} response — live payment status for polling.
struct OrderStatus: Codable, Hashable {
    let orderId: String
    let orderNumber: String
    let status: String          // pending_payment | paid | failed | cancelled
    let provider: String?
    let total: Int?
    let currency: String?
    let menuName: String?
    let chefName: String?
    let scheduledDate: String?
    let scheduledTime: String?
    let guests: Int?
    let paidAt: String?

    var isPaid: Bool { status == "paid" }
    var isFailed: Bool { status == "failed" }
    var isCancelled: Bool { status == "cancelled" }
}

/// Non-2xx checkout responses carry {"error": "message"}.
private struct CheckoutErrorBody: Decodable {
    let error: String?
}

// MARK: - Service

/// Client for the website checkout API. No auth header is needed for these endpoints.
enum CheckoutService {
    /// Checkout lives on the marketing/web app, not api.potluckhub.io.
    static let checkoutBase = URL(string: "https://potluckhub.io/api")!

    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        config.waitsForConnectivity = true
        // Payment status must always be live — never cached.
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        config.urlCache = nil
        return URLSession(configuration: config)
    }()

    /// Creates a pending order and returns the hosted-payment redirect URL.
    static func createOrder(_ body: CheckoutRequest) async throws -> CheckoutOrder {
        var req = URLRequest(url: checkoutBase.appendingPathComponent("checkout"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.httpBody = try JSONEncoder().encode(body)
        return try await send(req)
    }

    /// Fetches the current payment status for an order (used for polling).
    static func orderStatus(orderId: String) async throws -> OrderStatus {
        var req = URLRequest(url: checkoutBase.appendingPathComponent("checkout/\(orderId)"))
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        return try await send(req)
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
            let message = (try? JSONDecoder().decode(CheckoutErrorBody.self, from: data))?.error
            throw APIError.server(message ?? "Checkout failed (\(http.statusCode)).")
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decoding(String(describing: error))
        }
    }
}

// MARK: - Deep-link return

extension Notification.Name {
    /// Posted by PotluckApp when the app is reopened via
    /// potluck://checkout/result?order={orderId}&status={status}.
    static let potluckCheckoutReturn = Notification.Name("potluckCheckoutReturn")
}
