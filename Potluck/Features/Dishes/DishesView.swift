import SwiftUI

@MainActor
final class DishesModel: ObservableObject {
    @Published var menus: [Menu] = []
    @Published var search = ""
    @Published var selectedCuisine: Cuisine?
    @Published var phase: Phase = .loading
    enum Phase { case loading, loaded, error(String) }

    func load() async {
        phase = .loading
        do {
            menus = try await PotluckService.menus(
                search: search.isEmpty ? nil : search,
                category: selectedCuisine?.rawValue
            )
            phase = .loaded
        } catch {
            phase = .error((error as? APIError)?.errorDescription ?? error.localizedDescription)
        }
    }
}

struct DishesView: View {
    @StateObject private var model = DishesModel()
    @State private var didLoad = false

    let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        NavigationStack {
            Group {
                switch model.phase {
                case .loading where model.menus.isEmpty: StateView(kind: .loading)
                case .error(let m) where model.menus.isEmpty: StateView(kind: .error, message: m) { Task { await model.load() } }
                default: grid
                }
            }
            .background(Theme.background)
            .navigationTitle("Dishes")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $model.search, prompt: "Search dishes")
            .onSubmit(of: .search) { Task { await model.load() } }
            .navigationDestination(for: Menu.self) { DishDetailView(menu: $0) }
        }
        .task { if !didLoad { didLoad = true; await model.load() } }
        // Re-pull live data whenever the tab is reopened so newly published dishes show immediately.
        .onAppear { if didLoad { Task { await model.load() } } }
    }

    private var grid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(model.menus) { menu in
                    NavigationLink(value: menu) { DishCard(menu: menu) }.buttonStyle(.plain)
                }
            }
            .padding()
        }
        .refreshable { await model.load() }
    }
}

struct DishCard: View {
    let menu: Menu
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RemoteImage(url: menu.firstImage)
                .frame(height: 120).frame(maxWidth: .infinity).clipped()
            VStack(alignment: .leading, spacing: 5) {
                Text(menu.name).font(.subheadline.weight(.semibold)).lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let chef = menu.chef?.user {
                    Text(chef.fullName).font(.caption).foregroundStyle(Theme.mutedInk).lineLimit(1)
                }
                HStack {
                    Text(menu.displayPrice).font(.subheadline.bold()).foregroundStyle(Theme.terracotta)
                    Spacer()
                    if menu.rating > 0 { RatingLabel(rating: menu.rating) }
                }
            }
            .padding(10)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Theme.cardShadow, radius: 6, y: 3)
    }
}

struct DishDetailView: View {
    let menu: Menu
    @State private var full: Menu?
    @State private var reviews: [Review] = []
    @State private var reviewTotal = 0
    @State private var reviewAverage: Double = 0
    @State private var showBooking = false

    private var m: Menu { full ?? menu }

    /// Share sheet text — dish + chef + site link.
    private var shareText: String {
        let chefName = m.chef?.user?.fullName ?? "a home chef"
        return "\(m.name) by \(chefName) on Potluck 🍲 https://potluckhub.io"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                RemoteImage(url: m.firstImage)
                    .frame(height: 260).frame(maxWidth: .infinity).clipped()
                VStack(alignment: .leading, spacing: 14) {
                    Text(m.name).font(.title2.bold()).foregroundStyle(Theme.ink)
                    HStack {
                        Text(m.displayPrice).font(.title3.bold()).foregroundStyle(Theme.terracotta)
                        Spacer()
                        if m.rating > 0 { RatingLabel(rating: m.rating) }
                    }
                    if !m.dietaryTags.isEmpty {
                        HStack { ForEach(m.dietaryTags, id: \.self) { Pill(text: $0) } }
                    }
                    if let d = m.description { Text(d).font(.body).foregroundStyle(Theme.ink) }
                    if let chef = m.chef?.user {
                        Divider()
                        HStack {
                            AvatarView(url: chef.avatarUrl, initials: initials(chef.fullName), size: 44)
                            VStack(alignment: .leading) {
                                Text("Prepared by").font(.caption).foregroundStyle(Theme.mutedInk)
                                Text(chef.fullName).font(.subheadline.weight(.semibold))
                            }
                            Spacer()
                        }
                    }

                    if !reviews.isEmpty {
                        Divider()
                        HStack {
                            Text("Diner reviews").font(.headline).foregroundStyle(Theme.ink)
                            Spacer()
                            RatingLabel(rating: reviewAverage > 0 ? reviewAverage : m.rating, count: reviewTotal)
                        }
                        VStack(spacing: 12) {
                            ForEach(reviews.prefix(5)) { ReviewCard(review: $0, showMenuName: false) }
                        }
                    }
                }
                .padding()
            }
            .padding(.bottom, 24)
        }
        .background(Theme.background)
        .safeAreaInset(edge: .bottom) {
            BookingBar(price: m.displayPrice, title: "Request This Dish") { showBooking = true }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: shareText) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .task {
            full = try? await PotluckService.menu(id: menu.id)
            // Reviews come from the potluckhub.io website API (chef-level; the web
            // reviews model has no per-menu link).
            if let chefId = m.chefId ?? m.chef?.id,
               let response = try? await ReviewsService.reviews(chefId: chefId) {
                reviews = response.reviews.map(\.asReview)
                reviewTotal = response.total
                reviewAverage = response.average
            }
        }
        .sheet(isPresented: $showBooking) {
            if let chefUser = m.chef?.user, let chefId = m.chef?.id {
                BookingRequestView(
                    chef: Chef(id: chefId, userId: nil, bio: nil, specialties: nil, city: nil,
                               postalCode: nil, country: nil, instagramUrl: nil, facebookUrl: nil,
                               tiktokUrl: nil, websiteUrl: nil, averageRating: m.chef?.averageRating,
                               totalReviews: m.chef?.totalReviews, isVerified: m.chef?.isVerified,
                               isAvailable: true, user: chefUser, menus: nil),
                    menu: m
                )
            }
        }
    }

    private func initials(_ name: String) -> String {
        name.split(separator: " ").prefix(2).compactMap { $0.first.map(String.init) }.joined().uppercased()
    }
}
