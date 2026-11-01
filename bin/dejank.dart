import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:dejank/src/engine.dart';
import 'package:dejank/src/measure.dart';
import 'package:path/path.dart' as p;

Future<void> main(List<String> args) async {
  final runner = CommandRunner<void>('dejank', 'Finds slow Flutter code, fixes it, and proves it.')
    ..addCommand(ScanCommand())
    ..addCommand(FixCommand())
    ..addCommand(MeasureCommand());
  try {
    await runner.run(args);
  } on UsageException catch (e) {
    stderr.writeln(e);
    exitCode = 64;
  }
}

class ScanCommand extends Command<void> {
  @override
  final name = 'scan';
  @override
  final description = 'List slow code with file:line, impact, and whether `dejank fix` can fix it.';
  @override
  String get invocation => 'dejank scan [path, default lib]';

  ScanCommand() {
    argParser.addOption(
      'fail-on',
      allowed: ['high', 'any', 'never'],
      defaultsTo: 'high',
      help: 'Which findings make the exit code 1 (for CI).',
    );
  }

  @override
  Future<void> run() async {
    final report = await _analyze(name, argResults!.rest);
    final auto = report.findings.where((f) => f.autoFix).length;
    final suggest = report.findings.length - auto;
    final failOn = argResults!.option('fail-on');
    if (report.findings.any((f) => failOn == 'any' || (failOn == 'high' && f.impact == 'high'))) exitCode = 1;
    if (!_fancy) {
      for (final f in report.findings) {
        print(
          '${p.relative(f.path)}:${f.line}:${f.column}  ${f.rule.name}  ${f.impact}  '
          '${f.autoFix ? 'auto' : 'suggest'}',
        );
        print('  ${f.message.replaceAll('\n', '\n  ')}');
      }
      print(
        report.findings.isEmpty
            ? 'No problems found.'
            : '\n${_count(report.findings.length, 'problem')}: $auto auto-fixable (run `dejank fix`), $suggest need a human.',
      );
      return;
    }
    for (final (i, f) in report.findings.indexed) {
      print('${_badge(i + 1)} ${_bold('${p.relative(f.path)}:${f.line}:${f.column}')}');
      print(
        '    ${_impactIcon[f.impact]} ${_cyan(f.rule.name)} ${_dim('·')} ${f.impact} impact '
        '${_dim('·')} ${f.autoFix ? _green('🔧 auto-fix') : _amber('💡 suggestion')}',
      );
      print('    ${f.message.replaceAll('\n', '\n    ')}\n');
    }
    print(_bar());
    if (report.findings.isEmpty) {
      print(' ✨ ${_bold('No problems found.')} Smooth as butter.');
    } else {
      print(
        ' 🔎 ${_bold(_count(report.findings.length, 'problem'))}   🔧 ${_green('$auto auto-fixable')}   '
        '💡 ${_amber('$suggest need a human')}',
      );
      print(
        ' ${[for (final MapEntry(key: impact, value: icon) in _impactIcon.entries)
          if (report.findings.where((f) => f.impact == impact).length case final n when n > 0) '$icon ${_bold('$n')} $impact impact'].join('   ')}',
      );
      if (auto > 0) print(' 👉 Run ${_cyan('dejank fix')} to fix ${auto == 1 ? 'it' : 'those $auto'} now.');
    }
    _credit();
  }
}

class FixCommand extends Command<void> {
  @override
  final name = 'fix';
  @override
  final description = 'Apply the safe fixes and show what changed.';
  @override
  String get invocation => 'dejank fix [path, default lib]';

  FixCommand() {
    argParser.addFlag('dry-run', negatable: false, help: 'Show what would change without writing any file.');
  }

