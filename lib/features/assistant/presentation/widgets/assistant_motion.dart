import 'package:flutter/widgets.dart';

/// Animation length for the assistant, or none when the platform asks to
/// reduce motion.
Duration assistantMotion(BuildContext context, int milliseconds) =>
    MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context)
    ? Duration.zero
    : Duration(milliseconds: milliseconds);
