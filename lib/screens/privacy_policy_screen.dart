import 'package:flutter/material.dart';
import 'legal_content.dart';
import 'legal_screen.dart';

/// Approved content — do not change wording without approval.
const privacyPolicyDocument = LegalDocument(
  heading: 'PhishNet Privacy Policy',
  lastUpdated: 'October 20, 2026',
  sections: [
    LegalSection(
      title: 'What We Collect',
      blocks: [
        LegalSubheading('Account Information:'),
        LegalBullet(
          'Email address and password (or "Continue as Guest" — no account data collected)',
        ),
        LegalSubheading('Scanned Content:'),
        LegalBullet(
          'Messages, links, and files you manually upload or paste for scanning (Capture feature)',
        ),
        LegalBullet(
          'If you connect a Yahoo (or other) email account for Live Monitoring, we access your inbox using read-only permissions to scan incoming messages for phishing indicators',
        ),
        LegalSubheading('Usage & Detection Data:'),
        LegalBullet(
          'Your scan history, flagged results, and risk scores (History, Results pages)',
        ),
        LegalBullet(
          'Messages you send to the AI Chat assistant, to provide answers',
        ),
        LegalSubheading('Family/Social Data:'),
        LegalBullet('Contacts you choose to add as "Trusted Contacts"'),
        LegalBullet(
          'Scan alerts or messages you choose to share with those contacts.',
        ),
      ],
    ),
    LegalSection(
      title: 'How We Use It',
      blocks: [
        LegalBullet(
          'To scan messages/links and generate a phishing risk score',
        ),
        LegalBullet(
          'To power the AI Chat assistant\'s answers about a specific scan',
        ),
        LegalBullet(
          'To show you your scan history and trends (Recent Detections, Scan Activity)',
        ),
        LegalBullet(
          'Possible future model improvement, using the unlinked assessment copies kept after account deletion (model training is not currently implemented)',
        ),
        LegalBullet(
          'We do not sell your data. We do not use the content of your emails for advertising',
        ),
      ],
    ),
    LegalSection(
      title: 'Email Access (Live Monitoring)',
      blocks: [
        LegalSubheading('If you connect an email account:'),
        LegalBullet(
          'We request read-only access — PhishNet cannot send, delete, or modify your emails',
        ),
        LegalBullet(
          'We only read message metadata and content necessary to detect phishing (sender, links, subject/body)',
        ),
        LegalBullet(
          'We have not yet set how long email content read for Live Monitoring is kept. This policy will state that retention period before Live Monitoring is offered',
        ),
        LegalBullet(
          'You can disconnect this access at any time in Settings, which immediately revokes our access token',
        ),
        LegalBullet(
          'We comply with Yahoo\'s (and other providers\') API developer policies regarding data use and retention',
        ),
      ],
    ),
    LegalSection(
      title: 'Family/Social Sharing',
      blocks: [
        LegalBullet(
          'Sharing is entirely controlled by you — PhishNet does not share, send, or notify anyone on your behalf',
        ),
        LegalBullet(
          'Before sharing, we show you exactly what will be shared: the message you flagged and PhishNet\'s analysis of it',
        ),
        LegalBullet(
          'When you tap "Share," PhishNet hands off to your device\'s native share sheet (iOS), so you choose who to send it to and how (text, email, etc.)',
        ),
        LegalBullet(
          'Anyone you share with does not need a PhishNet account or the app itself to receive or view what you send — it\'s a normal message on their end, and any further conversation happens outside PhishNet entirely (e.g. in Messages or email)',
        ),
        LegalBullet(
          'Because the share happens through your device and not our servers, we don\'t collect, store, or have any visibility into what you send or how the recipient responds',
        ),
      ],
    ),
    LegalSection(
      title: 'Data Storage & Retention',
      blocks: [
        LegalSubheading('Transient processing:'),
        LegalBullet(
          'Message text you submit is sent to our backend and to Anthropic\'s Claude API to generate a result. Our backend does not save the message text and does not write it to logs. Anthropic\'s handling of API requests is governed by Anthropic\'s own terms',
        ),
        LegalSubheading('Stored results:'),
        LegalBullet(
          'The analysis result (brief description, scam-risk score, risk level, summary, red flags, and next steps) and a timestamp are saved to your account so you can view your scan history. The summary may refer to details from the message',
        ),
        LegalBullet(
          'Stored results are kept while your account exists. We do not delete them automatically for inactivity',
        ),
        LegalSubheading('Account deletion:'),
        LegalBullet(
          'When you delete your account (Settings → Delete My Account), we permanently delete the scan records linked to your account, your profile, and your PhishNet sign-in account, including your name, email address, and password',
        ),
        LegalBullet(
          'Copies of each scan\'s derived assessment remain after deletion, in a separate collection with no user ID, name, or email address. These copies are no longer linked to your account',
        ),
        LegalBullet(
          'Those copies keep the analysis fields (brief description, scam-risk score, risk level, summary, red flags, and next steps). A summary or red flags may still contain identifying information from a scanned message, and that information remains in the copy even though it is no longer linked to your account',
        ),
        LegalBullet(
          'The full message text is not stored, so it is not part of those copies',
        ),
        LegalSubheading('Model improvement:'),
        LegalBullet(
          'Those unlinked assessment copies are kept for possible future model improvement. Model training is not currently implemented',
        ),
      ],
    ),
    LegalSection(
      title: 'Third-Party Services',
      blocks: [
        LegalBullet(
          'We use the Yahoo Mail API (and other email provider APIs, if applicable) solely to enable Live Monitoring, under their respective developer terms',
        ),
        LegalSubheading(
          'We use Anthropic\'s Claude AI models to generate scam analysis results:',
        ),
        LegalBullet(
          'Message text you submit for scanning is sent to Claude to produce your result (see Data Storage & Retention)',
        ),
        LegalBullet(
          'Claude models also power the AI Chat assistant\'s responses',
        ),
      ],
    ),
    LegalSection(
      title: 'Your Rights & Choices',
      blocks: [
        LegalBullet('Delete your account anytime via Settings'),
        LegalBullet('Disconnect email monitoring anytime'),
        LegalBullet(
          'Contact us with privacy questions at phishnet05@gmail.com',
        ),
      ],
    ),
    LegalSection(
      title: 'Children\'s Privacy',
      blocks: [
        LegalBullet(
          'PhishNet is not directed at children under 13. This policy\'s data collection applies only to people who use the app directly (create an account or use it as a guest). Sharing a scan result with a family member or friend through the native share sheet does not create an account for them, direct them to download the app, or collect any data about them — so this doesn\'t extend to whoever you choose to share with.',
        ),
      ],
    ),
    LegalSection(
      title: 'Changes to This Policy',
      blocks: [
        LegalBullet(
          'We\'ll notify you in-app if we make material changes to this policy, and update the "Last updated" date above.',
        ),
      ],
    ),
    LegalSection(
      title: 'Contact Us',
      blocks: [
        LegalBullet(
          'Questions about this policy or your data? Reach us at phishnet05@gmail.com',
        ),
        LegalBullet('Or manage your account directly: Delete My Account →'),
      ],
    ),
  ],
);

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const LegalScreen(
      title: 'Privacy Policy',
      document: privacyPolicyDocument,
    );
  }
}
