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

/// Waits for [action] and reports the outcome with a SnackBar (none on
/// success without [success]). Returns whether it succeeded.
Future<bool> runWithFeedback(
  BuildContext context, {
  required Future<void> Function() action,
  String? success,
  String Function(Object error) failure = actionErrorMessage,
}) async {
  try {
    await action();
  } on Object catch (error) {
    if (context.mounted) showAppSnackBar(context, failure(error));
    return false;
  }
  if (success != null && context.mounted) showAppSnackBar(context, success);
  return true;
}

/// [runWithFeedback] for an action with a result. A null result means the
/// action was cancelled and shows no SnackBar.
Future<T?> runWithResultFeedback<T extends Object>(
  BuildContext context, {
  required Future<T?> Function() action,
  required String Function(T result) success,
  String Function(Object error) failure = actionErrorMessage,
}) async {
  final T? result;
  try {
    result = await action();
  } on Object catch (error) {
    if (context.mounted) showAppSnackBar(context, failure(error));
    return null;
  }
  if (result != null && context.mounted) {
    showAppSnackBar(context, success(result));
  }
  return result;
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
