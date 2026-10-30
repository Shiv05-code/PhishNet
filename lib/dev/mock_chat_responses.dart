/// Sample AI answers for previewing how chat formatting, typing and copy look.
///
/// Development only. These are never used by the real chat: they are served
/// only by the preview entry point (lib/dev/chat_preview_main.dart), which
/// hands them to a ChatService through a fake HTTP client.
class MockChatResponse {
  const MockChatResponse({required this.title, required this.answer});

  /// What this sample demonstrates, for the preview's reference only.
  final String title;
  final String answer;
}

const mockChatResponses = [
  MockChatResponse(
    title: 'Structured answer with headings and bullets',
    answer: '''## 🔍 What this message is doing
This looks like a **package delivery scam**. It creates urgency and asks for a small fee.

## ⚠️ Warning signs
- The link goes to **usps-redelivery.top**, not usps.com
- It asks you to pay a fee to receive a package
- It says your package will be returned **within 24 hours**

## ✅ What to do
- Do not click the link or enter any card details
- Go to the official site yourself to check tracking
- Delete the message and report it as spam''',
  ),
  MockChatResponse(
    title: 'Short answer with bold emphasis',
    answer:
        'Yes, **do not** click that link. Real banks will never ask you to confirm your password by text message. 🚫',
  ),
  MockChatResponse(
    title: 'Plain answer with a reassuring tone',
    answer:
        'Good call asking first. 👍 Take a breath. You have not done anything wrong by reading this message.\n\nIf you already clicked, change your password right away and call the bank using the number on the back of your card.',
  ),
  MockChatResponse(
    title: 'Steps with numbers and icons',
    answer: '''## 📋 Quick steps
- **1.** Do not reply or call the number in the message
- **2.** Forward the text to **7726** (SPAM) on most phones
- **3.** Block the sender
- **4.** If you shared a code, call your bank now 📞''',
  ),
  MockChatResponse(
    title: 'Medium-risk answer with a question back',
    answer:
        'This one is **hard to be sure about**. The sender name looks familiar, but the link is unusual. 🤔\n\nDid you order something recently from this store? If not, treat it as a scam.',
  ),
];
