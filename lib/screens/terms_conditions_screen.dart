import 'package:flutter/material.dart';
import 'legal_content.dart';
import 'legal_screen.dart';

/// Approved content — do not change wording without approval.
const termsConditionsDocument = LegalDocument(
  heading: 'PhishNet Terms & Conditions',
  lastUpdated: 'November 14, 2026',
  sections: [
    LegalSection(
      title: 'Acceptance of Terms',
      blocks: [
        LegalBullet(
          'By creating an account or using PhishNet as a guest, you agree to these Terms & Conditions and our Privacy Policy. If you don\'t agree, please don\'t use the app.',
        ),
      ],
    ),
    LegalSection(
      title: 'What PhishNet Does',
      blocks: [
        LegalBullet(
          'PhishNet scans messages, links, and emails to help identify phishing and scam attempts, using AI models to generate a risk assessment.',
        ),
        LegalBullet(
          'PhishNet\'s results are a helpful guide, **not a guarantee**. We can\'t catch every scam, and a "safe" result doesn\'t mean a message is 100% trustworthy. Use your own judgment, especially with requests for money, passwords, or personal information.',
        ),
      ],
    ),
    LegalSection(
      title: 'Your Account',
      blocks: [
        LegalBullet(
          'You\'re responsible for keeping your login credentials secure.',
        ),
        LegalBullet(
          'You must be old enough to use this app legally in your region.',
        ),
        LegalBullet('You\'re responsible for all activity under your account.'),
      ],
    ),
    LegalSection(
      title: 'Email Access (Live Monitoring)',
      blocks: [
        LegalBullet(
          'If you connect a Yahoo or other email account, you grant PhishNet read-only access to scan incoming messages, as described in our Privacy Policy. You can disconnect at any time in Settings.',
        ),
      ],
    ),
    LegalSection(
      title: 'Family/Social Sharing',
      blocks: [
        LegalBullet(
          'Sharing a scan result is your choice. It happens through your device\'s share feature, not through PhishNet\'s servers. You\'re responsible for what you share and with whom. PhishNet isn\'t responsible for how a recipient uses or responds to shared content.',
        ),
        LegalBullet(
          'If you add a contact to PhishNet, you **give us permission to hold onto it for you** as a convenience for Trusted Contacts.',
        ),
        LegalBullet(
          'You confirm that any phone number you save is correct and that you have the contact\'s permission to store it. Messages to a Trusted Contact are sent from your own Messages app, and you decide whether to send them.',
        ),
      ],
    ),
    LegalSection(
      title: 'Acceptable Use',
      blocks: [
        LegalSubheading('You agree not to:'),
        LegalBullet('Use PhishNet for anything illegal or to harm others'),
        LegalBullet(
          'Try to break, reverse-engineer, or interfere with the app',
        ),
        LegalBullet('Impersonate someone else when creating an account'),
      ],
    ),
    LegalSection(
      title: 'No Liability',
      blocks: [
        LegalBullet(
          'PhishNet is provided "as is." We\'re not liable for losses from a scam or phishing attempt our detection missed, or from a legitimate message flagged in error. Use PhishNet as one layer of protection, not your only one.',
        ),
      ],
    ),
    LegalSection(
      title: 'Changes to These Terms',
      blocks: [
        LegalBullet(
          'We may update these Terms occasionally. Continued use of the app after changes means you accept the updated Terms.',
        ),
      ],
    ),
    LegalSection(
      title: 'Contact Us',
      blocks: [
        LegalBullet(
          'Questions about these Terms? Reach us at **phishnet05@gmail.com**',
        ),
      ],
    ),
  ],
);

class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const LegalScreen(
      title: 'Terms & Conditions',
      document: termsConditionsDocument,
    );
  }
}
