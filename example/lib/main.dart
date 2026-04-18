/// Example for hardcoded_string_finder package.
///
/// This package is primarily a CLI tool. The example below demonstrates
/// how to use the KeyGenerator utility programmatically, which is one
/// of the few components that can be used directly in code.
///
/// For the main functionality (extraction and generation), use the CLI:
/// ```bash
/// dart run hardcoded_string_finder
/// ```
library hardcoded_string_finder_example;

import 'package:hardcoded_string_finder/hardcoded_string_finder.dart';

/// Main entry point for the example.
void main() {
  print('hardcoded_string_finder Example');
  print('================================\n');

  // Demonstrate KeyGenerator utility
  print('KeyGenerator Example:');
  print('---------------------\n');

  final inputs = [
    'Select Image',
    'Loading...',
    'Go Back?',
    'Photo was saved',
    '1000_am_1200_pm',
  ];

  for (final input in inputs) {
    final key = KeyGenerator.generate(input);
    print('  "$input" → "$key"');
  }

  print('\n');
  print('For full CLI functionality (extraction & generation):');
  print('  Run: dart run hardcoded_string_finder');
  print('\n');
  print('Full documentation: https://pub.dev/packages/hardcoded_string_finder');
}
