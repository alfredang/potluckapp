import SwiftUI

@MainActor
final class ChefDetailModel: ObservableObject {
    @Published var chef: Chef?
    @Published var reviews: [Review] = []
    @Published var phase: Phase = .loading
    enum Phase { case loading, loaded, error(String) }

    func load(id: String) async {
        phase = .loading
        do {
            async let chef = PotluckService.chef(id: id)
            async let reviews = PotluckService.chefReviews(chefId: id)
            self.chef = try await chef
            self.reviews = (try? await reviews) ?? []
            phase = .loaded
        } catch {
            phase = .error((error as? APIError)?.errorDescription ?? error.localizedDescription)
        }
    }
}

struct ChefDetailView: View {
    let chefId: String
    let preview: Chef?
    @StateObject private var model = ChefDetailModel()
    @State private var bookingMenu: Menu?

    var body: some View {
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
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load(id: chefId) }
        .sheet(item: $bookingMenu) { menu in
            if let chef = model.chef ?? preview {
                BookingRequestView(chef: chef, menu: menu)
            }
        }
    }

    private var displayChef: Chef? { model.chef ?? preview }

    private var header: some View {
        ZStack(alignment: .bottomLeading) {
            RemoteImage(url: displayChef?.user.avatarUrl)
                .frame(height: 240).frame(maxWidth: .infinity).clipped()
            LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .center, endPoint: .bottom)
                .frame(height: 240)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(displayChef?.user.fullName ?? "Chef").font(.title.bold()).foregroundStyle(.white)
                    if displayChef?.isVerified == true {
                        Image(systemName: "checkmark.seal.fill").foregroundStyle(.white)
                    }
                }
                if let city = displayChef?.city {
                    Label(city, systemImage: "mappin.and.ellipse")
                        .font(.subheadline).foregroundStyle(.white.opacity(0.9))
                }
            }
            .padding()
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
                    SectionHeader(title: "Menu")
                    VStack(spacing: 12) {
                        ForEach(menus) { menu in
                            MenuRow(menu: menu) { bookingMenu = menu }
                        }
                    }.padding(.horizontal)
                }

                if !model.reviews.isEmpty {
                    SectionHeader(title: "Reviews", subtitle: "\(model.reviews.count) verified diners")
                    VStack(spacing: 12) {
                        ForEach(model.reviews.prefix(8)) { ReviewCard(review: $0) }
                    }.padding(.horizontal)
                }
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
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                AvatarView(url: review.customer?.avatarUrl,
                           initials: initials(review.customer?.fullName ?? "P"), size: 36)
                VStack(alignment: .leading, spacing: 1) {
                    Text(review.customer?.fullName ?? "Diner").font(.subheadline.weight(.semibold))
                    if let m = review.menu?.name { Text(m).font(.caption).foregroundStyle(Theme.mutedInk) }
                }
                Spacer()
                HStack(spacing: 2) {
                    ForEach(0..<5) { i in
                        Image(systemName: i < review.rating ? "star.fill" : "star")
                            .font(.caption2).foregroundStyle(Theme.golden)
                    }
                }
            }
            if let title = review.title { Text(title).font(.subheadline.weight(.semibold)) }
            if let comment = review.comment {
                Text(comment).font(.subheadline).foregroundStyle(Theme.ink)
            }
        }
        .padding(14)
        .potluckCard()
    }

    private func initials(_ name: String) -> String {
        name.split(separator: " ").prefix(2).compactMap { $0.first.map(String.init) }.joined().uppercased()
    }
}
