/// Base interface for translation services.
///
/// This abstract class defines the contract for translation service
/// implementations, allowing for future expansion to other providers.
abstract class TranslationService {
  /// Name of the translation service.
  String get name;

  /// Description of the free tier.
  String get freeTier;

  /// Free quota in characters per month.
  int get freeQuotaChars;

  /// Translates a single text to multiple target languages in one batch call.
  ///
  /// [text] The text to translate.
  /// [targetLanguages] List of language codes to translate to (e.g., ['es', 'ar']).
  /// [apiKey] The API key for the service.
  /// Returns a map of language code to translated text.
  Future<Map<String, String>> translateBatch({
    required String text,
    required List<String> targetLanguages,
    required String apiKey,
  });

  /// Validates if the API key format is correct for this service.
  bool isValidApiKey(String key);

  /// Returns the URL where users can get an API key.
  String getSignupUrl();
}
