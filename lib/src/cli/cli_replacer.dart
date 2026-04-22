import 'dart:io';
import 'package:hardcoded_string_finder/hardcoded_string_finder.dart';
import 'package:hardcoded_string_finder/src/replacer/replacer.dart';

/// Run the auto-replace flow
Future<void> runReplacer() async {
  print('\n🔄 Auto-replace Hardcoded Strings\n');

  // Check lib/ directory exists
  if (!Directory('lib').existsSync()) {
    print('❌ Error: lib directory not found!');
    print('💡 Run this tool from your Flutter/Dart project root directory.');
    exit(1);
  }

  // Step 1: Choose format
  print('Choose your localization format:\n');
  print('1. ARB (Official Flutter)');
  print('   → AppLocalizations.of(context).key');
  print('2. GetX Map');
  print('   → \'key\'.tr\n');
  stdout.write('Type your choice (1/2) and press Enter: ');

  String? formatChoice;
  try {
    formatChoice = stdin.readLineSync()?.trim();
  } catch (_) {
    print('⚠️  Input error, defaulting to ARB format');
    formatChoice = '1';
  }

  String format;
  String defaultPath;
  String formatName;

  switch (formatChoice) {
    case '2':
      format = 'getx';
      formatName = 'GetX Map';
      defaultPath = 'lib/localization/';
      break;
    case '1':
    default:
      format = 'arb';
      formatName = 'ARB (Official Flutter)';
      defaultPath = 'lib/l10n/';
      break;
  }

  print('\n✓ Selected: $formatName\n');
  // format will be used to determine replacement pattern (e.g., AppLocalizations vs tr.key)

  // Step 2: Ask for folder path
  print('Enter path to your localization files:');
  stdout.write('(default: $defaultPath): ');

  String? folderPath;
  try {
    folderPath = stdin.readLineSync()?.trim();
  } catch (_) {
    folderPath = '';
  }

  if (folderPath == null || folderPath.isEmpty) {
    folderPath = defaultPath;
    print('📝 Using default: $defaultPath');
  }

  // Validate folder exists
  final folder = Directory(folderPath);
  if (!folder.existsSync()) {
    print('\n❌ Error: Folder "$folderPath" does not exist!');
    print('💡 Please generate localization files first using Option 2.');
    exit(1);
  }

  // Validate folder has files
  final files = folder.listSync().whereType<File>().toList();
  if (files.isEmpty) {
    print('\n❌ Error: Folder "$folderPath" is empty!');
    print('💡 Please generate localization files first using Option 2.');
    exit(1);
  }

  print('✓ Found ${files.length} file(s) in $folderPath\n');

  // Step 3: Scan for hardcoded strings
  print('📂 Scanning lib directory for hardcoded strings...\n');

  final scanner = HardcodedScanner(rootPath: 'lib');
  final results = await scanner.scan();

  if (results.isEmpty) {
    print('✅ No hardcoded strings found! Your project is clean.');
    return;
  }

  print('🔍 Found ${results.length} unique hardcoded strings\n');

  // Step 4: Backup suggestion
  print('⚠️  This will modify your source files.');
  print('💡 It\'s recommended to create a backup before proceeding.');
  stdout.write('Create backup to .hardcoded_backup/? (y/N): ');

  String? backupChoice;
  try {
    backupChoice = stdin.readLineSync()?.trim().toLowerCase();
  } catch (_) {
    backupChoice = 'n';
  }

  final shouldBackup = backupChoice == 'y' || backupChoice == 'yes';

  if (shouldBackup) {
    print('📦 Creating backup...\n');
    await createBackup();
    print('✓ Backup created to .hardcoded_backup/\n');
    print('💡 To restore backup later, run:');
    print('   rm -rf lib && cp -r .hardcoded_backup/lib lib\n');
  } else {
    print('⚠️  Skipping backup (not recommended)\n');
  }

  // Step 5: Perform replacement
  print('🔄 Replacing hardcoded strings...\n');

  // Create replacer instance
  final replacer = HardcodedReplacer(
    format: format,
    localizationPath: folderPath,
  );

  // Load localization keys
  print('📂 Loading localization keys...');
  final localizationKeys = await replacer.loadLocalizationKeys();

  if (localizationKeys.isEmpty) {
    print('❌ No localization keys found in files!');
    print('💡 Make sure your localization files contain key-value pairs.');
    exit(1);
  }

  print('✓ Loaded ${localizationKeys.length} localization keys\n');

  // Find replacements and track missed strings
  print('🔍 Finding matching strings...');
  final findResult =
      await replacer.findReplacementsWithMissed(localizationKeys);

  if (findResult.replacementsByFile.isEmpty) {
    print('✅ No matching hardcoded strings found to replace!');
    return;
  }

  int totalReplacements = 0;
  for (final entry in findResult.replacementsByFile.entries) {
    totalReplacements += entry.value.length;
  }

  print(
      '✓ Found $totalReplacements replacements in ${findResult.replacementsByFile.length} files');
  print('   (Asset/image files are automatically skipped)\n');

  // Show missed strings at the end
  if (findResult.missedStrings.isNotEmpty) {
    print(
        '⚠️  ${findResult.missedStrings.length} strings NOT found in localization file:');
    for (final missed in findResult.missedStrings) {
      print('   • ${missed.filePath}:${missed.lineNumber} - "${missed.value}"');
    }
    print('');
  }

  // File-by-file preview (only mode)
  final fileNames = findResult.replacementsByFile.keys.toList()..sort();
  int fileIndex = 0;

  for (final filePath in fileNames) {
    fileIndex++;
    final replacements = findResult.replacementsByFile[filePath]!;

    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print(
        '[$fileIndex/${fileNames.length}] $filePath (${replacements.length} strings)');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    // Process in batches of 10
    final batchSize = 10;
    int totalReplaced = 0;
    int totalBatches = (replacements.length / batchSize).ceil();

    for (int batchIndex = 0; batchIndex < totalBatches; batchIndex++) {
      final startIdx = batchIndex * batchSize;
      final endIdx = (startIdx + batchSize).clamp(0, replacements.length);
      final batch = replacements.sublist(startIdx, endIdx);

      print(
          '\n--- Batch ${batchIndex + 1}/$totalBatches (Strings ${startIdx + 1}-$endIdx) ---');
      for (int i = 0; i < batch.length; i++) {
        print('${startIdx + i + 1}. ${batch[i].toString()}');
      }

      stdout.write(
          '\n[Replace these ${batch.length} strings? Enter indices to skip (e.g., 2,5,6) or press Enter to replace all]: ');
      String? skipInput;
      try {
        skipInput = stdin.readLineSync()?.trim();
      } catch (_) {
        skipInput = '';
      }

      final batchReplacements = <Replacement>[];
      int skippedCount = 0;
      if (skipInput != null && skipInput.isNotEmpty) {
        final skipIndices = skipInput
            .split(',')
            .map((s) => int.tryParse(s.trim()))
            .where((i) => i != null && i > 0 && i <= replacements.length)
            .cast<int>()
            .toSet();

        if (skipIndices.isNotEmpty) {
          // Check if any indices are outside current batch range
          final invalidIndices =
              skipIndices.where((i) => i < startIdx + 1 || i > endIdx).toList();
          final validIndices = skipIndices
              .where((i) => i >= startIdx + 1 && i <= endIdx)
              .toSet();

          if (invalidIndices.isNotEmpty) {
            print(
                '⚠️  Warning: Indices ${invalidIndices.join(', ')} are outside the current batch range (${startIdx + 1}-$endIdx)');
            print('💡 These indices will be ignored');
            skippedCount = invalidIndices.length;
          }

          if (validIndices.isNotEmpty) {
            final validIndicesList = validIndices.toList()..sort();
            print('⏭️  Skipping indices: ${validIndicesList.join(', ')}');
            skippedCount += validIndices.length;

            for (int i = 0; i < batch.length; i++) {
              if (!validIndices.contains(startIdx + i + 1)) {
                batchReplacements.add(batch[i]);
              }
            }
          } else {
            batchReplacements.addAll(batch);
          }
        } else {
          batchReplacements.addAll(batch);
        }
      } else {
        batchReplacements.addAll(batch);
      }

      // Replace this batch immediately
      if (batchReplacements.isNotEmpty) {
        final actualReplaced =
            await replacer.replaceInFile(filePath, batchReplacements);
        print(
            '✓ Replaced $actualReplaced/${batch.length} strings, Skipped: $skippedCount\n');
        totalReplaced += actualReplaced;
      } else {
        print('⏭️  All strings in this batch skipped\n');
      }
    }

    print('✓ Total replaced: $totalReplaced/${replacements.length} strings\n');

    if (fileIndex < fileNames.length) {
      stdout.write('[Continue to next file? y/n]: ');
      String? continueChoice;
      try {
        continueChoice = stdin.readLineSync()?.trim().toLowerCase();
      } catch (_) {
        continueChoice = 'y';
      }

      if (continueChoice == 'n' || continueChoice == 'no') {
        print('⏹️  Stopping replacement process');
        break;
      }
    }
  }

  print('\n✅ Replacement completed!');
}

/// Create backup of lib/ directory
Future<void> createBackup() async {
  final backupDir = Directory('.hardcoded_backup');

  if (backupDir.existsSync()) {
    backupDir.deleteSync(recursive: true);
  }

  backupDir.createSync();

  final libDir = Directory('lib');
  await _copyDirectory(libDir, Directory('.hardcoded_backup/lib'));
}

/// Recursively copy directory
Future<void> _copyDirectory(Directory source, Directory destination) async {
  await destination.create(recursive: true);

  await for (final entity in source.list(recursive: true)) {
    final relativePath = entity.path.substring(source.path.length);
    final newPath = '${destination.path}$relativePath';

    if (entity is File) {
      await entity.copy(newPath);
    } else if (entity is Directory) {
      await Directory(newPath).create(recursive: true);
    }
  }
}