  @override
  Future<void> run() async {
    final report = await _analyze(name, argResults!.rest);
    final byFile = <String, List<Finding>>{};
    for (final f in report.findings.where((f) => f.autoFix)) {
      byFile.putIfAbsent(f.path, () => []).add(f);
    }
    final wanted = byFile.values.fold(0, (n, fs) => n + fs.length);
    byFile.updateAll((_, findings) => applicable(findings));
    final skipped = wanted - byFile.values.fold(0, (n, fs) => n + fs.length);
    final before = {for (final path in byFile.keys) path: File(path).readAsStringSync()};
    final after = {
      for (final MapEntry(key: path, value: findings) in byFile.entries)
        path: applyEdits(before[path]!, [for (final f in findings) ...f.edits]),
    };
    final broken = await wouldBreak(report, after);
    final dryRun = argResults!.flag('dry-run');
    if (!dryRun && byFile.isNotEmpty) {
      final git = Process.runSync('git', [
        'status',
        '--porcelain',
        '--',
        ...byFile.keys,
      ], runInShell: Platform.isWindows);
      if (git.exitCode == 0 && '${git.stdout}'.trim().isNotEmpty) {
        stderr.writeln(
          'Note: some of these files have changes that are not committed. '
          "dejank's edits will mix with yours; commit first if you want an easy undo.",
        );
      }
    }
    var fixed = 0, files = 0;
    final rules = <String, int>{};
    for (final MapEntry(key: path, value: findings) in byFile.entries) {
      if (broken.contains(path)) {
        stderr.writeln('Skipped ${p.relative(path)}: the fix would break it. This is a dejank bug, please report it.');
        continue;
      }
      if (!dryRun) {
        final formatted = _formatted(path);
        File(path).writeAsStringSync(after[path]!);
        if (formatted) Process.runSync('dart', ['format', path], runInShell: Platform.isWindows);
      }
      fixed += findings.length;
      for (final f in findings) {
        rules[f.rule.name] = (rules[f.rule.name] ?? 0) + 1;
      }
      files++;
      final changes = diff(before[path]!, [for (final f in findings) ...f.edits]);
      if (!_fancy) {
        print('${p.relative(path)}\n$changes');
        continue;
      }
      print('${_badge(files)} ${_bold(p.relative(path))}');
      for (final line in changes.trimRight().split('\n')) {
        print(
          '  ${switch (line) {
            _ when line.startsWith('  - ') => _red(line),
            _ when line.startsWith('  + ') => _green(line),
            _ => _dim(line),
          }}',
        );
      }
      print('');
    }
    final suggest = report.findings.where((f) => !f.autoFix).length;
    final summary = '${_count(fixed, 'problem')} in ${_count(files, 'file')}';
    final again = skipped > 0 ? ' $skipped more overlap these changes: run dejank fix again.' : '';
    if (!_fancy) {
      print(
        '${dryRun ? 'Would fix' : 'Fixed'} $summary.$again'
        '${suggest > 0 ? ' $suggest need a human, see `dejank scan`.' : ''}',
      );
      return;
    }
    print(_bar());
    print(
      dryRun
          ? ' 👀 ${_bold('Dry run:')} would fix $summary. Nothing was written.'
          : fixed == 0
          ? ' ✨ ${_bold('Nothing to fix automatically.')}'
          : ' ✅ ${_bold('Fixed $summary.')}',
    );
    if (again.isNotEmpty) print(' 🔁$again');
    if (rules.isNotEmpty) print('    ${rules.entries.map((e) => '${e.value}× ${_cyan(e.key)}').join(_dim(' · '))}');
    if (suggest > 0) print(' 💡 ${_amber('$suggest need a human:')} run ${_cyan('dejank scan')} to see them.');
    if (fixed > 0 && !dryRun) {
      final saved = <String, File>{};
      if (Directory('.dejank').existsSync()) {
        for (final f in Directory('.dejank').listSync().whereType<File>().where((f) => f.path.endsWith('.json'))) {
          final slug = p.basename(f.path).replaceFirst(RegExp(r'(\.baseline)?\.json$'), '');
          if (f.path.endsWith('.baseline.json') || !saved.containsKey(slug)) saved[slug] = f;
        }
      }
      if (saved.isEmpty) {
        print(' 📏 Prove it: ${_cyan('dejank measure <test file>')} before and after (with the dejank_meter package).');
      }
      for (final MapEntry(key: slug, value: f) in saved.entries) {
        final run = Run.fromJson(jsonDecode(f.readAsStringSync()) as Map<String, dynamic>);
        print(
          ' 📏 ${f.path.endsWith('.baseline.json') ? 'Baseline' : 'Last measured'}: ${_bold(slug)} had '
          '${_bold(thousands(run.total))} widget builds. Run ${_cyan('dejank measure')} again to see how much faster it is now.',
        );
      }
    }
    _credit();
  }
}

class MeasureCommand extends Command<void> {
  @override
  final name = 'measure';
  @override
  final description =
      'Measure widget rebuilds and frame times while you use your app, and compare them with the last run.\n'
      'Add the meter to your app first: flutter pub add dev:dejank_meter';
  @override
  String get invocation => 'dejank measure -d <device>   (or: dejank measure <test file> -d <device>)';

