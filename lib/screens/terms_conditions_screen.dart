import 'package:flutter/material.dart';
import 'legal_screen.dart';

class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const LegalScreen(
      title: 'Terms & Conditions',
      body: '''PhishNet Terms & Conditions

Last updated: September 5, 2026
----------------------------------------
----------------------------------------

1. Acceptance of Terms

- By creating an account or using PhishNet as a guest, you agree to these Terms & Conditions and our Privacy Policy. If you don't agree, please don't use the app.

2. What PhishNet Does

- PhishNet scans messages, links, and emails to help identify potential phishing and scam attempts, using AI models to generate a risk assessment.

- PhishNet's results are a helpful guide, not a guarantee. We cannot catch every scam or phishing attempt, and a "safe" result doesn't mean a message is 100% trustworthy. Always use your own judgment, especially with anything asking for money, passwords, or personal information.

3. Your Account

- You're responsible for keeping your login credentials secure

- You must be old enough to legally use this app in your region

- You're responsible for any activity that happens under your account

4. Email Access (Live Monitoring)

- If you choose to connect a Yahoo (or other) email account, you're granting PhishNet read-only access to scan incoming messages, as described in our Privacy Policy. You can disconnect this at any time in Settings.

5. Family/Social Sharing

- Sharing a scan result is your choice and happens through your device's native share feature, not through PhishNet's servers. You're responsible for what you choose to share and with whom. PhishNet isn't responsible for how a recipient uses or responds to shared content.

6. Acceptable Use

You agree not to:

- Use PhishNet for anything illegal or to harm others

- Try to break, reverse-engineer, or interfere with the app

- Impersonate someone else when creating an account

7. No Liability

- PhishNet is provided "as is." We're not liable for losses resulting from a scam or phishing attempt that our detection missed, or a legitimate message flagged incorrectly. Use PhishNet as one layer of protection, not your only one.

8. Changes to These Terms

- We may update these Terms occasionally. Continued use of the app after changes means you accept the updated Terms.

9. Contact Us

- Questions about these Terms? Reach us at phishnet05@gmail.com

----------------------------------------
----------------------------------------''',
    );
  }
}
