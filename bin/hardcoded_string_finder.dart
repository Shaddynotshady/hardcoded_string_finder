import 'dart:io';
import 'package:hardcoded_string_finder/hardcoded_string_finder.dart';

/// dart run hardcoded_string_finder

/// Check if output folder exists and get string count
Future<bool> _folderExists(String folderName) async {
  final dir = Directory(folderName);
  return await dir.exists();
}

/// Get existing string count from CSV
Future<int> _getExistingStringCount(String folderName, String fileName) async {
  try {
    final file = File('$folderName/$fileName.csv');
    if (!await file.exists()) return 0;

    final content = await file.readAsString();
    final lines = content.split('\n').where((line) => line.trim().isNotEmpty);
    // Subtract 3 header rows to get data rows
    return lines.length > 3 ? lines.length - 3 : 0;
  } catch (e) {
    print('⚠️  Warning: Could not read existing CSV: $e');
    return 0;
  }
}

/// Find all existing string folders
Future<List<Map<String, dynamic>>> _findExistingStringFolders() async {
  final currentDir = Directory.current;
  final existingFolders = <Map<String, dynamic>>[];

  try {
    await for (final entity in currentDir.list()) {
      if (entity is Directory) {
        final folderName = entity.path.replaceAll('\\', '/').split('/').last;

        // Skip system, IDE, and common project folders
        if (folderName.startsWith('.') ||
            folderName == 'build' ||
            folderName == 'node_modules' ||
            folderName == 'android' ||
            folderName == 'ios' ||
            folderName == 'web' ||
            folderName == 'windows' ||
            folderName == 'macos' ||
            folderName == 'linux' ||
            folderName == 'test' ||
            folderName == 'integration_test' ||
            folderName == '.dart_tool') {
          continue;
        }

        // Check if folder contains CSV or JSON files (any localization files)
        final files = await entity.list().toList();
        final hasStringFiles = files.any((file) =>
            file is File &&
            (file.path.endsWith('.csv') || file.path.endsWith('.json')));

        if (hasStringFiles) {
          // Extract base name (remove _strings suffix if present)
          String baseName = folderName;
          if (folderName.endsWith('_strings')) {
            baseName = folderName.replaceAll('_strings', '');
          }

          final stringCount =
              await _getExistingStringCount(folderName, baseName);
          final stat = await entity.stat();
          final modified = stat.modified;

          existingFolders.add({
            'name': folderName,
            'baseName': baseName,
            'count': stringCount,
            'modified': modified,
          });
        }
      }
    }
  } catch (e) {
    print('⚠️  Warning: Could not scan directories: $e');
  }

  // Sort by modification date (most recent first)
  existingFolders.sort((a, b) => b['modified'].compareTo(a['modified']));
  return existingFolders;
}

/// Display existing folders to user
void _showExistingFolders(List<Map<String, dynamic>> folders) {
  if (folders.isEmpty) return;

  print('\n📁 Found existing string folders:');
  for (final folder in folders) {
    final daysAgo = DateTime.now().difference(folder['modified']).inDays;
    String timeAgo;
    if (daysAgo == 0) {
      timeAgo = 'today';
    } else if (daysAgo == 1) {
      timeAgo = 'yesterday';
    } else if (daysAgo < 7) {
      timeAgo = '$daysAgo days ago';
    } else {
      final weeksAgo = (daysAgo / 7).floor();
      timeAgo = '$weeksAgo week${weeksAgo > 1 ? 's' : ''} ago';
    }

    // Show clean base name instead of folder name with _strings suffix
    final displayName = folder['baseName'] ?? folder['name'];
    print(
        '   • $displayName (${folder['count']} strings) - last modified $timeAgo');
  }
  print('');
}

/// Warn user about existing folder and get confirmation
bool _warnAboutExistingFolder(
    String folderName, int existingCount, int newCount) {
  print(
      '\n⚠️  Folder "$folderName" already exists with $existingCount strings.');
  print('');
  print('If you continue, you\'ll see options to:');
  print('• 🔀 Smart Merge (keep existing translations)');
  if (newCount > existingCount) {
    print(
        '• 📁 Create New Version (add ${newCount - existingCount} new strings)');
  } else {
    print('• 📁 Create New Version (start fresh with $newCount strings)');
  }
  print('• ⚠️  Complete Overwrite (delete existing translations)');
  print('');

  stdout
      .write('Type \'y\' and press Enter to continue, or Ctrl+C to choose a different name: ');
  
  try {
    final input = stdin.readLineSync()?.trim().toLowerCase();
    // Only continue if user types 'y', otherwise wait
    while (input != 'y') {
      stdout.write('Please type \'y\' and press Enter to continue: ');
      final newInput = stdin.readLineSync()?.trim().toLowerCase();
      if (newInput == 'y') break;
    }
  } catch (e) {
    // If input fails, just continue
    print(' (auto-continuing due to input error)');
  }
  
  return true;
}

