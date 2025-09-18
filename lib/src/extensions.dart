/// Extensions on [String] for convenience.
extension StringExtension on String {
  /// Try to parse the string as a BPM value.
  ///
  /// Returns `null` if the string is not a valid BPM value.
  double? tryParseBpm() {
    if (int.tryParse(this) case final bpm?) {
      return bpm / 100;
    }

    return null;
  }
}
