# Authentication setup and testing

Team guide for PhishNet sign-in, verification, and password reset.
Values in `<angle brackets>` are placeholders; get the real values from the
team's private channel. Never commit credentials or personal emails.

## Flow overview

- **Splash** (3s) → Home for a verified session, otherwise Login.
- **Signup** (first name, last name, email, password) → verification email →
  **Check Your Email** screen → Home. Name is stored as the Firebase Auth
  `displayName` ("First Last"); Home greets with the first word.
- **Forgot Password** always shows the same "If an account exists…" message,
  so it never reveals whether an email is registered.
- **Reset link** → hosted handoff page → app **Reset Password** screen →
  new password → Login.

## Firebase Console (manual, one time)

> [!WARNING]
> On the free Spark plan Firebase rejects template and action-URL edits
> (`EMAIL_TEMPLATE_UPDATE_NOT_ALLOWED`). Until the project is on Blaze,
> emails use Firebase's default text and links open Firebase's own page.
> Steps 3–5 below apply once edits are allowed.

1. Authentication → Sign-in method → enable **Email/Password**.
2. Authentication → Settings → keep **Email enumeration protection** on.
3. Project settings → General → Public-facing name: `PhishNet`.
4. Authentication → Templates → **Password reset** → edit:
   - Sender name: `PhishNet` · Reply-to: `<team support email>`
   - Subject: `Reset your PhishNet password`
   - Message:

     ```html
     <p>Hello,</p>
     <p>We received a request to reset the password for your PhishNet
     account (%EMAIL%).</p>
     <p><a href="%LINK%" style="display:inline-block;padding:14px 24px;
     background:#2479A6;color:#ffffff;border-radius:12px;font-weight:700;
     text-decoration:none;font-size:18px">Reset Password</a></p>
     <p>Open this email on the iPhone where PhishNet is installed. The link
     works once and expires in about an hour.</p>
     <p>Didn't ask for this? You can safely ignore this email; your password
     won't change.</p>
     <p>— The PhishNet team</p>
     ```

   - *Customize action URL*: `https://<hosting-domain>/auth/action/` (keep the trailing slash)
     (this one setting applies to every template, including verification).
5. Authentication → Templates → **Email address verification** → edit:
   - Sender name: `PhishNet` · Reply-to: `<team support email>`
   - Subject: `Verify your email for PhishNet`
   - Message:

     ```html
     <p>Hello %DISPLAY_NAME%,</p>
     <p>Welcome to PhishNet! Please confirm this is your email address
     (%EMAIL%) by tapping the button below.</p>
     <p><a href="%LINK%" style="display:inline-block;padding:14px 24px;
     background:#2479A6;color:#ffffff;border-radius:12px;font-weight:700;
     text-decoration:none;font-size:18px">Verify Email</a></p>
     <p>Then return to the PhishNet app and tap
     <b>I've Verified My Email</b>.</p>
     <p>Didn't create a PhishNet account? You can safely ignore this
     email.</p>
     <p>— The PhishNet team</p>
     ```

   Putting `%LINK%` inside a button hides the long raw link.

## Hosted handoff page

`hosting/public/auth/action/index.html` receives Firebase action links.
It shows the PhishNet logo and name on a large-text card for both actions,
and never displays the code:

- **verifyEmail:** verifies on the page (Identity Toolkit `accounts:update`
  with the link's API key), then shows "Your email is verified" with
  **Open PhishNet** (`phishnet://app/email-verified`, which re-checks the
  session and opens Home). Expired/used links show a Resend hint.
- **resetPassword:** opens `phishnet://app/reset-password?oobCode=…` with an
  **Open PhishNet** button and a browser fallback.
- Other actions forward to Firebase's default page.

The `phishnet` scheme is registered in `ios/Runner/Info.plist` with
`FlutterDeepLinkingEnabled`. Redeploy Hosting after editing the page.

Deploy (requires project access):

```bash
firebase login
firebase deploy --only hosting --project <firebase-project-id>
```

Preview: `https://<hosting-domain>/auth/action?mode=resetPassword&oobCode=test`

In the app, `lib/main.dart` (`onGenerateRoute`) parses links with
`lib/services/reset_link.dart` and opens `ResetPasswordScreen`. If the app
doesn't open, users can paste the link via **I have a reset link**.

## Testing

Automated: `dart format lib test`, `flutter analyze lib test`, `flutter test`.
Widget tests use `test/support/fake_auth_service.dart` (no Firebase needed).

Simulator deep link:

```bash
xcrun simctl openurl booted "phishnet://app/reset-password?oobCode=<code>"
```

Real iPhone end-to-end (use a test account):

1. `flutter run` on the device → Login → Forgot Password → request a reset.
2. Open the email in Mail; check sender, subject, and the **Reset Password** button.
3. Tap it → the hosted PhishNet card opens the app on **Create New Password**.
4. Save → **Password Updated** → Login with the new password.
5. Tap the same link again → **Link Expired** with **Request New Link**.
