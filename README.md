# PhishNet

**Your Shield Against Scams**

PhishNet is a cross-platform mobile app (iOS + Android, built with Flutter) that helps users detect and respond to phishing attempts and scam messages. Users can capture or paste a suspicious message, scan it for scam indicators, and get a clear, actionable breakdown of the risk — along with recommended next steps and the option to loop in a trusted contact for a second opinion.

## Features

- **Capture** — upload a screenshot or paste text of a suspicious message
- **Scan & Results** — get a scam-confidence score with a plain-language breakdown of *why* it looks suspicious and *what to do next*
- **AI Chat** — ask follow-up questions about a specific message or scam pattern
- **Family/Social** — share a flagged message with trusted contacts for a second opinion
- **History** — review past captures, chats, and detections
- **Analytics** — track scam trends and personal "learning outcomes" over time

## Tech Stack

- **Flutter** (Dart) — single codebase for iOS and Android
- **Xcode** / iOS Simulator for iOS builds and testing
- **Android Studio** / Android SDK for Android builds and testing

## Project Structure

```
lib/
├── main.dart                 # App entry point, theme, and initial route
├── screens/                  # One file per app screen
│   ├── loading_screen.dart
│   ├── login_screen.dart
│   ├── capture_screen.dart
│   ├── results_screen.dart
│   ├── ai_chat_screen.dart
│   ├── family_social_screen.dart
│   ├── settings_screen.dart
│   ├── history_screen.dart
│   └── analytics_screen.dart
├── widgets/                  # Shared, reusable UI components
│   ├── app_drawer.dart       # Main navigation drawer
│   └── swimming_fish.dart    # Loading-screen animation
└── models/
    └── scan_result.dart      # Data model for a scan/detection result
```

## Getting Started (Development Setup)

1. **Install the Flutter SDK**
   [flutter.dev/get-started/install](https://docs.flutter.dev/get-started/install)

2. **Clone this repo and install dependencies**
   ```bash
   git clone <this-repo-url>
   cd PhishNet
   flutter pub get
   ```

3. **Check your environment is ready**
   ```bash
   flutter doctor
   ```
   Resolve any issues it flags (Android SDK, Xcode, CocoaPods, etc.) before continuing.

4. **Run the app**
   ```bash
   flutter run
   ```
   This will prompt you to pick a connected device, simulator, or emulator if more than one is available.

## Regenerating App Icons

App icons are generated from `assets/images/phishnet_app_icon.png` using [`flutter_launcher_icons`](https://pub.dev/packages/flutter_launcher_icons). If the source image changes, regenerate icons with:

```bash
dart run flutter_launcher_icons
```

## Status

🚧 Actively in development — core navigation and screen structure are in place; scan/detection logic, authentication, and backend integration are in progress.
