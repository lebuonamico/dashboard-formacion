import 'package:app_finnegans/core/layout/window_size.dart';
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

/// [screenPadding] for the current window: 16 on phones. The bottom reserve
/// stays, because the assistant button floats there at every size.
EdgeInsets screenPaddingOf(BuildContext context) =>
    context.windowSize == WindowSize.compact
    ? const EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomFloatingReserve)
    : screenPadding;
