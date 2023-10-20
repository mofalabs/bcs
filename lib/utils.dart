import 'dart:convert';
import 'dart:typed_data';
import 'package:bcs/bs58.dart';
import 'package:bcs/hex.dart';

String toB58(List<int> buffer) => base58Encode(buffer);
Uint8List fromB58(String str) => base58Decode(str);

String toB64(List<int> buffer) => base64Encode(buffer);
Uint8List fromB64(String str) => base64Decode(str);

String toHEX(List<int> buffer) => Hex.encode(buffer);
Uint8List fromHEX(String str) => Hex.decode(str);


enum Encoding {
  base58, base64, hex
}

String encodeStr(Uint8List data, Encoding encoding) {
  switch (encoding) {
    case Encoding.base58:
      return toB58(data);
    case Encoding.base64:
      return toB64(data);
    case Encoding.hex:
      return toHEX(data);
    default:
      throw ArgumentError(
        "Unsupported encoding, supported values are: base64, hex"
      );
  }
}

Uint8List decodeStr(String data, Encoding encoding) {
  switch (encoding) {
    case Encoding.base58:
      return fromB58(data);
    case Encoding.base64:
      return fromB64(data);
    case Encoding.hex:
      return fromHEX(data);
    default:
      throw ArgumentError(
        "Unsupported encoding, supported values are: base64, hex"
      );
  }
}

List<String> splitGenericParameters(
	String str,
	[(String, String) genericSeparators = ('<', '>')]
) {
	final (left, right) = genericSeparators;
	final tok = <String>[];
	String word = '';
	int nestedAngleBrackets = 0;

	for (int i = 0; i < str.length; i++) {
		final char = str[i];
		if (char == left) {
			nestedAngleBrackets++;
		}
		if (char == right) {
			nestedAngleBrackets--;
		}
		if (nestedAngleBrackets == 0 && char == ',') {
			tok.add(word.trim());
			word = '';
			continue;
		}
		word += char;
	}

	tok.add(word.trim());

	return tok;
}

/// Unify argument types by converting them to BigInt.
BigInt toBN(dynamic number) {
  if (number is bool) {
    return number ? BigInt.one : BigInt.zero;
  } else if (number is int) {
    return BigInt.from(number);
  } else if (number is BigInt) {
    return number;
  } else {
    return BigInt.parse(number);
  }
}