import 'dart:io';
import 'dart:async';
import '../key_generator/key_generator.dart';

class HardcodedScanner {
  final String rootPath;
  final Duration? timeout;
  final void Function(String)? onProgress;

  HardcodedScanner({required this.rootPath, this.timeout, this.onProgress});

  Future<Map<String, String>> scan() async {
    final results = <String, String>{};

    // Patterns to search (matching your original script)
    final patterns = [
      RegExp(r'''Text\s*\(\s*['"]([^'"$]+)['"]'''),
      RegExp(r'''text\s*:\s*['"]([^'"$]+)['"]'''),
      RegExp(r'''title\s*:\s*['"]([^'"$]+)['"]'''),
      RegExp(r'''label\s*:\s*['"]([^'"$]+)['"]'''),
      RegExp(r'''hintText\s*:\s*['"]([^'"$]+)['"]'''),
      RegExp(r'''labelText\s*:\s*['"]([^'"$]+)['"]'''),
      RegExp(r'''content\s*:\s*Text\s*\(\s*['"]([^'"$]+)['"]'''),
      RegExp(r'''message\s*:\s*['"]([^'"$]+)['"]'''),
      RegExp(r'''return\s+['"]([^'"$]+)['"]'''),
      // Assignment patterns for localization classes
      RegExp(r'''=\s*['"]([^'"$]+)['"]'''),
    ];

    // Scan lib directory
    final libDir = Directory(rootPath);
    if (!libDir.existsSync()) {
      throw DirectoryNotFoundException('Directory not found: $rootPath');
    }

    // Collect files first for progress tracking
    onProgress?.call('📂 Collecting Dart files...');
    final dartFiles = await _collectDartFiles(libDir);

    if (dartFiles.isEmpty) {
      onProgress?.call('⚠️  No Dart files found in $rootPath');
      return results;
    }

    onProgress?.call('📊 Found ${dartFiles.length} Dart files to scan');

    // Process files with timeout and progress
    final scanFuture = _scanFiles(dartFiles, patterns, results);

    if (timeout != null) {
      try {
        await scanFuture.timeout(
          timeout!,
          onTimeout: () {
            throw TimeoutException(
              'Scan operation timed out after ${timeout!.inSeconds}s',
            );
          },
        );
      } on TimeoutException catch (e) {
        onProgress?.call('⚠️  ${e.message}');
        onProgress?.call(
          '📊 Partial results: ${results.length} strings found before timeout',
        );
        rethrow;
      }
    } else {
      await scanFuture;
    }

    return results;
  }

  /// Collect all Dart files efficiently
  Future<List<File>> _collectDartFiles(Directory dir) async {
    final files = <File>[];

    try {
      await for (final entity in dir.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File &&
            entity.path.endsWith('.dart') &&
            !_isLocalizationFile(entity.path) &&
            !_isLocalizationDirectory(entity.path)) {
          files.add(entity);
        }
      }
    } catch (e) {
      throw ScanException('Error collecting files: $e');
    }

