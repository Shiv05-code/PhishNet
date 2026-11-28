import 'dart:typed_data';

import 'package:flutter/services.dart';

/// Result of opening the system message composer.
enum MessageComposeResult { sent, cancelled, failed, unavailable }

/// Opens Messages with a recipient and body already filled in. The user
/// still taps Send, which iOS requires.
abstract interface class MessageComposer {
  Future<MessageComposeResult> compose({
    required String recipient,
    required String body,
    Uint8List? logo,
  });
}

/// Uses the native iOS message composer through the app's method channel.
class ChannelMessageComposer implements MessageComposer {
  static const _channel = MethodChannel('phishnet/message_composer');

  @override
  Future<MessageComposeResult> compose({
    required String recipient,
    required String body,
    Uint8List? logo,
  }) async {
    try {
      final status = await _channel.invokeMethod<String>('compose', {
        'recipient': recipient,
        'body': body,
        'logo': logo,
      });
      return switch (status) {
        'sent' => MessageComposeResult.sent,
        'cancelled' => MessageComposeResult.cancelled,
        'unavailable' => MessageComposeResult.unavailable,
        _ => MessageComposeResult.failed,
      };
    } on MissingPluginException {
      return MessageComposeResult.unavailable;
    } on PlatformException {
      return MessageComposeResult.failed;
    }
  }
}
