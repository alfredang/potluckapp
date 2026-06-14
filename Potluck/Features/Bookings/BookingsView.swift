import SwiftUI

@MainActor
final class BookingsModel: ObservableObject {
    @Published var bookings: [Booking] = []
    @Published var phase: Phase = .idle
    enum Phase { case idle, loading, loaded, error(String) }

    func load() async {
        phase = .loading
        do {
            bookings = try await PotluckService.myBookings()
            phase = .loaded
        } catch {
            phase = .error((error as? APIError)?.errorDescription ?? error.localizedDescription)
        }
    }
}

struct BookingsView: View {
    @EnvironmentObject private var auth: AuthManager
    @StateObject private var model = BookingsModel()
    @State private var showLogin = false

    var body: some View {
        NavigationStack {
            Group {
                if !auth.isLoggedIn {
                    signedOut
                } else {
                    switch model.phase {
                    case .loading: StateView(kind: .loading)
                    case .error(let m): StateView(kind: .error, message: m) { Task { await model.load() } }
                    case .loaded where model.bookings.isEmpty: emptyState
                    default: list
                    }
                }
            }
            .background(Theme.background)
            .navigationTitle("Bookings")
            .sheet(isPresented: $showLogin) { AuthSheet() }
        }
        .task(id: auth.isLoggedIn) { if auth.isLoggedIn { await model.load() } }
    }

    private var signedOut: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.clock").font(.system(size: 56)).foregroundStyle(Theme.golden)
            Text("Track your dining plans").font(.title3.bold())
            Text("Sign in to view and manage your bookings with home chefs.")
                .font(.subheadline).foregroundStyle(Theme.mutedInk).multilineTextAlignment(.center)
            Button("Sign In") { showLogin = true }.buttonStyle(PrimaryButton()).padding(.horizontal, 40)
        }
        .padding(32)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "fork.knife.circle").font(.system(size: 56)).foregroundStyle(Theme.golden)
            Text("No bookings yet").font(.title3.bold())
            Text("Explore home chefs and request your first dining experience.")
                .font(.subheadline).foregroundStyle(Theme.mutedInk).multilineTextAlignment(.center)
        }
        .padding(32)
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(model.bookings) { BookingCard(booking: $0) }
            }
            .padding()
        }
        .refreshable { await model.load() }
    }
}

struct BookingCard: View {
    let booking: Booking
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(booking.bookingNumber ?? "Booking").font(.subheadline.weight(.semibold))
                Spacer()
                if let status = booking.status { Pill(text: status.capitalized, filled: status == "confirmed") }
            }
            if let date = booking.scheduledDate {
                Label("\(date) \(booking.scheduledTime ?? "")", systemImage: "calendar")
                    .font(.caption).foregroundStyle(Theme.mutedInk)
            }
            if let total = booking.total {
                Text(Money.format(total)).font(.headline).foregroundStyle(Theme.terracotta)
            }
        }
        .padding().potluckCard()
    }
}
