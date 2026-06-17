import SwiftUI

/// Async remote image with a branded placeholder.
struct RemoteImage: View {
    let url: String?
    var contentMode: ContentMode = .fill

    var body: some View {
        AsyncImage(url: url.flatMap(URL.init(string:))) { phase in
            switch phase {
            case .success(let image):
                image.resizable().aspectRatio(contentMode: contentMode)
            case .failure:
                placeholder
            case .empty:
                ZStack { placeholder; ProgressView().tint(Theme.terracotta) }
            @unknown default:
                placeholder
            }
        }
    }

    private var placeholder: some View {
        LinearGradient(colors: [Theme.sand, Theme.cream], startPoint: .topLeading, endPoint: .bottomTrailing)
            .overlay(Image(systemName: "fork.knife").font(.title).foregroundStyle(Theme.golden))
    }
}

/// Star rating + review count.
struct RatingLabel: View {
    let rating: Double
    var count: Int? = nil

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "star.fill").font(.caption2).foregroundStyle(Theme.golden)
            Text(String(format: "%.1f", rating)).font(.subheadline.weight(.semibold))
            if let count, count > 0 {
                Text("(\(count))").font(.caption).foregroundStyle(Theme.mutedInk)
            }
        }
    }
}

struct Pill: View {
    let text: String
    var filled = false
    var body: some View {
        Text(text)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(filled ? Theme.terracotta : Theme.teal.opacity(0.12))
            .foregroundStyle(filled ? .white : Theme.teal)
            .clipShape(Capsule())
    }
}

struct AvatarView: View {
    let url: String?
    let initials: String
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            if let url, let u = URL(string: url) {
                AsyncImage(url: u) { img in
                    img.resizable().scaledToFill()
                } placeholder: { fallback }
            } else {
                fallback
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.white, lineWidth: 2))
    }

    private var fallback: some View {
        Circle().fill(Theme.teal.opacity(0.85))
            .overlay(Text(initials).font(.system(size: size * 0.4, weight: .bold)).foregroundStyle(.white))
    }
}

/// Standard centred state for loading / empty / error.
struct StateView: View {
    enum Kind { case loading, empty, error }
    let kind: Kind
    var title: String = ""
    var message: String = ""
    var retry: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 14) {
            switch kind {
            case .loading:
                ProgressView().controlSize(.large).tint(Theme.terracotta)
            case .empty:
                Image(systemName: "tray").font(.largeTitle).foregroundStyle(Theme.mutedInk)
                Text(title).font(.headline).foregroundStyle(Theme.ink)
                if !message.isEmpty { Text(message).font(.subheadline).foregroundStyle(Theme.mutedInk).multilineTextAlignment(.center) }
            case .error:
                Image(systemName: "exclamationmark.triangle").font(.largeTitle).foregroundStyle(Theme.terracotta)
                Text(title.isEmpty ? "Something went wrong" : title).font(.headline).foregroundStyle(Theme.ink)
                if !message.isEmpty { Text(message).font(.subheadline).foregroundStyle(Theme.mutedInk).multilineTextAlignment(.center) }
                if let retry {
                    Button("Try Again", action: retry)
                        .buttonStyle(.borderedProminent).tint(Theme.terracotta)
                }
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Pinned bottom action bar that keeps the primary booking CTA reachable without scrolling.
struct BookingBar: View {
    var price: String? = nil
    let title: String
    var systemImage: String? = nil
    var action: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            if let price {
                Text(price).font(.title3.bold()).foregroundStyle(Theme.terracotta)
            }
            Button(action: action) {
                if let systemImage {
                    Label(title, systemImage: systemImage)
                } else {
                    Text(title)
                }
            }
            .buttonStyle(PrimaryButton())
        }
        .padding(.horizontal)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
        .overlay(Divider(), alignment: .top)
    }
}

/// Primary call-to-action button style.
struct PrimaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(Theme.terracotta.opacity(configuration.isPressed ? 0.85 : 1))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
