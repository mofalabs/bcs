
import 'dart:typed_data';

import 'package:bcs/bcs.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {

  group("BCS: Encodings", () {
    test("should de/ser hex, base58 and base64", () {
      final bcs = BCS(getSuiMoveConfig());

      expect(bcs.de("u8", "AA==", Encoding.base64), 0);
      expect(bcs.de("u8", "00", Encoding.hex), 0);
      expect(bcs.de("u8", "1", Encoding.base58), 0);

      const STR = "this is a test string";
      final str = bcs.ser("string", STR);

      expect(bcs.de("string", fromB58(str.encode(Encoding.base58)), Encoding.base58),
        STR
      );
      expect(bcs.de("string", fromB64(str.encode(Encoding.base64)), Encoding.base64),
        STR
      );
      expect(bcs.de("string", fromHEX(str.encode(Encoding.hex)), Encoding.hex), STR);
    });

    test("should de/ser native encoding types", () {
      final bcs = BCS(getSuiMoveConfig());

      bcs.registerStructType("TestStruct", {
        "hex": BCS.HEX,
        "base58": BCS.BASE58,
        "base64": BCS.BASE64,
      });

      final hex_str = toHEX(Uint8List.fromList([1, 2, 3, 4, 5, 6]));
      final b58_str = toB58(Uint8List.fromList([1, 2, 3, 4, 5, 6]));
      final b64_str = toB64(Uint8List.fromList([1, 2, 3, 4, 5, 6]));

      final serialized = bcs.ser("TestStruct", {
        "hex": hex_str,
        "base58": b58_str,
        "base64": b64_str,
      });

      final deserialized = bcs.de("TestStruct", serialized.toBytes());

      expect(deserialized["hex"], hex_str);
      expect(deserialized["base58"], b58_str);
      expect(deserialized["base64"], b64_str);
    });
  });
}