import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:bcs/bcs.dart';

void main() {

  String largebcsVec() {
    return "6Af/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////";
  }

  group('BCS: Primitives', () {

    test("should de/ser primitives: u8", () {
      final bcs = BCS(getSuiMoveConfig());

      expect(bcs.de("u8", fromB64("AQ==")), 1);
      expect(bcs.de("u8", fromB64("AA==")), 0);
    });

    test("should ser/de u64", () {
      final bcs = BCS(getSuiMoveConfig());

      const exp = "AO/Nq3hWNBI=";
      const num = "1311768467750121216";
      final set = bcs.ser("u64", BigInt.parse(num)).encode(Encoding.base64);

      expect(set, exp);
      expect(bcs.de("u64", exp, Encoding.base64).toString(), "1311768467750121216");
    });

    test("should ser/de u128", () {
      final bcs = BCS(getSuiMoveConfig());

      const sample = "AO9ld3CFjD48AAAAAAAAAA==";
      final num = BigInt.parse("1111311768467750121216");

      expect(bcs.de("u128", sample, Encoding.base64).toString(),
        "1111311768467750121216"
      );
      expect(bcs.ser("u128", num).encode(Encoding.base64), sample);
    });

    test("should de/ser custom objects", ()  {
      final bcs = BCS(getSuiMoveConfig());

      bcs.registerStructType("Coin", {
        "value": BCS.U64,
        "owner": BCS.STRING,
        "is_locked": BCS.BOOL,
      });

      const rustBcs = "gNGxBWAAAAAOQmlnIFdhbGxldCBHdXkA";
      const expected = {
        "owner": "Big Wallet Guy",
        "value": "412412400000",
        "is_locked": false,
      };

      final setBytes = bcs.ser("Coin", expected);

      expect(bcs.de("Coin", fromB64(rustBcs)), expected);
      expect(setBytes.encode(Encoding.base64), rustBcs);
    });


    test("should de/ser vectors", () {
      final bcs = BCS(getSuiMoveConfig());

      // Rust-bcs generated vector with 1000 u8 elements (FF)
      final sample = largebcsVec();

      // deserialize data with JS
      final deserialized = bcs.de("vector<u8>", fromB64(sample));

      // create the same vec with 1000 elements
      final arr = List.filled(1000, 255);
      final serialized = bcs.ser("vector<u8>", arr);

      expect(deserialized.length, 1000);
      expect(serialized.encode(Encoding.base64), largebcsVec());
    });

    test("should de/ser enums", () {
      final bcs = BCS(getSuiMoveConfig());

      bcs.registerStructType("Coin", { "value": "u64" });
      bcs.registerEnumType("Enum", {
        "single": "Coin",
        "multi": "vector<Coin>",
      });

      // prepare 2 examples from Rust bcs
      final example1 = fromB64("AICWmAAAAAAA");
      final example2 = fromB64("AQIBAAAAAAAAAAIAAAAAAAAA");

      // serialize 2 objects with the same data and signature
      final set1 = bcs.ser("Enum", { "single": { "value": 10000000 } }).toBytes();
      final set2 = bcs
        .ser("Enum", {
          "multi": [{ "value": 1 }, { "value": 2 }],
        })
        .toBytes();

      // deserialize and compare results
      expect(bcs.de("Enum", example1).toString(), bcs.de("Enum", set1).toString());
      expect(bcs.de("Enum", example2).toString(), bcs.de("Enum", set2).toString());
    });

    test("should de/ser addresses", () {
      final config = getSuiMoveConfig();
      final bcsConfig = BcsConfig(
        vectorType: config.vectorType, 
        genericSeparators: config.genericSeparators,
        addressLength: 16,
        addressEncoding: Encoding.hex
      );
      final bcs = BCS(bcsConfig);

      // Move Kitty example:
      // Wallet { kitties: vector<Kitty>, owner: address }
      // Kitty { id: 'u8' }

      // bcs.registerAddressType('address', 16, 'base64'); // Move has 16/20/32 byte addresses
      bcs.registerStructType("Kitty", { "id": "u8" });
      bcs.registerStructType("Wallet", {
        "kitties": "vector<Kitty>",
        "owner": "address",
      });

      // Generated with Move CLI i.e. on the Move side
      const sample = "AgECAAAAAAAAAAAAAAAAAMD/7g==";
      final data = bcs.de("Wallet", fromB64(sample));

      expect(data["kitties"].length, 2);
      expect(data["owner"], "00000000000000000000000000c0ffee");
    });

    test("should support growing size", () {
      final bcs = BCS(getSuiMoveConfig());

      bcs.registerStructType("Coin", {
        "value": BCS.U64,
        "owner": BCS.STRING,
        "is_locked": BCS.BOOL,
      });

      const rustBcs = "gNGxBWAAAAAOQmlnIFdhbGxldCBHdXkA";
      const expected = {
        "owner": "Big Wallet Guy",
        "value": "412412400000",
        "is_locked": false,
      };

      final options = BcsWriterOptions(size: 1, maxSize: 1024);
      final setBytes = bcs.ser("Coin", expected, options);

      expect(bcs.de("Coin", fromB64(rustBcs)), expected);
      expect(setBytes.encode(Encoding.base64), rustBcs);
    });

    test("should error when attempting to grow beyond the allowed size", () {
      final bcs = BCS(getSuiMoveConfig());

      bcs.registerStructType("Coin", {
        "value": BCS.U64,
        "owner": BCS.STRING,
        "is_locked": BCS.BOOL,
      });

      final expected = {
        "owner": "Big Wallet Guy",
        "value": BigInt.from(412412400000),
        "is_locked": false,
      };

      final options = BcsWriterOptions(size: 1);
      expect(() {
        bcs.ser("Coin", expected, options);
      }, throwsArgumentError);
    });

  });

}
