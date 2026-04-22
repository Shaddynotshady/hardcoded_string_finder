# Hardcoded String Finder

A cross-platform CLI tool for Flutter/Dart projects that does two things:

1. **Extract** hardcoded strings from your code and export them to CSV/JSON for translation
2. **Generate** localization files from your translated CSV in multiple formats:
   - ARB (Official Flutter) - for `flutter gen-l10n`
   - GetX Map - for GetX state management
   - Simple JSON - for custom parsing

---

## Features

✨ **Automatic Detection** - Scans your entire `lib/` directory for hardcoded strings
📊 **CSV Export** - Generates spreadsheet with 70+ language columns ready for translation
📄 **JSON Export** - Creates JSON file with key-value pairs
🔄 **Translation Preservation** - Merges new strings with existing translations
🔑 **Auto Key Generation** - Converts strings to valid snake_case localization keys
🚫 **Smart Filtering** - Ignores URLs, numbers, asset paths, and already localized strings
🌍 **ARB Generation** - Converts translated CSV directly into `.arb` files for Flutter l10n
🚀 **GetX Map Generation** - Generates Dart Map files for GetX state management
📄 **JSON Generation** - Generates simple JSON files for custom parsing
📄 **l10n.yaml** - Auto-creates `l10n.yaml` in your project root (ARB format)
⚠️ **Missing Translation Report** - Generates report files showing exactly which keys are missing in which languages
🛡️ **Cross-Platform** - Works on Windows, macOS, and Linux  

---

## Installation

### Global Activation (Recommended)

```bash
dart pub global activate hardcoded_string_finder
```

Then run from any Flutter project:

```bash
hardcoded_string_finder
```

### Project-Specific Usage

```yaml
dev_dependencies:
  hardcoded_string_finder: ^2.0.0
```

Then run from project root:

```bash
dart run hardcoded_string_finder
```

---

## Usage

Run from your Flutter/Dart project root directory:

```bash
dart run hardcoded_string_finder
```

You will see:

```
🔍 Hardcoded String Finder v2.0.0

What would you like to do?

1. Extract hardcoded strings from project
2. Generate localization files from CSV
```

If you choose option 2, you'll see:

```
🌍 Localization Format Selection

Choose your localization format:

1. ARB (Official Flutter)
2. GetX Map
3. Simple JSON
```

---

## Option 1 — Extract Hardcoded Strings

Scans your `lib/` directory, finds all hardcoded strings, and exports them to CSV and/or JSON.

### First Time Run

- Creates the specified folder if it doesn't exist
- Generates `hardcoded_strings.json` and/or `hardcoded_strings.csv`
- CSV includes 70+ language columns ready for translation

### Subsequent Runs

When you run again on an existing project, you get three choices:

```
1. 🔀 Smart Merge (RECOMMENDED)
   → Keep all existing translations
   → Add new strings (empty translations ready)

2. 📁 Create New Version
   → Keep old files untouched
   → Create: myapp_strings_v2/

3. ⚠️  Complete Overwrite
   → DELETE existing translations
   → Start from scratch
```

### CSV Structure

The exported CSV includes three header rows:

- **Row 1**: Column numbers (1, 2, 3, ...)
- **Row 2**: Language codes (`app_en`, `app_ar`, `app_es`, ...)
- **Row 3**: Language names (ENGLISH - en, Arabic - ar, Spanish - es, ...)

**Example data rows:**

```
photo_was_saved,Photo was saved,,,
select_image,Select Image,,,
```

### Key Format

All keys are automatically converted to `snake_case`:

```
"Select Image"   →  select_image
"Loading..."     →  loading
"Go Back?"       →  go_back
```

### Smart Merge Tracking

```
🔄 CSV updated: myapp_strings/hardcoded_strings.csv
   📝 New strings: 5
   🔄 Updated strings: 2
   💾 Preserved strings: 23
   📊 Total strings: 30
```

---

## Option 3 — Auto-replace Hardcoded Strings

Automatically replaces hardcoded strings in your code with localization keys from your generated ARB, GetX, or JSON files.

### Flow

**Step 1** — Choose your localization format:
```
1. ARB (Official Flutter)
2. GetX Map
3. Custom JSON
```

**Step 2** — Enter your localization folder path (or press Enter for default):
```
Enter path to your localization files:
(default: lib/l10n/ for ARB, lib/localization/ for GetX, assets/translations/ for JSON)
```

**Step 3** — Choose replacement mode:
```
1. Replace all at once
2. Preview file-by-file with confirmation
```

**Step 4** — Backup suggestion:
```
⚠️  This will modify your source files.
💡 It's recommended to create a backup before proceeding.
Create backup to .hardcoded_backup/? (y/N)
```

