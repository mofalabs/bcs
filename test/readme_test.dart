
import 'package:bcs/legacy_bcs.dart';
import 'package:bcs/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group("BCS: README Examples", () {
    test("quick start", () {
      final bcs = LegacyBCS(getSuiMoveConfig());

      // registering types
      bcs.registerAlias("UID", LegacyBCS.ADDRESS);
      bcs.registerEnumType("Option<T>", {
        "none": null,
        "some": "T",
      });
      bcs.registerStructType("Coin", {
        "id": "UID",
        "value": LegacyBCS.U64,
      });

      // deserialization: BCS bytes into Coin
      final bytes = bcs
        .ser("Coin", {
          "id": "0000000000000000000000000000000000000000000000000000000000000001",
          "value": BigInt.from(1000000),
        })
        .toBytes();
    
      final coin = bcs.de("Coin", bytes);

      // serialization: Object into bytes
      final data = bcs.ser("Option<Coin>", { "some": coin }).hex();
      debugPrint(data);
    });

    test("Example: All options used", () {
      final bcs = LegacyBCS(BcsConfig(
        vectorType: "vector<T>",
        addressLength: SUI_ADDRESS_LENGTH,
        addressEncoding: Encoding.hex,
        genericSeparators: ("<", ">"),
        types: BcsConfigTypes(
          // define schema in the intestializer
          structs: {
            "User": {
              "name": LegacyBCS.STRING,
              "age": LegacyBCS.U8,
            },
          },
          enums: {},
          aliases: { "hex": LegacyBCS.HEX },
        ),
        withPrimitives: true
      ));

      final bytes = bcs.ser("User", { "name": "Adam", "age": "30" }).base64();
      debugPrint(bytes);
    });

    test("intestialization", () {
      final bcs = LegacyBCS(getSuiMoveConfig());

      // use bcs.ser() to serialize data
      const val = [1, 2, 3, 4];
      final ser = bcs.ser("vector<u8>", val).toBytes();

      // use bcs.de() to deserialize data
      final res = bcs.de("vector<u8>", ser);

      expect(res.toString(), val.toString());
    });

    test("Example: Rust Config", () {
      final bcs = LegacyBCS(getRustConfig());
      const val = [1, 2, 3, 4];
      final ser = bcs.ser("Vec<u8>", val).toBytes();
      final res = bcs.de("Vec<u8>", ser);

      expect(res.toString(), val.toString());
    });

    test("Example: Primtestive types", () {
      final bcs = LegacyBCS(getSuiMoveConfig());

      // Integers
      final _u8 = bcs.ser(LegacyBCS.U8, 100).toBytes();
      final _u64 = bcs.ser(LegacyBCS.U64, BigInt.from(1000000)).hex();
      final _u128 = bcs.ser(LegacyBCS.U128, "100000010000001000000").base64();

      // Other types
      final _bool = bcs.ser(LegacyBCS.BOOL, true).hex();
      final _addr = bcs
        .ser(LegacyBCS.ADDRESS, "0000000000000000000000000000000000000001")
        .toBytes();
      final _str = bcs.ser(LegacyBCS.STRING, "this is an ascii string").toBytes();

      // Vectors (vector<T>)
      final _u8_vec = bcs.ser("vector<u8>", [1, 2, 3, 4, 5, 6, 7]).toBytes();
      final _bool_vec = bcs.ser("vector<bool>", [true, true, false]).toBytes();
      final _str_vec = bcs
        .ser("vector<bool>", ["string1", "string2", "string3"])
        .toBytes();

      // Even vector of vector (...of vector) is an option
      final _matrix = bcs
        .ser("vector<vector<u8>>", [
          [0, 0, 0],
          [1, 1, 1],
          [2, 2, 2],
        ])
        .toBytes();
    });

    test("Example: Ser/de and Encoding", () {
      final bcs = LegacyBCS(getSuiMoveConfig());

      // bcs.ser() returns an instance of BcsWrtester which can be converted to bytes or a string
      final bcsWrtester = bcs.ser(LegacyBCS.STRING, "this is a string");

      // wrtester.toBytes() returns a Uint8Array
      final bytes = bcsWrtester.toBytes();

      // custom encodings can be chosen when needed (just like Buffer)
      final hex = bcsWrtester.hex();
      final base64 = bcsWrtester.base64();
      final base58 = bcsWrtester.base58();

      // bcs.de() reads BCS data and returns the value
      // by default test expects data to be `Uint8Array`
      final str1 = bcs.de(LegacyBCS.STRING, bytes);

      // alternatively, an encoding of input can be specified
      final str2 = bcs.de(LegacyBCS.STRING, hex, Encoding.hex);
      final str3 = bcs.de(LegacyBCS.STRING, base64, Encoding.base64);
      final str4 = bcs.de(LegacyBCS.STRING, base58, Encoding.base58);

      expect((str1 == str2), (str3 == str4));
    });

    test("Example: Alias", () {
      final bcs = LegacyBCS(getSuiMoveConfig());

      // When registering alias simply specify a new name for the type
      bcs.registerAlias("ObjectDigest", LegacyBCS.BASE58);

      // ObjectDigest is now treated as base58 string
      final _b58 = bcs.ser("ObjectDigest", "Ldp").toBytes();

      // we can override already existing defintestion
      bcs.registerAlias("ObjectDigest", LegacyBCS.HEX);

      final _hex = bcs.ser("ObjectDigest", "C0FFEE").toBytes();
    });

    test("Example: Struct", () {
      final bcs = LegacyBCS(getSuiMoveConfig());

      // register a custom type (test becomes available for using)
      bcs.registerStructType("Balance", {
        "value": LegacyBCS.U64,
      });

      bcs.registerStructType("Coin", {
        "id": LegacyBCS.ADDRESS,
        // reference another registered type
        "balance": "Balance",
      });

      // value passed into ser function has to have the same
      // structure as the defintestion
      final _bytes = bcs
        .ser("Coin", {
          "id": "0x0000000000000000000000000000000000000000000000000000000000000005",
          "balance": {
            "value": BigInt.from(100000000),
          },
        })
        .toBytes();
    });

    test("Example: Generics", () {
      final bcs = LegacyBCS(getSuiMoveConfig());

      // Container -> the name of the type
      // T -> type parameter which has to be passed in `ser()` or `de()` methods
      // If you're not familiar wtesth generics, treat them as type Templates
      bcs.registerStructType(["Container", "T"], {
        "contents": "T",
      });

      // When serializing, we have to pass the type to use for `T`
      bcs
        .ser(["Container", LegacyBCS.U8], {
          "contents": 100,
        })
        .hex();

      // Reusing the same Container type wtesth different contents.
      // Mind that generics need to be passed as Array after the main type.
      bcs
        .ser(["Container", ["vector", LegacyBCS.BOOL]], {
          "contents": [true, false, true],
        })
        .hex();

      // Using multiple generics - you can use any string for convenience and
      // readabiltesty. See how we also use array notation for a field defintestion.
      bcs.registerStructType(["VecMap", "Key", "Val"], {
        "keys": ["vector", "Key"],
        "values": ["vector", "Val"],
      });

      // To serialize VecMap, we can use:
      bcs.ser(["VecMap", LegacyBCS.STRING, LegacyBCS.STRING], {
        "keys": ["key1", "key2", "key3"],
        "values": ["value1", "value2", "value3"],
      });
    });

    test("Example: Enum", () {
      final bcs = LegacyBCS(getSuiMoveConfig());

      bcs.registerEnumType("Option<T>", {
        "none": null,
        "some": "T",
      });

      bcs.registerEnumType("TransactionType", {
        "single": "vector<u8>",
        "batch": "vector<vector<u8>>",
      });

      // any truthy value marks empty in struct value
      final _optionNone = bcs.ser("Option<TransactionType>", {
        "none": true,
      });

      // some now contains a value of type TransactionType
      final _optionTx = bcs.ser("Option<TransactionType>", {
        "some": {
          "single": [1, 2, 3, 4, 5, 6],
        },
      });

      // same type signature but a different enum invariant - batch
      final _optionTxBatch = bcs.ser("Option<TransactionType>", {
        "some": {
          "batch": [
            [1, 2, 3, 4, 5, 6],
            [1, 2, 3, 4, 5, 6],
          ],
        },
      });
    });

    test("Example: Inline Struct", () {
      final bcs = LegacyBCS(getSuiMoveConfig());

      // Some value we want to serialize
      final coin = {
        "id": "0000000000000000000000000000000000000000000000000000000000000005",
        "value": BigInt.from(1111333333222),
      };

      // Instead of defining a type we pass struct schema as the first argument
      final coin_bytes = bcs
        .ser({ "id": LegacyBCS.ADDRESS, "value": LegacyBCS.U64 }, coin)
        .toBytes();

      // Same wtesth deserialization
      final coin_restored = bcs.de({ "id": LegacyBCS.ADDRESS, "value": LegacyBCS.U64 }, coin_bytes);

      expect(coin["id"], coin_restored["id"]);
      expect(coin["value"], BigInt.parse(coin_restored["value"]));
    });
  });
}