import 'dart:typed_data';

const _hexDigits = '0123456789abcdef';

/// Encodes [bytes] as a lowercase hexadecimal string without a `0x` prefix.
String hexEncode(List<int> bytes) {
  final buffer = StringBuffer();
  for (final byte in bytes) {
    if (byte < 0 || byte > 0xff) {
      throw FormatException(
          'Invalid byte $byte, expected a value in range 0-255');
    }
    buffer
      ..writeCharCode(_hexDigits.codeUnitAt(byte >> 4))
      ..writeCharCode(_hexDigits.codeUnitAt(byte & 0x0f));
  }
  return buffer.toString();
}

/// Decodes a hexadecimal string into bytes.
///
/// An optional `0x`/`0X` prefix is ignored. Odd-length input is padded with a
/// leading zero, so `'1'` decodes to `[0x01]` (Sui addresses are often
/// shortened by trimming leading zeros).
Uint8List hexDecode(String hex) {
  var normalized =
      hex.startsWith('0x') || hex.startsWith('0X') ? hex.substring(2) : hex;
  if (normalized.length.isOdd) {
    normalized = '0$normalized';
  }

  final result = Uint8List(normalized.length ~/ 2);
  for (var i = 0; i < result.length; i++) {
    final high = _hexDigit(normalized.codeUnitAt(i * 2));
    final low = _hexDigit(normalized.codeUnitAt(i * 2 + 1));
    if (high == -1 || low == -1) {
      throw FormatException('Invalid hexadecimal string', hex);
    }
    result[i] = (high << 4) | low;
  }
  return result;
}

int _hexDigit(int code) {
  if (code >= 0x30 && code <= 0x39) return code - 0x30; // 0-9
  if (code >= 0x61 && code <= 0x66) return code - 0x57; // a-f
  if (code >= 0x41 && code <= 0x46) return code - 0x37; // A-F
  return -1;
}

const _base58Alphabet =
    '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';

final List<int> _base58DecodeTable = () {
  final table = List<int>.filled(128, -1);
  for (var i = 0; i < _base58Alphabet.length; i++) {
    table[_base58Alphabet.codeUnitAt(i)] = i;
  }
  return table;
}();

/// Encodes [bytes] as a base58 string using the Bitcoin alphabet.
String base58Encode(List<int> bytes) {
  var zeroes = 0;
  while (zeroes < bytes.length && bytes[zeroes] == 0) {
    zeroes++;
  }

  // log(256) / log(58) rounded up.
  final size = (bytes.length - zeroes) * 138 ~/ 100 + 1;
  final digits = Uint8List(size);
  var length = 0;

  for (var i = zeroes; i < bytes.length; i++) {
    var carry = bytes[i];
    if (carry < 0 || carry > 0xff) {
      throw FormatException(
          'Invalid byte $carry, expected a value in range 0-255');
    }
    var j = 0;
    for (var k = size - 1; (carry != 0 || j < length) && k >= 0; k--, j++) {
      carry += 256 * digits[k];
      digits[k] = carry % 58;
      carry ~/= 58;
    }
    length = j;
  }

  final buffer = StringBuffer('1' * zeroes);
  for (var i = size - length; i < size; i++) {
    buffer.write(_base58Alphabet[digits[i]]);
  }
  return buffer.toString();
}

/// Decodes a base58 string (Bitcoin alphabet) into bytes.
Uint8List base58Decode(String input) {
  if (input.isEmpty) {
    return Uint8List(0);
  }

  var zeroes = 0;
  while (zeroes < input.length && input[zeroes] == '1') {
    zeroes++;
  }

  // log(58) / log(256) rounded up.
  final size = (input.length - zeroes) * 733 ~/ 1000 + 1;
  final bytes = Uint8List(size);
  var length = 0;

  for (var i = zeroes; i < input.length; i++) {
    final code = input.codeUnitAt(i);
    final digit = code < 128 ? _base58DecodeTable[code] : -1;
    if (digit == -1) {
      throw FormatException('Invalid base58 character "${input[i]}"', input, i);
    }
    var carry = digit;
    var j = 0;
    for (var k = size - 1; (carry != 0 || j < length) && k >= 0; k--, j++) {
      carry += 58 * bytes[k];
      bytes[k] = carry % 256;
      carry ~/= 256;
    }
    length = j;
  }

  final result = Uint8List(zeroes + length);
  result.setRange(zeroes, result.length, bytes, size - length);
  return result;
}
