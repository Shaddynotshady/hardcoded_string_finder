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

/// Full GetX flow: read CSV → preview → ask rows → ask package name → generate GetX files
Future<void> runGetXGenerator() async {
  print('\n🌍 GetX Map Generator\n');

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
  await GetXGenerator.showCsvPreview(csvPath);

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
    final headerCols = GetXGenerator.parseCsvLine(headerLine);
    final hasLanguageCodes = GetXGenerator.validateHeaderRow(headerCols);

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

  // --- STEP 5: Ask for package name ---
  print('Enter your package name:');
  print('(This will be used for imports in app_translations.dart)');
  print('(default: my_app)');
  stdout.write('Package name: ');

  final packageInput = readLine(fallback: '');
  final packageName = packageInput.isEmpty ? 'my_app' : packageInput;

  print('✅ Package name: $packageName\n');

  // --- STEP 6: Ask output folder ---
  print('Enter output folder for GetX files:');
  print('(default: lib/localization)');
  stdout.write('Output folder: ');

  final outputInput = readLine(fallback: '');
  final outputDir = outputInput.isEmpty ? 'lib/localization' : outputInput;

  print('\n🔄 Generating GetX files...\n');

  // --- STEP 7: Generate ---
  try {
    final result = await GetXGenerator.generate(
      csvPath: csvPath,
      headerRow: headerRow,
      dataStartRow: effectiveDataStart,
      outputDir: outputDir,
      packageName: packageName,
      onProgress: print,
    );

    // Write report if there are missing translations
    await GetXGenerator.writeReport(
      result: result,
      outputDir: outputDir,
      onProgress: print,
    );

    // --- STEP 8: Summary ---
    print('\n✅ Done!');
    print('   📁 $outputDir/');
    print('   📁 $outputDir/languages/');
    print('   📄 $outputDir/app_translations.dart');
    print('   🌍 ${result.filesCreated} files created');
    print('   🔑 ${result.totalKeys} total keys\n');

    print('━' * 50);
    print('Next steps:\n');
    print('1. Run:');
    print('      flutter pub add get\n');
    print('2. In your main.dart, configure GetX:');
    print('      GetMaterialApp(');
    print('        translations: AppTranslations(),');
    print('        locale: Locale(\'en\', \'US\'),');
    print('        fallbackLocale: Locale(\'en\', \'US\'),');
    print('      )');
    print('━' * 50);
  } catch (e) {
    print('❌ Error generating GetX files: $e');
  }
}
