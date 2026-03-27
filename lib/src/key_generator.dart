class KeyGenerator {
  static String generate(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '') // Remove special chars
        .trim()
        .replaceAll(RegExp(r'\s+'), '_'); // Spaces to underscores
  }
}
