import 'dart:io';
import 'package:hardcoded_string_finder/src/translation/langbly_translator.dart';
import 'package:hardcoded_string_finder/src/translation/deepl_translator.dart';
import 'package:hardcoded_string_finder/src/translation/quota_tracker.dart';
import 'package:hardcoded_string_finder/src/translation/translation_service.dart';
import 'package:hardcoded_string_finder/src/translation/translation_exceptions.dart';

/// Allows user to select translation service.
Future<TranslationService> _selectTranslationService() async {
  print('\nSelect Translation Service:');
  print('   1. DeepL (Industry Standard)');
  print('      • Best translation quality (human-like)');
  print('      • 121 languages supported');
  print('      • Fast batch API');
  print('      • Free quota: 500k chars/month');
  print('      • ⚠️  Requires credit card for free tier');
  print('      • ⚠️  Auto-charges if quota exceeded');
  print('      • Get API key: https://www.deepl.com/pro-api');
  print('');
  print('   2. Langbly (Broad Coverage)');
  print('      • 100+ languages supported');
  print('      • Basic translation quality');
  print('      • Slower API (1 call per language)');
  print('      • Free quota: 500k chars/month');
  print('      • ✅ No credit card required');
  print('      • ✅ No auto-charges (stops when quota exceeded)');
  print('      • Get API key: https://langbly.com');

  stdout.write('\n   Choice: ');
  final choice = stdin.readLineSync();

  if (choice == '1') {
    return DeeplTranslator();
  } else {
    return LangblyTranslator();
  }
}

