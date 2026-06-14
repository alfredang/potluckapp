import SwiftUI

@MainActor
final class ExploreModel: ObservableObject {
    @Published var featured: [Chef] = []
    @Published var chefs: [Chef] = []
    @Published var search = ""
    @Published var selectedCuisine: Cuisine?
    @Published var phase: LoadPhase = .loading

    enum LoadPhase { case loading, loaded, error(String) }

    func load() async {
        phase = .loading
        do {
            async let featured = PotluckService.featuredChefs()
            async let chefs = PotluckService.chefs(category: selectedCuisine?.rawValue)
            self.featured = try await featured
            self.chefs = try await chefs
            phase = .loaded
        } catch {
            phase = .error((error as? APIError)?.errorDescription ?? error.localizedDescription)
        }
    }

    func applyFilters() async {
        do {
            chefs = try await PotluckService.chefs(
                search: search.isEmpty ? nil : search,
                category: selectedCuisine?.rawValue
            )
            phase = .loaded
        } catch {
            phase = .error((error as? APIError)?.errorDescription ?? error.localizedDescription)
        }
    }
}

struct ExploreView: View {
    @StateObject private var model = ExploreModel()
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                switch model.phase {
                case .loading where model.chefs.isEmpty:
                    StateView(kind: .loading)
                case .error(let msg) where model.chefs.isEmpty:
                    StateView(kind: .error, message: msg) { Task { await model.load() } }
                default:
                    content
                }
            }
            .background(Theme.background)
            .navigationTitle("Explore")
            .searchable(text: $model.search, prompt: "Search home chefs")
            .onSubmit(of: .search) { Task { await model.applyFilters() } }
        }
        .task {
            if model.chefs.isEmpty { await model.load() }
            if ScreenshotConfig.openFirstChef, let first = model.featured.first ?? model.chefs.first {
                path.append(first)
            }
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                cuisineFilter

                if !model.featured.isEmpty {
                    SectionHeader(title: "Featured Chefs", subtitle: "Top-rated home cooks near you")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 14) {
                            ForEach(model.featured) { chef in
                                NavigationLink(value: chef) { FeaturedChefCard(chef: chef) }
                                    .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                SectionHeader(title: "All Home Chefs", subtitle: "\(model.chefs.count) cooks ready to host")
                LazyVStack(spacing: 14) {
                    ForEach(model.chefs) { chef in
                        NavigationLink(value: chef) { ChefRow(chef: chef) }
                            .buttonStyle(.plain)
                    }
                    if model.chefs.isEmpty {
                        Text("No chefs match your filters yet.")
                            .font(.subheadline).foregroundStyle(Theme.mutedInk)
                            .frame(maxWidth: .infinity).padding(.vertical, 40)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationDestination(for: Chef.self) { ChefDetailView(chefId: $0.id, preview: $0) }
        .refreshable { await model.load() }
    }

    private var cuisineFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Cuisine.allCases) { cuisine in
                    let isOn = model.selectedCuisine == cuisine
                    Button {
                        model.selectedCuisine = isOn ? nil : cuisine
                        Task { await model.applyFilters() }
                    } label: {
                        HStack(spacing: 6) {
                            Text(cuisine.emoji)
                            Text(cuisine.label).font(.subheadline.weight(.medium))
                        }
                        .padding(.horizontal, 14).padding(.vertical, 9)
                        .background(isOn ? Theme.terracotta : Color.white)
                        .foregroundStyle(isOn ? .white : Theme.ink)
                        .clipShape(Capsule())
                        .shadow(color: Theme.cardShadow, radius: 4, y: 2)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.title3.bold())
            if let subtitle { Text(subtitle).font(.subheadline).foregroundStyle(Theme.mutedInk) }
        }
        .padding(.horizontal)
    }
}

struct FeaturedChefCard: View {
    let chef: Chef
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RemoteImage(url: chef.user.avatarUrl)
                .frame(width: 220, height: 140)
                .clipped()
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(chef.user.fullName).font(.headline).lineLimit(1)
                    if chef.isVerified == true {
                        Image(systemName: "checkmark.seal.fill").font(.caption).foregroundStyle(Theme.teal)
                    }
                }
                RatingLabel(rating: chef.rating, count: chef.reviewCount)
                if let first = chef.displaySpecialties.first {
                    Pill(text: first)
                }
            }
            .padding(12)
        }
        .frame(width: 220, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Theme.cardShadow, radius: 8, y: 4)
    }
}

struct ChefRow: View {
    let chef: Chef
    var body: some View {
        HStack(spacing: 14) {
            RemoteImage(url: chef.user.avatarUrl)
                .frame(width: 78, height: 78)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 5) {
                    Text(chef.user.fullName).font(.headline)
                    if chef.isVerified == true {
                        Image(systemName: "checkmark.seal.fill").font(.caption).foregroundStyle(Theme.teal)
                    }
                }
                if let bio = chef.bio {
                    Text(bio).font(.caption).foregroundStyle(Theme.mutedInk).lineLimit(2)
                }
                HStack(spacing: 10) {
                    RatingLabel(rating: chef.rating, count: chef.reviewCount)
                    if let city = chef.city {
                        Label(city, systemImage: "mappin.and.ellipse")
                            .font(.caption).foregroundStyle(Theme.mutedInk)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .potluckCard()
    }
}
