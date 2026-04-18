import 'dart:io';

/// Check if a folder exists
Future<bool> folderExists(String folderName) async {
  return await Directory(folderName).exists();
}

/// Get existing string count from CSV (subtract 3 header rows)
Future<int> getExistingStringCount(String folderName, String fileName) async {
  try {
    final file = File('$folderName/$fileName.csv');
    if (!await file.exists()) return 0;
    final lines = (await file.readAsString())
        .split('\n')
        .where((l) => l.trim().isNotEmpty);
    return lines.length > 3 ? lines.length - 3 : 0;
  } catch (e) {
    print('⚠️  Warning: Could not read existing CSV: $e');
    return 0;
  }
}

/// Scan current directory for folders that contain CSV/JSON files
Future<List<Map<String, dynamic>>> findExistingStringFolders() async {
  final currentDir = Directory.current;
  final existingFolders = <Map<String, dynamic>>[];

  const skipFolders = {
    'build',
    'node_modules',
    'android',
    'ios',
    'web',
    'windows',
    'macos',
    'linux',
    'test',
    'integration_test',
    '.dart_tool',
  };

  try {
    await for (final entity in currentDir.list()) {
      if (entity is! Directory) continue;

      final folderName = entity.path.contains('\\')
          ? entity.path.split('\\').last
          : entity.path.split('/').last;

      if (folderName.startsWith('.') || skipFolders.contains(folderName)) {
        continue;
      }

      final files = await entity.list().toList();
      final hasStringFiles = files.any((f) =>
          f is File && (f.path.endsWith('.csv') || f.path.endsWith('.json')));

      if (!hasStringFiles) continue;

      final baseName = folderName.endsWith('_strings')
          ? folderName.replaceAll('_strings', '')
          : folderName;

      final stringCount = await getExistingStringCount(folderName, baseName);
      final modified = (await entity.stat()).modified;

      existingFolders.add({
        'name': folderName,
        'baseName': baseName,
        'count': stringCount,
        'modified': modified,
      });
    }
  } catch (e) {
    print('⚠️  Warning: Could not scan directories: $e');
  }

  existingFolders.sort((a, b) => b['modified'].compareTo(a['modified']));
  return existingFolders;
}

/// Print list of existing string folders
void showExistingFolders(List<Map<String, dynamic>> folders) {
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
      timeAgo = '$weeksAgo week${weeksAgo > 1 ? "s" : ""} ago';
    }
    final displayName = folder['baseName'] ?? folder['name'];
    print(
        '   • $displayName (${folder['count']} strings) - last modified $timeAgo');
  }
  print('');
}

/// Warn user that folder already exists before showing merge menu
void warnAboutExistingFolder(
    String folderName, int existingCount, int newCount) {
  print(
      '\n⚠️  Folder "$folderName" already exists with $existingCount strings.\n');
  print('If you continue, you\'ll see options to:');
  print('• 🔀 Smart Merge (keep existing translations)');
  if (newCount > existingCount) {
    print(
        '• 📁 Create New Version (add ${newCount - existingCount} new strings)');
  } else {
    print('• 📁 Create New Version (start fresh with $newCount strings)');
  }
  print('• ⚠️  Complete Overwrite (delete existing translations)\n');

  stdout.write('Type \'y\' and press Enter to continue, or Ctrl+C to cancel: ');

  try {
    var input = stdin.readLineSync()?.trim().toLowerCase();
    while (input != 'y') {
      stdout.write('Please type \'y\' and press Enter to continue: ');
      input = stdin.readLineSync()?.trim().toLowerCase();
    }
  } catch (_) {
    print(' (auto-continuing due to input error)');
  }
}

/// Show merge/version/overwrite menu, return 1/2/3
int showMergeMenu(String folderName, int existingCount, int newCount) {
  print('\n🔍 Found existing folder: $folderName/ with $existingCount strings');
  print('\nWhat would you like to do?\n');
  print('1. 🔀 Smart Merge (RECOMMENDED)');
  print('   → Keep all existing translations');
  print('   → Add new strings (empty translations ready)');
  print('   → Archive removed strings for reference\n');
  print('2. 📁 Create New Version');
  print('   → Keep old files untouched');
  print('   → Create: ${folderName}_v2/');
  print('   → Start fresh with all $newCount strings\n');
  print('3. ⚠️  Complete Overwrite');
  print('   → DELETE existing translations');
  print('   → Start from scratch');
  print('   → (Not recommended - you\'ll lose work!)\n');

  stdout.write('Type your choice (1/2/3) and press Enter: ');

  String? choice;
  try {
    choice = stdin.readLineSync()?.trim();
  } catch (_) {
    print('⚠️  Input error, using Smart Merge (option 1)');
    return 1;
  }

  if (choice == null || choice.isEmpty) {
    print('⚠️  No input detected, using Smart Merge (option 1)');
    return 1;
  }

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

/// Ask user for a version suffix, returns full folder name like myapp_v2
String getVersionFolderName(String baseFolderName) {
  stdout.write('Enter version name (default: v2): ');
  String? version;
  try {
    version = stdin.readLineSync();
  } catch (_) {
    print('⚠️  Input error, using v2');
    return '${baseFolderName}_v2';
  }
  if (version == null || version.trim().isEmpty) {
    print('⚠️  Using v2 - default version name');
    return '${baseFolderName}_v2';
  }
  return '${baseFolderName}_${version.trim()}';
}

/// Ask user to confirm destructive overwrite
bool confirmOverwrite() {
  print('\n⚠️  Are you sure? This will delete all translations! (y/N): ');
  final confirm = stdin.readLineSync()?.trim().toLowerCase();
  return confirm == 'y' || confirm == 'yes';
}

/// Read a line from stdin safely with a fallback default
String readLine({String fallback = ''}) {
  try {
    final input = stdin.readLineSync()?.trim() ?? '';
    return input.isEmpty ? fallback : input;
  } catch (_) {
    return fallback;
  }
}

/// Clean (delete) json and csv files inside a folder
Future<void> cleanFolder(String folderName, String fileName) async {
  try {
    final jsonFile = File('$folderName/$fileName.json');
    final csvFile = File('$folderName/$fileName.csv');
    if (await jsonFile.exists()) await jsonFile.delete();
    if (await csvFile.exists()) await csvFile.delete();
  } catch (e) {
    print('⚠️  Warning: Could not clean existing files: $e');
  }
}
