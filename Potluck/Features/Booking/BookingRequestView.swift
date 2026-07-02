import SwiftUI
import SafariServices

// MARK: - Checkout view-model

@MainActor
final class CheckoutModel: ObservableObject {
    enum Phase: Equatable {
        case details            // step 1 — date / guests / notes
        case payment            // step 2 — pick a payment method
        case creating           // POST /checkout in flight
        case awaitingPayment    // redirected to hosted payment, polling status
        case paid
        case failed(String)
    }

    @Published var phase: Phase = .details
    @Published var provider: CheckoutProvider = .stripe
    @Published var showSafari = false
    @Published var errorMessage: String?
    @Published private(set) var order: CheckoutOrder?

    private var pollTask: Task<Void, Never>?

    var redirectURL: URL? { order.flatMap { URL(string: $0.redirectUrl) } }

    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy-MM-dd"
        return df
    }()

    private static let timeFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "HH:mm"
        return df
    }()

    /// Creates the order on the website checkout API, then opens the hosted payment page.
    func startCheckout(menu: Menu, guests: Int, date: Date, notes: String, user: User) async {
        phase = .creating
        errorMessage = nil
        let request = CheckoutRequest(
            menuId: menu.id,
            guests: guests,
            scheduledDate: Self.dateFormatter.string(from: date),
            scheduledTime: Self.timeFormatter.string(from: date),
            specialRequests: notes.isEmpty ? nil : notes,
            customerName: user.fullName,
            customerEmail: user.email,
            customerPhone: user.phone,
            provider: provider.rawValue,
            platform: "ios"
        )
        do {
            order = try await CheckoutService.createOrder(request)
            phase = .awaitingPayment
            showSafari = true
            startPolling()
        } catch {
            phase = .payment
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    /// Polls the order status every 2 seconds for up to 5 minutes.
    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            let deadline = Date().addingTimeInterval(5 * 60)
            while !Task.isCancelled, Date() < deadline {
                guard let self, self.phase == .awaitingPayment else { return }
                await self.pollOnce()
                if self.phase != .awaitingPayment { return }
                try? await Task.sleep(for: .seconds(2))
            }
            guard !Task.isCancelled, let self, self.phase == .awaitingPayment else { return }
            self.showSafari = false
            self.phase = .failed(
                "We couldn't confirm your payment in time. If you were charged, you'll receive an email receipt — otherwise please try again."
            )
        }
    }

    /// One immediate status check (used on foreground / deep-link return).
    func pollOnce() async {
        guard phase == .awaitingPayment, let id = order?.orderId else { return }
        guard let status = try? await CheckoutService.orderStatus(orderId: id) else { return }
        if status.isPaid {
            showSafari = false
            phase = .paid
        } else if status.isFailed {
            showSafari = false
            phase = .failed("Your payment didn't go through. You haven't been charged — please try again.")
        } else if status.isCancelled {
            showSafari = false
            phase = .failed("The payment was cancelled. You haven't been charged — please try again.")
        }
    }

    func refreshNow() {
        Task { await pollOnce() }
    }

    /// Called when the web success page deep-links back into the app.
    func handleWebReturn() {
        showSafari = false
        refreshNow()
    }

    /// Back to the payment-method step (Try Again / cancel waiting).
    func backToPayment() {
        pollTask?.cancel()
        errorMessage = nil
        phase = .payment
    }
}

// MARK: - Booking + checkout sheet

/// Booking sheet. Step 1: pick a date, guests and review the price breakdown.
/// Step 2: choose a payment method and pay via the hosted checkout in an in-app browser.
struct BookingRequestView: View {
    let chef: Chef
    let menu: Menu

    @EnvironmentObject private var auth: AuthManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var model = CheckoutModel()
    @State private var date = Date()
    @State private var guests = 2
    @State private var notes = ""
    @State private var showLogin = false

    private var subtotal: Int { menu.price * guests }
    private var platformFee: Int { Int(Double(subtotal) * 0.04) }
    private var total: Int { subtotal + platformFee }

