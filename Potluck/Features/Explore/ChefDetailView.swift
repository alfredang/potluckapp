import SwiftUI

@MainActor
final class ChefDetailModel: ObservableObject {
    @Published var chef: Chef?
    @Published var reviews: [Review] = []
    @Published var reviewTotal = 0
    @Published var reviewAverage: Double = 0
    @Published var phase: Phase = .loading
    enum Phase { case loading, loaded, error(String) }

    func load(id: String) async {
        phase = .loading
        do {
            // Reviews come from the potluckhub.io website API (same origin as checkout).
            async let chef = PotluckService.chef(id: id)
            async let reviews = ReviewsService.reviews(chefId: id)
            self.chef = try await chef
            if let response = try? await reviews {
                self.reviews = response.reviews.map(\.asReview)
                self.reviewTotal = response.total
                self.reviewAverage = response.average
            }
            phase = .loaded
        } catch {
            phase = .error((error as? APIError)?.errorDescription ?? error.localizedDescription)
        }
    }

    /// Shows a freshly submitted review at the top of the list.
    func prepend(_ review: WebReview) {
        reviews.insert(review.asReview, at: 0)
        reviewTotal += 1
    }
}

struct ChefDetailView: View {
    let chefId: String
    let preview: Chef?
    @EnvironmentObject private var auth: AuthManager
    @StateObject private var model = ChefDetailModel()
    @State private var bookingMenu: Menu?
    @State private var showWriteReview = false
    @State private var showLogin = false
    @State private var showThankYou = false

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    if case .error(let msg) = model.phase, model.chef == nil {
                        StateView(kind: .error, message: msg) { Task { await model.load(id: chefId) } }
                            .frame(height: 300)
                    } else {
                        body(for: model.chef ?? preview)
                    }
                }
                .padding(.bottom, 32)
            }
            .background(Theme.background)
            .safeAreaInset(edge: .bottom) {
                if let menus = displayChef?.menus, !menus.isEmpty {
                    BookingBar(title: "See the menu", systemImage: "fork.knife") {
                        withAnimation { proxy.scrollTo("menu", anchor: .top) }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: shareText) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
            .task { await model.load(id: chefId) }
            .sheet(item: $bookingMenu) { menu in
                if let chef = model.chef ?? preview {
                    BookingRequestView(chef: chef, menu: menu)
                }
            }
            .sheet(isPresented: $showWriteReview) {
                if let chef = displayChef {
                    WriteReviewView(chef: chef) { review in
                        model.prepend(review)
                        showThankYou = true
                        Task {
                            try? await Task.sleep(for: .seconds(3))
                            showThankYou = false
                        }
                    }
                }
            }
            .sheet(isPresented: $showLogin) { AuthSheet() }
        }
    }

    /// Share sheet text — chef name + first specialty (or "Singapore") + site link.
    private var shareText: String {
        let name = displayChef?.user.fullName ?? "a home chef"
        let flavour = displayChef?.displaySpecialties.first ?? "Singapore"
        return "Check out \(name) — home-cooked \(flavour) on Potluck 🍲 https://potluckhub.io"
    }

    private var displayChef: Chef? { model.chef ?? preview }

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                RemoteImage(url: displayChef?.user.avatarUrl)
                    .frame(height: 240).frame(maxWidth: .infinity).clipped()
                LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .center, endPoint: .bottom)
                    .frame(height: 240)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(displayChef?.user.fullName ?? "Chef").font(.title.bold()).foregroundStyle(.white)
                        if displayChef?.isVerified == true {
                            VerifiedPill(onPhoto: true)
                        }
                    }
                    if let city = displayChef?.city {
                        Label(city, systemImage: "mappin.and.ellipse")
                            .font(.subheadline).foregroundStyle(.white.opacity(0.9))
                    }
                }
                .padding()
            }
            if displayChef?.isVerified == true {
                Label("Identity & kitchen verified by Potluck (site visit)", systemImage: "checkmark.seal.fill")
                    .font(.caption).foregroundStyle(Theme.teal)
                    .padding(.horizontal).padding(.top, 10)
            }
        }
    }

    @ViewBuilder
    private func body(for chef: Chef?) -> some View {
        if let chef {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 16) {
                    RatingLabel(rating: chef.rating, count: chef.reviewCount)
                    if chef.isAvailable == true {
                        Label("Available", systemImage: "circle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.teal)
                            .imageScale(.small)
                    }
                }
                .padding(.horizontal)

                if let bio = chef.bio {
                    Text(bio).font(.body).foregroundStyle(Theme.ink).padding(.horizontal)
                }

                if !chef.displaySpecialties.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack { ForEach(chef.displaySpecialties, id: \.self) { Pill(text: $0) } }
                            .padding(.horizontal)
                    }
                }

                if let socials = socialLinks(for: chef), !socials.isEmpty {
                    HStack(spacing: 18) {
                        ForEach(socials, id: \.0) { handle in
                            Label(handle.1, systemImage: "link").font(.caption).foregroundStyle(Theme.teal)
                        }
                    }.padding(.horizontal)
                }

                if let menus = chef.menus, !menus.isEmpty {
                    SectionHeader(title: "Menu", subtitle: "Tap Book to reserve a dish").id("menu")
                    VStack(spacing: 12) {
                        ForEach(menus) { menu in
                            MenuRow(menu: menu) { bookingMenu = menu }
                        }
                    }.padding(.horizontal)
                }

                SectionHeader(title: "Reviews", subtitle: "What diners are saying")
                VStack(spacing: 12) {
                    Button {
                        if auth.isLoggedIn { showWriteReview = true } else { showLogin = true }
                    } label: {
                        Label("Write a Review", systemImage: "square.and.pencil")
                    }
                    .buttonStyle(PrimaryButton())

                    if showThankYou {
                        Label("Thanks for your review!", systemImage: "checkmark.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.teal)
                            .frame(maxWidth: .infinity)
                            .padding(12)
                            .background(Theme.teal.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .transition(.opacity)
                    }

                    if !model.reviews.isEmpty {
                        RatingSummary(
                            rating: model.reviewAverage > 0 ? model.reviewAverage : chef.rating,
                            count: model.reviewTotal > 0 ? model.reviewTotal : model.reviews.count
                        )
                        ForEach(model.reviews.prefix(8)) { ReviewCard(review: $0) }
                    } else {
                        Text("No reviews yet — be the first to share your experience.")
                            .font(.subheadline).foregroundStyle(Theme.mutedInk)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal)
                .animation(.default, value: showThankYou)
            }
        } else {
            StateView(kind: .loading).frame(height: 300)
        }
    }

    private func socialLinks(for chef: Chef) -> [(String, String)]? {
        var out: [(String, String)] = []
        if let v = chef.instagramUrl { out.append(("ig", "@\(v)")) }
        if let v = chef.tiktokUrl { out.append(("tt", "TikTok @\(v)")) }
        return out
    }
}

