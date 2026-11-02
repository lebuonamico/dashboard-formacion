import 'package:flutter/widgets.dart';

/// Free strip at the bottom of every screen: the AI assistant button and,
/// in the deploy, the Netlify badge float there without covering content.
/// Screens with paginated tables size their rows with the remaining height.
const double bottomFloatingReserve = 48;

/// Content margin of every screen, below the top bar.
const EdgeInsets screenPadding = EdgeInsets.fromLTRB(
  24,
  24,
  24,
  24 + bottomFloatingReserve,
);
