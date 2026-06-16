import Foundation

/// High-level API calls mapped to Potluck endpoints.
enum PotluckService {
    private static var api: APIClient { .shared }

    // Chefs
    static func featuredChefs() async throws -> [Chef] {
        try await api.send("GET", "chefs/featured", as: [Chef].self)
    }

    static func chefs(search: String? = nil, category: String? = nil, page: Int = 1) async throws -> [Chef] {
        var q: [URLQueryItem] = [.init(name: "page", value: String(page)), .init(name: "limit", value: "20")]
        if let search, !search.isEmpty { q.append(.init(name: "search", value: search)) }
        if let category, !category.isEmpty { q.append(.init(name: "category", value: category)) }
        return try await api.send("GET", "chefs", query: q, as: [Chef].self)
    }

    static func chef(id: String) async throws -> Chef {
        try await api.send("GET", "chefs/\(id)", as: Chef.self)
    }

    static func chefReviews(chefId: String) async throws -> [Review] {
        try await api.send("GET", "reviews/chef/\(chefId)", as: [Review].self)
    }

    static func chefAvailability(chefId: String) async throws -> [AvailabilitySlot] {
        try await api.send("GET", "chefs/\(chefId)/availability", as: [AvailabilitySlot].self)
    }

    // Menus
    static func featuredMenus() async throws -> [Menu] {
        try await api.send("GET", "menus/featured", as: [Menu].self)
    }

    static func menus(search: String? = nil, category: String? = nil, page: Int = 1) async throws -> [Menu] {
        var q: [URLQueryItem] = [.init(name: "page", value: String(page)), .init(name: "limit", value: "20")]
        if let search, !search.isEmpty { q.append(.init(name: "search", value: search)) }
        if let category, !category.isEmpty { q.append(.init(name: "category", value: category)) }
        return try await api.send("GET", "menus", query: q, as: [Menu].self)
    }

    static func menu(id: String) async throws -> Menu {
        try await api.send("GET", "menus/\(id)", as: Menu.self)
    }

    // Auth
    static func login(email: String, password: String) async throws -> AuthResult {
        struct Body: Encodable { let email: String; let password: String }
        return try await api.send("POST", "auth/login", body: Body(email: email, password: password), as: AuthResult.self)
    }

    static func register(email: String, password: String, firstName: String, lastName: String) async throws -> AuthResult {
        struct Body: Encodable {
            let email: String; let password: String
            let firstName: String; let lastName: String; let role: String
        }
        return try await api.send(
            "POST", "auth/register",
            body: Body(email: email, password: password, firstName: firstName, lastName: lastName, role: "customer"),
            as: AuthResult.self
        )
    }

    static func me() async throws -> User {
        try await api.send("GET", "auth/me", authenticated: true, as: User.self)
    }

    /// Permanently deletes the signed-in user's account (App Store Guideline 5.1.1(v)).
    static func deleteAccount() async throws {
        struct Empty: Decodable {}
        _ = try await api.send("DELETE", "auth/account", authenticated: true, as: Empty.self)
    }

    // Bookings
    static func myBookings() async throws -> [Booking] {
        try await api.send("GET", "bookings", authenticated: true, as: [Booking].self)
    }
}
