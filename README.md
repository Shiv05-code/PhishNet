# PhishNet

**Your Shield Against Scams**

PhishNet is a Flutter mobile app that helps people identify and respond to
phishing attempts and scam messages. Users can capture or paste suspicious
content, review a plain-language risk assessment, and get recommended next
steps.

## Current features

- Authentication with Firebase Email/Password
- Signup validation for Gmail and Yahoo addresses
- Email verification after account creation
- Login with verified-account checks
- Password reset email flow
- Guest access to the capture flow
- Capture, results, AI chat, family/social, history, settings, and payment-plan
  screen foundations
- Shared authentication styling and accessible controls

Some product screens are still UI foundations or placeholders; scan detection,
AI responses, history persistence, and social sharing are not fully connected
to backend services yet.

## Tech stack

- [Flutter](https://docs.flutter.dev/) and Dart
- Firebase Core and Firebase Authentication
- Xcode and the iOS Simulator for iOS development
- Android Studio and the Android SDK for Android development

The current Firebase configuration generated in this repository is for iOS.
The iOS target requires iOS 15 or newer because of the Firebase packages.

## Project structure

```text
lib/
├── main.dart                    # Firebase initialization and app entry point
├── firebase_options.dart        # FlutterFire-generated platform configuration
├── models/                      # Application data models
├── screens/                     # Feature and authentication screens
├── services/
│   ├── auth_service.dart        # Firebase Auth operations and error mapping
│   └── auth_validation.dart     # Shared signup validation rules
├── theme/                       # App-wide colors and authentication theme
└── widgets/                     # Reusable UI components and transitions

test/
├── auth_validation_test.dart    # Signup validation unit tests
└── widget_test.dart             # Authentication and navigation widget tests
```

## Firebase setup

The app uses Firebase project `phishnet-b93e0` and the iOS bundle identifier
`com.Phishers.PhishNetApp`.

To configure Firebase for a new checkout:

1. Install the [Firebase CLI](https://firebase.google.com/docs/cli).
2. Sign in with an account that has access to the Firebase project:

   ```bash
   firebase login
   ```

3. Install FlutterFire CLI:

   ```bash
   dart pub global activate flutterfire_cli
   ```

4. From the project root, configure iOS:

   ```bash
   flutterfire configure \
     --project=phishnet-b93e0 \
     --platforms=ios \
     --ios-bundle-id=com.Phishers.PhishNetApp
   ```

5. Enable **Email/Password** under Firebase Console → Authentication →
   Sign-in method.

Do not commit credentials, debug logs, or generated build artifacts. The
FlutterFire-generated configuration files are environment-specific and should
only be shared through the project's approved source-control process.

## Development

Install dependencies:

```bash
flutter pub get
```

Run static analysis and tests:

```bash
flutter analyze
flutter test
```

Run on an available simulator, emulator, or connected device:

```bash
flutter run
```

Regenerate app icons after changing
`assets/images/phishnet_app_icon.png`:

```bash
dart run flutter_launcher_icons
```

Before opening an iOS issue, run:

```bash
flutter clean
flutter pub get
flutter run
```

## Status

PhishNet is actively in development. Firebase authentication and the primary
navigation flow are connected; detection, AI, history, and social features
remain under construction.
