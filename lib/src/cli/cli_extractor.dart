import 'dart:io';
import 'package:hardcoded_string_finder/hardcoded_string_finder.dart';

/// Full v1 flow: scan lib/, ask questions, export CSV/JSON
Future<void> runExtractor(List<String> args) async {
  // Check lib/ directory exists
  if (!Directory('lib').existsSync()) {
    print('❌ Error: lib directory not found!');
    print('💡 Run this tool from your Flutter/Dart project root directory.');
    exit(1);
  }

  print('📂 Scanning lib directory...\n');

  final scanner = HardcodedScanner(rootPath: 'lib');
  final results = await scanner.scan();

  if (results.isEmpty) {
    print('✅ No hardcoded strings found! Your project is clean.');
    return;
  }

  print('🔍 Found ${results.length} unique hardcoded strings');

  // Show existing localization folders
  print('🔍 Checking for existing localization folders...\n');
  final existingFolders = await findExistingStringFolders();
  showExistingFolders(existingFolders);

  // --- ASK FOR PROJECT NAME ---
  print('Enter project name (default: hardcoded_strings):');
  stdout.write('Project name: ');
  final projectName = readLine(fallback: 'hardcoded_strings');
  if (projectName == 'hardcoded_strings') {
    print('📝 Using default: hardcoded_strings');
  }

  // Resolve folder and file names
  String folderName;
  String fileName;

  if (projectName.endsWith('_strings')) {
    folderName = projectName;
    fileName = projectName.replaceAll('_strings', '');
  } else if (projectName.endsWith('_string')) {
    folderName = '${projectName}s';
    fileName = projectName.replaceAll('_string', '');
  } else {
    folderName = '${projectName}_strings';
    fileName = projectName;
  }

  // Check if CSV already exists
  final csvExists = await folderExists(folderName) &&
      await File('$folderName/$fileName.csv').exists();

  if (csvExists) {
    final existingCount = await getExistingStringCount(folderName, fileName);
    warnAboutExistingFolder(folderName, existingCount, results.length);
  }

  // --- MERGE / VERSION / OVERWRITE MENU ---
  String finalFolderName = folderName;
  bool shouldMerge = false;
  bool shouldOverwrite = false;

  if (csvExists) {
    final existingCount = await getExistingStringCount(folderName, fileName);
    final choice = showMergeMenu(folderName, existingCount, results.length);

    switch (choice) {
      case 1:
        shouldMerge = true;
        finalFolderName = folderName;
        break;
      case 2:
        finalFolderName = getVersionFolderName(projectName);
        break;
      case 3:
        if (!confirmOverwrite()) {
          print('❌ Operation cancelled.');
          return;
        }
        shouldOverwrite = true;
        finalFolderName = folderName;
        break;
    }
  }

  // --- OUTPUT FORMAT ---
  print('\nSelect output formats:');
  print('1. JSON only');
  print('2. CSV only');
  print('3. Both JSON and CSV');
  stdout.write('Type your choice (1/2/3) and press Enter: ');

  final formatChoice = readLine(fallback: '3');
  bool exportJson = formatChoice == '1' || formatChoice == '3';
  bool exportCsv = formatChoice == '2' || formatChoice == '3';

  if (!exportJson && !exportCsv) {
    print('⚠️  Invalid choice, exporting both formats.');
    exportJson = true;
    exportCsv = true;
  }

  // --- KEY FORMAT (CSV only) ---
  bool snakeCase = true;
  if (exportCsv) {
    print('\nChoose key format for CSV:');
    print('1. Snake case (add_comment)');
    print('2. Readable lowercase (add comment)');
    stdout.write('Type your choice (1/2) and press Enter: ');

    final keyChoice = readLine(fallback: '1');
    snakeCase = keyChoice != '2';

    print(snakeCase
        ? '✓ Using snake_case for keys.\n'
        : '✓ Using readable lowercase for keys.\n');
  }

  // --- CREATE FOLDER ---
  final outputDir = Directory(finalFolderName);
  if (!outputDir.existsSync()) {
    outputDir.createSync();
    print('📁 Created folder: $finalFolderName/\n');
  } else if (shouldOverwrite) {
    await cleanFolder(finalFolderName, fileName);
    print('🗑️  Cleaned existing files for overwrite\n');
  }

  // --- EXPORT ---
  print('Exporting...\n');

  if (exportJson) {
    await StringExporter.exportToJson(
      results,
      '$finalFolderName/$fileName.json',
      onProgress: print,
    );
  }

  if (exportCsv) {
    await StringExporter.exportToCsv(
      results,
      '$finalFolderName/$fileName.csv',
      snakeCaseKeys: snakeCase,
      onProgress: print,
    );
  }

  // --- SUMMARY ---
  print('\n✅ Done! Check the generated files:');
  print('   📁 $finalFolderName/');
  if (exportJson) print('      📄 $fileName.json');
  if (exportCsv) print('      📊 $fileName.csv (opens in Excel/Google Sheets)');

  if (shouldMerge) {
    print(
        '\n🔀 Smart Merge completed: Your existing translations are preserved!');
  } else if (shouldOverwrite) {
    print(
        '\n⚠️  Overwrite completed: Previous translations have been deleted.');
  }

  if (exportCsv) {
    print(
        '\n💡 Tip: Double-click CSV to open in Excel or upload to Google Sheets');
  }
}
