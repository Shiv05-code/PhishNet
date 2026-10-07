# PhishNet — notes for Claude

Flutter (iOS-focused) app with Firebase Auth. Team auth setup/testing guide:
`docs/auth-setup.md`.

## Docs rules
- README.md is the public repo front page: do NOT edit it, and never put
  sensitive content (project IDs, emails, keys, URLs to private resources)
  in any committed doc. Use `<placeholders>`.
- Only CLAUDE.md (and team guides under `docs/`) may be updated by Claude.

## Commands
- `dart format lib test` · `flutter analyze lib test` · `flutter test` (CI runs all three)

## Auth architecture
- `lib/services/auth_service.dart` wraps FirebaseAuth; every auth screen takes an
  optional `authService` so tests inject `test/support/fake_auth_service.dart`.
  Never call `FirebaseAuth.instance` directly from screens.
- Flow: Splash (`loading_screen.dart`, 3s) → Home if verified session, else Login.
  Signup (name, email, password) → `EmailVerificationScreen` → Home.
  Forgot → email link → `ResetPasswordScreen(oobCode)` → Login.
- Reset links: `lib/services/reset_link.dart` + `onGenerateRoute` in `main.dart`;
  iOS scheme `phishnet://`; redirect page in `hosting/public/auth/action/`.
- Forgot Password must stay enumeration-safe (same message for any email).

## UI conventions
- Auth screens use `AuthPage` + `AuthCard` + `AuthHeader`, `AuthField`,
  `AuthPrimaryButton`, `AuthStatusBanner` from `lib/widgets/auth_widgets.dart`;
  colors/styles in `lib/theme/auth_theme.dart`.
- Accessibility (older-adult audience): field and legal text ≥18pt, WCAG AA
  contrast, inline errors (banners) over snackbars.
- Signup collects First/Last name → Auth `displayName` "First Last"; Home greets
  with `AuthService.firstName` (first word; fallback "Hello there").
- Legal text is structured data (`legal_content.dart`) in `terms_conditions_screen.dart` / `privacy_policy_screen.dart`;
  only change it with approved content.

## PR tracker (auth + legal work)
Stacked PRs; merge in order with "Create a merge commit" (not squash).
Check items off only after the user confirms manual testing.

### PR 1 — `feature/auth/login-signup` → main
- [x] Shared auth components, auth service + validation, Login/Signup
      redesign, first/last name → `displayName`, Home first-name greeting
      (user-tested)
- [ ] Re-test: submit is the original Figma-blue circular arrow
      (`AuthArrowButton`, 48px, loading spinner) — Login: "Forgot
      Password?" left / arrow right; Signup: arrow right. No duplicate
      "Login"/"Sign Up" label (heading only).
- Temporary: Login/Signup call `EmailVerificationScreen(email:)` /
  `const ForgotPasswordScreen()` without the new params so the PR builds
  alone; PR 2/3 commit the final files.

### PR 2 — `feature/auth/splash-verification` (base: PR 1)
- [x] Session-based Splash, real Log Out, deleted-account check
- [x] Verification screen redesign
- [ ] **Blocked (follow-up):** branded verification email. Firebase returns
      `EMAIL_TEMPLATE_UPDATE_NOT_ALLOWED` for template/action-URL edits on the
      free Spark plan, so emails stay Firebase's default (raw link). Revisit if
      the project moves to Blaze, then apply `docs/auth-setup.md`.
- [x] **Bug fixed, device-verified:** Menu → Logout (`app_drawer.dart`
      `_openLogin`) never called `signOut()`, so the session survived a
      relaunch. Both Menu Logout and Settings Log Out now sign out (tests).
- Files: `loading_screen.dart`, `settings_screen.dart`, `app_drawer.dart`,
  `email_verification_screen.dart`, final `login_screen.dart` /
  `signup_screen.dart`, `test/splash_verification_test.dart`.

### PR 3 — `feature/auth/password-recovery` (base: PR 2)
- [x] Reset via link works end to end (user-tested)
- [ ] **Blocked (follow-up):** branded reset email, same Firebase plan
      restriction. Hosted page is deployed (`firebase deploy --only hosting`)
      but unused until the custom action URL can be saved; reset links open
      Firebase's default page meanwhile.
- [x] Invalid pasted reset link shows "This reset link isn't valid."
      (device-verified; shortened per user)
- [x] Forgot → paste link → Create New Password → Login works (user-tested)
- Files: `forgot_password_screen.dart`, `reset_password_screen.dart`,
  `reset_link.dart`, `main.dart`, `ios/Runner/Info.plist`, `firebase.json`,
  `hosting/public/**`, delete `verification_screen.dart`, `docs/auth-setup.md`, `CLAUDE.md`,
  tests `password_recovery_test.dart`, `reset_link_test.dart`,
  `deep_link_test.dart`.

### PR 4 — `feature/legal-screens` (base: PR 1 or main after PR 1)
- [x] Structured sections, 18pt text, no draft dashes
- [ ] **Open:** add PhishNet logo at top-left beside the document heading
      ("PhishNet Terms & Conditions" / "PhishNet Privacy Policy").
- [ ] **Open (wording needs approval):** account deletion text should state
      that the account and personal info (name, email, password) are
      removed, while content the user submitted for scanning is retained by
      PhishNet to improve detection and the app experience.
- Files: `legal_content.dart`, `legal_screen.dart`,
  `terms_conditions_screen.dart`, `privacy_policy_screen.dart`,
  `test/legal_screens_test.dart`.

### Tests layout
One file per feature so PRs commit whole files: `login_signup_test.dart`,
`splash_verification_test.dart`, `password_recovery_test.dart`,
`deep_link_test.dart`, `legal_screens_test.dart`; helpers in
`test/support/`.
