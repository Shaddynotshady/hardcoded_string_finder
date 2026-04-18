/// A cross-platform CLI tool for Flutter/Dart projects that extracts hardcoded strings
/// and generates localization files in multiple formats.
///
/// ## Option 1 — Extract strings
/// Scans `lib/` for hardcoded strings and exports them to CSV/JSON
/// with 70+ language columns ready for translation.
///
/// ## Option 2 — Generate localization files
/// Reads a translated CSV and generates localization files in your chosen format:
/// - ARB (Official Flutter) - for `flutter gen-l10n`
/// - GetX Map - for GetX state management
/// - Simple JSON - for custom parsing
///
/// ## Usage
///
/// Run from your Flutter project root:
/// ```bash
/// dart run hardcoded_string_finder
/// ```
///
/// Or globally activate:
/// ```bash
/// dart pub global activate hardcoded_string_finder
/// hardcoded_string_finder
/// ```
library hardcoded_string_finder;

export 'src/scanner/scanner.dart';
export 'src/exporter/exporter.dart';
export 'src/key_generator/key_generator.dart';
export 'src/generators/arb_generator.dart';
export 'src/generators/getx_generator.dart';
export 'src/generators/json_generator.dart';
export 'src/cli/cli_helpers.dart';
export 'src/cli/cli_extractor.dart';
export 'src/cli/cli_arb.dart';
export 'src/cli/cli_getx.dart';
export 'src/cli/cli_json.dart';
// export 'src/cli/cli_translate.dart'; // Commented for v2 release
export 'src/cli/cli_format_selector.dart';
// export 'src/translation/langbly_translator.dart'; // Commented for v2 release
// export 'src/translation/deepl_translator.dart'; // Commented for v2 release
// export 'src/translation/quota_tracker.dart'; // Commented for v2 release
// export 'src/translation/translation_service.dart'; // Commented for v2 release
// export 'src/translation/translation_exceptions.dart'; // Commented for v2 release


/// 