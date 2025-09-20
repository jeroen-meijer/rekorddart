import 'package:rekorddart/rekorddart.dart';

/// Extensions on [DjmdContentData] for convenience.
extension DjmdContentDataExtension on DjmdContentData {
  /// Returns the BPM value ([bpm]) as a double and divides it by 100.
  ///
  /// Since the [bpm] value is stored as an integer with 2 decimal places, we
  /// need to divide it by 100 to get the real BPM value.
  ///
  /// Returns `null` if the BPM value is `null`.
  ///
  /// ```dart
  /// final bpm = track.bpm; // 17400
  /// final realBpm = track.realBpm; // 174
  /// ```
  double? get realBpm => bpm == null ? null : bpm! / 100;
}