**Step 5** — The tool scans lib/ for hardcoded strings and matches them with your localization keys.

**Replace All Mode:**
- Automatically replaces all matched strings
- Shows summary of changes
- Backup created if requested

**File-by-File Preview Mode:**
- Shows each file with proposed changes
- Preview example:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[1/4] lib/screens/home.dart (5 strings)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Line 24: - Text("Select Image")
         + Text(AppLocalizations.of(context).selectImage)

Line 45: - Text("Loading...")
         + Text(AppLocalizations.of(context).loading)
```
- Choose to replace, skip, or continue to next file
- Full control over which files to modify

### Prerequisites

- You must have generated localization files first using Option 2
- Localization files must contain key-value pairs matching your hardcoded strings
- Backup is recommended (saves to `.hardcoded_backup/`)

### Replacement Patterns

**ARB Format:**
```
"Select Image" → AppLocalizations.of(context).selectImage
```

**GetX Format:**
```
"Select Image" → tr.selectImage
```

**Custom JSON Format:**
```
"Select Image" → AppLocalizations.of(context).selectImage
```
(You can customize this pattern for your JSON implementation)

### Safety Features

- Backup option saves original files to `.hardcoded_backup/`
- File-by-file preview mode lets you review changes before applying
- Only replaces strings that have exact matches in localization files
- Shows clear summary of all changes made

### Example Usage

```bash
dart run hardcoded_string_finder
# Choose option 3
# Select ARB format
# Confirm folder path
# Choose file-by-file preview
# Review and approve changes per file
```

---

## Option 2 — Generate Localization Files from CSV

Takes your translated CSV and generates localization files in your chosen format.

### Common Flow (All Formats)

**Step 1** — Choose your format:
```
1. ARB (Official Flutter)
2. GetX Map
3. Simple JSON
```

**Step 2** — Enter your CSV path (or press Enter for default):
```
Enter path to your CSV file:
(default: ./hardcoded_strings/hardcoded_strings.csv)
```

**Step 3** — The tool shows a 5×5 terminal preview so you can identify your rows:
```
┌──────────────────────┬──────────────────────┬─────┐
│                      │                      │ ... │  ← Row 1
├──────────────────────┼──────────────────────┼─────┤
│ app_en               │ app_ar               │ ... │  ← Row 2
├──────────────────────┼──────────────────────┼─────┤
│ ENGLISH - en         │ Arabic - ar          │ ... │  ← Row 3
├──────────────────────┼──────────────────────┼─────┤
│ select_image         │ Select Image         │ ... │  ← Row 4
└──────────────────────┴──────────────────────┴─────┘
```

**Step 4** — Tell the tool which rows to use:
```
Which row number contains the language codes? (e.g. app_en, app_ru): 2
Which row number does the translation data start?: 4
```

**Step 5** — Choose output folder (format-specific defaults).

**Step 6** — Files are generated with progress feedback.

---

## ARB Format (Official Flutter)

Generates `.arb` files for Flutter's official localization system.

### Output Folder
- Default: `lib/l10n/`

### Generated Files
- `app_en.arb`, `app_ar.arb`, etc. (one per language column)
- `l10n.yaml` (in project root)
- `arb_report.txt` (if any translations are missing)

### Example ARB File

```json
{
  "@@locale": "en",
  "select_image": "Select Image",
  "loading": "Loading...",
  "photo_was_saved": "Photo was saved"
}
```

### l10n.yaml (auto-created in project root)

```yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
output-class: AppLocalizations
nullable-getter: false
```

### Next Steps

```bash
# Add to pubspec.yaml under flutter:
#   generate: true

flutter pub add intl
flutter pub add flutter_localizations --sdk=flutter
flutter pub get
flutter gen-l10n
```

---

## GetX Map Format

Generates Dart Map files for GetX state management.

### Output Folder
- Default: `lib/localization/`

### Generated Files
- `lib/localization/languages/app_en.dart`, `app_ar.dart`, etc. (one per language column)
- `lib/localization/app_translations.dart` (main translation class)
- `getx_report.txt` (if any translations are missing)

### Example Language File (app_en.dart)

```dart
final Map<String, String> app_en = {
  'select_image': 'Select Image',
  'loading': 'Loading...',
  'photo_was_saved': 'Photo was saved'
};
```

### Main Translation File (app_translations.dart)

```dart
import 'package:your_package/localization/languages/app_en.dart';
import 'package:your_package/localization/languages/app_ar.dart';
import 'package:get/get.dart';

