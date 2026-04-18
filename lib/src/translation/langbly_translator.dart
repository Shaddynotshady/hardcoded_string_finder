import 'dart:convert';
import 'dart:io';
import 'translation_service.dart';
import 'translation_exceptions.dart';

/// Langbly translation service implementation.
///
/// This class provides integration with the Langbly translation API
/// for batch translation to multiple languages.
class LangblyTranslator implements TranslationService {
  @override
  String get name => 'Langbly';

  @override
  String get freeTier => '500k chars/month';

  @override
  int get freeQuotaChars => 500000;

  static const String _baseUrl = 'https://api.langbly.com';

  @override
  Future<Map<String, String>> translateBatch({
    required String text,
    required List<String> targetLanguages,
    required String apiKey,
  }) async {
    final translations = <String, String>{};

    // Langbly API only supports single target per call
    // Make one API call per target language
    for (final targetLang in targetLanguages) {
      try {
        final requestBody = {
          'q': text,
          'target': targetLang,
          'source': 'en',
        };

        final request = await HttpClient()
            .postUrl(Uri.parse('$_baseUrl/language/translate/v2'));
        request.headers
          ..add('X-API-Key', apiKey)
          ..add('Content-Type', 'application/json');

        request.write(jsonEncode(requestBody));
        final response = await request.close();

        if (response.statusCode == 200) {
          final responseBody = await response.transform(utf8.decoder).join();
          final data = jsonDecode(responseBody);

          // Parse response - Langbly returns translated text
          if (data['translatedText'] != null) {
            translations[targetLang] = data['translatedText'];
          } else if (data['data'] != null &&
              data['data']['translations'] != null) {
            translations[targetLang] =
                data['data']['translations'][0]['translatedText'];
          }
        } else if (response.statusCode == 401) {
          throw InvalidApiKeyException('Invalid Langbly API key');
        } else if (response.statusCode == 429) {
          throw RateLimitException('Rate limit exceeded');
        } else {
          final responseBody = await response.transform(utf8.decoder).join();
          throw TranslationException(
            'API error: ${response.statusCode} - $responseBody',
          );
        }

        // Small delay to avoid rate limiting
        await Future.delayed(const Duration(milliseconds: 100));
      } on SocketException {
        throw TranslationException(
            'Network error: Could not connect to Langbly API');
      }
    }

    return translations;
  }

  @override
  bool isValidApiKey(String key) {
    // Langbly API keys are typically 32 characters
    return key.length >= 20 && key.isNotEmpty;
  }

  @override
  String getSignupUrl() {
    return 'https://langbly.com';
  }
}
