import 'dart:io';
import 'dart:convert';
import 'package:hardcoded_string_finder/src/scanner/scanner.dart';

/// Represents a single replacement to be made
class Replacement {
  final String filePath;
  final int lineNumber;
  final String original;
  final String replacement;
  final String key;

  Replacement({
    required this.filePath,
    required this.lineNumber,
    required this.original,
    required this.replacement,
    required this.key,
  });

  @override
  String toString() {
    return 'Line $lineNumber: - $original\n         + $replacement';
  }
}

/// Result of replacement operation
class ReplacementResult {
  final int filesModified;
  final int totalReplacements;
  final Map<String, int> replacementsByFile;

  ReplacementResult({
    required this.filesModified,
    required this.totalReplacements,
    required this.replacementsByFile,
  });
}

/// Result of find replacements with missed strings
class FindReplacementsResult {
  final Map<String, List<Replacement>> replacementsByFile;
  final List<MissedString> missedStrings;

  FindReplacementsResult({
    required this.replacementsByFile,
    required this.missedStrings,
  });
}

/// Represents a missed string with location info
class MissedString {
  final String value;
  final String filePath;
  final int lineNumber;

  MissedString({
    required this.value,
    required this.filePath,
    required this.lineNumber,
  });

  @override
  String toString() {
    return '$filePath:$lineNumber - "$value"';
  }
}

/// Replacer for hardcoded strings with localization keys
class HardcodedReplacer {
  final String format;
  final String localizationPath;

  // Files/patterns to skip during replacement (asset/image/color files)
  static const List<String> ignorePatterns = [
    'app_images.dart',
    'app_assets.dart',
    'app_icons.dart',
    'app_colors.dart',
    'assets.dart',
    'images.dart',
    'icons.dart',
    'colors.dart',
    'generated/',
  ];

  HardcodedReplacer({
    required this.format,
    required this.localizationPath,
  });

  /// Check if a file should be ignored
  bool shouldIgnoreFile(String filePath) {
    final lowerPath = filePath.toLowerCase();
    for (final pattern in ignorePatterns) {
      if (lowerPath.contains(pattern.toLowerCase())) {
        return true;
      }
    }
    return false;
  }

  /// Load localization keys from files based on format
  Future<Map<String, String>> loadLocalizationKeys() async {
    final keys = <String, String>{};
    final dir = Directory(localizationPath);

    if (!await dir.exists()) {
      throw Exception('Localization directory not found: $localizationPath');
    }

    // Search recursively for files
    final files = await _findFilesRecursively(dir);

    for (final file in files) {
      final fileKeys = await _loadKeysFromFile(file);
      keys.addAll(fileKeys);
    }

    return keys;
  }