class AppTranslations extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
    'en_US': app_en,
    'ar_SA': app_ar,
  };
}
```

### Next Steps

```bash
flutter pub add get
```

Then configure in your main.dart:
```dart
GetMaterialApp(
  translations: AppTranslations(),
  locale: Locale('en', 'US'),
  fallbackLocale: Locale('en', 'US'),
)
```

---

## JSON Format

Generates simple JSON files for custom parsing.

### Output Folder
- Default: `assets/translations/`

### Generated Files
- `app_en.json`, `app_ar.json`, etc. (one per language column)
- `json_report.txt` (if any translations are missing)

### Example JSON File (app_en.json)

```json
{
  "select_image": "Select Image",
  "loading": "Loading...",
  "photo_was_saved": "Photo was saved"
}
```

### Next Steps

Add to your pubspec.yaml:
```yaml
flutter:
  assets:
    - assets/translations/
```

Then run:
```bash
flutter pub get
```

Load in your app:
```dart
final content = await rootBundle.loadString('assets/translations/app_en.json');
final translations = jsonDecode(content);
```

---

## Missing Translation Reports

All formats generate missing translation reports if any key has a translation in some languages but is missing in others:

- **ARB**: `arb_report.txt` in `lib/l10n/`
- **GetX**: `getx_report.txt` in `lib/localization/`
- **JSON**: `json_report.txt` in `assets/translations/`

### Report Format

```
📊 [Format] Generation Report
Generated: 2026-01-15 10:30:00
Total keys: 141
[Format] files created: 70
Keys with missing translations: 2

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Missing Translations (by key):
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[select_image]
  Missing in: app_ar, app_zh

[loading]
  Missing in: app_ru
```

> Keys missing in ALL languages are not reported — that is considered intentional (not yet translated).

---

## What It Detects

- `Text()` widgets
- `text:` properties
- `title:` properties
- `label:`, `hintText:`, `labelText:` properties
- `message:` properties
- String return statements

## What It Ignores

- Numbers (e.g., `"123"`, `"1.5"`)
- URLs (e.g., `"https://example.com"`)
- Asset paths (e.g., `"assets/image.png"`)
- File paths
- Symbols only
- Already localized strings (`.tr`, `.i18n`, `AppString.`)

---

## Supported Languages

70+ languages including English, Arabic, Spanish, French, German, Chinese, Japanese, Korean, Russian, Hindi, and many more.

**All language codes:** `app_en`, `app_af`, `app_sq`, `app_am`, `app_ar`, `app_hy`, `app_az`, `app_bn`, `app_eu`, `app_be`, `app_bg`, `app_my`, `app_ca`, `app_zh`, `app_zh_hk`, `app_hr`, `app_cs`, `app_da`, `app_nl`, `app_et`, `app_fil`, `app_fi`, `app_fr`, `app_gl`, `app_ka`, `app_de`, `app_el`, `app_gu`, `app_he`, `app_hi`, `app_hu`, `app_is`, `app_id`, `app_it`, `app_ja`, `app_kn`, `app_kk`, `app_km`, `app_ko`, `app_ky`, `app_lo`, `app_lv`, `app_lt`, `app_mk`, `app_ms`, `app_ml`, `app_mr`, `app_mn`, `app_ne`, `app_no`, `app_fa`, `app_pl`, `app_pt`, `app_pa`, `app_ro`, `app_ru`, `app_sr`, `app_si`, `app_sk`, `app_sl`, `app_es`, `app_sw`, `app_sv`, `app_ta`, `app_te`, `app_th`, `app_tr`, `app_uk`, `app_vi`, `app_zu`

---

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT License - see LICENSE file for details

## Issues

Found a bug? Have a feature request? Please open an issue on GitHub.

---

## Changelog

### 2.0.0

- Added Option 2: Generate localization files in multiple formats
  - ARB (Official Flutter) - for `flutter gen-l10n`
  - GetX Map - for GetX state management
  - Simple JSON - for custom parsing
- Format selection menu for choosing localization format
- CSV preview in terminal (5×5 table) before asking for row configuration
- Header row validation with retry loop
- Auto-creates `l10n.yaml` in project root (ARB format)
- Per-key missing translation reports for all formats:
  - `arb_report.txt`
  - `getx_report.txt`
  - `json_report.txt`
- Locale derived automatically from column name (`app_en` → `en`, `app_zh_hk` → `zh_HK`)
- All keys auto-converted to snake_case regardless of CSV format
- Clean file structure — all generators in `lib/src/generators/`
- GetX generator only includes languages with actual translations
- Package name prompt for GetX imports

### 1.0.0

- Initial release
- Automatic hardcoded string detection
- JSON and CSV export with 70+ language support
- Translation preservation feature
- Smart filtering for URLs, numbers, and already localized strings