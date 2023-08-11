

import 'package:bcs/bcs.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {

  dynamic serde(BCS bcs, dynamic type, dynamic data) {
    final ser = bcs.ser(type, data).hex();
    final de = bcs.de(type, ser, Encoding.hex);
    return de;
  }

  group("BCS: Nested temp object", () {
    test("should support object as a type", () {
      final bcs = BCS(getSuiMoveConfig());
      const value = { "name": { "boop": "beep", "beep": "100" } };

      bcs.registerStructType("Beep", {
        "name": {
          "boop": BCS.STRING,
          "beep": BCS.U64,
        },
      });

      expect(serde(bcs, "Beep", value), value);
    });

    test("should support enum invariant as an object", () {
      final bcs = BCS(getSuiMoveConfig());
      const value = {
        "user": {
          "name": "Bob",
          "age": 20,
        },
      };

      bcs.registerEnumType("AccountType", {
        "system": null,
        "user": {
          "name": BCS.STRING,
          "age": BCS.U8,
        },
      });

      expect(serde(bcs, "AccountType", value), value);
    });

    test("should support a nested schema", () {
      final bcs = BCS(getSuiMoveConfig());
      const value = {
        "some": {
          "account": {
            "user": "Bob",
            "age": 20,
          },
          "meta": {
            "status": {
              "active": true,
            },
          },
        },
      };

      bcs.registerEnumType("Option", {
        "none": null,
        "some": {
          "account": {
            "user": BCS.STRING,
            "age": BCS.U8,
          },
          "meta": {
            "status": {
              "active": BCS.BOOL,
            },
          },
        },
      });

      expect(serde(bcs, "Option", value), value);
    });
  });

}