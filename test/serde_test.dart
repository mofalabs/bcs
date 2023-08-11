
import 'package:bcs/bcs.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {

  dynamic serde(BCS bcs, type, data) {
    final ser = bcs.ser(type, data).encode(Encoding.hex);
    final de = bcs.de(type, ser, Encoding.hex);
    return de;
  }

  group("BCS: Serde", () {
    test("should serialize primtestives in both directions", () {
      final bcs = BCS(getSuiMoveConfig());

      expect(serde(bcs, "u8", "0"), 0);
      expect(serde(bcs, "u8", "200"),200);
      expect(serde(bcs, "u8", "255"),255);

      expect(serde(bcs, "u16", "10000"),10000);
      expect(serde(bcs, "u32", "10000"),10000);
      expect(serde(bcs, "u256", "10000"),"10000");

      expect(bcs.ser("u256", "100000").encode(Encoding.hex),
        "a086010000000000000000000000000000000000000000000000000000000000"
      );

      expect(serde(bcs, "u64", "1000"),"1000");
      expect(serde(bcs, "u128", "1000"),"1000");
      expect(serde(bcs, "u256", "1000"),"1000");

      expect(serde(bcs, "bool", true),true);
      expect(serde(bcs, "bool", false),false);

      expect(
        serde(
          bcs,
          "address",
          "0x000000000000000000000000e3edac2c684ddbba5ad1a2b90fb361100b2094af"
        )
      ,
        "000000000000000000000000e3edac2c684ddbba5ad1a2b90fb361100b2094af"
      );
    });

    test("should serde structs", () {
      final bcs = BCS(getSuiMoveConfig());

      bcs.registerAddressType("address", SUI_ADDRESS_LENGTH, Encoding.hex);
      bcs.registerStructType("Beep", { "id": "address", "value": "u64" });

      final bytes = bcs
        .ser("Beep", {
          "id": "0x00000000000000000000000045aacd9ed90a5a8e211502ac3fa898a3819f23b2",
          "value": 10000000,
        })
        .toBytes();
      final struct = bcs.de("Beep", bytes);

      expect(struct["id"],
        "00000000000000000000000045aacd9ed90a5a8e211502ac3fa898a3819f23b2"
      );
      expect(struct["value"], "10000000");
    });

    test("should serde enums", () {
      final bcs = BCS(getSuiMoveConfig());
      bcs.registerAddressType("address", SUI_ADDRESS_LENGTH, Encoding.hex);
      bcs.registerEnumType("Enum", {
        "with_value": "address",
        "no_value": null,
      });

      const addr = "bb967ddbebfee8c40d8fdd2c24cb02452834cd3a7061d18564448f900eb9e66d";

      expect(addr,
        bcs.de("Enum", bcs.ser("Enum", { "with_value": addr }).toBytes())["with_value"]
      );

      Map<String, dynamic> tmp = bcs.de("Enum", bcs.ser("Enum", { "no_value": null }).toBytes());
      expect(tmp.containsKey("no_value"), true);
    });

    test("should serde vectors natively", () {
      final bcs = BCS(getSuiMoveConfig());

      {
        final value = ["0", "255", "100"];
        expect(
          serde(bcs, "vector<u8>", value).map((e) => e.toString())
        , value);
      }

      {
        const value = ["100000", "555555555", "1123123", "0", "1214124124214"];
        expect(
          serde(bcs, "vector<u64>", value).map((e) => e.toString())
        , value);
      }

      {
        const value = ["100000", "555555555", "1123123", "0", "1214124124214"];
        expect(
          serde(bcs, "vector<u128>", value).map((e) => e.toString())
        , value);
      }

      {
        const value = [true, false, false, true, false];
        expect(serde(bcs, "vector<bool>", value), value);
      }

      {
        const value = [
          "000000000000000000000000e3edac2c684ddbba5ad1a2b90fb361100b2094af",
          "0000000000000000000000000000000000000000000000000000000000000001",
          "0000000000000000000000000000000000000000000000000000000000000002",
          "000000000000000000000000c0ffeec0ffeec0ffeec0ffeec0ffeec0ffee1337",
        ];

        expect(serde(bcs, "vector<address>", value), value);
      }

      {
        const value = [
          [true, false, true, true],
          [true, true, false, true],
          [false, true, true, true],
          [true, true, true, false],
        ];

        expect(serde(bcs, "vector<vector<bool>>", value), value);
      }
    });

    test("should structs and nested enums", () {
      final bcs = BCS(getSuiMoveConfig());

      bcs.registerStructType("User", { "age": "u64", "name": "string" });
      bcs.registerStructType("Coin<T>", { "balance": "Balance<T>" });
      bcs.registerStructType("Balance<T>", { "value": "u64" });

      bcs.registerStructType("Container<T>", {
        "owner": "address",
        "is_active": "bool",
        "testem": "T",
      });

      {
        final value = { "age": "30", "name": "Bob" };
        expect(serde(bcs, "User", value)["age"], value["age"]);
        expect(serde(bcs, "User", value)["name"], value["name"]);
      }

      {
        Map<String, dynamic> value = {
          "owner":
            "0000000000000000000000000000000000000000000000000000000000000001",
          "is_active": true,
          "testem": { "balance": { "value": "10000" } },
        };

        // Deep Nested Generic!
        final result = serde(bcs, "Container<Coin<Balance<T>>>", value);

        expect(result["owner"], value["owner"]);
        expect(result["is_active"], value["is_active"]);
        expect(result["testem"]["balance"]["value"],
          value["testem"]["balance"]["value"]
        );
      }
    });

    test("should serde SuiObjectRef", () {
      final bcs = BCS(getSuiMoveConfig());
      bcs.registerStructType("SuiObjectRef", {
        "objectId": "address",
        "version": "u64",
        "digest": "ObjectDigest",
      });

      // console.log('base58', toB64('1Bhh3pU9gLXZhoVxkr5wyg9sX6'));

      bcs.registerAlias("ObjectDigest", BCS.STRING);

      const value = {
        "objectId":
          "5443700000000000000000000000000000000000000000000000000000000000",
        "version": "9180",
        "digest": "hahahahahaha",
      };

      expect(serde(bcs, "SuiObjectRef", value), value);
    });
  });
}