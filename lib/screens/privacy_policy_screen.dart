import 'package:flutter/material.dart';
import 'legal_content.dart';
import 'legal_screen.dart';

/// Approved content — do not change wording without approval.
const privacyPolicyDocument = LegalDocument(
  heading: 'PhishNet Privacy Policy',
  lastUpdated: 'November 14, 2026',
  sections: [
    LegalSection(
      title: 'What We Collect',
      blocks: [
        LegalSubheading('Account Information:'),
        LegalBullet(
          'Email address and password, or "Continue as Guest" (no account data collected)',
        ),
        LegalSubheading('Scanned Content:'),
        LegalBullet(
          'Messages, links, and files you upload or paste for scanning (Capture)',
        ),
        LegalBullet(
          'If you connect a Yahoo or other email account for Live Monitoring, we read your inbox with read-only permission to scan incoming messages for phishing',
        ),
        LegalSubheading('Usage & Detection Data:'),
        LegalBullet(
          'Your scan history, flagged results, and risk scores (History and Results)',
        ),
        LegalBullet('Messages you send to the AI Chat assistant'),
        LegalSubheading('Family/Social Data:'),
        LegalBullet('Contacts you add as "**Trusted Contacts**"'),
        LegalBullet(
          '**Phone numbers** for Trusted Contacts, taken from your device contacts only when you choose to add someone. We store them in your account so Messages can open to that contact. They are deleted when you remove the contact or delete your account.',
        ),
        LegalBullet(
          'Scan results or messages you choose to share with those contacts',
        ),
      ],
    ),
    LegalSection(
      title: 'How We Use It',
      blocks: [
        LegalBullet(
          'To scan messages and links and generate a phishing risk score',
        ),
        LegalBullet('To power AI Chat answers about a specific scan'),
        LegalBullet(
          'To show your scan history and trends (Recent Detections, Scan Activity)',
        ),
        LegalBullet(
          'Possible future model improvement, using the unlinked assessment copies kept after account deletion (model training is not currently implemented)',
        ),
        LegalBullet(
          '**We do not sell your data.** We do not use your email content for advertising.',
        ),
      ],
    ),
    LegalSection(
      title: 'Email Access (Live Monitoring)',
      blocks: [
        LegalSubheading('If you connect an email account:'),
        LegalBullet(
          'We request **read-only access**. PhishNet **cannot send, delete, or modify** your emails.',
        ),
        LegalBullet(
          'We read only the message metadata and content needed to detect phishing (sender, links, subject, and body)',
        ),
        LegalBullet(
          'We have not yet set how long Live Monitoring email content is kept. This policy will state that period before Live Monitoring is offered.',
        ),
        LegalBullet(
          'You can disconnect access at any time in Settings. This immediately revokes our access token.',
        ),
        LegalBullet(
          'We follow Yahoo\'s (and other providers\') API developer policies for data use and retention',
        ),
      ],
    ),
    LegalSection(
      title: 'Family/Social Sharing',
      blocks: [
        LegalBullet(
          'Sharing is **entirely controlled by you**. PhishNet does not share, send, or notify anyone on your behalf.',
        ),
        LegalBullet(
          'Before you share, we show exactly what will be shared: the message you flagged and PhishNet\'s analysis of it',
        ),
        LegalBullet(
          'When you tap "Message" on a Trusted Contact, PhishNet opens Messages to that contact\'s number with the scan filled in. You tap Send yourself. PhishNet **never sends a message** for you.',
        ),
        LegalBullet(
          'When you tap "Share," your device\'s share sheet opens, so you choose who receives it and how (text, email, etc.)',
        ),
        LegalBullet(
          'Recipients don\'t need a PhishNet account or the app to view what you send. Any further conversation happens outside PhishNet, for example in Messages or email.',
        ),
        LegalBullet(
          'Sharing happens on your device, not on our servers. We don\'t collect or see what you send or how the recipient responds.',
        ),
      ],
    ),
    LegalSection(
      title: 'Data Storage & Retention',
      blocks: [
        LegalSubheading('Transient processing:'),
        LegalBullet(
          'Message text you submit is sent to our backend and to Anthropic\'s Claude API to generate a result. Our backend does not save or log the message text. Anthropic\'s handling of API requests is governed by Anthropic\'s terms.',
        ),
        LegalSubheading('Stored results:'),
        LegalBullet(
          'The analysis result (brief description, scam-risk score, risk level, summary, red flags, and next steps) and a timestamp are saved to your account for your scan history. The summary may refer to details from the message.',
        ),
        LegalBullet(
          'Stored results are kept while your account exists. We don\'t delete them automatically for inactivity.',
        ),
        LegalSubheading('Account deletion (Settings → Delete My Account):'),
        LegalBullet(
          'We permanently delete your scan records, Trusted Contacts (including phone numbers), profile, and sign-in account, including your name, email address, and password.',
        ),
        LegalBullet(
          'A copy of each scan\'s analysis remains in a separate collection with no user ID, name, or email address. These copies are no longer linked to your account.',
        ),
        LegalBullet(
          'Those copies keep the analysis fields. A summary or red flags may still contain identifying details from the scanned message. The full message text is not stored, so it is not part of the copies.',
        ),
        LegalSubheading('Model improvement:'),
        LegalBullet(
          'These unlinked copies are kept for possible future model improvement. Model training is not currently implemented.',
        ),
      ],
    ),
    LegalSection(
      title: 'Third-Party Services',
      blocks: [
        LegalBullet(
          'The Yahoo Mail API (and other email provider APIs, if applicable) is used only for Live Monitoring, under those providers\' developer terms',
        ),
        LegalBullet(
          'Anthropic\'s Claude models generate scam analysis results. Message text you submit is sent to Claude to produce your result (see Data Storage & Retention). Claude models also power AI Chat responses.',
        ),
      ],
    ),
    LegalSection(
      title: 'Your Rights & Choices',
      blocks: [
        LegalBullet('Delete your account anytime in Settings'),
        LegalBullet('Disconnect email monitoring anytime'),
        LegalBullet(
          'Contact us with privacy questions at **phishnet05@gmail.com**',
        ),
      ],
    ),
    LegalSection(
      title: 'Children\'s Privacy',
      blocks: [
        LegalBullet('PhishNet is not directed at children under 13.'),
        LegalBullet(
          'We collect data only from people who use the app directly, by creating an account or using it as a guest.',
        ),
        LegalBullet(
          'Sharing a scan through the share sheet does not create an account for, contact, or collect data about the recipient.',
        ),
      ],
    ),
    LegalSection(
      title: 'Changes to This Policy',
      blocks: [
        LegalBullet(
          'We\'ll notify you in the app of material changes and update the "Last updated" date above.',
        ),
      ],
    ),
    LegalSection(
      title: 'Contact Us',
      blocks: [
        LegalBullet(
          'Questions about this policy or your data? Reach us at **phishnet05@gmail.com**',
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
