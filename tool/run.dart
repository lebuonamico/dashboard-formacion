import 'dart:io';

typedef FlutterProcessRunner =
    Future<int> Function({
      required String executable,
      required List<String> arguments,
      required String workingDirectory,
      required bool runInShell,
      required ProcessStartMode mode,
    });

const _usage = '''Uso:

  dart run tool/run.dart local
  dart run tool/run.dart supabase''';

Future<void> main(List<String> arguments) async {
  exitCode = await runProject(arguments);
}

Future<int> runProject(
  List<String> arguments, {
  Directory? projectDirectory,
  FlutterProcessRunner? startProcess,
  bool? isWindows,
  void Function(String)? reportError,
}) async {
  final report = reportError ?? stderr.writeln;
  if (arguments.length != 1 ||
      !const {'local', 'supabase'}.contains(arguments.single)) {
    report(_usage);
    return 1;
  }

  final project = projectDirectory ?? Directory.current;
  final windows = isWindows ?? Platform.isWindows;
  try {
    if (arguments.single == 'supabase' &&
        !await File.fromUri(
          project.uri.resolve('config/supabase.local.json'),
        ).exists()) {
      report(
        'Falta config/supabase.local.json para ejecutar el modo supabase.',
      );
      return 1;
    }

    return await (startProcess ?? _startFlutter)(
      executable: windows ? 'flutter.bat' : 'flutter',
      arguments: [
        'run',
        '-d',
        'chrome',
        '--web-port',
        '3000',
        if (arguments.single == 'local')
          '--dart-define=USE_SUPABASE=false'
        else
          '--dart-define-from-file=config/supabase.local.json',
      ],
      workingDirectory: project.path,
      runInShell: windows,
      mode: ProcessStartMode.inheritStdio,
    );
  } on FileSystemException {
    report('No se pudo verificar config/supabase.local.json.');
    return 1;
  } on ProcessException {
    report('No se pudo iniciar Flutter. Verificá que esté disponible en PATH.');
    return 1;
  }
}

Future<int> _startFlutter({
  required String executable,
  required List<String> arguments,
  required String workingDirectory,
  required bool runInShell,
  required ProcessStartMode mode,
}) async {
  final process = await Process.start(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    runInShell: runInShell,
    mode: mode,
  );
  return process.exitCode;
}
