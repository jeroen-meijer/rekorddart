import 'package:drift/drift.dart';

/// Extensions on any nullable object [T] to convert from and to [Value]s.
extension ObjectValueExtension<T> on T {
  /// Converts this object to an absent [Value] if it is `null`, otherwise to a
  /// [Value].
  Value<T> toValue() => this == null ? const Value.absent() : Value(this);
}
