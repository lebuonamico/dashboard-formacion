import 'dart:io';

typedef FlutterProcessRunner =
    Future<int> Function({
      required String executable,
      required List<String> arguments,
      required String workingDirectory,
      required bool runInShell,
      required ProcessStartMode mode,
    });

/// IPv4 addresses of this machine on the local network.
typedef LanAddressLister = Future<List<String>> Function();

const _usage = '''Uso:

  dart run tool/run.dart local
  dart run tool/run.dart local --lan
  dart run tool/run.dart supabase''';

const _lanFlag = '--lan';
const _port = '3000';

Future<void> main(List<String> arguments) async {
  exitCode = await runProject(arguments);
}

Future<int> runProject(
  List<String> arguments, {
  Directory? projectDirectory,
  FlutterProcessRunner? startProcess,
  bool? isWindows,
  void Function(String)? reportError,
  void Function(String)? reportInfo,
  LanAddressLister? listLanAddresses,
}) async {
  final void Function(String) report = reportError ?? stderr.writeln;
  final mode = arguments.isEmpty ? null : arguments.first;
  final lan = arguments.length == 2 && arguments.last == _lanFlag;
  if (!const {'local', 'supabase'}.contains(mode) ||
      (arguments.length != 1 && !lan)) {
    report(_usage);
    return 1;
  }
  if (mode == 'supabase' && lan) {
    report(
      'El modo supabase no se puede abrir desde la red local: el login con '
      'Google solo vuelve a los orígenes registrados en Supabase. Probalo en '
      'un deploy de preview, o usá "local --lan".',
    );
    return 1;
  }

  final project = projectDirectory ?? Directory.current;
  final windows = isWindows ?? Platform.isWindows;
  if (lan) {
    _reportLanUrls(
      await (listLanAddresses ?? _lanAddresses)(),
      reportInfo ?? stdout.writeln,
    );
  }
  try {
    if (mode == 'supabase' &&
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
        if (lan) ...['web-server', '--web-hostname', '0.0.0.0'] else 'chrome',
        '--web-port',
        _port,
        if (mode == 'local')
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

void _reportLanUrls(List<String> addresses, void Function(String) report) {
  if (addresses.isEmpty) {
    report(
      'No se encontró la IP de esta máquina en la red local. Buscala con '
      'ipconfig y abrí http://<IP>:$_port en el celular.',
    );
  } else {
    report('Abrí en el celular, conectado a la misma red Wi-Fi:');
    addresses.map((address) => '  http://$address:$_port').forEach(report);
  }
  report(
    'Si Windows pregunta por el firewall, permití el acceso en redes privadas.',
  );
}

Future<List<String>> _lanAddresses() async {
  try {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
    );
    return interfaces
        .expand((interface) => interface.addresses)
        .map((address) => address.address)
        .toList();
  } on SocketException {
    return const [];
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
