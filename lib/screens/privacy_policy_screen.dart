import 'package:flutter/material.dart';
import 'legal_screen.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const LegalScreen(
      title: 'Privacy Policy',
      body: '''PhishNet Privacy Policy

Last updated: September 5, 2026
----------------------------------------
----------------------------------------

1. What We Collect

Account Information:

- Email address and password (or "Continue as Guest" — no account data collected)

Scanned Content:

- Messages, links, and files you manually upload or paste for scanning (Capture feature)

- If you connect a Yahoo (or other) email account for Live Monitoring, we access your inbox using read-only permissions to scan incoming messages for phishing indicators

- Any content scanned or provided to us through the app may be stored and used to train our detection models and improve the app experience

Usage & Detection Data:

- Your scan history, flagged results, and risk scores (History, Results pages)

- Messages you send to the AI Chat assistant, to provide answers and improve detection accuracy

Family/Social Data:

- Contacts you choose to add as "Trusted Contacts"

- Scan alerts or messages you choose to share with those contacts.

2. How We Use It

- To scan messages/links and generate a phishing risk score

- To power the AI Chat assistant's answers about a specific scan

- To show you your scan history and trends (Recent Detections, Scan Activity)

- To train and improve our phishing detection models

- We do not sell your data. We do not use the content of your emails for advertising

3. Email Access (Live Monitoring)

If you connect an email account:

- We request read-only access — PhishNet cannot send, delete, or modify your emails

- We only read message metadata and content necessary to detect phishing (sender, links, subject/body)

- Information we read or that you otherwise provide through the app may be stored by us and used to train our models and improve the app for all users

- You can disconnect this access at any time in Settings, which immediately revokes our access token

- We comply with Yahoo's (and other providers') API developer policies regarding data use and retention

4. Family/Social Sharing

- Sharing is entirely controlled by you — PhishNet does not share, send, or notify anyone on your behalf

- Before sharing, we show you exactly what will be shared: the message you flagged and PhishNet's analysis of it

- When you tap "Share," PhishNet hands off to your device's native share sheet (iOS), so you choose who to send it to and how (text, email, etc.)

- Anyone you share with does not need a PhishNet account or the app itself to receive or view what you send — it's a normal message on their end, and any further conversation happens outside PhishNet entirely (e.g. in Messages or email)

- Because the share happens through your device and not our servers, we don't collect, store, or have any visibility into what you send or how the recipient responds

5. Data Storage & Retention

- Scan results and history are stored securely and linked to your account

- We keep your data as long as your account exists — there's no automatic deletion for inactivity

- If you delete your account or use "Delete my Data" (Settings), we permanently remove your scan history, chat logs, and revoke any connected email access

6. Third-Party Services

- We use the Yahoo Mail API (and other email provider APIs, if applicable) solely to enable Live Monitoring, under their respective developer terms

We use Anthropic's Claude AI models to power core features of the app:

- Claude Haiku 3.5 — scans and classifies messages for phishing risk (Capture/Results)

- Claude Sonnet 4 — powers the AI Chat assistant's responses

- Claude Haiku 3.5 may also power other in-app AI features, such as Results page insights or chat-based agents

- Content sent to these models is processed to generate your results and chat responses, and may be retained by us as described in Section 1 to improve detection accuracy

7. Your Rights & Choices

- Delete your data anytime via Settings

- Disconnect email monitoring anytime

- Contact us with privacy questions at phishnet05@gmail.com

8. Children's Privacy

- PhishNet is not directed at children under 13. This policy's data collection applies only to people who use the app directly (create an account or use it as a guest). Sharing a scan result with a family member or friend through the native share sheet does not create an account for them, direct them to download the app, or collect any data about them — so this doesn't extend to whoever you choose to share with.

9. Changes to This Policy

- We'll notify you in-app if we make material changes to this policy, and update the "Last updated" date above.

10. Contact Us

- Questions about this policy or your data? Reach us at phishnet05@gmail.com

- Or manage your data directly: Delete My Data →

----------------------------------------
----------------------------------------''',
    );
  }
}