    return files;
  }

  /// Check if file is a generated localization file
  bool _isLocalizationFile(String filePath) {
    final fileName = filePath.split('/').last.toLowerCase();

    // Skip files with localization patterns
    final localizationPatterns = [
      'localizations',
      'messages_',
      'app_localizations',
      '_generated.dart',
      '_intl.dart',
      'internationalization',
    ];

    for (final pattern in localizationPatterns) {
      if (fileName.contains(pattern)) {
        return true;
      }
    }

    return false;
  }

  /// Check if directory is a localization directory
  bool _isLocalizationDirectory(String dirPath) {
    final dirName = dirPath.split('/').last.toLowerCase();

    // Skip common localization directories
    final localizationDirs = [
      'l10n',
      'generated',
      'intl',
      'internationalization',
      'localization',
    ];

    return localizationDirs.contains(dirName);
  }

  /// Scan files with progress tracking
  Future<void> _scanFiles(
    List<File> files,
    List<RegExp> patterns,
    Map<String, String> results,
  ) async {
    int processed = 0;
    int errors = 0;

    for (final file in files) {
      try {
        // Process file in chunks to reduce memory usage
        await _processFile(file, patterns, results);

        processed++;

        // Show progress every 10 files or at the end
        if (processed % 10 == 0 || processed == files.length) {
          final percentage = ((processed / files.length) * 100).toStringAsFixed(
            1,
          );
          onProgress?.call(
            '⏳ Progress: $processed/${files.length} files ($percentage%) - ${results.length} strings found',
          );
        }
      } catch (e) {
        errors++;
        onProgress?.call(
          '⚠️  Error reading ${_getRelativePath(file.path)}: $e',
        );

        // Stop if too many errors
        if (errors > 10) {
          throw ScanException(
            'Too many errors encountered (>10). Stopping scan.',
          );
        }
      }
    }

    if (errors > 0) {
      onProgress?.call('⚠️  Completed with $errors error(s)');
    }
  }

  /// Process a single file efficiently
  Future<void> _processFile(
    File file,
    List<RegExp> patterns,
    Map<String, String> results,
  ) async {
    // Read file as stream for memory efficiency with large files
    final content = await file.readAsString();

    // Skip very large files (>1MB) with warning
    if (content.length > 1024 * 1024) {
      onProgress?.call(
        '⚠️  Skipping large file (>1MB): ${_getRelativePath(file.path)}',
      );
      return;
    }

    final lines = content.split('\n');

    for (final pattern in patterns) {
      final matches = pattern.allMatches(content);

      for (final match in matches) {
        final text = match.group(1) ?? '';

        // Skip if should ignore
        if (_shouldIgnore(text)) continue;

        final lineNum = content.substring(0, match.start).split('\n').length;
        final lineContent = lines[lineNum - 1].trim();

        // Skip if already localized
        if (_isAlreadyLocalized(lineContent, match.end, content)) continue;

        // Generate key and add to results
        final key = KeyGenerator.generate(text);
        results[key] = text;
      }
    }
  }

  /// Get relative path for cleaner output
  String _getRelativePath(String fullPath) {
    final current = Directory.current.path;
    if (fullPath.startsWith(current)) {
      return fullPath.substring(current.length + 1);
    }
    return fullPath;
  }

  bool _shouldIgnore(String text) {
    final trimmed = text.trim();

    // Ignore empty or whitespace
    if (trimmed.isEmpty) return true;

    // Ignore only numbers
    if (RegExp(r'^[0-9]+(\.[0-9]+)?$').hasMatch(trimmed)) return true;

    // Ignore URLs
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return true;
    }

    // Ignore asset paths
    if (trimmed.startsWith('assets/')) return true;

    // Ignore file paths
    if (trimmed.startsWith('/') || trimmed.startsWith('\\')) return true;

    // Ignore only symbols
    if (RegExp(
      r'^[\.\,\:\;\!\?\-\+\*\/\=\(\)\[\]\{\}\s]+$',
    ).hasMatch(trimmed)) {
      return true;
    }

    // Ignore L10n localization references
    if (trimmed.contains('L10n.') ||
        trimmed.contains('\${L10n.') ||
        trimmed.startsWith('L10n.') ||
        trimmed.startsWith('\${L10n.')) {
      return true;
    }

    return false;
  }

  bool _isAlreadyLocalized(
    String lineContent,
    int matchEnd,
    String fullContent,
  ) {
    // Check if there's .tr or .i18n after the string quote
    // Look ahead in the content from the match end position
    final remainingContent = fullContent.substring(matchEnd).trim();

    // Check for GetX .tr pattern or other localization patterns
    if (remainingContent.startsWith('.tr') ||
        remainingContent.startsWith('.i18n') ||
        lineContent.contains('.tr') ||
        lineContent.contains('.i18n')) {
      return true;
    }

    return false;
  }
}

/// Custom exceptions for better error handling
class ScanException implements Exception {
  final String message;
  ScanException(this.message);

  @override
  String toString() => 'ScanException: $message';
}

class DirectoryNotFoundException implements Exception {
  final String message;
  DirectoryNotFoundException(this.message);

  @override
  String toString() => 'DirectoryNotFoundException: $message';
}