    var body: some View {
        NavigationStack {
            Group {
                switch model.phase {
                case .details: detailsStep
                case .payment, .creating: paymentStep
                case .awaitingPayment: waitingView
                case .paid: successView
                case .failed(let message): failedView(message)
                }
            }
            .background(Theme.background)
            .navigationTitle(navTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if model.phase == .payment || model.phase == .creating {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Back") { model.phase = .details }
                            .disabled(model.phase == .creating)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) { Button("Close") { dismiss() } }
            }
            .sheet(isPresented: $showLogin) { AuthSheet() }
            .fullScreenCover(isPresented: $model.showSafari) {
                if let url = model.redirectURL {
                    SafariView(url: url) { model.showSafari = false }
                        .ignoresSafeArea()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .potluckCheckoutReturn)) { _ in
                model.handleWebReturn()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active { model.refreshNow() }
            }
        }
    }

    private var navTitle: String {
        switch model.phase {
        case .details: return "Request Booking"
        case .payment, .creating: return "Payment"
        case .awaitingPayment: return "Confirming Payment"
        case .paid: return "Booking Paid"
        case .failed: return "Payment"
        }
    }

    // MARK: Step 1 — booking details

    private var detailsStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                menuHeader

                VStack(alignment: .leading, spacing: 12) {
                    DatePicker("Date & time", selection: $date, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                    Divider()
                    Stepper("Guests: \(guests)", value: $guests, in: 1...20)
                }
                .padding().potluckCard()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Special requests").font(.subheadline.weight(.semibold))
                    TextField("Allergies, dietary needs, occasion…", text: $notes, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                        .textFieldStyle(.roundedBorder)
                }
                .padding().potluckCard()

                priceBreakdown

                Button(auth.isLoggedIn ? "Continue to Payment" : "Sign in to Book") {
                    if auth.isLoggedIn { model.phase = .payment } else { showLogin = true }
                }
                .buttonStyle(PrimaryButton())

                Text("Pay securely in SGD — held until the chef confirms. No deposit drama.")
                    .font(.caption).foregroundStyle(Theme.mutedInk)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding()
        }
    }

    // MARK: Step 2 — payment method

    private var paymentStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                menuHeader

                VStack(alignment: .leading, spacing: 8) {
                    Text("Payment method").font(.subheadline.weight(.semibold))
                    VStack(spacing: 0) {
                        ForEach(Array(CheckoutProvider.allCases.enumerated()), id: \.element) { index, provider in
                            if index > 0 { Divider().padding(.leading, 58) }
                            providerRow(provider)
                        }
                    }
                    .potluckCard()
                }

                priceBreakdown

                if let error = model.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(Theme.terracotta)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(Theme.terracotta.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                Button {
                    if let user = auth.currentUser {
                        Task { await model.startCheckout(menu: menu, guests: guests, date: date, notes: notes, user: user) }
                    } else {
                        showLogin = true
                    }
                } label: {
                    if model.phase == .creating {
                        ProgressView().tint(.white)
                    } else {
                        Text(auth.isLoggedIn ? "Proceed to Payment — \(Money.format(total))" : "Sign in to Book")
                    }
                }
                .buttonStyle(PrimaryButton())
                .disabled(model.phase == .creating)

                Text("You'll be taken to a secure payment page. Your booking is confirmed once payment is received.")
                    .font(.caption).foregroundStyle(Theme.mutedInk)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding()
        }
    }

    private func providerRow(_ provider: CheckoutProvider) -> some View {
        Button { model.provider = provider } label: {
            HStack(spacing: 14) {
                Image(systemName: provider.systemImage)
                    .foregroundStyle(Theme.teal)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(provider.title).font(.subheadline.weight(.medium)).foregroundStyle(Theme.ink)
                    if let subtitle = provider.subtitle {
                        Text(subtitle).font(.caption).foregroundStyle(Theme.mutedInk)
                    }
                }
                Spacer()
                Image(systemName: model.provider == provider ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(model.provider == provider ? Theme.terracotta : Theme.mutedInk)
            }
            .padding(16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Waiting / success / failure states

    private var waitingView: some View {
        VStack(spacing: 16) {
            ProgressView().controlSize(.large).tint(Theme.terracotta)
            Text("Confirming your payment…").font(.headline).foregroundStyle(Theme.ink)
            if let order = model.order {
                Text("Order \(order.orderNumber)").font(.subheadline).foregroundStyle(Theme.mutedInk)
            }
            Text("Keep this screen open — we'll confirm as soon as the payment goes through.")
                .font(.caption).foregroundStyle(Theme.mutedInk).multilineTextAlignment(.center)
            Button("Cancel") { model.backToPayment() }
                .font(.subheadline).foregroundStyle(Theme.terracotta).padding(.top, 8)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var successView: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: "checkmark.seal.fill").font(.system(size: 64)).foregroundStyle(Theme.teal)
                Text("Payment received!").font(.title2.bold()).foregroundStyle(Theme.ink)
                if let order = model.order {
                    Pill(text: order.orderNumber, filled: true)
                }
                Text("Your booking request is now with the chef — you'll get a confirmation shortly.")
                    .font(.subheadline).foregroundStyle(Theme.mutedInk).multilineTextAlignment(.center)

                if let amount = model.order?.amount {
                    VStack(spacing: 10) {
                        row("Subtotal", Money.format(amount.subtotal, currency: amount.currency))
                        row("Platform fee", Money.format(amount.platformFee, currency: amount.currency))
                        Divider()
                        row("Total paid", Money.format(amount.total, currency: amount.currency), bold: true)
                    }
                    .padding().potluckCard()
                }

                Button("Done") { dismiss() }.buttonStyle(PrimaryButton()).padding(.top)
            }
            .padding(24)
        }
    }

    private func failedView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 56)).foregroundStyle(Theme.terracotta)
            Text("Payment not completed").font(.title3.bold()).foregroundStyle(Theme.ink)
            Text(message)
                .font(.subheadline).foregroundStyle(Theme.mutedInk).multilineTextAlignment(.center)
            Button("Try Again") { model.backToPayment() }
                .buttonStyle(PrimaryButton()).padding(.top)
            Button("Close") { dismiss() }
                .font(.subheadline).foregroundStyle(Theme.mutedInk)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Shared pieces

    private var menuHeader: some View {
        HStack(spacing: 12) {
            RemoteImage(url: menu.firstImage)
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 3) {
                Text(menu.name).font(.headline)
                Text("with \(chef.user.fullName)").font(.subheadline).foregroundStyle(Theme.mutedInk)
                Text(menu.displayPrice).font(.subheadline.bold()).foregroundStyle(Theme.terracotta)
            }
            Spacer()
        }
        .padding().potluckCard()
    }

    private var priceBreakdown: some View {
        VStack(spacing: 10) {
            row("\(menu.displayPrice) × \(guests)", Money.format(subtotal))
            row("Platform fee (4%)", Money.format(platformFee))
            Divider()
            row("Total", Money.format(total), bold: true)
        }
        .padding().potluckCard()
    }

    private func row(_ label: String, _ value: String, bold: Bool = false) -> some View {
        HStack {
            Text(label).font(bold ? .headline : .subheadline).foregroundStyle(bold ? Theme.ink : Theme.mutedInk)
            Spacer()
            Text(value).font(bold ? .headline : .subheadline.weight(.medium))
                .foregroundStyle(bold ? Theme.terracotta : Theme.ink)
        }
    }
}

// MARK: - In-app browser

/// SFSafariViewController wrapper for the hosted payment page.
struct SafariView: UIViewControllerRepresentable {
    let url: URL
    var onFinished: () -> Void = {}

    func makeCoordinator() -> Coordinator { Coordinator(onFinished: onFinished) }

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let controller = SFSafariViewController(url: url)
        controller.delegate = context.coordinator
        controller.preferredControlTintColor = UIColor(Theme.terracotta)
        controller.dismissButtonStyle = .close
        return controller
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}

    final class Coordinator: NSObject, SFSafariViewControllerDelegate {
        let onFinished: () -> Void
        init(onFinished: @escaping () -> Void) { self.onFinished = onFinished }

        func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
            onFinished()
        }
    }
}
