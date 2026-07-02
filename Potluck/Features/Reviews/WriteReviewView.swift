import SwiftUI

// MARK: - Write-review view-model

@MainActor
final class WriteReviewModel: ObservableObject {
    enum Phase: Equatable {
        case editing
        case submitting
        case error(String)
    }

    @Published var phase: Phase = .editing
    @Published var rating = 5
    @Published var title = ""
    @Published var body = ""

    var isSubmitting: Bool { phase == .submitting }
    var canSubmit: Bool {
        body.trimmingCharacters(in: .whitespacesAndNewlines).count >= 10 && !isSubmitting
    }

    /// POSTs the review to the website API; returns the created review on success.
    func submit(chefId: String, user: User) async -> WebReview? {
        phase = .submitting
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let request = CreateReviewRequest(
            chefId: chefId,
            authorName: user.fullName,
            authorEmail: user.email.isEmpty ? nil : user.email,
            rating: rating,
            title: trimmedTitle.isEmpty ? nil : trimmedTitle,
            body: body.trimmingCharacters(in: .whitespacesAndNewlines),
            platform: "ios"
        )
        do {
            let review = try await ReviewsService.submit(request)
            phase = .editing
            return review
        } catch {
            phase = .error((error as? APIError)?.errorDescription ?? error.localizedDescription)
            return nil
        }
    }
}

// MARK: - Sheet

/// Sheet for writing a chef review — tappable stars, optional title, and a body
/// (min 10 characters). Requires a signed-in user for author name/email.
struct WriteReviewView: View {
    let chef: Chef
    var onSubmitted: (WebReview) -> Void

    @EnvironmentObject private var auth: AuthManager
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = WriteReviewModel()
    @FocusState private var focusedField: Field?

    private enum Field { case title, body }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    chefHeader
                    starPicker
                    titleField
                    bodyField

                    if case .error(let message) = model.phase {
                        Label(message, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(Theme.terracotta)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(Theme.terracotta.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    Button {
                        submit()
                    } label: {
                        if model.isSubmitting {
                            ProgressView().tint(.white)
                        } else {
                            Text(submitLabel)
                        }
                    }
                    .buttonStyle(PrimaryButton())
                    .disabled(!model.canSubmit)
                    .opacity(model.canSubmit ? 1 : 0.6)

                    Text("Your review is public and appears with your name. Please keep it honest and kind.")
                        .font(.caption).foregroundStyle(Theme.mutedInk)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding()
            }
            .background(Theme.background)
            .navigationTitle("Write a Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }.disabled(model.isSubmitting)
                }
            }
        }
    }

    private var submitLabel: String {
        if case .error = model.phase { return "Try Again" }
        return "Submit Review"
    }

    private func submit() {
        guard let user = auth.currentUser else { return }
        focusedField = nil
        Task {
            if let review = await model.submit(chefId: chef.id, user: user) {
                onSubmitted(review)
                dismiss()
            }
        }
    }

    // MARK: Pieces

    private var chefHeader: some View {
        HStack(spacing: 12) {
            AvatarView(url: chef.user.avatarUrl, initials: chef.user.initialsLabel, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text("Reviewing").font(.caption).foregroundStyle(Theme.mutedInk)
                Text(chef.user.fullName).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
            }
            Spacer()
        }
        .padding().potluckCard()
    }

    private var starPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your rating").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
            HStack(spacing: 10) {
                ForEach(1...5, id: \.self) { star in
                    Button {
                        model.rating = star
                    } label: {
                        Image(systemName: star <= model.rating ? "star.fill" : "star")
                            .font(.title2)
                            .foregroundStyle(Theme.golden)
                    }
                    .buttonStyle(.plain)
                    .disabled(model.isSubmitting)
                }
                Spacer()
                Text("\(model.rating)/5").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.mutedInk)
            }
        }
        .padding().potluckCard()
    }

    private var titleField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Title (optional)").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
            TextField("Sum it up in a few words", text: $model.title)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .title)
                .disabled(model.isSubmitting)
        }
        .padding().potluckCard()
    }

    private var bodyField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your review").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
            ZStack(alignment: .topLeading) {
                TextEditor(text: $model.body)
                    .frame(minHeight: 120)
                    .scrollContentBackground(.hidden)
                    .focused($focusedField, equals: .body)
                    .disabled(model.isSubmitting)
                if model.body.isEmpty {
                    Text("Share your experience — the food, the host, the vibe…")
                        .font(.body)
                        .foregroundStyle(Theme.mutedInk.opacity(0.7))
                        .padding(.top, 8).padding(.leading, 5)
                        .allowsHitTesting(false)
                }
            }
            .padding(8)
            .background(Color(.systemGray6).opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            Text("At least 10 characters.")
                .font(.caption)
                .foregroundStyle(model.canSubmit || model.isSubmitting ? Theme.mutedInk : Theme.terracotta)
        }
        .padding().potluckCard()
    }
}

private extension ChefUser {
    /// Initials for the avatar fallback, e.g. "Ah Ma" → "AM".
    var initialsLabel: String {
        let f = firstName.first.map(String.init) ?? ""
        let l = lastName.first.map(String.init) ?? ""
        return (f + l).uppercased()
    }
}
