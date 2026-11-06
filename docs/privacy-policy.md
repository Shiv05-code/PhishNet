# PhishNet Privacy Policy

Last updated: October 20, 2026

> **Draft.** Review before publishing. Live Monitoring is in development and is not yet available to users. Sections on it describe planned behavior and will be updated when it ships.

## What We Collect

**Account information**
- Email address and password, or "Continue as Guest" (no account data is collected).

**Scanned content**
- Messages, links, and files you paste or upload for scanning (Capture feature).
- If you connect a Yahoo (or other) email account for Live Monitoring, we read incoming messages using read-only access to check for phishing signs. See [Email Access (Live Monitoring)](#email-access-live-monitoring).

**Usage and detection data**
- Your scan history, flagged results, and risk scores (History and Results pages).
- Messages you send to the AI Chat assistant, so it can answer your questions.

**Family/Social data**
- Contacts you choose to add as "Trusted Contacts."
- Scan alerts or messages you choose to share with those contacts.

## How We Use It

- To scan messages and links and produce a phishing risk score.
- To power the AI Chat assistant's answers about a specific scan.
- To show your scan history and trends (Recent Detections, Scan Activity).
- We do not sell your data.
- We do not use the content of your emails for advertising.

## Email Access (Live Monitoring)

If you connect an email account:
- We request **read-only** access. PhishNet cannot send, delete, or modify your emails.
- We read only the message content needed to detect phishing (sender, links, subject, and body).
- You can disconnect at any time in Settings. Disconnecting removes our stored access.
- **Retention:** we have not yet set how long email content read for Live Monitoring is kept. This policy will state that period before Live Monitoring is offered.
- We follow Yahoo's API developer policies for data use and retention.

## Family/Social Sharing

- You control all sharing. PhishNet does not share, send, or notify anyone on your behalf.
- Before sharing, you see exactly what will be shared: the message you flagged and PhishNet's analysis of it.
- Sharing uses your device's share sheet, so you choose who to send it to and how.
- Recipients do not need a PhishNet account to view what you send.
- Because sharing happens on your device and not through our servers, we do not collect or see what you send or how the recipient responds.

## Data Storage and Retention

**Transient processing**
- Message text you submit is sent to our backend and to Anthropic's Claude API to generate a result.
- Our backend does not save message text or write it to logs.
- Anthropic's handling of API requests is governed by Anthropic's own terms.

**Stored results**
- The analysis result (brief description, scam-risk score, risk level, summary, red flags, and next steps) and a timestamp are saved to your account so you can view your history.
- The summary may refer to details from the message.
- Stored results are kept while your account exists. We do not delete them automatically for inactivity.

**Account deletion**
- When you delete your account (Settings → Delete My Account), we permanently delete the scan records linked to your account, your profile, and your sign-in account, including your name, email address, and password.
- Copies of each scan's derived assessment remain in a separate collection with no user ID, name, or email address. These copies are no longer linked to your account.
- Those copies keep the analysis fields. A summary or red flags may still include details from the scanned message.
- Full message text is not stored, so it is not part of those copies.

**Model improvement**
- The unlinked assessment copies may be used for future model improvement. Model training is not currently implemented.

## Third-Party Services

- **Yahoo Mail API** (for Live Monitoring only), under Yahoo's developer terms.
- **Anthropic's Claude** generates scam analysis results. Message text you submit for scanning is sent to Claude to produce your result. Claude models also power the AI Chat assistant's responses.
- **Firebase** (authentication and database) and **Amazon Web Services** (hosting and secrets storage) support the app.

## Your Rights and Choices

- Delete your account anytime in Settings.
- Disconnect email monitoring anytime in Settings.
- Contact us with privacy questions at phishnet05@gmail.com.

## Children's Privacy

PhishNet is not directed at children under 13. This policy applies to people who use the app directly (create an account or use it as a guest). Sharing a result with a family member or friend does not create an account for them or collect data about them.

## Changes to This Policy

We will notify you in the app if we make material changes to this policy and update the "Last updated" date.

## Contact Us

Questions about this policy or your data: phishnet05@gmail.com
