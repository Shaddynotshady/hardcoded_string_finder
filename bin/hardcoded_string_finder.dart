import 'dart:io';
import 'package:hardcoded_string_finder/src/cli/cli_extractor.dart';
import 'package:hardcoded_string_finder/src/cli/cli_format_selector.dart';
// import 'package:hardcoded_string_finder/src/cli/cli_translate.dart'; // Commented for v2 release

/// Entry point
/// Run with: dart run hardcoded_string_finder
void main(List<String> args) async {
  print('🔍 Hardcoded String Finder v2.0.0\n');
  print('What would you like to do?\n');
  print('1. Extract hardcoded strings from project');
  print('2. Generate localization files from CSV');
  // print('3. Auto-translate CSV (Langbly/DeepL)\n'); // Commented for v2 release
  stdout.write('Type your choice (1/2) and press Enter: ');

  String? choice;
  try {
    choice = stdin.readLineSync()?.trim();
  } catch (_) {
    print('⚠️  Input error, defaulting to option 1');
    choice = '1';
  }

  if (choice == null || choice.isEmpty || choice == '1') {
    await runExtractor(args);
  } else if (choice == '2') {
    await runFormatSelector();
  } // else if (choice == '3') {
  //   await runTranslateGenerator();
  // } // Commented for v2 release
  else {
    print('⚠️  Invalid choice, defaulting to option 1');
    await runExtractor(args);
  }
}
