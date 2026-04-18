import 'dart:io';
import 'dart:convert';
import 'package:hardcoded_string_finder/hardcoded_string_finder.dart';

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

/// Full JSON flow: read CSV → preview → ask rows → ask output folder → generate JSON files
Future<void> runJsonGenerator() async {
  print('\n🌍 Simple JSON Generator\n');

  // --- STEP 1: Ask for CSV path ---
  print('Enter path to your CSV file:');
  print('(default: ./hardcoded_strings/hardcoded_strings.csv)');
  stdout.write('CSV path: ');

  final csvInput = readLine(fallback: '');
  final csvPath =
      csvInput.isEmpty ? './hardcoded_strings/hardcoded_strings.csv' : csvInput;

  if (!await File(csvPath).exists()) {
    print('❌ File not found: $csvPath');
    print('💡 Make sure the path is correct and try again.');
    return;
  }

  print('✅ Found: $csvPath\n');

  // --- STEP 2: Show 5x5 preview ---
  await JsonGenerator.showCsvPreview(csvPath);

  // --- STEP 3: Ask which row has language codes ---
  final file = File(csvPath);
  final lines = (await _readFileWithEncoding(file))
      .split('\n')
      .where((l) => l.trim().isNotEmpty)
      .toList();

  int headerRow;
  while (true) {
    stdout.write(
        'Which row number contains the language codes? (e.g. app_en, app_ru): ');
    final headerInput = readLine(fallback: '2');
    headerRow = int.tryParse(headerInput) ?? 2;

    // Validate row number range
    if (headerRow < 1 || headerRow > lines.length) {
      print('❌ Error: Row number must be between 1 and ${lines.length}');
      continue;
    }

    // Check if the selected row contains language codes
    final headerLine = lines[headerRow - 1];
    final headerCols = JsonGenerator.parseCsvLine(headerLine);
    final hasLanguageCodes = JsonGenerator.validateHeaderRow(headerCols);

    if (!hasLanguageCodes) {
      print(
          '❌ Error: Row $headerRow does not appear to contain language codes.');
      print('💡 Language codes should look like: app_en, app_ru, app_zh_hk');
      print('💡 Please check the CSV preview and try again.\n');
      continue;
    }

    // Valid row, break out of loop
    break;
  }

  // --- STEP 4: Ask which row data starts ---
  stdout.write('Which row number does the translation data start?: ');
  final dataInput = readLine(fallback: '4');
  final dataStartRow = int.tryParse(dataInput) ?? 4;

  if (dataStartRow <= headerRow) {
    print(
        '⚠️  Data start row ($dataStartRow) must be after header row ($headerRow).');
    print('💡 Using header row + 1 as data start.');
  }

  final effectiveDataStart =
      dataStartRow > headerRow ? dataStartRow : headerRow + 1;

  print('\n✅ Settings:');
  print('   Language codes row : $headerRow');
  print('   Data starts at row : $effectiveDataStart\n');

  // --- STEP 5: Ask output folder ---
  print('Enter output folder for JSON files:');
  print('(default: assets/translations)');
  stdout.write('Output folder: ');

  final outputInput = readLine(fallback: '');
  final outputDir = outputInput.isEmpty ? 'assets/translations' : outputInput;

  print('\n🔄 Generating JSON files...\n');

  // --- STEP 6: Generate ---
  try {
    final result = await JsonGenerator.generate(
      csvPath: csvPath,
      headerRow: headerRow,
      dataStartRow: effectiveDataStart,
      outputDir: outputDir,
      onProgress: print,
    );

    // Write report if there are missing translations
    await JsonGenerator.writeReport(
      result: result,
      outputDir: outputDir,
      onProgress: print,
    );

    // --- STEP 7: Summary ---
    print('\n✅ Done!');
    print('   📁 $outputDir/');
    print('   🌍 ${result.filesCreated} JSON files created');
    print('   🔑 ${result.totalKeys} total keys\n');

    print('━' * 50);
    print('Next steps:\n');
    print('1. Add to your pubspec.yaml:');
    print('      flutter:');
    print('        assets:');
    print('          - $outputDir/\n');
    print('2. Run:');
    print('      flutter pub get');
    print('3. Load JSON files in your app:');
    print(
        '      final content = await rootBundle.loadString(\'$outputDir/app_en.json\');');
    print('      final translations = jsonDecode(content);');
    print('━' * 50);
  } catch (e) {
    print('❌ Error generating JSON files: $e');
  }
}
