import 'dart:convert';
import 'dart:typed_data';

import 'package:bcs/bcs.dart';
import 'package:test/test.dart';

void main() {
  group('BCS: Encodings', () {
    test('should de/ser hex, base58 and base64', () {
      expect(Bcs.u8().parse(base64Decode('AA==')), 0);
      expect(Bcs.u8().parse(hexDecode('00')), 0);
      expect(Bcs.u8().parse(base58Decode('1')), 0);

      const testStr = 'this is a test string';
      final str = Bcs.string().serialize(testStr);

      expect(Bcs.string().parse(base58Decode(str.toBase58())), testStr);
      expect(Bcs.string().parse(base64Decode(str.toBase64())), testStr);
      expect(Bcs.string().parse(hexDecode(str.toHex())), testStr);
    });

    test('should deserialize hex with leading 0s', () {
      const addressLeading0 =
          'a7429d7a356dd98f688f11a330a32e0a3cc1908734a8c5a5af98f34ec93df0c';
      expect(hexEncode(Uint8List.fromList([0, 1])), '0001');
      expect(hexDecode('0x1'), Uint8List.fromList([1]));
      expect(hexDecode('1'), Uint8List.fromList([1]));
      expect(hexDecode('111'), Uint8List.fromList([1, 17]));
      expect(hexDecode('001'), Uint8List.fromList([0, 1]));
      expect(hexDecode('011'), Uint8List.fromList([0, 17]));
      expect(hexDecode('0011'), Uint8List.fromList([0, 17]));
      expect(hexDecode('0x0011'), Uint8List.fromList([0, 17]));
      expect(
        hexDecode(addressLeading0),
        Uint8List.fromList([
          10,
          116,
          41,
          215,
          163,
          86,
          221,
          152,
          246,
          136,
          241,
          26,
          51,
          10,
          50,
          224,
          163,
          204,
          25,
          8,
          115,
          74,
          140,
          90,
          90,
          249,
          143,
          52,
          236,
          147,
          223,
          12,
        ]),
      );
      expect(hexEncode(hexDecode(addressLeading0)), '0$addressLeading0');
    });
  });
}
