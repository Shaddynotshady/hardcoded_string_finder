import 'dart:io';
import 'package:hardcoded_string_finder/hardcoded_string_finder.dart';

/// Format selection menu for localization generation
Future<void> runFormatSelector() async {
  print('\n🌍 Localization Format Selection\n');
  print('Choose your localization format:\n');
  print('1. ARB (Official Flutter)');
  print('2. GetX Map');
  print('3. Simple JSON\n');
  stdout.write('Type your choice (1/2/3) and press Enter: ');

  String? choice;
  try {
    choice = stdin.readLineSync()?.trim();
  } catch (_) {
    print('⚠️  Input error, defaulting to option 1');
    choice = '1';
  }

  if (choice == null || choice.isEmpty || choice == '1') {
    await runArbGenerator();
  } else if (choice == '2') {
    await runGetXGenerator();
  } else if (choice == '3') {
    await runJsonGenerator();
  } else {
    print('⚠️  Invalid choice, defaulting to option 1');
    await runArbGenerator();
  }
}
