/// Extracts the Firebase password-reset `oobCode` from a link.
///
/// Accepts the Firebase action URL (`...?mode=resetPassword&oobCode=...`),
/// the app scheme (`phishnet://reset-password?oobCode=...`), the in-app route
/// (`/reset-password?oobCode=...`), links nested in a `link`/`continueUrl`
/// parameter, or a bare code pasted by the user.
String? parseResetCode(String? input) {
  final text = input?.trim() ?? '';
  if (text.isEmpty) return null;

  final uri = Uri.tryParse(text);
  if (uri == null || (!text.contains('?') && !text.contains('/'))) {
    return RegExp(r'^[A-Za-z0-9_-]{10,}$').hasMatch(text) ? text : null;
  }

  final params = uri.queryParameters;
  final mode = params['mode'];
  final code = params['oobCode'];
  final isResetPath =
      uri.host == 'reset-password' || uri.path.endsWith('reset-password');
  if (code != null &&
      code.isNotEmpty &&
      (mode == 'resetPassword' || (mode == null && isResetPath))) {
    return code;
  }

  for (final key in ['link', 'continueUrl', 'deep_link_id']) {
    final nested = params[key];
    if (nested != null) return parseResetCode(nested);
  }
  return null;
}
