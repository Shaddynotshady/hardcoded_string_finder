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

/// Result of GetX Map generation operation.
///
/// Contains information about the generated GetX localization files including
/// the number of files created, total keys, and missing translations.
class GetXResult {
  /// Number of Dart files successfully created (language files + main translation file).
  final int filesCreated;

  /// Total number of unique translation keys across all languages.
  final int totalKeys;

  /// Mapping of keys to the language codes where they are missing.
  ///
  /// Only includes keys that have translations in some languages
  /// but are missing in others. Keys missing in all languages are
  /// not included (considered intentionally untranslated).
  final Map<String, List<String>> missingByKey;

  GetXResult({
    required this.filesCreated,
    required this.totalKeys,
    required this.missingByKey,
  });
}

/// Generates GetX Map files from CSV for GetX state management localization.
///
/// This generator reads a translated CSV file and creates Dart Map files
/// compatible with GetX's Translations system. It generates individual
/// language files and a main AppTranslations class.
///
/// Example usage:
/// ```dart
/// final result = await GetXGenerator.generate(
///   csvPath: 'hardcoded_strings.csv',
///   headerRow: 2,
///   dataStartRow: 4,
///   outputDir: 'lib/localization',
///   packageName: 'com.example.myapp',
/// );
/// ```
class GetXGenerator {
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