  MeasureCommand() {
    argParser
      ..addOption(
        'device',
        abbr: 'd',
        help: 'Run on this device (see flutter devices). Frame times need a real device.',
      )
      ..addOption('target', abbr: 't', defaultsTo: 'lib/main.dart', help: "Your app's main file, for live mode.")
      ..addOption('flavor', help: 'Build flavor, for live mode.')
      ..addFlag(
        'baseline',
        negatable: false,
        help: 'Save this run as the baseline. Later runs compare against it instead of the last run.',
      );
  }

  static const _addMeter = "flutter pub add dev:dejank_meter 'dev:integration_test:{\"sdk\":\"flutter\"}'";

  @override
  Future<void> run() async {
    final test = argResults!.rest.firstOrNull;
    if (test == null) return _live();
    if (!File(test).existsSync()) usageException('Not found: $test');
    final root = _root(File(test).absolute.parent) ?? usageException('No pubspec.yaml above $test');
    final device = argResults!.option('device');
    if (_fancy) {
      _header(name, p.relative(test));
      print(' ⏱  Running the test${device == null ? '' : ' on $device'}...');
    } else {
      print('Running ${p.relative(test)}...');
    }
    final result = await Process.run(
      'flutter',
      [
        'test',
        p.relative(File(test).absolute.path, from: root.path),
        if (device != null) ...['-d', device],
      ],
      workingDirectory: root.path,
      runInShell: Platform.isWindows,
    );
    if (result.exitCode != 0) {
      stderr
        ..writeln(result.stdout)
        ..writeln(result.stderr)
        ..writeln('The test failed, nothing was saved.');
      exitCode = 1;
      return;
    }
    final runs = parseRuns(LineSplitter.split('${result.stdout}'));
    if (runs.isEmpty) {
      stderr
        ..writeln("No numbers found. Wrap the steps in measure('name', () async { ... }) from dejank_meter.")
        ..writeln('Add it to your app with: $_addMeter');
      exitCode = 1;
      return;
    }
    _report(root, runs);
  }

  static Directory? _root(Directory from) {
    for (var dir = from; ; dir = dir.parent) {
      if (File(p.join(dir.path, 'pubspec.yaml')).existsSync()) return dir;
      if (dir.parent.path == dir.path) return null;
    }
  }

