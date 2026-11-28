import 'package:flutter/foundation.dart';

/// Unreviewed live-monitoring alerts for the signed-in Plus user.
/// Always 0 for non-Plus users. Drives the red count on the menu and Home item.
final ValueNotifier<int> attentionCount = ValueNotifier<int>(0);
