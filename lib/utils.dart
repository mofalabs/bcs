import 'dart:convert';
import 'dart:typed_data';

import 'package:bcs/bs58.dart';
import 'package:bcs/hex.dart';

String toB58(Uint8List buffer) => base58Encode(buffer);
Uint8List fromB58(String str) => base58Decode(str);

String toB64(Uint8List buffer) => base64Encode(buffer);
Uint8List fromB64(String str) => base64Decode(str);

String toHEX(Uint8List buffer) => Hex.encode(buffer);
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