/// Runs the auto-translate CSV CLI flow.
Future<void> runTranslateGenerator() async {
  print('\n🌍 Auto-Translate CSV');
  print('━' * 50);

  try {
    // Step 1: Select translation service
    final service = await _selectTranslationService();

    // Step 2: Get CSV path
    stdout.write(
        '\nEnter path to your CSV file (default: ./hardcoded_strings/hardcoded_strings.csv): ');
    final csvPath = stdin.readLineSync()?.trim() ??
        './hardcoded_strings/hardcoded_strings.csv';

    if (!File(csvPath).existsSync()) {
      print('❌ File not found: $csvPath');
      return;
    }

    // Step 2: Read and parse CSV
    final csvFile = File(csvPath);
    final csvContent = await csvFile.readAsString();
    final lines =
        csvContent.split('\n').where((line) => line.isNotEmpty).toList();

    if (lines.length < 3) {
      print('❌ CSV must have at least 3 rows');
      return;
    }

    // Step 3: Show CSV preview (5x5)
    _showCsvPreview(lines);

    // Step 4: Get header row with validation
    final headerRow = await _getHeaderRowWithValidation(lines);

    // Step 5: Parse header to get languages
    final headerColumns = _parseCsvLine(lines[headerRow - 1]);
    final languages = headerColumns.skip(1).toList(); // Skip first column (key)

    if (languages.isEmpty) {
      print('❌ No language columns found in header');
      return;
    }

    print('\n🌍 Language Detection:');
    print('   Source: ${headerColumns[0]} (English)');
    print('   Target: ${languages.length} languages found');
    print(
        '   [${languages.take(5).join(', ')}${languages.length > 5 ? '...' : ''}]');

    // Step 6: Get data starting row
    stdout.write('\nWhich row number does the translation data start?: ');
    final dataStartRowStr = stdin.readLineSync();
    final dataStartRow = int.tryParse(dataStartRowStr ?? '') ?? (headerRow + 1);

    if (dataStartRow <= headerRow) {
      print('❌ Data start row must be after header row');
      return;
    }

    // Step 6.5: Get row limit
    print('\nRow Selection:');
    print('   1. Translate all data rows');
    print('   2. Translate specific range (for testing)');
    stdout.write('\n   Choice: ');
    final rowChoice = stdin.readLineSync();

    int dataEndRow = lines.length; // Default to all rows

    if (rowChoice == '2') {
      stdout.write('   Enter end row number (default: ${lines.length}): ');
      final endRowStr = stdin.readLineSync();
      final endRow = int.tryParse(endRowStr ?? '') ?? lines.length;

      if (endRow < dataStartRow) {
        print('❌ End row must be after data start row');
        return;
      }

      dataEndRow = endRow;
      print('   Will translate rows $dataStartRow to $dataEndRow');
    }

    // Step 7: Get API key
    print('\n🔑 Enter ${service.name} API Key:');
    print('   To get your API key:');
    print('   1. Go to: ${service.getSignupUrl()}');
    print('   2. Sign up for free account');
    if (service.name == 'DeepL') {
      print('   ⚠️  Note: DeepL requires credit card for free tier');
      print('   ⚠️  Auto-charges if quota exceeded');
    }
    print('   3. Get your API key from dashboard');
    stdout.write('\n   API Key: ');
    final apiKey = stdin.readLineSync()?.trim() ?? '';

    if (apiKey.isEmpty) {
      print('❌ API key is required');
      return;
    }

    if (!service.isValidApiKey(apiKey)) {
      print('⚠️  Invalid API key format');
      stdout.write('   Continue anyway? (y/n): ');
      final confirm = stdin.readLineSync();
      if (confirm?.toLowerCase() != 'y') {
        return;
      }
    }

    // Step 8: Estimate and select languages
    final dataRows = lines
        .skip(dataStartRow - 1)
        .take(dataEndRow - dataStartRow + 1)
        .toList();
    final stringCount = dataRows.length;
    final avgChars = 20; // Estimate

    print('\n📊 Translation Estimation:');
    print('   Strings to translate: $stringCount');
    print('   Target languages: ${languages.length}');
    print('   Avg characters per string: ~$avgChars');
    final estimated = stringCount * avgChars * languages.length;
    print('   Estimated characters: ~$estimated');
    print('   Free quota: ${service.freeQuotaChars} characters');
    print(
        '   Quota usage: ${(estimated / service.freeQuotaChars * 100).toStringAsFixed(1)}%');

    if (estimated > service.freeQuotaChars) {
      print('   ⚠️  WARNING: Exceeds free quota!');
    } else {
      print('   ✅ Within free quota');
    }

    // Ask if user wants to select specific languages
    print('\nOptions:');
    print('   1. Translate all ${languages.length} languages');
    print('   2. Select specific languages');
    print('   3. Cancel');
    stdout.write('\n   Choice: ');
    final choice = stdin.readLineSync();

    List<String> targetLanguages = languages;

    if (choice == '2') {
      targetLanguages = await _selectLanguages(languages);
      print('\n   Selected: ${targetLanguages.join(', ')}');
      final newEstimated = stringCount * avgChars * targetLanguages.length;
      print(
          '   Estimated: ~$newEstimated characters (${(newEstimated / service.freeQuotaChars * 100).toStringAsFixed(1)}% of free tier)');
    } else if (choice == '3') {
      print('Cancelled.');
      return;
    }

    // Step 9: Confirm
    print('\nReady to translate:');
    print('   CSV: $csvPath');
    print('   Rows: $dataStartRow to $dataEndRow ($stringCount strings)');
    print(
        '   Languages: ${targetLanguages.length} (${targetLanguages.join(', ')})');
    print(
        '   Estimated: ~${stringCount * avgChars * targetLanguages.length} characters');
    stdout.write('\nProceed with translation? (y/n): ');
    final confirm = stdin.readLineSync();

    if (confirm?.toLowerCase() != 'y') {
      print('Cancelled.');
      return;
    }

    // Step 10: Translate
    print('\nTranslating...');
    final quotaTracker = QuotaTracker();
    final updatedLines = List<String>.from(lines);

    for (int i = 0; i < dataRows.length; i++) {
      final row = dataRows[i];
      final columns = _parseCsvLine(row);
      final key = columns[0];
      final englishText = columns[1];

      if (englishText.isEmpty) {
        continue;
      }

      try {
        final translations = await service.translateBatch(
          text: englishText,
          targetLanguages: targetLanguages,
          apiKey: apiKey,
        );

        // Update the row with translations
        final newColumns = List<String>.from(columns);
        for (int j = 0; j < targetLanguages.length; j++) {
          final lang = targetLanguages[j];
          final langIndex = languages.indexOf(lang);
          if (langIndex != -1 && translations.containsKey(lang)) {
            newColumns[langIndex + 1] = translations[lang]!;
          }
        }

        // Update the line
        updatedLines[dataStartRow - 1 + i] = newColumns.join(',');

        // Track quota
        quotaTracker.addUsage(englishText.length * targetLanguages.length);

        // Show progress
        final progress = ((i + 1) / dataRows.length * 100).toStringAsFixed(1);
        print(
            '✅ [${i + 1}/${dataRows.length}] $key → Translated to ${targetLanguages.length} languages ($progress%)');

        // Warning if near quota
        if (quotaTracker.isNearLimit()) {
          print('⚠️  Quota Warning: ${quotaTracker.usageString}');
        }

        // Small delay to avoid rate limiting
        await Future.delayed(const Duration(milliseconds: 100));
      } catch (e) {
        print('❌ [${i + 1}/${dataRows.length}] $key failed: $e');
      }
    }

    // Step 11: Write updated CSV
    await csvFile.writeAsString(updatedLines.join('\n'));

    // Step 12: Summary
    print('\n✅ Translation Complete!');
    print('   CSV updated: $csvPath');
    print('   Rows: $dataStartRow to $dataEndRow');
    print('   Strings translated: $stringCount');
    print(
        '   Languages translated: ${targetLanguages.length} (${targetLanguages.join(', ')})');
    print('   API calls made: ${dataRows.length}');
    print('   Characters used: ${quotaTracker.usedChars}');
    print('   Quota remaining: ${quotaTracker.remaining}');
    print(
        '   Percentage used: ${quotaTracker.percentageUsed.toStringAsFixed(1)}%');

    print('\n${'━' * 50}');
    print('Next steps:');
    print('\n1. Review the translated CSV');
    print('2. Make manual corrections if needed');
    print('3. Generate localization files from CSV');
    print('   \$ dart run hardcoded_string_finder');
    print('   > Option 2: Generate localization files');
    print('━' * 50);
  } on InvalidApiKeyException catch (e) {
    print('\n❌ $e');
    print('   Check your API key at: https://langbly.com/dashboard');
  } on RateLimitException catch (e) {
    print('\n❌ $e');
    print('   Please wait and try again later');
  } on TranslationException catch (e) {
    print('\n❌ $e');
  } catch (e) {
    print('\n❌ Error: $e');
  }
}

