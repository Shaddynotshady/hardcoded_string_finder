import 'dart:io';
import 'dart:convert';

/// Read file content with encoding fallback for cross-platform compatibility
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

/// Represents a single row from an existing CSV file,
/// storing the key, English text, and all existing translations.
class CsvRow {
  /// The localization key (snake_case).
  final String key;

  /// The English source text.
  final String english;

  /// A map of language codes to their translated values.
  /// e.g. `{'app_ar': 'مرحبا', 'app_fr': 'Bonjour'}`
  final Map<String, String> translations;

  /// Creates a [CsvRow] with the given [key], [english] text, and [translations].
  CsvRow({
    required this.key,
    required this.english,
    required this.translations,
  });
}

/// Handles exporting hardcoded strings to JSON and CSV formats.
///
/// Use [exportToJson] to create a simple key-value JSON file,
/// or [exportToCsv] to create a spreadsheet with 70+ language columns
/// ready for translation.
class StringExporter {
  /// Exports [strings] to a JSON file at [outputPath].
  ///
  /// The output is a pretty-printed JSON object with snake_case keys
  /// and English values.
  ///
  /// ```dart
  /// await StringExporter.exportToJson(
  ///   strings,
  ///   'output/strings.json',
  ///   onProgress: print,
  /// );
  /// ```
  static Future<void> exportToJson(
    Map<String, String> strings,
    String outputPath, {
    void Function(String)? onProgress,
  }) async {
    try {
      onProgress?.call('📝 Exporting JSON...');

      final file = File(outputPath);
      final jsonContent = const JsonEncoder.withIndent('  ').convert(strings);

      await file.writeAsString(jsonContent);

      final sizeKB = (jsonContent.length / 1024).toStringAsFixed(2);
      onProgress?.call('✅ JSON exported: $outputPath ($sizeKB KB)');
    } catch (e) {
      throw ExportException('Failed to export JSON: $e');
    }
  }

