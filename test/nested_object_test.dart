import 'package:bcs/legacy_bcs.dart';
import 'package:bcs/utils.dart';
import 'package:test/test.dart';

void main() {
  dynamic serde(LegacyBCS bcs, dynamic type, dynamic data) {
    final ser = bcs.ser(type, data).hex();
    final de = bcs.de(type, ser, Encoding.hex);
    return de;
  }

  group("BCS: Nested temp object", () {
    test("should support object as a type", () {
      final bcs = LegacyBCS(getSuiMoveConfig());
      const value = {
        "name": {"boop": "beep", "beep": "100"}
      };

      bcs.registerStructType("Beep", {
        "name": {
          "boop": LegacyBCS.STRING,
          "beep": LegacyBCS.U64,
        },
      });

      expect(serde(bcs, "Beep", value), value);
    });

    test("should support enum invariant as an object", () {
      final bcs = LegacyBCS(getSuiMoveConfig());
      const value = {
        "user": {
          "name": "Bob",
          "age": 20,
        },
      };

      bcs.registerEnumType("AccountType", {
        "system": null,
        "user": {
          "name": LegacyBCS.STRING,
          "age": LegacyBCS.U8,
        },
      });

      expect(serde(bcs, "AccountType", value), value);
    });

    test("should support a nested schema", () {
      final bcs = LegacyBCS(getSuiMoveConfig());
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
            "user": LegacyBCS.STRING,
            "age": LegacyBCS.U8,
          },
          "meta": {
            "status": {
              "active": LegacyBCS.BOOL,
            },
          },
        },
      });

      expect(serde(bcs, "Option", value), value);
    });
  });
}
