import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:easy_localization/src/missing_keys_scanner.dart';
import 'package:path/path.dart' as path;

void main(List<String> args) {
  if (args.length == 1 && (args[0] == '--help' || args[0] == '-h')) {
    _printHelperDisplay();
    return;
  }
  _scan(_scanOption(args));
}

void _printHelperDisplay() {
  final parser = _buildArgParser(null);
  stdout.writeln('Scans translation files and reports missing or extra keys.');
  stdout.writeln('');
  stdout.writeln('Usage: dart run easy_localization:scan_missing_keys [options]');
  stdout.writeln('');
  stdout.writeln(parser.usage);
}

ScanOptions _scanOption(List<String> args) {
  final options = ScanOptions();
  final parser = _buildArgParser(options);
  parser.parse(args);
  return options;
}

ArgParser _buildArgParser(ScanOptions? options) {
  final parser = ArgParser();

  parser.addOption(
    'source-dir',
    abbr: 'S',
    defaultsTo: 'resources/langs',
    callback: (String? x) => options?.sourceDir = x,
    help: 'Folder containing translation JSON files',
  );

  parser.addOption(
    'reference',
    abbr: 'r',
    defaultsTo: 'en',
    callback: (String? x) => options?.reference = x,
    help: 'Reference locale filename without extension (e.g. "en", "en-US")',
  );

  parser.addFlag(
    'verbose',
    abbr: 'v',
    defaultsTo: false,
    callback: (bool? x) => options?.verbose = x,
    help: 'Show matched keys as well as missing/extra',
  );

  return parser;
}

class ScanOptions {
  String? sourceDir;
  String? reference;
  bool? verbose;
}

void _scan(ScanOptions options) async {
  final current = Directory.current;
  final sourcePath = Directory(path.join(current.path, options.sourceDir!));

  if (!await sourcePath.exists()) {
    stderr.writeln('Source path does not exist: ${sourcePath.path}');
    exitCode = 1;
    return;
  }

  final files = await _dirContents(sourcePath);
  final jsonFiles = files
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .toList();

  if (jsonFiles.isEmpty) {
    stderr.writeln('No JSON files found in: ${sourcePath.path}');
    exitCode = 1;
    return;
  }

  final referenceName = options.reference!;
  File? referenceFile;
  try {
    referenceFile = jsonFiles.firstWhere(
      (f) => path.basenameWithoutExtension(f.path) == referenceName,
    );
  } catch (_) {
    final available = jsonFiles
        .map((f) => path.basenameWithoutExtension(f.path))
        .join(', ');
    stderr.writeln(
        'Reference locale "$referenceName" not found in ${sourcePath.path}.');
    stderr.writeln('Available locales: $available');
    exitCode = 1;
    return;
  }

  final referenceData =
      json.decode(await referenceFile.readAsString()) as Map<String, dynamic>;
  final referenceKeys = flattenTranslationKeys(referenceData);

  stdout.writeln('Reference: $referenceName (${referenceKeys.length} keys)');
  stdout.writeln('');

  int totalMissing = 0;
  int totalExtra = 0;

  for (final file in jsonFiles) {
    final localeName = path.basenameWithoutExtension(file.path);
    if (localeName == referenceName) continue;

    final data =
        json.decode(await file.readAsString()) as Map<String, dynamic>;
    final localeKeys = flattenTranslationKeys(data);

    final missing = referenceKeys.difference(localeKeys);
    final extra = localeKeys.difference(referenceKeys);

    if (missing.isEmpty && extra.isEmpty) {
      stdout.writeln('✓  $localeName — complete');
      if (options.verbose == true) {
        for (final k in localeKeys.toList()..sort()) {
          stdout.writeln('     $k');
        }
      }
    } else {
      stdout.writeln(
          '✗  $localeName — ${missing.length} missing, ${extra.length} extra');
      for (final k in missing.toList()..sort()) {
        stdout.writeln('   - missing: $k');
      }
      for (final k in extra.toList()..sort()) {
        stdout.writeln('   + extra:   $k');
      }
      totalMissing += missing.length;
      totalExtra += extra.length;
    }
  }

  stdout.writeln('');

  if (totalMissing == 0 && totalExtra == 0) {
    stdout.writeln('All locales are complete.');
  } else {
    stdout.writeln(
        'Found $totalMissing missing key(s) and $totalExtra extra key(s).');
    exitCode = 1;
  }
}


Future<List<FileSystemEntity>> _dirContents(Directory dir) {
  final files = <FileSystemEntity>[];
  final completer = Completer<List<FileSystemEntity>>();
  dir
      .list(recursive: false)
      .listen(files.add, onDone: () => completer.complete(files));
  return completer.future;
}
