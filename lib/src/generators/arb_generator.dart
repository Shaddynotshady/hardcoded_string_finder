import 'dart:io';
import 'dart:convert';
import 'package:hardcoded_string_finder/src/key_generator/key_generator.dart';

/// Read file content with encoding fallback for cross-platform compatibility
/// Tries UTF-8 first, then falls back to Latin-1 if UTF-8 fails
Future<String> _readFileWithEncoding(File file) async {
  try {
    return await file.readAsString(encoding: utf8);
  } catch (e) {
    // Fallback to Latin-1 (ISO-8859-1) which can read any byte sequence
    try {
      return await file.readAsString(encoding: latin1);
    } catch (e2) {
      // Last resort: try system encoding
      try {
        return await file.readAsString(encoding: Encoding.getByName(Platform.localeName) ?? utf8);
      } catch (e3) {
        throw Exception('Failed to read file with any encoding: ${file.path}. Error: $e3');
      }
    }
  }
}

/// Result of ARB generation operation.
///
/// Contains information about the generated ARB files including
/// the number of files created, total keys, and missing translations.
class ArbResult {
  /// Number of ARB files successfully created.
  final int filesCreated;

  /// Total number of unique translation keys across all languages.
  final int totalKeys;

  /// Mapping of keys to the language codes where they are missing.
  ///
  /// Only includes keys that have translations in some languages
  /// but are missing in others. Keys missing in all languages are
  /// not included (considered intentionally untranslated).
  final Map<String, List<String>> missingByKey;

  ArbResult({
    required this.filesCreated,
    required this.totalKeys,
    required this.missingByKey,
  });
}

/// Generates ARB (Application Resource Bundle) files from CSV for Flutter localization.
///
/// This generator reads a translated CSV file and creates `.arb` files
/// compatible with Flutter's `flutter gen-l10n` command. It also generates
/// a `l10n.yaml` configuration file in the project root.
///
/// Example usage:
/// ```dart
/// final result = await ArbGenerator.generate(
///   csvPath: 'hardcoded_strings.csv',
///   headerRow: 2,
///   dataStartRow: 4,
///   outputDir: 'lib/l10n',
/// );
/// ```
class ArbGenerator {
  /// Parse a single CSV line, handling quoted values correctly
  static List<String> _parseCsvLine(String line) {
    final values = <String>[];
    bool inQuotes = false;
    String current = '';

    for (int i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          current += '"';
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (ch == ',' && !inQuotes) {
        values.add(current);
        current = '';
      } else {
        current += ch;
      }
    }
    values.add(current);
    return values;
  }

  /// Show a terminal-readable preview: first 5 rows x first 5 columns
  static Future<void> showCsvPreview(String csvPath) async {
    final file = File(csvPath);
    if (!await file.exists()) {
      print('❌ File not found: $csvPath');
      return;
    }

    final lines = (await _readFileWithEncoding(file))
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .take(5)
        .toList();

    if (lines.isEmpty) {
      print('❌ CSV file is empty.');
      return;
    }

    print('\n📋 CSV Preview (first 5 rows × first 5 columns):\n');

    // Collect first 5 columns from each of first 5 rows
    final tableData = <List<String>>[];
    for (final line in lines) {
      final cols = _parseCsvLine(line).take(5).toList();
      // Pad to 5 columns if fewer
      while (cols.length < 5) {
        cols.add('');
      }
      tableData.add(cols);
    }

    // Calculate column widths
    final colWidths = List.filled(5, 0);
    for (final row in tableData) {
      for (int i = 0; i < row.length; i++) {
        final len = row[i].length > 20 ? 20 : row[i].length; // cap at 20 chars
        if (len > colWidths[i]) colWidths[i] = len;
      }
    }
    // Minimum width for row number label col
    colWidths[0] = colWidths[0] < 5 ? 5 : colWidths[0];

    // Print header separator
    final separator = colWidths.map((w) => '─' * (w + 2)).join('┼');
    final topBorder = colWidths.map((w) => '─' * (w + 2)).join('┬');
    final bottomBorder = colWidths.map((w) => '─' * (w + 2)).join('┴');

    print('┌$topBorder┐');

    for (int r = 0; r < tableData.length; r++) {
      final row = tableData[r];
      // Build row string
      final cells = <String>[];
      for (int c = 0; c < 5; c++) {
        final raw = c == 0 && row[c].isEmpty ? '' : row[c];
        final truncated = raw.length > 20 ? '${raw.substring(0, 17)}...' : raw;
        cells.add(' ${truncated.padRight(colWidths[c])} ');
      }
      print('│${cells.join('│')}│  ← Row ${r + 1}');

      if (r < tableData.length - 1) {
        print('├$separator┤');
      }
    }

    print('└$bottomBorder┘\n');
  }

