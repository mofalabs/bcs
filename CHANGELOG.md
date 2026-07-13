## 0.2.0

Full rewrite of the package as idiomatic Dart. **Breaking changes.**

* Single public entry point `package:bcs/bcs.dart`; implementation moved to `lib/src/`.
* Removed the legacy string-based registry API (`LegacyBCS`, `registerStructType`, ...).
* Renamed encoding helpers to `hexEncode`/`hexDecode` and `base58Encode`/`base58Decode`;
  removed the `Encoding` enum and base64 wrappers (use `dart:convert`).
* Strictly typed inputs for primitive types; `u64`/`u128`/`u256` accept `int`,
  `BigInt` or decimal `String`. `struct`/`enumeration` accept any `Map` or an object
  exposing `toJson()`.
* Stricter decoding: canonical booleans, bounds-checked reads, validated enum indexes.
* `BcsWriter` grows its buffer geometrically and writes byte ranges in bulk;
  its write methods return `void` (use cascades for chaining) and the
  `allocateSize` option is gone.
* Enabled strict analyzer modes and additional lints; requires Dart 3.2+.

## 0.1.2
* Feat: Replace flutter_test with test package

## 0.1.1

* Optimize: Reading Bytes

## 0.1.0

* Refactor: version 2

## 0.0.6

* Feat: Register Fixed Array Type

## 0.0.5

* Fix: Convert Object to Map

## 0.0.4

* Fix: read128/read256 padLeft

## 0.0.3

* Fix: Iterate MappedListIterable

## 0.0.2

* Refactor BCS.

## 0.0.1

* Initial version, created by 0xmove.
