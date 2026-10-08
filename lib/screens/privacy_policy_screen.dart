import 'package:flutter/material.dart';
import 'legal_content.dart';
import 'legal_screen.dart';

/// Approved content — do not change wording without approval.
const privacyPolicyDocument = LegalDocument(
  heading: 'PhishNet Privacy Policy',
  lastUpdated: 'October 7, 2026',
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
        LegalBullet(
          'Any content scanned or provided to us through the app may be stored and used to train our detection models and improve the app experience',
        ),
        LegalSubheading('Usage & Detection Data:'),
        LegalBullet(
          'Your scan history, flagged results, and risk scores (History, Results pages)',
        ),
        LegalBullet(
          'Messages you send to the AI Chat assistant, to provide answers and improve detection accuracy',
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
        LegalBullet('To train and improve our phishing detection models'),
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
          'Information we read or that you otherwise provide through the app may be stored by us and used to train our models and improve the app for all users',
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
        LegalBullet(
          'Scan results and history are stored securely and linked to your account',
        ),
        LegalBullet(
          'We keep your data as long as your account exists — there\'s no automatic deletion for inactivity',
        ),
        LegalBullet(
          'If you delete your account (Settings → Delete My Account), we '
          'permanently delete your PhishNet account and the account details '
          'linked to it — your name, email address, and password — and revoke '
          'any connected email access.',
        ),
        LegalBullet(
          'Content you submitted to PhishNet, including scanned messages, links, '
          'and files, their analysis results, and AI Chat conversations, is '
          'retained and may be used to improve our detection models and the app '
          'experience. After deletion, this content is no longer associated with '
          'your account, but any personal information you included within it '
          '(such as a name or address in a scanned message) may remain.',
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
          'We use Anthropic\'s Claude AI models to power core features of the app:',
        ),
        LegalBullet(
          'Claude Haiku 3.5 — scans and classifies messages for phishing risk (Capture/Results)',
        ),
        LegalBullet(
          'Claude Sonnet 4 — powers the AI Chat assistant\'s responses',
        ),
        LegalBullet(
          'Claude Haiku 3.5 may also power other in-app AI features, such as Results page insights or chat-based agents',
        ),
        LegalBullet(
          'Content sent to these models is processed to generate your results and chat responses, and may be retained by us as described in Section 1 to improve detection accuracy',
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
