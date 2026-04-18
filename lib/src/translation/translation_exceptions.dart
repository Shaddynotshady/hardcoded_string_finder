/// Exception thrown when quota is exceeded.
class QuotaExceededException implements Exception {
  final String message;

  QuotaExceededException(this.message);

  @override
  String toString() => 'QuotaExceededException: $message';
}

/// Exception thrown when the API key is invalid.
class InvalidApiKeyException implements Exception {
  final String message;

  InvalidApiKeyException(this.message);

  @override
  String toString() => 'InvalidApiKeyException: $message';
}

/// Exception thrown when rate limit is exceeded.
class RateLimitException implements Exception {
  final String message;

  RateLimitException(this.message);

  @override
  String toString() => 'RateLimitException: $message';
}

/// Exception thrown when translation fails.
class TranslationException implements Exception {
  final String message;

  TranslationException(this.message);

  @override
  String toString() => 'TranslationException: $message';
}