  /// Generate GetX localization files from a CSV
  /// [csvPath]        - path to the CSV file
  /// [headerRow]      - 1-based row index containing language codes (e.g. app_en, app_ru)
  /// [dataStartRow]   - 1-based row index where translation data begins
  /// [outputDir]      - folder to write GetX files into (e.g. lib/localization)
  /// [packageName]    - package name for imports (e.g. e_sign_app)
  static Future<GetXResult> generate({
    required String csvPath,
    required int headerRow,
    required int dataStartRow,
    required String outputDir,
    required String packageName,
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

    // Track missing translations: key → list of langCodes missing that key
    final missingByKey = <String, List<String>>{};
    for (final key in allKeys) {
      final missingLangs = <String>[];
      for (final langCode in langColumns.values) {
        final langTranslations = translations[langCode];
        if (langTranslations == null || !langTranslations.containsKey(key)) {
          missingLangs.add(langCode);
        }
      }
      if (missingLangs.isNotEmpty) {
        missingByKey[key] = missingLangs;
      }
    }

    // Create output directory
    final dir = Directory(outputDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
      onProgress?.call('📁 Created folder: $outputDir/');
    }

    // Create languages subfolder
    final languagesDir = Directory('$outputDir/languages');
    if (!await languagesDir.exists()) {
      await languagesDir.create(recursive: true);
      onProgress?.call('📁 Created folder: $outputDir/languages/');
    }

    int filesCreated = 0;
    final createdLanguages = <String>[]; // Track languages with actual files

    // Generate individual language files
    for (final entry in translations.entries) {
      final langCode = entry.key; // e.g. app_en
      final keyValues = entry.value; // {key: value}

      // Skip languages with zero translations
      if (keyValues.isEmpty) {
        onProgress?.call('⏭️  Skipping $langCode (no translations)');
        continue;
      }

      // Generate individual language file
      final fileName = '$langCode.dart';
      final filePath = '$outputDir/languages/$fileName';
      final content = _generateLanguageFile(langCode, keyValues);
      await File(filePath).writeAsString(content);
      onProgress?.call('✅ Written: $filePath (${keyValues.length} keys)');
      filesCreated++;
      createdLanguages.add(langCode);
    }

    // Generate main translation file
    final mainFilePath = '$outputDir/app_translations.dart';
    final mainContent = _generateMainTranslationFile(
      packageName,
      createdLanguages,
      allKeys,
    );
    await File(mainFilePath).writeAsString(mainContent);
    onProgress?.call('✅ Written: $mainFilePath');
    filesCreated++;

    return GetXResult(
      filesCreated: filesCreated,
      totalKeys: allKeys.length,
      missingByKey: missingByKey,
    );
  }

  /// Generate individual language file
  static String _generateLanguageFile(
    String langCode,
    Map<String, String> translations,
  ) {
    final buffer = StringBuffer();
    buffer.writeln('final Map<String, String> $langCode = {');

    final entries = translations.entries.toList();
    for (int i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final key = entry.key;
      final value = _escapeDartString(entry.value);
      final isLast = i == entries.length - 1;

      if (isLast) {
        buffer.writeln("  '$key': '$value'");
      } else {
        buffer.writeln("  '$key': '$value',");
      }
    }

    buffer.writeln('};');
    return buffer.toString();
  }

  /// Generate main translation file
  static String _generateMainTranslationFile(
    String packageName,
    List<String> langCodes,
    List<String> allKeys,
  ) {
    final buffer = StringBuffer();

    // Imports
    for (final langCode in langCodes) {
      buffer.writeln(
          "import 'package:$packageName/localization/languages/$langCode.dart';");
    }
    buffer.writeln("import 'package:get/get.dart';");
    buffer.writeln();

    // Class
    buffer.writeln('class AppTranslations extends Translations {');
    buffer.writeln('  @override');
    buffer.writeln('  Map<String, Map<String, String>> get keys => {');

    // Locale mappings
    for (int i = 0; i < langCodes.length; i++) {
      final langCode = langCodes[i];
      final fullLocale = _convertToFullLocale(langCode);
      final isLast = i == langCodes.length - 1;

      if (isLast) {
        buffer.writeln("    '$fullLocale': $langCode");
      } else {
        buffer.writeln("    '$fullLocale': $langCode,");
      }
    }

    buffer.writeln('  };');
    buffer.writeln('}');

    return buffer.toString();
  }

  /// Convert language code to full locale code
  /// e.g. app_en → en_US, app_zh_hk → zh_HK, app_zhcn → zh_CN
  static String _convertToFullLocale(String langCode) {
    // Remove app_ prefix
    var code = langCode.startsWith('app_') ? langCode.substring(4) : langCode;

    // Handle special cases
    if (code == 'zh_hk') return 'zh_HK';
    if (code == 'zhcn') return 'zh_CN';
    if (code == 'zh_tw') return 'zh_TW';

    // Handle standard format: language_country
    final parts = code.split('_');
    if (parts.length == 2) {
      return '${parts[0]}_${parts[1].toUpperCase()}';
    }

    // Simple language code - add default country
    final countryMap = {
      'en': 'US',
      'af': 'ZA',
      'ar': 'SA',
      'de': 'DE',
      'es': 'ES',
      'fr': 'FR',
      'it': 'IT',
      'ja': 'JP',
      'ko': 'KR',
      'pt': 'PT',
      'ru': 'RU',
      'zh': 'CN',
    };

    final country = countryMap[code] ?? 'US';
    return '${code}_$country';
  }

  /// Escape special characters for Dart strings
  static String _escapeDartString(String value) {
    return value
        .replaceAll('\\', '\\\\') // Escape backslashes
        .replaceAll("'", "\\'") // Escape single quotes
        .replaceAll('\n', '\\n') // Escape newlines
        .replaceAll('\r', '\\r') // Escape carriage returns
        .replaceAll('\t', '\\t'); // Escape tabs
  }

  /// Write getx_report.txt if there are any missing translations
  static Future<void> writeReport({
    required GetXResult result,
    required String outputDir,
    void Function(String)? onProgress,
  }) async {
    if (result.missingByKey.isEmpty) return;

    final buf = StringBuffer();
    final now = DateTime.now();
    final dateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

    buf.writeln('📊 GetX Generation Report');
    buf.writeln('Generated: $dateStr');
    buf.writeln('Total keys: ${result.totalKeys}');
    buf.writeln('GetX files created: ${result.filesCreated}');
    buf.writeln(
        'Keys with missing translations: ${result.missingByKey.length}');
    buf.writeln('');
    buf.writeln('━' * 50);
    buf.writeln('Missing Translations (by key):');
    buf.writeln('━' * 50);
    buf.writeln('');

    for (final entry in result.missingByKey.entries) {
      buf.writeln('[${entry.key}]');
      buf.writeln('  Missing in: ${entry.value.join(', ')}');
      buf.writeln('');
    }

    final reportPath = '$outputDir/getx_report.txt';
    await File(reportPath).writeAsString(buf.toString());
    onProgress?.call('📄 Report written: $reportPath');
  }
}