/// Shows a 5x5 preview of the CSV with formatted table.
void _showCsvPreview(List<String> lines) {
  print('\n📋 CSV Preview (first 5 rows × first 5 columns):\n');

  // Collect first 5 columns from each of first 5 rows
  final tableData = <List<String>>[];
  for (final line in lines.take(5)) {
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

/// Gets the header row with validation.
Future<int> _getHeaderRowWithValidation(List<String> lines) async {
  while (true) {
    stdout.write(
        '\nWhich row number contains the language codes? (e.g. app_en, app_ru): ');
    final rowStr = stdin.readLineSync();
    final row = int.tryParse(rowStr ?? '') ?? 2;

    if (row < 1 || row > lines.length) {
      print('❌ Invalid row number. Must be between 1 and ${lines.length}');
      continue;
    }

    final columns = _parseCsvLine(lines[row - 1]);
    final hasLanguageCodes = _hasLanguageCodes(columns);

    if (hasLanguageCodes) {
      print('✅ Valid header row found');
      return row;
    } else {
      print('⚠️  Row $row doesn\'t contain language codes');
      print('   Expected format: app_en, app_ar, app_es, etc.');
    }
  }
}

/// Checks if a row contains language codes.
bool _hasLanguageCodes(List<String> columns) {
  for (int i = 1; i < columns.length; i++) {
    final col = columns[i].trim();
    if (col.startsWith('app_') || (col.contains('_') && col.length > 2)) {
      return true;
    }
  }
  return false;
}

/// Parses a CSV line, handling quoted values.
List<String> _parseCsvLine(String line) {
  final values = <String>[];
  bool inQuotes = false;
  String current = '';

  for (int i = 0; i < line.length; i++) {
    final ch = line[i];
    if (ch == '"') {
      inQuotes = !inQuotes;
    } else if (ch == ',' && !inQuotes) {
      values.add(current.trim());
      current = '';
    } else {
      current += ch;
    }
  }
  values.add(current.trim());

  return values;
}

/// Allows user to select specific languages.
Future<List<String>> _selectLanguages(List<String> languages) async {
  print('\nAvailable languages:');
  for (int i = 0; i < languages.length; i++) {
    print('   ${i + 1}. ${languages[i]}');
  }

  print('\nCommon selections:');
  print('   a. Spanish + Arabic');
  print('   b. Top 10 languages');
  print('   c. Custom selection (comma-separated numbers)');

  stdout.write('\n   Choice: ');
  final choice = stdin.readLineSync()?.toLowerCase();

  if (choice == 'a') {
    // Spanish + Arabic
    final selected = <String>[];
    for (final lang in languages) {
      if (lang.contains('es') || lang.contains('ar')) {
        selected.add(lang);
      }
    }
    return selected;
  } else if (choice == 'b') {
    // Top 10
    return languages.take(10).toList();
  } else if (choice == 'c') {
    stdout.write('   Enter language numbers (comma-separated): ');
    final input = stdin.readLineSync();
    final indices = input
        ?.split(',')
        .map((s) => int.tryParse(s.trim()))
        .where((i) => i != null)
        .toList();

    final selected = <String>[];
    for (final index in indices ?? []) {
      if (index! > 0 && index <= languages.length) {
        selected.add(languages[index - 1]);
      }
    }
    return selected;
  } else {
    // Default to all
    return languages;
  }
}
