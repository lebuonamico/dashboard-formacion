/// What the report button does with the generated PDF.
enum ReportOutput {
  /// Opens the print dialog, which can also save it as a PDF.
  print,

  /// Downloads the file: phone browsers cannot print it from the page.
  download,
}
