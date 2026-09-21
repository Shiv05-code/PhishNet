final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

String? validateSignupEmail(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) return 'Enter your email.';
  if (!_emailPattern.hasMatch(email)) return 'Enter a valid email address.';

  final domain = email.split('@').last.toLowerCase();
  if (domain != 'gmail.com' && domain != 'yahoo.com') {
    return 'Use a Gmail or Yahoo email address.';
  }
  return null;
}

String? validateSignupPassword(String? value) {
  final password = value ?? '';
  if (password.length < 8) return 'Use at least 8 characters.';

  final missing = <String>[
    if (!RegExp(r'[A-Za-z]').hasMatch(password)) 'letter',
    if (!RegExp(r'\d').hasMatch(password)) 'number',
    if (!RegExp(r'[^A-Za-z0-9]').hasMatch(password)) 'symbol',
  ];
  if (missing.isEmpty) return null;
  if (missing.length == 1) {
    return 'Weak password. Add a ${missing.single}.';
  }
  if (missing.length == 2) {
    return 'Weak password. Add a ${missing[0]} and ${missing[1]}.';
  }
  return 'Weak password. Add a letter, number, and symbol.';
}

String? validateConfirmPassword(String? value, String password) {
  if ((value ?? '').isEmpty) return 'Re-enter your password.';
  if (value != password) return 'Passwords do not match.';
  return null;
}
