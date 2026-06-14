# Potluck — Native iOS App 🌈🥄

[![Swift](https://img.shields.io/badge/Swift-5.9-F05138?style=flat-square&logo=swift&logoColor=white)](https://swift.org)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-iOS%2017+-0A84FF?style=flat-square&logo=swift&logoColor=white)](https://developer.apple.com/xcode/swiftui/)
[![Xcode](https://img.shields.io/badge/Xcode-26-1575F9?style=flat-square&logo=xcode&logoColor=white)](https://developer.apple.com/xcode/)
[![Platform](https://img.shields.io/badge/Platform-iPhone-lightgrey?style=flat-square&logo=apple)](https://www.apple.com/iphone/)
[![App Store](https://img.shields.io/badge/App%20Store-Submitted-0D96F6?style=flat-square&logo=app-store)](https://apps.apple.com/)

The native **SwiftUI** iPhone app for [**Potluck**](https://potluckhub.io) — a Singapore
marketplace connecting home chefs with food lovers. Discover talented local cooks, browse
their menus, and book authentic home-cooked dining experiences.

> Companion to the [Potluck web platform](https://github.com/alfredang/potluck). This app
> talks directly to the production Potluck API (`api.potluckhub.io`) — no mock data.

## Screenshots

| Explore | Dishes | Chef Profile | Sign In |
|:---:|:---:|:---:|:---:|
| ![Explore](screenshots/01-explore.png) | ![Dishes](screenshots/02-dishes.png) | ![Chef](screenshots/03-chef.png) | ![Profile](screenshots/04-profile.png) |

## Features

- **Explore home chefs** — featured carousel, full directory, search, and nine cuisine filters (Chinese, Western, Thai, Japanese, Korean, Malay, Indian, Halal, Vegetarian)
- **Browse dishes** — a photo-rich grid of menus across every chef, with prices and ratings
- **Chef profiles** — bio, specialties, social links, full menu, and verified diner reviews
- **Booking flow** — pick a date, guest count and special requests with a live price breakdown (incl. service fee)
- **Accounts** — register / sign in against the live API, with tokens stored securely in the Keychain
- **My bookings** — track requested and confirmed dining experiences

## Tech Stack

| Area | Choice |
|------|--------|
| UI | SwiftUI (iOS 17+), `NavigationStack`, `TabView` |
| Networking | `async`/`await` `URLSession`, `Codable`, typed `APIError` |
| Auth | JWT access/refresh tokens persisted in the **Keychain** |
| State | `ObservableObject` view models per screen |
| Project gen | [XcodeGen](https://github.com/yonyz/XcodeGen) (`project.yml`) |
| Backend | Potluck REST API — `https://api.potluckhub.io/api/v1` |

## Architecture

```
Potluck/
├── App/            # @main entry, Theme (brand palette), RootView (tabs)
├── Networking/     # APIClient, PotluckService (endpoints), Codable Models
├── Auth/           # AuthManager (session) + Keychain wrapper
├── Components/     # Reusable views (RemoteImage, RatingLabel, Pill, states…)
└── Features/
    ├── Explore/    # Chef discovery + chef detail
    ├── Dishes/     # Menu grid + dish detail
    ├── Booking/    # Booking request sheet
    ├── Bookings/   # My bookings
    └── Profile/    # Auth sheet + profile
```

The API wraps every response in a `{ success, data, pagination? }` envelope; `APIClient`
unwraps it generically. Prices are stored as integer **cents** and ratings sometimes arrive
as strings and sometimes as numbers — a `FlexNumber` decoder handles both.

## Getting Started

Requires **Xcode 16+** and [XcodeGen](https://github.com/yonyz/XcodeGen) (`brew install xcodegen`).

```bash
# Generate the Xcode project from project.yml
xcodegen generate

# Open and run
open Potluck.xcodeproj
```

The app points at the production API out of the box, so chefs and dishes load immediately.

## Build & Distribution

```bash
# Archive
xcodebuild archive -project Potluck.xcodeproj -scheme Potluck \
  -configuration Release -destination 'generic/platform=iOS' \
  -archivePath build/Potluck.xcarchive

# Export a signed App Store IPA
xcodebuild -exportArchive -archivePath build/Potluck.xcarchive \
  -exportOptionsPlist ExportOptions.plist -exportPath build/export

# Upload to App Store Connect
xcrun altool --upload-app -f build/export/Potluck.ipa -t ios \
  --apiKey <KEY_ID> --apiIssuer <ISSUER_ID>
```

- **Bundle ID:** `io.potluckhub.app`
- **Version:** 1.0

## License

MIT
