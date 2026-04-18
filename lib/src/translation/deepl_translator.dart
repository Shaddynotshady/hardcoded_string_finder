import 'dart:convert';
import 'dart:io';
import 'translation_service.dart';
import 'translation_exceptions.dart';

/// DeepL translation service implementation.
///
/// This class provides integration with the DeepL translation API
/// for batch translation to multiple languages.
class DeeplTranslator implements TranslationService {
  @override
  String get name => 'DeepL';

  @override
  String get freeTier => '500k chars/month';

  @override
  int get freeQuotaChars => 500000;

  static const String _baseUrl = 'https://api-free.deepl.com/v2';

  @override
  Future<Map<String, String>> translateBatch({
    required String text,
    required List<String> targetLanguages,
    required String apiKey,
  }) async {
    final translations = <String, String>{};

    try {
      // DeepL supports multiple target languages in one call
      final requestBody = {
        'text': [text],
        'target_lang': targetLanguages.join(','),
        'source_lang': 'EN',
      };

      final request =
          await HttpClient().postUrl(Uri.parse('$_baseUrl/translate'));
      request.headers
        ..add('Authorization', 'DeepL-Auth-Key $apiKey')
        ..add('Content-Type', 'application/json');

      request.write(jsonEncode(requestBody));
      final response = await request.close();

      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final data = jsonDecode(responseBody);

        // Parse response - DeepL returns translations
        if (data['translations'] != null) {
          for (int i = 0; i < targetLanguages.length; i++) {
            if (i < data['translations'].length) {
              final translation = data['translations'][i];
              translations[targetLanguages[i]] = translation['text'];
            }
          }
        }
      } else if (response.statusCode == 403) {
        throw QuotaExceededException('DeepL quota exceeded');
      } else if (response.statusCode == 401) {
        throw InvalidApiKeyException('Invalid DeepL API key');
      } else if (response.statusCode == 429) {
        throw RateLimitException('Rate limit exceeded');
      } else {
        final responseBody = await response.transform(utf8.decoder).join();
        throw TranslationException(
          'API error: ${response.statusCode} - $responseBody',
        );
      }
    } on SocketException {
      throw TranslationException(
          'Network error: Could not connect to DeepL API');
    }

    return translations;
  }

  @override
  bool isValidApiKey(String key) {
    // DeepL keys are typically 36 characters
    return key.length >= 20 && key.isNotEmpty;
  }

  @override
  String getSignupUrl() {
    return 'https://www.deepl.com/pro-api';
  }

  /// Returns list of supported language codes (121 languages)
  static List<String> get supportedLanguages => [
        'BG',
        'CS',
        'DA',
        'DE',
        'EL',
        'EN',
        'ES',
        'ET',
        'FI',
        'FR',
        'HU',
        'ID',
        'IT',
        'JA',
        'KO',
        'LT',
        'LV',
        'NB',
        'NL',
        'PL',
        'PT',
        'RO',
        'RU',
        'SK',
        'SL',
        'SV',
        'TR',
        'UK',
        'ZH',
        'ACE',
        'AF',
        'SQ',
        'AR',
        'AN',
        'HY',
        'AS',
        'AY',
        'AZ',
        'BA',
        'BE',
        'BN',
        'BHO',
        'BS',
        'BR',
        'MY',
        'YUE',
        'CA',
        'CEB',
        'ZH-HANS',
        'ZH-HANT',
        'HR',
        'PRS',
        'GA',
        'GN',
        'GU',
        'HT',
        'HA',
        'HE',
        'HI',
        'IS',
        'IG',
        'JV',
        'PAM',
        'KK',
        'GOM',
        'KMR',
        'CKB',
        'KY',
        'LA',
        'LN',
        'LMO',
        'LB',
        'MK',
        'MAI',
        'MG',
        'ML',
        'MT',
        'MI',
        'MR',
        'MN',
        'NE',
        'OC',
        'OM',
        'PAG',
        'PS',
        'FA',
        'PT-BR',
        'PT-PT',
        'PA',
        'QU',
        'SA',
        'ST',
        'SCN',
        'SU',
        'TL',
        'TG',
        'TA',
        'TT',
        'TE',
        'TH',
        'TS',
        'TN',
        'TK',
        'UR',
        'UZ',
        'CY',
        'WO',
        'XH',
        'YI',
        'ZU',
      ];

  /// Checks if a language is supported
  static bool isLanguageSupported(String langCode) {
    return supportedLanguages.contains(langCode.toUpperCase());
  }
}
