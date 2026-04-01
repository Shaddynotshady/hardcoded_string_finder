import 'dart:io';
import 'dart:convert';

class CsvRow {
  final String key;
  final String english;
  final Map<String, String> translations;

  CsvRow(
      {required this.key, required this.english, required this.translations});
}

class StringExporter {
  /// Export strings to JSON with error handling
  static Future<void> exportToJson(
    Map<String, String> strings,
    String outputPath, {
    void Function(String)? onProgress,
  }) async {
    try {
      onProgress?.call('📝 Exporting JSON...');

      final file = File(outputPath);
      final jsonContent = const JsonEncoder.withIndent('  ').convert(strings);

      // Write with error handling
      await file.writeAsString(jsonContent);

      final sizeKB = (jsonContent.length / 1024).toStringAsFixed(2);
      onProgress?.call('✅ JSON exported: $outputPath ($sizeKB KB)');
    } catch (e) {
      throw ExportException('Failed to export JSON: $e');
    }
  }

  static Future<void> exportToCsv(
    Map<String, String> strings,
    String outputPath, {
    bool snakeCaseKeys = true,
    void Function(String)? onProgress,
  }) async {
    try {
      onProgress?.call('📊 Preparing CSV export...');

      // Read existing CSV data if it exists
      final existingData = await _readExistingCsv(outputPath, onProgress);

      final buffer = StringBuffer();

      // Language codes for header
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
        'app_zu'
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
        'Zulu - zu'
      ];

      onProgress?.call('📝 Writing CSV headers...');

      // Row 1: Numbers (empty first cell, then 1, 2, 3...)
      buffer.write(','); // Empty first column
      for (int i = 1; i <= languageCodes.length; i++) {
        buffer.write('$i');
        if (i < languageCodes.length) buffer.write(',');
      }
      buffer.writeln();

      // Row 2: Language codes (empty first cell)
      buffer.write(','); // Empty first column
      buffer.writeln(languageCodes.join(','));

      // Row 3: Language names
      buffer.writeln(_escapeCsvRow(languageNames));

      // Track statistics for reporting
      int newStrings = 0;
      int updatedStrings = 0;
      int preservedStrings = 0;

      onProgress?.call('📝 Processing ${strings.length} strings...');

      // Data rows - merge new strings with existing translations
      strings.forEach((key, value) {
        final formattedKey = snakeCaseKeys ? key : key.replaceAll('_', ' ');

        // Check if this string exists in existing data
        final existingRow = existingData?[formattedKey];

        if (existingRow != null) {
          // String exists - preserve translations, update English if changed
          updatedStrings++;
          final row = [
            formattedKey,
            value, // Always use current English text
            ...List.generate(languageCodes.length - 1, (index) {
              final langCode = languageCodes[index + 1]; // Skip app_en
              return existingRow.translations[langCode] ?? '';
            }),
          ];
          buffer.writeln(_escapeCsvRow(row));
        } else {
          // New string - create empty translations
          newStrings++;
          final row = [
            formattedKey,
            value,
            ...List.generate(languageCodes.length - 1, (_) => ''),
          ];
          buffer.writeln(_escapeCsvRow(row));
        }
      });

      // Add existing strings that are no longer found in code (preserve them)
      if (existingData != null) {
        onProgress?.call('📝 Preserving removed strings...');
        for (final existingKey in existingData.keys) {
          final formattedKey =
              snakeCaseKeys ? existingKey : existingKey.replaceAll('_', ' ');

          // Skip if already processed (exists in current strings)
          if (strings.containsKey(existingKey)) continue;

          preservedStrings++;
          final existingRow = existingData[existingKey]!;
          final row = [
            formattedKey,
            existingRow.english,
            ...List.generate(languageCodes.length - 1, (index) {
              final langCode = languageCodes[index + 1]; // Skip app_en
              return existingRow.translations[langCode] ?? '';
            }),
          ];
          buffer.writeln(_escapeCsvRow(row));
        }
      }

      onProgress?.call('💾 Writing CSV file...');
      await File(outputPath).writeAsString(buffer.toString());

      final sizeKB = (buffer.length / 1024).toStringAsFixed(2);

      // Report what happened
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

  /// Helper to escape CSV values with quotes if needed
  static String _escapeCsvRow(List<String> values) {
    return values.map((value) {
      if (value.contains(',') || value.contains('"') || value.contains('\n')) {
        return '"${value.replaceAll('"', '""')}"';
      }
      return value;
    }).join(',');
  }

  /// Read existing CSV file and parse into structured data
  static Future<Map<String, CsvRow>?> _readExistingCsv(
    String outputPath,
    void Function(String)? onProgress,
  ) async {
    try {
      final file = File(outputPath);
      if (!await file.exists()) return null;

      onProgress?.call('📖 Reading existing CSV...');

      final content = await file.readAsString();
      final lines = content.split('\n').where((line) => line.trim().isNotEmpty);

      if (lines.isEmpty || lines.length < 4) {
        return null;
      }
      // Parse language codes from row 2 (index 1)
      final languageCodesLine = lines.elementAt(1);
      final languageCodes = languageCodesLine
          .split(',')
          .where((code) => code.trim().isNotEmpty)
          .toList();

      // Remove empty first element and clean up codes
      languageCodes.removeAt(0);
      final cleanCodes = languageCodes.map((code) => code.trim()).toList();

      Map<String, CsvRow> existingData = {};

      // Parse data rows (starting from row 4, index 3)
      for (int i = 3; i < lines.length; i++) {
        final line = lines.elementAt(i);
        final values = _parseCsvLine(line);

        if (values.isNotEmpty) {
          final key = values.elementAt(0).trim();
          final english = values.length > 1 ? values.elementAt(1).trim() : '';

          Map<String, String> translations = {};
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

  /// Parse CSV line handling quoted values
  static List<String> _parseCsvLine(String line) {
    List<String> values = [];
    bool inQuotes = false;
    String currentValue = '';

    for (int i = 0; i < line.length; i++) {
      final char = line[i];

      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          // Escaped quote
          currentValue += '"';
          i++; // Skip next quote
        } else {
          // Toggle quote mode
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        // End of value
        values.add(currentValue);
        currentValue = '';
      } else {
        currentValue += char;
      }
    }

    // Add last value
    values.add(currentValue);
    return values;
  }
}

/// Custom exception for export errors
class ExportException implements Exception {
  final String message;
  ExportException(this.message);

  @override
  String toString() => 'ExportException: $message';
}
