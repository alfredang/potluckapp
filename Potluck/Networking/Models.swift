import Foundation

// MARK: - Response envelopes

struct APIEnvelope<T: Decodable>: Decodable {
    let success: Bool
    let data: T?
    let error: APIErrorBody?
    let pagination: Pagination?
}

struct APIErrorBody: Decodable {
    let code: String?
    let message: String?
}

struct Pagination: Decodable {
    let page: Int
    let limit: Int
    let total: Int
    let totalPages: Int
    let hasMore: Bool
}

/// Decodes a numeric value that the API may send as either a String ("4.91")
/// or a JSON number (4.91) — the Potluck API is inconsistent between the two.
struct FlexNumber: Decodable, Hashable {
    let value: Double
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let d = try? c.decode(Double.self) { value = d }
        else if let s = try? c.decode(String.self) { value = Double(s) ?? 0 }
        else { value = 0 }
    }
}

// MARK: - Domain models

struct ChefUser: Decodable, Hashable {
    let id: String
    let firstName: String
    let lastName: String
    let avatarUrl: String?

    var fullName: String { "\(firstName) \(lastName)" }
}

struct Chef: Decodable, Identifiable, Hashable {
    let id: String
    let userId: String?
    let bio: String?
    let specialties: [String]?
    let city: String?
    let postalCode: String?
    let country: String?
    let instagramUrl: String?
    let facebookUrl: String?
    let tiktokUrl: String?
    let websiteUrl: String?
    let averageRating: FlexNumber?
    let totalReviews: Int?
    let isVerified: Bool?
    let isAvailable: Bool?
    let user: ChefUser
    let menus: [Menu]?

    var rating: Double { averageRating?.value ?? 0 }
    var reviewCount: Int { totalReviews ?? 0 }
    var displaySpecialties: [String] { specialties ?? [] }
}

struct Category: Decodable, Hashable {
    let id: String
    let name: String
    let slug: String?
}

struct MenuChef: Decodable, Hashable {
    let id: String
    let averageRating: FlexNumber?
    let totalReviews: Int?
    let isVerified: Bool?
    let user: ChefUser?
}

struct Menu: Decodable, Identifiable, Hashable {
    let id: String
    let chefId: String?
    let name: String
    let description: String?
    let price: Int
    let currency: String?
    let images: [String]?
    let isVegetarian: Bool?
    let isVegan: Bool?
    let isGlutenFree: Bool?
    let allergens: [String]?
    let servingSize: String?
    let preparationTime: Int?
    let averageRating: FlexNumber?
    let category: Category?
    let chef: MenuChef?

    var firstImage: String? { images?.first }
    var rating: Double { averageRating?.value ?? 0 }
    /// Price is stored in cents.
    var displayPrice: String { Money.format(price, currency: currency ?? "SGD") }
    var dietaryTags: [String] {
        var t: [String] = []
        if isVegetarian == true { t.append("Vegetarian") }
        if isVegan == true { t.append("Vegan") }
        if isGlutenFree == true { t.append("Gluten-Free") }
        return t
    }
}

struct ReviewUser: Decodable, Hashable {
    let id: String
    let firstName: String
    let lastName: String
    let avatarUrl: String?
    var fullName: String { "\(firstName) \(lastName)" }
}

struct ReviewMenu: Decodable, Hashable {
    let id: String
    let name: String
}

struct Review: Decodable, Identifiable, Hashable {
    let id: String
    let rating: Int
    let title: String?
    let comment: String?
    let chefResponse: String?
    let createdAt: String?
    let customer: ReviewUser?
    let menu: ReviewMenu?
}

struct AvailabilitySlot: Decodable, Identifiable, Hashable {
    let id: String
    let chefId: String?
    let date: String
    let startTime: String
    let endTime: String
    let maxBookings: Int?
    let currentBookings: Int?
    let isAvailable: Bool?

    var hasCapacity: Bool {
        (isAvailable ?? true) && (currentBookings ?? 0) < (maxBookings ?? 1)
    }
}

// MARK: - Auth

struct User: Decodable, Identifiable, Hashable {
    let id: String
    let email: String
    let firstName: String
    let lastName: String
    let role: String
    let avatarUrl: String?
    let phone: String?

    var fullName: String { "\(firstName) \(lastName)" }
    var initials: String {
        let f = firstName.first.map(String.init) ?? ""
        let l = lastName.first.map(String.init) ?? ""
        return (f + l).uppercased()
    }
}

struct AuthResult: Decodable {
    let user: User
    let accessToken: String
    let refreshToken: String
}

// MARK: - Booking

struct Booking: Decodable, Identifiable, Hashable {
    let id: String
    let bookingNumber: String?
    let chefId: String?
    let menuId: String?
    let scheduledDate: String?
    let scheduledTime: String?
    let guestCount: Int?
    let total: Int?
    let status: String?
    let createdAt: String?
}

// MARK: - Helpers

enum Money {
    static func format(_ cents: Int, currency: String = "SGD") -> String {
        let amount = Double(cents) / 100.0
        let symbol = currency == "SGD" ? "S$" : "$"
        return symbol + String(format: "%.2f", amount)
    }
}
