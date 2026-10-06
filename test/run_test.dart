import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/run.dart';

const _usage =
    'Uso:\n\n'
    '  dart run tool/run.dart local\n'
    '  dart run tool/run.dart supabase';

class _ProcessCall {
  final String executable;
  final List<String> arguments;
  final String workingDirectory;
  final bool runInShell;
  final ProcessStartMode mode;

  _ProcessCall({
    required this.executable,
    required this.arguments,
    required this.workingDirectory,
    required this.runInShell,
    required this.mode,
  });
}

void main() {
  late Directory project;
  late List<_ProcessCall> calls;
  late List<String> errors;
  var processExitCode = 0;
  ProcessException? processError;

  Future<int> startProcess({
    required String executable,
    required List<String> arguments,
    required String workingDirectory,
    required bool runInShell,
    required ProcessStartMode mode,
  }) async {
    calls.add(
      _ProcessCall(
        executable: executable,
        arguments: List.of(arguments),
        workingDirectory: workingDirectory,
        runInShell: runInShell,
        mode: mode,
      ),
    );
    if (processError case final error?) throw error;
    return processExitCode;
  }

  Future<int> run(List<String> arguments, {bool windows = false}) => runProject(
    arguments,
    projectDirectory: project,
    startProcess: startProcess,
    isWindows: windows,
    reportError: errors.add,
  );

  Future<File> createConfig([String content = '{}']) async {
    final file = File(
      '${project.path}${Platform.pathSeparator}config'
      '${Platform.pathSeparator}supabase.local.json',
    );
    await file.parent.create(recursive: true);
    return file.writeAsString(content);
  }

  setUp(() async {
    project = await Directory.systemTemp.createTemp('two_mode_runner_test_');
    calls = [];
    errors = [];
    processExitCode = 0;
    processError = null;
  });

  tearDown(() async {
    await project.delete(recursive: true);
  });

  final invalidArguments = <String, List<String>>{
    'sin argumentos': [],
    'DEV ya no es un modo válido': ['dev'],
    'PROD ya no es un modo válido': ['prod'],
    'modo desconocido': ['invalid'],
    'argumentos extra en local': ['local', 'extra'],
    'argumentos extra en supabase': ['supabase', 'extra'],
  };
  for (final entry in invalidArguments.entries) {
    test('${entry.key}: muestra el uso y no inicia Flutter', () async {
      expect(await run(entry.value), 1);
      expect(errors, [_usage]);
      expect(calls, isEmpty);
    });
  }

  test(
    'LOCAL funciona sin configuración y ejecuta los argumentos exactos',
    () async {
      expect(await run(['local']), 0);
      expect(errors, isEmpty);
      final call = calls.single;
      expect(call.executable, 'flutter');
      expect(call.arguments, [
        'run',
        '-d',
        'chrome',
        '--web-port',
        '3000',
        '--dart-define=USE_SUPABASE=false',
      ]);
      expect(call.workingDirectory, project.path);
      expect(call.runInShell, isFalse);
      expect(call.mode, ProcessStartMode.inheritStdio);
    },
  );

  test('LOCAL no lee ni modifica el archivo de Supabase', () async {
    final config = await createConfig('contenido que no es JSON');
    expect(await run(['local']), 0);
    expect(errors, isEmpty);
    expect(await config.readAsString(), 'contenido que no es JSON');
    expect(
      calls.single.arguments,
      isNot(contains(startsWith('--dart-define-from-file='))),
    );
  });

  test('SUPABASE bloquea el arranque si falta el archivo local', () async {
    expect(await run(['supabase']), 1);
    expect(calls, isEmpty);
    expect(errors, hasLength(1));
    expect(errors.single, contains('config/supabase.local.json'));
  });

  test(
    'SUPABASE pasa el archivo existente a Flutter sin alterar su contenido',
    () async {
      final config = await createConfig('configuración delegada a Flutter');
      expect(await run(['supabase']), 0);
      expect(errors, isEmpty);
      final call = calls.single;
      expect(call.executable, 'flutter');
      expect(call.arguments, [
        'run',
        '-d',
        'chrome',
        '--web-port',
        '3000',
        '--dart-define-from-file=config/supabase.local.json',
      ]);
      expect(call.workingDirectory, project.path);
      expect(call.runInShell, isFalse);
      expect(call.mode, ProcessStartMode.inheritStdio);
      expect(await config.readAsString(), 'configuración delegada a Flutter');
    },
  );

  for (final mode in ['local', 'supabase']) {
    test('$mode usa flutter.bat con shell e inheritStdio en Windows', () async {
      if (mode == 'supabase') await createConfig();
      expect(await run([mode], windows: true), 0);
      final call = calls.single;
      expect(call.executable, 'flutter.bat');
      expect(call.runInShell, isTrue);
      expect(call.mode, ProcessStartMode.inheritStdio);
      expect(call.workingDirectory, project.path);
      expect(errors, isEmpty);
    });

    test('$mode conserva el código de salida del proceso Flutter', () async {
      if (mode == 'supabase') await createConfig();
      processExitCode = 27;
      expect(await run([mode]), 27);
      expect(calls, hasLength(1));
      expect(errors, isEmpty);
    });
  }

  test(
    'Un error al iniciar Flutter se informa y termina con código 1',
    () async {
      processError = const ProcessException(
        'flutter',
        [],
        'No se encontró Flutter',
      );
      expect(await run(['local']), 1);
      expect(calls, hasLength(1));
      expect(errors, hasLength(1));
      expect(errors.single.toLowerCase(), contains('flutter'));
    },
  );
}
