/// Generates snake_case keys from input strings for localization.
///
/// This utility converts any string into a valid snake_case key suitable
/// for use in localization files (ARB, GetX, JSON).
///
/// Example:
/// ```dart
/// KeyGenerator.generate('Select Image') // Returns: 'select_image'
/// KeyGenerator.generate('Loading...') // Returns: 'loading'
/// KeyGenerator.generate('Go Back?') // Returns: 'go_back'
/// ```
class KeyGenerator {
  /// Converts a string to snake_case for use as a localization key.
  ///
  /// Removes special characters, converts to lowercase, and replaces
  /// spaces with underscores.
  ///
  /// [text] The input string to convert.
  /// Returns A snake_case string suitable for use as a localization key.
  static String generate(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '') // Remove special chars
        .trim()
        .replaceAll(RegExp(r'\s+'), '_'); // Spaces to underscores
  }
}
