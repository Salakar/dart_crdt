/// Shared conversions between user-visible text indexes and CRDT clocks.
library;

import '../structs/abstract_struct.dart';
import 'content.dart';

/// Converts between Unicode-scalar text offsets and item-local wire clocks.
///
/// Dart's shared-text API indexes strings by Unicode scalar value (`runes`),
/// while portable string structs allocate one clock per UTF-16 code unit.
/// These helpers keep that boundary explicit and deterministic.
abstract final class ContentTextIndex {
  /// Returns the user-visible scalar length contributed by [item].
  static int visibleLength(Item item) {
    if (item.deleted || !item.countable) {
      return 0;
    }
    return switch (item.content) {
      ContentString(:final value) => value.runes.length,
      ContentType() => 1,
      final content => content.length,
    };
  }

  /// Converts a visible scalar [textOffset] to an item-local wire clock.
  static int clockOffsetAtTextOffset(Item item, int textOffset) {
    RangeError.checkValueInInterval(textOffset, 0, visibleLength(item));
    return switch (item.content) {
      ContentString(:final value) => _stringClockOffsetAtTextOffset(
          value,
          textOffset,
        ),
      _ => textOffset,
    };
  }

  /// Converts an item-local wire [clockOffset] to a visible scalar offset.
  ///
  /// A clock inside a surrogate pair resolves to the scalar's leading
  /// boundary. This floor behavior also makes positions emitted by older peers
  /// deterministic instead of placing a cursor past the containing scalar.
  static int textOffsetAtClockOffset(Item item, int clockOffset) {
    RangeError.checkValueInInterval(clockOffset, 0, item.length);
    return switch (item.content) {
      ContentString(:final value) => _stringTextOffsetAtClockOffset(
          value,
          clockOffset,
        ),
      _ => clockOffset,
    };
  }
}

int _stringClockOffsetAtTextOffset(String value, int textOffset) {
  RangeError.checkValueInInterval(textOffset, 0, value.runes.length);
  var scalarIndex = 0;
  var clockOffset = 0;
  for (final rune in value.runes) {
    if (scalarIndex == textOffset) {
      return clockOffset;
    }
    clockOffset += String.fromCharCode(rune).length;
    scalarIndex += 1;
  }
  return clockOffset;
}

int _stringTextOffsetAtClockOffset(String value, int clockOffset) {
  RangeError.checkValueInInterval(clockOffset, 0, value.length);
  var scalarOffset = 0;
  var currentClock = 0;
  for (final rune in value.runes) {
    final nextClock = currentClock + String.fromCharCode(rune).length;
    if (clockOffset < nextClock) {
      return scalarOffset;
    }
    currentClock = nextClock;
    scalarOffset += 1;
  }
  return scalarOffset;
}
