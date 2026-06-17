import SwiftUI

/// Booking request sheet. Lets a signed-in diner pick a date, guests and review the
/// price breakdown before requesting a booking.
struct BookingRequestView: View {
    let chef: Chef
    let menu: Menu

    @EnvironmentObject private var auth: AuthManager
    @Environment(\.dismiss) private var dismiss

    @State private var date = Date()
    @State private var guests = 2
    @State private var notes = ""
    @State private var showLogin = false
    @State private var submitted = false

    private var subtotal: Int { menu.price * guests }
    private var platformFee: Int { Int(Double(subtotal) * 0.04) }
    private var total: Int { subtotal + platformFee }

    var body: some View {
        NavigationStack {
            Group {
                if submitted { confirmation } else { form }
            }
            .background(Theme.background)
            .navigationTitle("Request Booking")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
            .sheet(isPresented: $showLogin) { AuthSheet() }
        }
    }

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
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

                Button(auth.isLoggedIn ? "Request Booking" : "Sign in to Book") {
                    if auth.isLoggedIn { submitted = true } else { showLogin = true }
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

    private var priceBreakdown: some View {
        VStack(spacing: 10) {
            row("\(menu.displayPrice) × \(guests)", Money.format(subtotal))
            row("Service fee", Money.format(platformFee))
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

    private var confirmation: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 64)).foregroundStyle(Theme.teal)
            Text("Request Sent!").font(.title2.bold())
            Text("\(chef.user.fullName) will review your request for \(menu.name) and get back to you shortly.")
                .font(.subheadline).foregroundStyle(Theme.mutedInk).multilineTextAlignment(.center)
            Button("Done") { dismiss() }.buttonStyle(PrimaryButton()).padding(.top)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