  /// Exports [strings] to a CSV file at [outputPath] with 70+ language columns.
  ///
  /// If a CSV already exists at [outputPath], existing translations are
  /// preserved and new strings are merged in (non-destructive).
  ///
  /// Set [snakeCaseKeys] to `true` (default) to use `snake_case` keys,
  /// or `false` for readable lowercase keys with spaces.
  ///
  /// ```dart
  /// await StringExporter.exportToCsv(
  ///   strings,
  ///   'output/strings.csv',
  ///   snakeCaseKeys: true,
  ///   onProgress: print,
  /// );
  /// ```
  static Future<void> exportToCsv(
    Map<String, String> strings,
    String outputPath, {
    bool snakeCaseKeys = true,
    void Function(String)? onProgress,
  }) async {
    try {
      onProgress?.call('📊 Preparing CSV export...');

      final existingData = await _readExistingCsv(outputPath, onProgress);

      final buffer = StringBuffer();

      final languageCodes = [
        'app_en',
        'app_af',
        'app_sq',
        'app_am',
        'app_ar',
        'app_hy',
        'app_az',
        'app_bn',
        'app_eu',
        'app_be',
        'app_bg',
        'app_my',
        'app_ca',
        'app_zh',
        'app_zh_hk',
        'app_hr',
        'app_cs',
        'app_da',
        'app_nl',
        'app_et',
        'app_fil',
        'app_fi',
        'app_fr',
        'app_gl',
        'app_ka',
        'app_de',
        'app_el',
        'app_gu',
        'app_he',
        'app_hi',
        'app_hu',
        'app_is',
        'app_id',
        'app_it',
        'app_ja',
        'app_kn',
        'app_kk',
        'app_km',
        'app_ko',
        'app_ky',
        'app_lo',
        'app_lv',
        'app_lt',
        'app_mk',
        'app_ms',
        'app_ml',
        'app_mr',
        'app_mn',
        'app_ne',
        'app_no',
        'app_fa',
        'app_pl',
        'app_pt',
        'app_pa',
        'app_ro',
        'app_ru',
        'app_sr',
        'app_si',
        'app_sk',
        'app_sl',
        'app_es',
        'app_sw',
        'app_sv',
        'app_ta',
        'app_te',
        'app_th',
        'app_tr',
        'app_uk',
        'app_vi',
        'app_zu',
      ];

      final languageNames = [
        'Key',
        'ENGLISH - en',
        'AFRIKAANS - af',
        'Albanian - sq',
        'Amharic - am',
        'Arabic - ar',
        'Armenian - hy',
        'Azerbaijani - az',
        'Bangla - bn',
        'Basque - eu',
        'Belarusian - be',
        'Bulgarian - bg',
        'Burmese - my',
        'Catalan - ca',
        'Chinese Simplified - zh-CN',
        'Chinese Traditional - zh-HK',
        'Croatian - hr',
        'Czech - cs',
        'Danish - da',
        'Dutch - nl',
        'Estonian - et',
        'Filipino - fil',
        'Finnish - fi',
        'French - fr',
        'Galician - gl',
        'Georgian - ka',
        'German - de',
        'Greek - el',
        'Gujarati - gu',
        'Hebrew - he',
        'Hindi - hi',
        'Hungarian - hu',
        'Icelandic - is',
        'Indonesian - id',
        'Italian - it',
        'Japanese - ja',
        'Kannada - kn',
        'Kazakh - kk',
        'Khmer - km',
        'Korean - ko',
        'Kyrgyz - ky',
        'Lao - lo',
        'Latvian - lv',
        'Lithuanian - lt',
        'Macedonian - mk',
        'Malay - ms',
        'Malayalam - ml',
        'Marathi - mr',
        'Mongolian - mn',
        'Nepali - ne',
        'Norwegian - no',
        'Persian - fa',
        'Polish - pl',
        'Portuguese - pt',
        'Punjabi - pa',
        'Romanian - ro',
        'Russian - ru',
        'Serbian - sr',
        'Sinhala - si',
        'Slovak - sk',
        'Slovenian - sl',
        'Spanish - es',
        'Swahili - sw',
        'Swedish - sv',
        'Tamil - ta',
        'Telugu - te',
        'Thai - th',
        'Turkish - tr',
        'Ukrainian - uk',
        'Vietnamese - vi',
        'Zulu - zu',
      ];

      onProgress?.call('📝 Writing CSV headers...');

      // Row 1: Numbers
      buffer.write(',');
      for (int i = 1; i <= languageCodes.length; i++) {
        buffer.write('$i');
        if (i < languageCodes.length) buffer.write(',');
      }
      buffer.writeln();

      // Row 2: Language codes
      buffer.write(',');
      buffer.writeln(languageCodes.join(','));

      // Row 3: Language names
      buffer.writeln(_escapeCsvRow(languageNames));

      int newStrings = 0;
      int updatedStrings = 0;
      int preservedStrings = 0;

      onProgress?.call('📝 Processing ${strings.length} strings...');

      strings.forEach((key, value) {
        final formattedKey = snakeCaseKeys ? key : key.replaceAll('_', ' ');
        final existingRow = existingData?[formattedKey];

        if (existingRow != null) {
          // Check if English text actually changed
          final englishChanged = existingRow.english != value;
          if (englishChanged) {
            updatedStrings++;
          } else {
            preservedStrings++;
          }
          final row = [
            formattedKey,
            existingRow.english.isNotEmpty ? existingRow.english : value,
            ...List.generate(languageCodes.length - 1, (index) {
              final langCode = languageCodes[index + 1];
              return existingRow.translations[langCode] ?? '';
            }),
          ];
          buffer.writeln(_escapeCsvRow(row));
        } else {
          newStrings++;
          final row = [
            formattedKey,
            value,
            ...List.generate(languageCodes.length - 1, (_) => ''),
          ];
          buffer.writeln(_escapeCsvRow(row));
        }
      });

      if (existingData != null) {
        onProgress?.call('📝 Preserving removed strings...');
        for (final existingKey in existingData.keys) {
          final formattedKey =
              snakeCaseKeys ? existingKey : existingKey.replaceAll('_', ' ');

          if (strings.containsKey(existingKey)) continue;

          preservedStrings++;
          final existingRow = existingData[existingKey]!;
          final row = [
            formattedKey,
            existingRow.english,
            ...List.generate(languageCodes.length - 1, (index) {
              final langCode = languageCodes[index + 1];
              return existingRow.translations[langCode] ?? '';
            }),
          ];
          buffer.writeln(_escapeCsvRow(row));
        }
      }

      onProgress?.call('💾 Writing CSV file...');
      try {
        await File(outputPath).writeAsString(buffer.toString());
      } on PathAccessException catch (e) {
        throw ExportException(
          'Cannot write to CSV file because it is open in another program.\n'
          '💡 Please close the file (Excel, spreadsheet viewer, etc.) and try again.\n'
          '📁 File: $outputPath\n'
          'Error: $e',
        );
      }

      final sizeKB = (buffer.length / 1024).toStringAsFixed(2);

      if (existingData == null) {
        onProgress?.call(
            '✅ CSV exported: $outputPath (${strings.length} strings, $sizeKB KB)');
      } else {
        onProgress?.call('🔄 CSV updated: $outputPath ($sizeKB KB)');
        onProgress?.call('   📝 New strings: $newStrings');
        onProgress?.call('   🔄 Updated strings: $updatedStrings');
        onProgress?.call('   💾 Preserved strings: $preservedStrings');
        onProgress?.call(
            '   📊 Total strings: ${newStrings + updatedStrings + preservedStrings}');
      }
    } catch (e, stack) {
      throw ExportException('CSV export error: $e\n$stack');
    }
  }