struct MenuRow: View {
    let menu: Menu
    var onBook: () -> Void
    var body: some View {
        HStack(spacing: 12) {
            RemoteImage(url: menu.firstImage)
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(menu.name).font(.subheadline.weight(.semibold)).lineLimit(2)
                if let d = menu.description { Text(d).font(.caption).foregroundStyle(Theme.mutedInk).lineLimit(2) }
                Text(menu.displayPrice).font(.subheadline.bold()).foregroundStyle(Theme.terracotta)
            }
            Spacer(minLength: 0)
            Button("Book", action: onBook)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(Theme.teal).foregroundStyle(.white).clipShape(Capsule())
        }
        .padding(12)
        .potluckCard()
    }
}

struct ReviewCard: View {
    let review: Review
    var showMenuName = true
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                AvatarView(url: review.customer?.avatarUrl,
                           initials: initials(review.customer?.fullName ?? "P"), size: 36)
                VStack(alignment: .leading, spacing: 1) {
                    Text(review.customer?.fullName ?? "Diner").font(.subheadline.weight(.semibold))
                    if showMenuName, let m = review.menu?.name {
                        Text(m).font(.caption).foregroundStyle(Theme.mutedInk)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    HStack(spacing: 2) {
                        ForEach(0..<5) { i in
                            Image(systemName: i < review.rating ? "star.fill" : "star")
                                .font(.caption2).foregroundStyle(Theme.golden)
                        }
                    }
                    if let date = Self.formatted(review.createdAt) {
                        Text(date).font(.caption2).foregroundStyle(Theme.mutedInk)
                    }
                }
            }
            if let title = review.title { Text(title).font(.subheadline.weight(.semibold)) }
            if let comment = review.comment {
                Text(comment).font(.subheadline).foregroundStyle(Theme.ink)
            }
            if let reply = review.chefResponse, !reply.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "arrowshape.turn.up.left.fill")
                        .font(.caption2).foregroundStyle(Theme.teal)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Chef's reply").font(.caption.weight(.semibold)).foregroundStyle(Theme.teal)
                        Text(reply).font(.caption).foregroundStyle(Theme.ink)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.teal.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .padding(14)
        .potluckCard()
    }

    private func initials(_ name: String) -> String {
        name.split(separator: " ").prefix(2).compactMap { $0.first.map(String.init) }.joined().uppercased()
    }

    /// Formats an ISO-8601 timestamp to a short "Mon YYYY" label for review cards.
    static func formatted(_ iso: String?) -> String? {
        guard let iso else { return nil }
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = parser.date(from: iso) ?? {
            let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime]
            return f.date(from: iso)
        }()
        guard let date else { return nil }
        let out = DateFormatter()
        out.dateFormat = "MMM yyyy"
        return out.string(from: date)
    }
}

/// Compact average-rating summary shown atop a reviews section.
struct RatingSummary: View {
    let rating: Double
    let count: Int
    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 0) {
                Text(String(format: "%.1f", rating)).font(.title.bold()).foregroundStyle(Theme.ink)
                HStack(spacing: 2) {
                    ForEach(0..<5) { i in
                        Image(systemName: Double(i) < rating.rounded() ? "star.fill" : "star")
                            .font(.caption2).foregroundStyle(Theme.golden)
                    }
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("\(count) verified \(count == 1 ? "review" : "reviews")")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                Text("From diners who've eaten here").font(.caption).foregroundStyle(Theme.mutedInk)
            }
            Spacer()
        }
        .padding(14)
        .potluckCard()
    }
}