  /// Find all files recursively in a directory
  Future<List<File>> _findFilesRecursively(Directory dir) async {
    final files = <File>[];

    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        files.add(entity);
      }
    }

    return files;
  }

  /// Load keys from a single file based on format
  Future<Map<String, String>> _loadKeysFromFile(File file) async {
    final keys = <String, String>{};

    try {
      final content = await file.readAsString();

      switch (format) {
        case 'arb':
          if (file.path.endsWith('.arb')) {
            final json = jsonDecode(content) as Map<String, dynamic>;
            // Skip metadata keys like @@locale
            for (final entry in json.entries) {
              if (!entry.key.startsWith('@@')) {
                keys[entry.key] = entry.value.toString();
              }
            }
          }
          break;
        case 'getx':
          if (file.path.endsWith('.dart')) {
            // Parse GetX Map files
            final regex = RegExp(r"'([^']+)':\s*'([^']*)'");
            for (final match in regex.allMatches(content)) {
              keys[match.group(1)!] = match.group(2)!;
            }
          }
          break;
        case 'json':
          if (file.path.endsWith('.json')) {
            final json = jsonDecode(content) as Map<String, dynamic>;
            for (final entry in json.entries) {
              keys[entry.key] = entry.value.toString();
            }
          }
          break;
      }
    } catch (e) {
      print('⚠️  Warning: Could not load keys from ${file.path}: $e');
    }

    return keys;
  }

  /// Generate replacement pattern for a key based on format
  String generateReplacementPattern(String key, String originalString) {
    switch (format) {
      case 'arb':
        return 'AppLocalizations.of(context).$key';
      case 'getx':
        // GetX uses 'key'.tr (key in quotes, tr outside)
        return "'$key'.tr";
      default:
        return 'AppLocalizations.of(context).$key';
    }
  }

  /// Find all replacements needed in the project
  Future<Map<String, List<Replacement>>> findReplacements(
    Map<String, String> localizationKeys,
  ) async {
    final replacementsByFile = <String, List<Replacement>>{};

    // Scan for hardcoded strings with details
    final scanner = HardcodedScanner(rootPath: 'lib');
    final results = await scanner.scanWithDetails();

    for (final result in results) {
      // Skip if file should be ignored
      if (shouldIgnoreFile(result.filePath)) {
        continue;
      }

      final key = _findMatchingKey(result.value, localizationKeys);
      if (key != null) {
        final replacement = generateReplacementPattern(key, result.value);

        final replacementObj = Replacement(
          filePath: result.filePath,
          lineNumber: result.lineNumber,
          original: result.value,
          replacement: replacement,
          key: key,
        );

        replacementsByFile
            .putIfAbsent(result.filePath, () => [])
            .add(replacementObj);
      }
    }

    return replacementsByFile;
  }

  /// Find all replacements and track missed strings
  Future<FindReplacementsResult> findReplacementsWithMissed(
    Map<String, String> localizationKeys,
  ) async {
    final replacementsByFile = <String, List<Replacement>>{};
    final missedStrings = <MissedString>{};

    // Scan for hardcoded strings with details
    final scanner = HardcodedScanner(rootPath: 'lib');
    final results = await scanner.scanWithDetails();

    for (final result in results) {
      // Skip if file should be ignored
      if (shouldIgnoreFile(result.filePath)) {
        continue;
      }

      final key = _findMatchingKey(result.value, localizationKeys);
      if (key != null) {
        final replacement = generateReplacementPattern(key, result.value);

        final replacementObj = Replacement(
          filePath: result.filePath,
          lineNumber: result.lineNumber,
          original: result.value,
          replacement: replacement,
          key: key,
        );

        replacementsByFile
            .putIfAbsent(result.filePath, () => [])
            .add(replacementObj);
      } else {
        // Track missed strings with file and line info
        missedStrings.add(MissedString(
          value: result.value,
          filePath: result.filePath,
          lineNumber: result.lineNumber,
        ));
      }
    }

    return FindReplacementsResult(
      replacementsByFile: replacementsByFile,
      missedStrings: missedStrings.toList(),
    );
  }

  /// Find a matching localization key for a string
  String? _findMatchingKey(
    String hardcodedString,
    Map<String, String> localizationKeys,
  ) {
    // First try exact match
    if (localizationKeys.containsValue(hardcodedString)) {
      for (final entry in localizationKeys.entries) {
        if (entry.value == hardcodedString) {
          return entry.key;
        }
      }
    }

    // Try case-insensitive match
    final lowerString = hardcodedString.toLowerCase();
    for (final entry in localizationKeys.entries) {
      if (entry.value.toLowerCase() == lowerString) {
        return entry.key;
      }
    }

    // Try with trimmed whitespace
    final trimmedString = hardcodedString.trim();
    if (localizationKeys.containsValue(trimmedString)) {
      for (final entry in localizationKeys.entries) {
        if (entry.value == trimmedString) {
          return entry.key;
        }
      }
    }

    return null;
  }

  /// Apply all replacements at once
  Future<ReplacementResult> replaceAll(
    Map<String, List<Replacement>> replacementsByFile,
  ) async {
    int totalReplacements = 0;
    final replacementsByFileCount = <String, int>{};

    for (final entry in replacementsByFile.entries) {
      final filePath = entry.key;
      final replacements = entry.value;

      if (replacements.isEmpty) continue;

      final file = File(filePath);
      if (!await file.exists()) continue;

      final lines = await file.readAsLines();
      var modified = false;

      // Sort replacements by line number in descending order to preserve line numbers
      replacements.sort((a, b) => b.lineNumber.compareTo(a.lineNumber));

      for (final replacement in replacements) {
        final lineIndex = replacement.lineNumber - 1; // 0-indexed
        if (lineIndex >= 0 && lineIndex < lines.length) {
          final line = lines[lineIndex];
          var newLine = line;

          // Try replacing with double quotes
          newLine = newLine.replaceAll(
              '"${replacement.original}"', replacement.replacement);

          // If no change, try with single quotes
          if (newLine == line) {
            newLine = newLine.replaceAll(
                "'${replacement.original}'", replacement.replacement);
          }

          if (newLine != line) {
            lines[lineIndex] = newLine;
            modified = true;
            totalReplacements++;
          }
        }
      }

      if (modified) {
        await file.writeAsString(lines.join('\n'));
        replacementsByFileCount[filePath] = replacements.length;
      }
    }

    return ReplacementResult(
      filesModified: replacementsByFileCount.length,
      totalReplacements: totalReplacements,
      replacementsByFile: replacementsByFileCount,
    );
  }

  /// Show preview of replacements for a single file
  void showFilePreview(String filePath, List<Replacement> replacements) {
    print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('$filePath (${replacements.length} strings)');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    for (int i = 0; i < replacements.length; i++) {
      print('${i + 1}. ${replacements[i].toString()}');
    }
  }

  /// Apply replacements for a single file
  Future<int> replaceInFile(
      String filePath, List<Replacement> replacements) async {
    final file = File(filePath);
    if (!await file.exists()) return 0;

    String content = await file.readAsString();
    var modified = false;
    int replacedCount = 0;

    for (final replacement in replacements) {
      final original = replacement.original;
      final replacementText = replacement.replacement;

      // Escape special regex characters in the original string
      final escapedOriginal = RegExp.escape(original);

      // Try replacing with double quotes
      var pattern = RegExp('"$escapedOriginal"');
      var newContent = content.replaceAll(pattern, replacementText);

      // If no change, try with single quotes
      if (newContent == content) {
        pattern = RegExp("'$escapedOriginal'");
        newContent = content.replaceAll(pattern, replacementText);
      }

      // If still no change, try with flexible whitespace
      if (newContent == content) {
        pattern = RegExp(r'"\s*' + escapedOriginal + r'\s*"');
        newContent = content.replaceAll(pattern, replacementText);
        if (newContent == content) {
          pattern = RegExp(r"'\s*" + escapedOriginal + r"\s*'");
          newContent = content.replaceAll(pattern, replacementText);
        }
      }

      if (newContent != content) {
        content = newContent;
        modified = true;
        replacedCount++;
      }
    }

    if (modified) {
      await file.writeAsString(content);
      print('   → Replaced $replacedCount/${replacements.length} strings');
    } else {
      print('   → Could not find exact matches for any strings');
    }

    return replacedCount;
  }
}
