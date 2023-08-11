
import 'package:bcs/bcs.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group("BCS: README Examples", () {
    test("quick start", () {
      final bcs = BCS(getSuiMoveConfig());

      // registering types
      bcs.registerAlias("UID", BCS.ADDRESS);
      bcs.registerEnumType("Option<T>", {
        "none": null,
        "some": "T",
      });
      bcs.registerStructType("Coin", {
        "id": "UID",
        "value": BCS.U64,
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
      final data = bcs.ser("Option<Coin>", { "some": coin }).encode(Encoding.hex);
    });

    test("Example: All options used", () {
      final bcs = BCS(BcsConfig(
        vectorType: "vector<T>",
        addressLength: SUI_ADDRESS_LENGTH,
        addressEncoding: Encoding.hex,
        genericSeparators: ("<", ">"),
        types: BcsConfigTypes(
          // define schema in the intestializer
          structs: {
            "User": {
              "name": BCS.STRING,
              "age": BCS.U8,
            },
          },
          enums: {},
          aliases: { "hex": BCS.HEX },
        ),
        withPrimitives: true
      ));

      final bytes = bcs.ser("User", { "name": "Adam", "age": "30" }).encode(Encoding.base64);
    });

    test("intestialization", () {
      final bcs = BCS(getSuiMoveConfig());

      // use bcs.ser() to serialize data
      const val = [1, 2, 3, 4];
      final ser = bcs.ser("vector<u8>", val).toBytes();

      // use bcs.de() to deserialize data
      final res = bcs.de("vector<u8>", ser);

      expect(res.toString(), val.toString());
    });

    test("Example: Rust Config", () {
      final bcs = BCS(getRustConfig());
      const val = [1, 2, 3, 4];
      final ser = bcs.ser("Vec<u8>", val).toBytes();
      final res = bcs.de("Vec<u8>", ser);

      expect(res.toString(), val.toString());
    });

    test("Example: Primtestive types", () {
      final bcs = BCS(getSuiMoveConfig());

      // Integers
      final _u8 = bcs.ser(BCS.U8, 100).toBytes();
      final _u64 = bcs.ser(BCS.U64, BigInt.from(1000000)).encode(Encoding.hex);
      final _u128 = bcs.ser(BCS.U128, "100000010000001000000").encode(Encoding.base64);

      // Other types
      final _bool = bcs.ser(BCS.BOOL, true).encode(Encoding.hex);
      final _addr = bcs
        .ser(BCS.ADDRESS, "0000000000000000000000000000000000000001")
        .toBytes();
      final _str = bcs.ser(BCS.STRING, "this is an ascii string").toBytes();

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
      final bcs = BCS(getSuiMoveConfig());

      // bcs.ser() returns an instance of BcsWrtester which can be converted to bytes or a string
      final bcsWrtester = bcs.ser(BCS.STRING, "this is a string");

      // wrtester.toBytes() returns a Uint8Array
      final bytes = bcsWrtester.toBytes();

      // custom encodings can be chosen when needed (just like Buffer)
      final hex = bcsWrtester.encode(Encoding.hex);
      final base64 = bcsWrtester.encode(Encoding.base64);
      final base58 = bcsWrtester.encode(Encoding.base58);

      // bcs.de() reads BCS data and returns the value
      // by default test expects data to be `Uint8Array`
      final str1 = bcs.de(BCS.STRING, bytes);

      // alternatively, an encoding of input can be specified
      final str2 = bcs.de(BCS.STRING, hex, Encoding.hex);
      final str3 = bcs.de(BCS.STRING, base64, Encoding.base64);
      final str4 = bcs.de(BCS.STRING, base58, Encoding.base58);

      expect((str1 == str2), (str3 == str4));
    });

    test("Example: Alias", () {
      final bcs = BCS(getSuiMoveConfig());

      // When registering alias simply specify a new name for the type
      bcs.registerAlias("ObjectDigest", BCS.BASE58);

      // ObjectDigest is now treated as base58 string
      final _b58 = bcs.ser("ObjectDigest", "Ldp").toBytes();

      // we can override already existing defintestion
      bcs.registerAlias("ObjectDigest", BCS.HEX);

      final _hex = bcs.ser("ObjectDigest", "C0FFEE").toBytes();
    });

    test("Example: Struct", () {
      final bcs = BCS(getSuiMoveConfig());

      // register a custom type (test becomes available for using)
      bcs.registerStructType("Balance", {
        "value": BCS.U64,
      });

      bcs.registerStructType("Coin", {
        "id": BCS.ADDRESS,
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
      final bcs = BCS(getSuiMoveConfig());

      // Container -> the name of the type
      // T -> type parameter which has to be passed in `ser()` or `de()` methods
      // If you're not familiar wtesth generics, treat them as type Templates
      bcs.registerStructType(["Container", "T"], {
        "contents": "T",
      });

      // When serializing, we have to pass the type to use for `T`
      bcs
        .ser(["Container", BCS.U8], {
          "contents": 100,
        })
        .encode(Encoding.hex);

      // Reusing the same Container type wtesth different contents.
      // Mind that generics need to be passed as Array after the main type.
      bcs
        .ser(["Container", ["vector", BCS.BOOL]], {
          "contents": [true, false, true],
        })
        .encode(Encoding.hex);

      // Using multiple generics - you can use any string for convenience and
      // readabiltesty. See how we also use array notation for a field defintestion.
      bcs.registerStructType(["VecMap", "Key", "Val"], {
        "keys": ["vector", "Key"],
        "values": ["vector", "Val"],
      });

      // To serialize VecMap, we can use:
      bcs.ser(["VecMap", BCS.STRING, BCS.STRING], {
        "keys": ["key1", "key2", "key3"],
        "values": ["value1", "value2", "value3"],
      });
    });

    test("Example: Enum", () {
      final bcs = BCS(getSuiMoveConfig());

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
      final bcs = BCS(getSuiMoveConfig());

      // Some value we want to serialize
      final coin = {
        "id": "0000000000000000000000000000000000000000000000000000000000000005",
        "value": BigInt.from(1111333333222),
      };

      // Instead of defining a type we pass struct schema as the first argument
      final coin_bytes = bcs
        .ser({ "id": BCS.ADDRESS, "value": BCS.U64 }, coin)
        .toBytes();

      // Same wtesth deserialization
      final coin_restored = bcs.de({ "id": BCS.ADDRESS, "value": BCS.U64 }, coin_bytes);

      expect(coin["id"], coin_restored["id"]);
      expect(coin["value"], BigInt.parse(coin_restored["value"]));
    });
  });
}