  static String _escapeCsvRow(List<String> values) {
    return values.map((value) {
      if (value.contains(',') || value.contains('"') || value.contains('\n')) {
        return '"${value.replaceAll('"', '""')}"';
      }
      return value;
    }).join(',');
  }

  static Future<Map<String, CsvRow>?> _readExistingCsv(
    String outputPath,
    void Function(String)? onProgress,
  ) async {
    try {
      final file = File(outputPath);
      if (!await file.exists()) return null;

      onProgress?.call('📖 Reading existing CSV...');

      final content = await _readFileWithEncoding(file);
      final lines = content.split('\n').where((line) => line.trim().isNotEmpty);

      if (lines.isEmpty || lines.length < 4) return null;

      final languageCodesLine = lines.elementAt(1);
      final languageCodes = languageCodesLine
          .split(',')
          .where((code) => code.trim().isNotEmpty)
          .toList();

      languageCodes.removeAt(0);
      final cleanCodes = languageCodes.map((code) => code.trim()).toList();

      final Map<String, CsvRow> existingData = {};

      for (int i = 3; i < lines.length; i++) {
        final line = lines.elementAt(i);
        final values = _parseCsvLine(line);

        if (values.isNotEmpty) {
          final key = values.elementAt(0).trim();
          final english = values.length > 1 ? values.elementAt(1).trim() : '';

          final Map<String, String> translations = {};
          for (int j = 2; j < values.length && j - 2 < cleanCodes.length; j++) {
            translations[cleanCodes[j - 2]] = values.elementAt(j).trim();
          }

          existingData[key] = CsvRow(
            key: key,
            english: english,
            translations: translations,
          );
        }
      }

      onProgress?.call('📖 Found ${existingData.length} existing strings');
      return existingData;
    } catch (e) {
      onProgress?.call('⚠️  Warning: Could not read existing CSV: $e');
      return null;
    }
  }

  static List<String> _parseCsvLine(String line) {
    final List<String> values = [];
    bool inQuotes = false;
    String currentValue = '';

    for (int i = 0; i < line.length; i++) {
      final char = line[i];

      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          currentValue += '"';
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        values.add(currentValue);
        currentValue = '';
      } else {
        currentValue += char;
      }
    }

    values.add(currentValue);
    return values;
  }
}

/// Thrown when an export operation fails.
class ExportException implements Exception {
  /// The error message describing what went wrong.
  final String message;

  /// Creates an [ExportException] with the given [message].
  ExportException(this.message);

  @override
  String toString() => 'ExportException: $message';
}