/// Show menu and get user choice
int _showMenu(String folderName, int existingCount, int newCount) {
  print('\n🔍 Found existing folder: $folderName/ with $existingCount strings');
  print('\nWhat would you like to do?\n');

  print('1. 🔀 Smart Merge (RECOMMENDED)');
  print('   → Keep all existing translations');
  print('   → Add new strings (empty translations ready)');
  print('   → Archive removed strings for reference');
  print('');

  print('2. 📁 Create New Version');
  print('   → Keep old files untouched');
  print('   → Create: ${folderName}_v2/');
  print('   → Start fresh with all $newCount strings');
  print('');

  print('3. ⚠️  Complete Overwrite');
  print('   → DELETE existing translations');
  print('   → Start from scratch');
  print('   → (Not recommended - you\'ll lose work!)');
  print('');

  stdout.write('Type your choice (1/2/3) and press Enter: ');

  String? choice;
  try {
    choice = stdin.readLineSync()?.trim();
  } catch (e) {
    print('⚠️  Input error, using Smart Merge (option 1) - default choice');
    return 1;
  }

  // Handle empty input - default to option 1
  if (choice == null || choice.trim().isEmpty) {
    print('⚠️  No input detected, using Smart Merge (option 1) - default choice');
    return 1;
  }

  choice = choice.trim();
  switch (choice) {
    case '1':
      return 1;
    case '2':
      return 2;
    case '3':
      return 3;
    default:
      print('⚠️  Invalid choice, using Smart Merge (option 1)');
      return 1;
  }
}

/// Get version name for new folder
String _getVersionName(String baseFolderName) {
  stdout.write('Enter version name (default: v2): ');
  String? version;
  
  try {
    version = stdin.readLineSync();
  } catch (e) {
    print('⚠️  Input error, using v2 - default version name');
    return '${baseFolderName}_v2';
  }

  // Handle empty input - default to v2
  if (version == null || version.trim().isEmpty) {
    print('⚠️  Using v2 - default version name');
    return '${baseFolderName}_v2';
  }

  version = version.trim();
  return '${baseFolderName}_$version';
}

/// Confirm overwrite action
bool _confirmOverwrite() {
  print('\n⚠️  Are you sure? This will delete all translations! (y/N): ');
  String? confirm = stdin.readLineSync()?.trim().toLowerCase();
  return confirm == 'y' || confirm == 'yes';
}