  /// Validate if a row contains language codes (e.g., app_en, app_ru)
  static bool validateHeaderRow(List<String> columns) {
    // Check if any column looks like a language code (starts with app_ or contains underscore)
    for (int i = 1; i < columns.length; i++) {
      final col = columns[i].trim();
      if (col.startsWith('app_') || (col.contains('_') && col.length > 2)) {
        return true;
      }
    }
    return false;
  }

  /// Parse a single CSV line, handling quoted values correctly (public for CLI validation)
  static List<String> parseCsvLine(String line) {
    return _parseCsvLine(line);
  }

  /// Generate ARB files from a CSV
  /// [csvPath]        - path to the CSV file
  /// [headerRow]      - 1-based row index containing language codes (e.g. app_en, app_ru)
  /// [dataStartRow]   - 1-based row index where translation data begins
  /// [outputDir]      - folder to write ARB files into (e.g. lib/l10n)
  static Future<ArbResult> generate({
    required String csvPath,
    required int headerRow,
    required int dataStartRow,
    required String outputDir,
    void Function(String)? onProgress,
  }) async {
    onProgress?.call('📖 Reading CSV: $csvPath');

    final file = File(csvPath);
    if (!await file.exists()) {
      throw Exception('CSV file not found: $csvPath');
    }

    final allLines = (await _readFileWithEncoding(file))
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .toList();

    if (allLines.length < headerRow) {
      throw Exception(
          'CSV has fewer rows than the specified header row ($headerRow).');
    }

    // Parse language codes row (1-based → 0-based index)
    final headerCols = _parseCsvLine(allLines[headerRow - 1]);

    // First column is always the key column — language codes start at index 1
    // Filter to only columns that look like language codes (contain underscore or start with app_)
    final langColumns = <int, String>{}; // colIndex → langCode
    for (int i = 1; i < headerCols.length; i++) {
      final code = headerCols[i].trim();
      if (code.isNotEmpty) {
        langColumns[i] = code;
      }
    }

    if (langColumns.isEmpty) {
      throw Exception('No language columns found in header row $headerRow.');
    }

    onProgress?.call(
        '✅ Detected ${langColumns.length} language columns: ${langColumns.values.join(', ')}');

    // Parse data rows
    final dataRows = allLines.skip(dataStartRow - 1).toList();
    onProgress?.call('📊 Processing ${dataRows.length} translation rows...');

    // Build per-language maps: langCode → {key: value}
    final translations = <String, Map<String, String>>{};
    final allKeys = <String>[];

    for (final line in dataRows) {
      final cols = _parseCsvLine(line);
      if (cols.isEmpty) continue;

      final key = cols[0].trim();
      if (key.isEmpty) continue;

      final snakeKey = KeyGenerator.generate(key);
      allKeys.add(snakeKey);

      for (final entry in langColumns.entries) {
        final colIdx = entry.key;
        final langCode = entry.value;
        final value = colIdx < cols.length ? cols[colIdx].trim() : '';

        translations.putIfAbsent(langCode, () => {});
        if (value.isNotEmpty) {
          translations[langCode]![snakeKey] = value;
        }
      }
    }

    // Create output directory
    final dir = Directory(outputDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
      onProgress?.call('📁 Created folder: $outputDir/');
    }

    int filesCreated = 0;

    for (final entry in translations.entries) {
      final langCode = entry.key; // e.g. app_en
      final keyValues = entry.value; // {key: value}

      // Skip languages with zero translations
      if (keyValues.isEmpty) {
        onProgress?.call('⏭️  Skipping $langCode (no translations)');
        continue;
      }

      // Derive locale from langCode: app_en → en, app_zh_hk → zh_HK
      final locale = _deriveLocale(langCode);

      // Build ARB map — clean key-value only
      final arb = <String, dynamic>{};
      arb['@@locale'] = locale;

      for (final key in allKeys) {
        final value = keyValues[key];
        if (value != null && value.isNotEmpty) {
          final fixedKey = _fixArbKey(key);
          arb[fixedKey] = value;
        }
      }

      // Write ARB file
      final fileName = '$langCode.arb';
      final filePath = '$outputDir/$fileName';
      final content = const JsonEncoder.withIndent('  ').convert(arb);
      await File(filePath).writeAsString(content);
      onProgress?.call('✅ Written: $filePath (${keyValues.length} keys)');
      filesCreated++;
    }

    // Track how many keys were fixed (start with numbers)
    int fixedKeys = 0;
    for (final key in allKeys) {
      if (RegExp(r'^[0-9]').hasMatch(key)) {
        fixedKeys++;
      }
    }
    if (fixedKeys > 0) {
      onProgress?.call(
          '⚠️  Fixed $fixedKeys keys starting with numbers (added "key_" prefix for ARB compatibility)');
    }

    // Build per-key missing map: key → which languages are missing it
    // Only include keys that have AT LEAST one translation somewhere
    final missingByKey = <String, List<String>>{};
    for (final key in allKeys) {
      final missingLangs = <String>[];
      for (final entry in translations.entries) {
        final langCode = entry.key;
        final keyValues = entry.value;
        // Only flag if this language has SOME translations (not completely empty)
        if (keyValues.isNotEmpty && !keyValues.containsKey(key)) {
          missingLangs.add(langCode);
        }
      }
      if (missingLangs.isNotEmpty) {
        missingByKey[key] = missingLangs;
      }
    }

    // Write l10n.yaml to project root
    await _writeL10nYaml(outputDir, onProgress);

    return ArbResult(
      filesCreated: filesCreated,
      totalKeys: allKeys.length,
      missingByKey: missingByKey,
    );
  }

