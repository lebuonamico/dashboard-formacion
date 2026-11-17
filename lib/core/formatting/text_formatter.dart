/// A dash for an empty or blank value.
String orDash(String value) => value.trim().isEmpty ? '—' : value;

/// [count] with the noun in singular or plural: `1 área`, `3 áreas`.
String countLabel(int count, String singular, String plural) =>
    '$count ${count == 1 ? singular : plural}';
