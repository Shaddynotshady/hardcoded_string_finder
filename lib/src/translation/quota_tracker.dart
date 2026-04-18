/// Tracks translation quota usage for the current session.
///
/// This class monitors character usage and provides warnings
/// when approaching or exceeding quota limits.
class QuotaTracker {
  /// Total free quota in characters.
  final int totalQuota;

  /// Number of characters used in current session.
  int usedChars = 0;

  /// Creates a quota tracker with the specified total quota.
  ///
  /// [totalQuota] The total free quota in characters (default: 500,000).
  QuotaTracker({this.totalQuota = 500000});

  /// Adds character usage to the tracker.
  ///
  /// [chars] Number of characters used.
  void addUsage(int chars) {
    usedChars += chars;
  }

  /// Returns the percentage of quota used (0-100).
  double get percentageUsed {
    if (totalQuota == 0) return 100.0;
    return (usedChars / totalQuota * 100);
  }

  /// Returns the number of characters remaining in the quota.
  int get remaining {
    return totalQuota - usedChars;
  }

  /// Returns true if quota usage is near the limit (80%+).
  bool isNearLimit() {
    return percentageUsed >= 80;
  }

  /// Returns true if quota has been exceeded.
  bool isExceeded() {
    return usedChars >= totalQuota;
  }

  /// Returns a formatted string of current usage.
  String get usageString {
    return '$usedChars / $totalQuota characters (${percentageUsed.toStringAsFixed(1)}%)';
  }
}