  /// Write l10n.yaml to project root
  static Future<void> _writeL10nYaml(
    String outputDir,
    void Function(String)? onProgress,
  ) async {
    const content = '''arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
output-class: AppLocalizations
nullable-getter: false
''';
    await File('l10n.yaml').writeAsString(content);
    onProgress?.call('📄 Created: l10n.yaml (project root)');
  }

  /// Derive Flutter locale string from a language code column name
  /// e.g. app_en → en, app_zh_hk → zh_HK, app_pt → pt
  static String _deriveLocale(String langCode) {
    // Strip app_ prefix
    var locale = langCode.startsWith('app_') ? langCode.substring(4) : langCode;

    // Handle known regional variants: zh_hk → zh_HK, zh_tw → zh_TW etc.
    final parts = locale.split('_');
    if (parts.length == 2) {
      locale = '${parts[0]}_${parts[1].toUpperCase()}';
    }

    return locale;
  }

  /// Fix keys that start with numbers (invalid for ARB)
  /// ARB resource names must be valid Dart method names
  static String _fixArbKey(String key) {
    if (key.isEmpty) return key;

    // Check if key starts with a digit
    if (RegExp(r'^[0-9]').hasMatch(key)) {
      return 'key_$key';
    }

    return key;
  }

  /// Write arb_report.txt if there are any missing translations
  static Future<void> writeReport({
    required ArbResult result,
    required String outputDir,
    void Function(String)? onProgress,
  }) async {
    if (result.missingByKey.isEmpty) return;

    final buf = StringBuffer();
    final now = DateTime.now();
    final dateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

    buf.writeln('📊 ARB Generation Report');
    buf.writeln('Generated: $dateStr');
    buf.writeln('Total keys: ${result.totalKeys}');
    buf.writeln('ARB files created: ${result.filesCreated}');
    buf.writeln(
        'Keys with missing translations: ${result.missingByKey.length}');
    buf.writeln('');
    buf.writeln('━' * 50);
    buf.writeln('Missing Translations (by key):');
    buf.writeln('━' * 50);
    buf.writeln('');

    for (final entry in result.missingByKey.entries) {
      final fixedKey = _fixArbKey(entry.key);
      buf.writeln('[$fixedKey]');
      buf.writeln('  Missing in: ${entry.value.join(', ')}');
      buf.writeln('');
    }

    final reportPath = '$outputDir/arb_report.txt';
    await File(reportPath).writeAsString(buf.toString());
    onProgress?.call('📄 Report written: $reportPath');
  }
}
