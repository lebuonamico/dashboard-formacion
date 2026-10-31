import 'package:flutter/material.dart';

void showAppSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..removeCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

const actionFailedMessage =
    'No se pudo completar la acción. Intentá nuevamente.';

String actionErrorMessage(Object error) =>
    error is FormatException ? error.message : actionFailedMessage;

/// Waits for [action] and reports the outcome with a SnackBar. Returns
/// whether it succeeded.
Future<bool> runWithFeedback(
  BuildContext context, {
  required Future<void> Function() action,
  required String success,
  String Function(Object error) failure = actionErrorMessage,
}) async {
  try {
    await action();
  } on Object catch (error) {
    if (context.mounted) showAppSnackBar(context, failure(error));
    return false;
  }
  if (context.mounted) showAppSnackBar(context, success);
  return true;
}

Future<bool> showConfirmationDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  Color? confirmColor,
  Key? confirmKey,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Text(message),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: confirmKey,
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: confirmColor == null
              ? null
              : FilledButton.styleFrom(backgroundColor: confirmColor),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
