enum AssistantErrorType {
  temporary,
  limit,
  connection,
  session,
  permission,
  unknown,
}

class AssistantException implements Exception {
  final AssistantErrorType type;
  final int? status;

  /// Only known codes, for diagnosis: the raw response body is never kept.
  final String? code;

  const AssistantException(this.type, {this.status, this.code});

  bool get allowsRetry =>
      status != 401 &&
      status != 403 &&
      type != AssistantErrorType.session &&
      type != AssistantErrorType.permission;
}

enum AssistantQueryIssue { invalidMonth, contextTooLarge }

/// A question that has to be rephrased: retrying it gives the same result.
class AssistantQueryException implements Exception {
  final AssistantQueryIssue issue;

  const AssistantQueryException(this.issue);
}