  Future<void> _live() async {
    final root = _root(Directory.current) ?? usageException('Run this inside your Flutter app (no pubspec.yaml here).');
    final device =
        argResults!.option('device') ?? usageException('Which device? Run `flutter devices` and add -d <device>.');
    final pubspec = File(p.join(root.path, 'pubspec.yaml')).readAsStringSync();
    if (!RegExp(r'^\s+dejank_meter\s*:', multiLine: true).hasMatch(pubspec)) {
      stderr
        ..writeln('This app needs the meter first. Add it once with:')
        ..writeln('  flutter pub add dev:dejank_meter');
      exitCode = 1;
      return;
    }
    final target = argResults!.option('target')!;
    final entry = File(p.join(root.path, target));
    if (!entry.existsSync()) usageException('Not found: $target (use --target for another main file)');
    final package = RegExp(r'^name:\s*(\S+)', multiLine: true).firstMatch(pubspec)?[1];
    final inLib = p.relative(entry.absolute.path, from: p.join(root.path, 'lib'));
    final import = inLib.startsWith('..') || package == null
        ? '../${p.posix.joinAll(p.split(p.relative(entry.absolute.path, from: root.path)))}'
        : 'package:$package/${p.posix.joinAll(p.split(inLib))}';
    final takesArgs = RegExp(r'\bmain\s*\(\s*[^)\s]').hasMatch(entry.readAsStringSync());
    final launcher = File(p.join(root.path, '.dejank', 'live_main.dart'))
      ..createSync(recursive: true)
      ..writeAsStringSync(
        "import 'package:dejank_meter/dejank_meter.dart' as dejank;\n"
        "import '$import' as app;\n\n"
        'void main() {\n'
        '  dejank.live();\n'
        '  app.main(${takesArgs ? 'const []' : ''});\n'
        '}\n',
      );
    File(p.join(launcher.parent.path, '.gitignore')).writeAsStringSync('*\n');

    if (_fancy) {
      _header(name, 'live on $device');
      print(' ⏱  Building and starting your app... (the first build can take a few minutes)');
    } else {
      print('Building and starting your app on $device...');
    }
    final flavor = argResults!.option('flavor');
    final process = await Process.start(
      'flutter',
      [
        'run',
        '-t',
        p.relative(launcher.path, from: root.path),
        '-d',
        device,
        if (flavor != null) ...['--flavor', flavor],
      ],
      workingDirectory: root.path,
      runInShell: Platform.isWindows,
    );
    final meter = <String>[];
    final other = <String>[];
    final ready = Completer<void>();
    void onLine(String line) {
      if (line.contains(marker)) {
        meter.add(line);
        if (!ready.isCompleted && line.contains('"ready":true')) ready.complete();
      } else {
        other.add(line);
        if (other.length > 60) other.removeAt(0);
      }
    }

    for (final stream in [process.stdout, process.stderr]) {
      stream.transform(utf8.decoder).transform(const LineSplitter()).listen(onLine);
    }
    final exited = process.exitCode;
    await Future.any([ready.future, exited]);
    if (!ready.isCompleted) {
      stderr
        ..writeln(other.join('\n'))
        ..writeln('The app did not start, nothing was measured.')
        ..writeln(
          other.any((l) => l.contains("'live'"))
              ? 'Your dejank_meter is too old for live mode: flutter pub upgrade dejank_meter'
              : 'Check that the app builds and runs with: flutter run -d $device',
        );
      launcher.deleteSync();
      exitCode = 1;
      return;
    }

    final steps = [
      'Go to the screen you want to check.',
      'Do what feels slow: scroll the list, search, open the keyboard.',
      'Come back here and press Enter.',
    ];
    if (_fancy) {
      print(' ✅ ${_bold('Your app is open on the phone, with the meter on.')}');
      for (final (i, step) in steps.indexed) {
        print('    ${i + 1}. $step');
      }
      print(_dim('    To compare later runs fairly, do the same steps each time.'));
    } else {
      print('Your app is open with the meter on.');
      for (final (i, step) in steps.indexed) {
        print('${i + 1}. $step');
      }
    }
    final started = DateTime.now();
    final enter = stdin.transform(utf8.decoder).transform(const LineSplitter()).first.catchError((Object _) => '');
    await Future.any([enter, exited]);
    final seconds = DateTime.now().difference(started).inSeconds;
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    process.stdin.write('q');
    await Future.any([exited, Future<void>.delayed(const Duration(seconds: 5))]);
    process.kill();
    launcher.deleteSync();

    final runs = parseRuns(meter);
    if (runs.isEmpty || runs.values.first.total == 0) {
      stderr.writeln('No rebuilds were counted. Use the app for a moment before pressing Enter.');
      exitCode = 1;
      return;
    }
    final total = runs.values.first.total;
    print(
      _fancy
          ? '\n ⏱  ${_bold(_count(seconds, 'second'))} of use: ${thousands(total)} widget builds '
                '(${thousands(seconds == 0 ? total : total / seconds)} per second)'
          : '$seconds seconds of use: $total widget builds',
    );
    _report(root, runs);
  }