void main(List<String> args) async {
  print('🔍 Hardcoded String Finder v1.0.0\n');

  // Check if lib directory exists
  final libDir = Directory('lib');
  if (!libDir.existsSync()) {
    print('❌ Error: lib directory not found!');
    print('💡 Run this tool from your Flutter/Dart project root directory.');
    exit(1);
  }

  print('📂 Scanning lib directory...\n');

  // Scan for hardcoded strings
  final scanner = HardcodedScanner(rootPath: 'lib');
  final results = await scanner.scan();

  if (results.isEmpty) {
    print('✅ No hardcoded strings found! Your project is clean.');
    return;
  }

  print('🔍 Found ${results.length} unique hardcoded strings');

  // --- SHOW EXISTING FOLDERS UPFRONT ---
  print('🔍 Checking for existing localization folders...\n');
  final existingFolders = await _findExistingStringFolders();
  _showExistingFolders(existingFolders);

  // --- ASK FOR PROJECT NAME ---
  print('Enter project name (default: hardcoded_strings):');
  stdout.write('Project name: ');
  
  String? projectName;
  try {
    // Try to read input normally
    final input = stdin.readLineSync();
    
    // Handle different types of "empty" input across Windows terminals
    if (input == null || input.isEmpty) {
      // Empty or null input - treat as default
      projectName = 'hardcoded_strings';
      print('📝 Using default: hardcoded_strings');
    } else {
      // Trim whitespace and newlines
      projectName = input.trim();
      
      // Handle Windows-specific empty inputs
      if (projectName.isEmpty || 
          projectName == '\r' || 
          projectName == '\n' || 
          projectName == '\r\n' ||
          projectName.length == 0) {
        projectName = 'hardcoded_strings';
        print('📝 Using default: hardcoded_strings');
      }
    }
  } catch (e) {
    print('⚠️  Input error, using default name');
    projectName = 'hardcoded_strings';
  }

  final baseName = projectName;

  final folderName = '${baseName}_strings';
  final fileName = baseName;

  // --- CHECK IF CHOSEN FOLDER AND CSV EXIST ---
  // Cache folder existence to avoid duplicate checks
  final folderExists = await _folderExists(folderName);
  final csvExists =
      folderExists && await File('$folderName/$fileName.csv').exists();

  if (csvExists) {
    final existingCount = await _getExistingStringCount(folderName, fileName);

    // Show warning and get confirmation before showing menu
    _warnAboutExistingFolder(folderName, existingCount, results.length);
  }

  // --- SHOW MENU IF CSV EXISTS ---
  String finalFolderName = folderName;
  bool shouldMerge = false;
  bool shouldOverwrite = false;

  if (csvExists) {
    final existingCount = await _getExistingStringCount(folderName, fileName);
    final choice = _showMenu(folderName, existingCount, results.length);

    switch (choice) {
      case 1: // Smart Merge
        shouldMerge = true;
        finalFolderName = folderName;
        break;
      case 2: // New Version
        finalFolderName = _getVersionName(baseName);
        shouldMerge = false; // Fresh export
        break;
      case 3: // Overwrite
        if (!_confirmOverwrite()) {
          print('❌ Operation cancelled.');
          return;
        }
        shouldOverwrite = true;
        finalFolderName = folderName;
        break;
    }
  }

  // --- ASK FOR OUTPUT FORMATS ---
  print('\nSelect output formats:');
  print('1. JSON only');
  print('2. CSV only');
  print('3. Both JSON and CSV');
  stdout.write('Type your choice (1/2/3) and press Enter: ');

  String? formatChoice;
  try {
    formatChoice = stdin.readLineSync()?.trim();
  } catch (e) {
    print('⚠️  Input error, using both formats (JSON + CSV) - default choice');
    return;
  }

  // Handle empty input - default to both formats
  if (formatChoice == null || formatChoice.trim().isEmpty) {
    print('⚠️  No input detected, using both formats (JSON + CSV) - default choice');
    return;
  }

  formatChoice = formatChoice.trim();
  bool exportJson = formatChoice == '1' || formatChoice == '3';
  bool exportCsv = formatChoice == '2' || formatChoice == '3';

  // Default to both if invalid input
  if (!exportJson && !exportCsv) {
    print('⚠️  Invalid choice, exporting both formats.');
    exportJson = true;
    exportCsv = true;
  }

  // --- ASK USER FOR KEY FORMAT (only if CSV is selected) ---
  bool snakeCase = true; // Default
  if (exportCsv) {
    print('\nChoose key format for CSV:');
    print('1. Snake case (add_comment)');
    print('2. Readable lowercase (add comment)');
    stdout.write('Type your choice (1/2) and press Enter: ');

    String? input;
    try {
      input = stdin.readLineSync()?.trim();
    } catch (e) {
      print('⚠️  Input error, using snake_case for keys - default choice');
    }

    // Handle empty input - default to snake case
    if (input == null || input.trim().isEmpty) {
      print('⚠️  No input detected, using snake_case for keys - default choice');
    } else {
      input = input.trim();
      snakeCase = input == '1' || input != '2'; // Default to snake case
    }

    print(snakeCase
        ? '✓ Using snake_case for keys.\n'
        : '✓ Using readable lowercase for keys.\n');
  }

  // --- CREATE OUTPUT FOLDER ---
  final outputDir = Directory(finalFolderName);
  if (!outputDir.existsSync()) {
    outputDir.createSync();
    print('📁 Created folder: $finalFolderName/\n');
  } else if (shouldOverwrite) {
    // Delete existing files for overwrite option
    await _cleanFolder(finalFolderName, fileName);
    print('🗑️  Cleaned existing files for overwrite\n');
  }

  // --- EXPORT FILES ---
  print('Exporting...\n');

  if (exportJson) {
    await StringExporter.exportToJson(
      results,
      '$finalFolderName/$fileName.json',
    );
  }

  if (exportCsv) {
    await StringExporter.exportToCsv(
      results,
      '$finalFolderName/$fileName.csv',
      snakeCaseKeys: snakeCase,
    );
  }

  // --- SUMMARY ---
  print('\n✅ Done! Check the generated files:');
  print('   📁 $finalFolderName/');
  if (exportJson) {
    print('      📄 $fileName.json');
  }
  if (exportCsv) {
    print('      📊 $fileName.csv (opens in Excel/Google Sheets)');
  }

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

/// Clean folder for overwrite option
Future<void> _cleanFolder(String folderName, String fileName) async {
  try {
    final jsonFile = File('$folderName/$fileName.json');
    final csvFile = File('$folderName/$fileName.csv');

    if (await jsonFile.exists()) await jsonFile.delete();
    if (await csvFile.exists()) await csvFile.delete();
  } catch (e) {
    print('⚠️  Warning: Could not clean existing files: $e');
  }
}
