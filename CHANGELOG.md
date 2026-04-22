# Changelog

## 2.1.0 - 2026

### 🐛 Bug Fixes & Enhancements

- **Duplicate key detection and reporting** — Added edge case handling for duplicate keys in CSV files
- **Duplicate key report** — Generates a report showing which keys appear multiple times and which one is used
- Users can now identify and manually fix duplicate keys in their CSV files

---

## 2.0.0 - 2026

### 🚀 Major Release — Localization File Generation

#### New Features

- **Option 2: Generate localization files from CSV** in three formats:
  - **ARB** (Official Flutter) — generates `.arb` files for `flutter gen-l10n`
  - **GetX Map** — generates Dart Map files for GetX state management
  - **Simple JSON** — generates JSON files for custom parsing
- **Adaptive main menu** — choose between Extract (Option 1) or Generate (Option 2)
- **CSV preview in terminal** — 5×5 table shown before row configuration
- **Auto l10n.yaml creation** — generated in project root for ARB format
- **Per-key missing translation reports** for all formats:
  - `arb_report.txt` in `lib/l10n/`
  - `getx_report.txt` in `lib/localization/`
  - `json_report.txt` in `assets/translations/`
- **Smart missing key detection** — only reports keys missing in SOME languages, not all (intentionally untranslated keys are ignored)
- **Locale auto-detection** — derives locale from column name (`app_en` → `en_US`, `app_zh_hk` → `zh_HK`)
- **All keys auto-converted to snake_case** regardless of CSV format
- **Package name detection** for GetX imports (reads from `pubspec.yaml`, confirms with user)
- **GetX generator** creates individual language files + main `AppTranslations` class
- **JSON generator** creates per-language JSON files ready for `easy_localization` or custom loading

#### Technical Improvements

- Clean file structure — all generators in `lib/src/generators/`
- Shared `KeyGenerator` reused across all generators (no duplicate logic)
- CLI split into focused files (`cli_extractor.dart`, `cli_localization.dart`, `cli_helpers.dart`)

---

## 1.0.1 - 2026

- Fixed string filtration logic for more accurate detection
- Fixed override issue during merge — existing translations are now fully preserved
- Improved smart merging behavior in terminal output

---

## 1.0.0 - 2026

### 🚀 Initial Release

#### Core Features

- Automatic hardcoded string detection in Flutter/Dart projects
- JSON and CSV export with 70+ language support
- Translation preservation feature (smart merge)
- Smart filtering for URLs, numbers, and already localized strings
- Auto key generation (snake_case)
- Detects already localized strings (`.tr`, `.i18n`, `AppString.`)

#### 🎯 Performance & Reliability

- **Memory Efficient**: Stream-based file processing for large codebases
- **Progress Tracking**: Real-time progress indicators showing:
  - File collection progress
  - Scanning progress (every 10 files)
  - String count updates
  - Export progress with file sizes
- **Timeout Handling**: 5-minute default timeout prevents hanging on large projects
- **Error Handling**:
  - Graceful error recovery
  - Custom exceptions (`ScanException`, `DirectoryNotFoundException`, `ExportException`)
  - Detailed error messages with stack traces
  - Stops after 10 consecutive errors to prevent cascading failures
- **Large File Protection**: Automatically skips files >1MB with warning
- **Memory Monitoring**: Cross-platform memory usage tracking (Windows, macOS, Linux)

#### 🛠️ Technical Improvements

- Async file operations for better performance
- Non-blocking directory traversal
- Efficient regex pattern matching
- Smart CSV parsing with quote handling
- Relative path display for cleaner output
- Fixed all linter warnings

#### 📊 User Experience

- Interactive CLI with smart defaults
- **Command-line options**:
  - `--memory` / `-m` flag to enable memory monitoring
  - `--timeout=<minutes>` to set custom timeout
  - `--help` / `-h` to show usage information
- Existing folder detection and management
- Three merge strategies (Smart Merge, New Version, Overwrite)
- Format selection (JSON, CSV, or both)
- Key format options (snake_case or readable)
- Comprehensive progress feedback
- Optional memory usage reporting (enabled with `--memory` flag)

#### What Makes This Production-Ready

✅ Handles large codebases efficiently
✅ Won't hang or crash on edge cases
✅ Clear progress feedback for long operations
✅ Preserves existing translation work
✅ Comprehensive error handling
✅ Cross-platform compatibility
✅ Memory-conscious design