  void _report(Directory root, Map<String, Run> runs) {
    final lib = Directory(p.join(root.path, 'lib'));
    final own = {
      if (lib.existsSync())
        for (final f in lib.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart')))
          for (final m in RegExp(r'class\s+(\w+)').allMatches(f.readAsStringSync())) m[1]!,
    };
    var first = true;
    final setBaseline = argResults!.flag('baseline');
    var vsBaseline = false;
    final wins = <String>[];
    for (final MapEntry(key: name, value: now) in runs.entries) {
      final slug = name.replaceAll(RegExp(r'[^\w-]'), '_');
      final file = File(p.join(root.path, '.dejank', '$slug.json'));
      final baseline = File(p.join(root.path, '.dejank', '$slug.baseline.json'));
      final from = baseline.existsSync() && !setBaseline ? baseline : file;
      vsBaseline |= from == baseline;
      final before = from.existsSync()
          ? Run.fromJson(jsonDecode(from.readAsStringSync()) as Map<String, dynamic>)
          : null;
      if (before != null) first = false;
      final text = table(name, before, now, own: own);
      print('\n${_fancy ? _colorTable(text) : text}');
      if (before != null) wins.add(_win(name, before, now));
      file
        ..createSync(recursive: true)
        ..writeAsStringSync(jsonEncode(now.toJson()));
      if (setBaseline) baseline.writeAsStringSync(jsonEncode(now.toJson()));
      File(p.join(file.parent.path, '.gitignore')).writeAsStringSync('*\n');
    }
    final note = setBaseline
        ? 'Saved as the baseline: later runs compare against it.'
        : vsBaseline
        ? 'Compared with the baseline (dejank measure --baseline replaces it).'
        : null;
    if (!_fancy) {
      if (note != null) print(note);
      if (first) print('Saved in .dejank/. Change your code and run again to compare.');
      return;
    }
    print(_bar());
    for (final w in wins) {
      print(' $w');
    }
    if (note != null) print(' 📌 $note');
    if (first) print(' 📁 Saved. Change your code and run ${_cyan('dejank measure')} again to compare.');
    _credit();
  }

  static String _win(String name, Run before, Run now) {
    String change(num b, num n, String what) {
      if (b == 0 || n == b) return 'same $what';
      final pct = ((n - b).abs() / b * 100).round();
      return n < b ? _green('$pct% fewer $what') : _red('$pct% more $what');
    }

    final slow = [before.frames?['slow'], now.frames?['slow']];
    return '${now.total < before.total ? '🎉' : '📊'} ${_bold(name)}: ${change(before.total, now.total, 'widget builds')}'
        '${slow.contains(null) ? '' : ', ${change(slow[0]!, slow[1]!, 'slow frames')}'}';
  }

  static String _colorTable(String text) {
    final lines = text.trimRight().split('\n');
    return [
      _dim(lines.first),
      for (final line in lines.skip(1))
        line.replaceFirstMapped(RegExp(r'([+-]\d+%)$'), (m) {
          final pct = m[1]!;
          if (line.startsWith('frames ')) return _dim(pct);
          return pct.startsWith('-') ? _green(pct) : _red(pct);
        }),
    ].join('\n');
  }
}

Future<Report> _analyze(String command, List<String> rest) async {
  final path = rest.firstOrNull ?? (Directory('lib').existsSync() ? 'lib' : '.');
  if (FileSystemEntity.typeSync(path) == FileSystemEntityType.notFound) {
    throw UsageException('Not found: $path', 'dejank scan [path]');
  }
  if (_fancy) _header(command, path);
  final report = await analyze(path);
  if (report.unresolved.isNotEmpty) {
    stderr.writeln(
      'Warning: ${report.unresolved.length} files have imports that could not be found. '
      'Run `flutter pub get` first, or some problems will be missed.',
    );
  }
  return report;
}

const _impactIcon = {'high': '🔴', 'medium': '🟡', 'low': '⚪'};

bool _formatted(String path) =>
    Process.runSync('dart', [
      'format',
      '--output=none',
      '--set-exit-if-changed',
      path,
    ], runInShell: Platform.isWindows).exitCode ==
    0;

String _count(int n, String word) => '$n $word${n == 1 ? '' : 's'}';

final _fancy = switch (Platform.environment) {
  {'NO_COLOR': _} => false,
  {'FORCE_COLOR': final force} => force != '0',
  _ => stdout.hasTerminal && stdout.supportsAnsiEscapes,
};

String _paint(String s, String code) => _fancy ? '\x1B[${code}m$s\x1B[0m' : s;
String _bold(String s) => _paint(s, '1');
String _dim(String s) => _paint(s, '38;5;245');
String _cyan(String s) => _paint(s, '38;5;81');
String _green(String s) => _paint(s, '38;5;78');
String _red(String s) => _paint(s, '38;5;203');
String _amber(String s) => _paint(s, '38;5;221');
String _badge(int n) => _paint(' $n ', '1;38;5;16;48;5;208');

const _gradient = [202, 208, 214, 220, 226, 190, 154, 118, 82, 46];

String _bar([int width = 56]) =>
    [for (var i = 0; i < width; i++) _paint('━', '38;5;${_gradient[i * _gradient.length ~/ width]}')].join();

void _header(String command, String target) {
  print('\n${_paint(' ⚡ dejank ', '1;38;5;16;48;5;208')} ${_bold(command)} ${_dim(target)}\n');
}

void _credit() {
  print(
    '\n ${_dim('made with')} 💙 ${_dim('by')} ${_bold('Abojawdat')} ${_dim('·')} ⭐ ${_dim('github.com/Abojawdat/dejank')}\n',
  );
}
