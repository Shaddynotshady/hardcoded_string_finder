# Hardcoded String Finder

Find hardcoded strings in Flutter/Dart projects and export them to JSON/CSV for easy localization.

## Features

✨ **Automatic Detection** - Scans your entire `lib/` directory for hardcoded strings  
📊 **CSV Export** - Generates spreadsheet with 70+ language columns ready for translation  
📄 **JSON Export** - Creates JSON file with key-value pairs  
🔄 **Translation Preservation** - Merges new strings with existing translations  
🔑 **Auto Key Generation** - Converts strings to valid localization keys  
🚫 **Smart Filtering** - Ignores URLs, numbers, asset paths, and already localized strings  
⚡ **Memory Efficient** - Handles large codebases without memory issues  
⏱️ **Progress Tracking** - Real-time feedback on operations  
🛡️ **Cross-Platform** - Works on Windows, macOS, and Linux  
� **Smart Input Handling** - Never hangs on empty input  

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

Add to your project:

```yaml
dev_dependencies:
  hardcoded_string_finder: ^1.0.0
```

Then run from project root:

```bash
dart run hardcoded_string_finder
```

## Usage

Run from your Flutter/Dart project root directory:

```bash
dart run hardcoded_string_finder
```

### Command-Line Options

```bash
# Basic usage
dart run hardcoded_string_finder

# Enable memory monitoring
dart run hardcoded_string_finder --memory

# Set custom timeout (in minutes)
dart run hardcoded_string_finder --timeout=10

# Combine options
dart run hardcoded_string_finder --memory --timeout=15

# Show help
dart run hardcoded_string_finder --help
```

**Available Options:**

- `--memory`, `-m` - Enable memory usage monitoring (shows memory at key stages)
- `--timeout=<minutes>` - Set custom timeout in minutes (default: 5 minutes)
- `--help`, `-h` - Display help message

The tool will prompt you to enter a folder name for your localization files. If the folder doesn't exist, it will be created automatically.

### Folder Management

**First Time Run:**

- Creates the specified folder if it doesn't exist
- Generates both `hardcoded_strings.json` and `hardcoded_strings.csv` files
- All strings are exported with empty translation columns ready for localization

**Subsequent Runs:**

- Detects existing localization folders in your project
- Merges new hardcoded strings with your existing translations
- Preserves all previously completed translations
- Updates English text for existing strings if they've changed
- Maintains translation history for strings that may have been removed from code

**Example Workflow:**

```bash
# First run - creates new localization folder
dart run hardcoded_string_finder
# Enter folder name: myapp_strings

# Later runs - merges with existing translations
dart run hardcoded_string_finder
# Detects existing: myapp_strings
# Merges new strings without touching existing translations
```

## Output

The tool generates two files in your specified folder:

- **hardcoded_strings.json** - JSON format with key-value pairs
- **hardcoded_strings.csv** - CSV spreadsheet with 70+ language columns

### Intelligent File Management

The tool implements smart file handling to protect your existing localization work:

- **Non-destructive merging** - Never overwrites existing translations
- **Incremental updates** - Only adds new strings, preserves existing ones
- **Change detection** - Updates English text when source strings change
- **Historical preservation** - Keeps translations for removed strings for future reference

### Example Output

**JSON:**

```json
{
  "photo_was_saved": "Photo was saved",
  "select_image": "Select Image",
  "loading": "Loading..."
}
```

**CSV:**
The CSV includes three header rows:

1. **Row 1**: Column numbers (1, 2, 3, ...)
2. **Row 2**: Language codes (app_en, app_ar, app_es, ...)
3. **Row 3**: Language names (ENGLISH - en, Arabic - ar, Spanish - es, ...)

**Data rows example:**

```
photo_was_saved,Photo was saved,,,
select_image,Select Image,,,
```

### Translation Preservation

When you run the tool multiple times, it intelligently manages your localization data:

**🆕 New Strings:**

- Added with empty translation columns
- Ready for manual translation

**🔄 Updated Strings:**

- English text updated to match current code
- All existing translations preserved
- No manual work lost

**💾 Preserved Strings:**

- Strings removed from code remain in CSV
- Maintains translation history
- Useful for feature re-implementation or rollback

**📊 Progress Tracking:**
The tool provides detailed feedback:

```
🔄 CSV updated: myapp_strings/hardcoded_strings.csv
   📝 New strings: 5
   🔄 Updated strings: 2
   💾 Preserved strings: 23
   📊 Total strings: 30
```

## What It Detects

The tool finds hardcoded strings in:

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

## Supported Languages

The CSV output includes columns for 70+ languages including:
English, Arabic, Spanish, French, German, Chinese, Japanese, Korean, Russian, Hindi, and many more.

**Language codes included:** app_en, app_af, app_sq, app_am, app_ar, app_hy, app_az, app_bn, app_eu, app_be, app_bg, app_my, app_ca, app_zh, app_zh_hk, app_hr, app_cs, app_da, app_nl, app_et, app_fil, app_fi, app_fr, app_gl, app_ka, app_de, app_el, app_gu, app_he, app_hi, app_hu, app_is, app_id, app_it, app_ja, app_kn, app_kk, app_km, app_ko, app_ky, app_lo, app_lv, app_lt, app_mk, app_ms, app_ml, app_mr, app_mn, app_ne, app_no, app_fa, app_pl, app_pt, app_pa, app_ro, app_ru, app_sr, app_si, app_sk, app_sl, app_es, app_sw, app_sv, app_ta, app_te, app_th, app_tr, app_uk, app_vi, app_zu

## Advanced Usage

### Custom Output Directory

```bash
dart run hardcoded_string_finder --output-dir ./localization
```

### Snake Case Keys (Default)

The tool generates snake_case keys by default:

```dart
"Select Image" → "select_image"
"Loading..." → "loading"
```

### Programmatic Usage

```dart
import 'package:hardcoded_string_finder/hardcoded_string_finder.dart';

void main() async {
  // Create scanner with progress tracking
  final scanner = HardcodedScanner(
    rootPath: './lib',
    timeout: Duration(minutes: 5),
    onProgress: (message) => print(message),
  );

  // Scan for strings
  final strings = await scanner.scan();

  // Export with progress tracking
  await StringExporter.exportToJson(
    strings,
    'output.json',
    onProgress: (message) => print(message),
  );

  await StringExporter.exportToCsv(
    strings,
    'output.csv',
    onProgress: (message) => print(message),
  );
}
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT License - see LICENSE file for details

## Issues

Found a bug? Have a feature request? Please open an issue on GitHub.

## Changelog

### 1.0.0

- Initial release
- Automatic hardcoded string detection
- JSON and CSV export with 70+ language support
- Translation preservation feature
- Smart filtering for URLs, numbers, and already localized strings
