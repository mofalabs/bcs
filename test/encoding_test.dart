
import 'dart:typed_data';

import 'package:bcs/index.dart';
import 'package:bcs/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {

  group('BCS: Encodings', () {
    test('should de/ser hex, base58 and base64', () {
      expect(Bcs.u8().parse(fromB64('AA==')), 0);
      expect(Bcs.u8().parse(fromHEX('00')), 0);
      expect(Bcs.u8().parse(fromB58('1')), 0);

      const STR = 'this is a test string';
      final str = Bcs.string().serialize(STR);

      expect(Bcs.string().parse(fromB58(str.toBase58())), STR);
      expect(Bcs.string().parse(fromB64(str.toBase64())), STR);
      expect(Bcs.string().parse(fromHEX(str.toHex())), STR);
    });

    test('should deserialize hex with leading 0s', () {
      const addressLeading0 = 'a7429d7a356dd98f688f11a330a32e0a3cc1908734a8c5a5af98f34ec93df0c';
      expect(toHEX(Uint8List.fromList([0, 1])), '0001');
      expect(fromHEX('0x1'), Uint8List.fromList([1]));
      expect(fromHEX('1'), Uint8List.fromList([1]));
      expect(fromHEX('111'), Uint8List.fromList([1, 17]));
      expect(fromHEX('001'), Uint8List.fromList([0, 1]));
      expect(fromHEX('011'), Uint8List.fromList([0, 17]));
      expect(fromHEX('0011'), Uint8List.fromList([0, 17]));
      expect(fromHEX('0x0011'), Uint8List.fromList([0, 17]));
      expect(fromHEX(addressLeading0), 
        Uint8List.fromList([
          10, 116, 41, 215, 163, 86, 221, 152, 246, 136, 241, 26, 51, 10, 50, 224, 163, 204, 25, 8,
          115, 74, 140, 90, 90, 249, 143, 52, 236, 147, 223, 12,
        ]),
      );
      expect(toHEX(fromHEX(addressLeading0)), "0$addressLeading0");
    });
  });
  
}