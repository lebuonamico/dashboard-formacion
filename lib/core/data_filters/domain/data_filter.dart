enum DataFilterScope {
  employees,
  teams,
  areas,
  courses,
  timeEntries,
  certifications,
  adminUsers,
  dashboardAreas,
}

typedef DataFilterValues = Map<String, Set<String>>;

typedef DataFilterLabels = Map<String, Map<String, String>>;

class FilterRow {
  final Map<String, String> values;
  final Map<String, String> labels;

  const FilterRow(this.values, {this.labels = const {}});
}

class DataFilterOptions {
  final List<String> values;
  final Set<String> incompatibleValues;
  final Map<String, String> labels;

  const DataFilterOptions({
    required this.values,
    required this.incompatibleValues,
    required this.labels,
  });
}
