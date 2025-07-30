import 'package:bcs/legacy_bcs.dart';
import 'package:bcs/utils.dart';
import 'package:test/test.dart';

void main() {
  dynamic serde(LegacyBCS bcs, type, data) {
    final ser = bcs.ser(type, data).hex();
    final de = bcs.de(type, ser, Encoding.hex);
    return de;
  }

  group("BCS: Array type", () {
    test("should support destructured type name in ser/de", () {
      final bcs = LegacyBCS(getSuiMoveConfig());
      const values = ["this is a string"];

      expect(serde(bcs, ["vector", LegacyBCS.STRING], values), values);
    });

    test("should support destructured type name in struct", () {
      final bcs = LegacyBCS(getSuiMoveConfig());
      const value = {
        "name": 'Bob',
        "role": 'Admin',
        "meta": {"lastLogin": '23 Feb', "isActive": false}
      };

      bcs.registerStructType(
          "Metadata", {"lastLogin": LegacyBCS.STRING, "isActive": LegacyBCS.BOOL});

      bcs.registerStructType(
          ["User", "T"], {"name": LegacyBCS.STRING, "role": LegacyBCS.STRING, "meta": "T"});

      expect(serde(bcs, ["User", "Metadata"], value), value);
    });

    test("should support destructured type name in enum", () {
      final bcs = LegacyBCS(getSuiMoveConfig());
      const values = {
        "some": ["this is a string"]
      };

      bcs.registerEnumType([
        "Option",
        "T"
      ], {
        "none": null,
        "some": "T",
      });

      expect(
          serde(
              bcs,
              [
                "Option",
                ["vector", "string"]
              ],
              values),
          values);
    });

    test("should solve nested generic issue", () {
      final bcs = LegacyBCS(getSuiMoveConfig());
      const value = {
        "contents": {
          "content_one": {"key": "A", "value": "B"},
          "content_two": {"key": "C", "value": "D"}
        }
      };

      bcs.registerStructType(["Entry", "K", "V"], {"key": "K", "value": "V"});

      bcs.registerStructType(["Wrapper", "A", "B"], {"content_one": "A", "content_two": "B"});

      bcs.registerStructType([
        "VecMap",
        "K",
        "V"
      ], {
        "contents": [
          "Wrapper",
          ["Entry", "K", "V"],
          ["Entry", "V", "K"]
        ]
      });

      expect(serde(bcs, ["VecMap", "string", "string"], value), value);
    });

    // More complicated invariant of the test case above
    test('should support arrays in global generics', () {
      final bcs = LegacyBCS(getSuiMoveConfig());
      bcs.registerEnumType(["Option", "T"], {"none": null, "some": "T"});
      const value = {
        "contents": {
          "content_one": {
            "key": {"some": "A"},
            "value": ["B"]
          },
          "content_two": {
            "key": [],
            "value": {"none": true}
          }
        }
      };

      bcs.registerStructType(["Entry", "K", "V"], {"key": "K", "value": "V"});

      bcs.registerStructType(["Wrapper", "A", "B"], {"content_one": "A", "content_two": "B"});

      bcs.registerStructType([
        "VecMap",
        "K",
        "V"
      ], {
        "contents": [
          "Wrapper",
          ["Entry", "K", "V"],
          ["Entry", "V", "K"]
        ]
      });

      expect(
          serde(
              bcs,
              [
                "VecMap",
                ["Option", "string"],
                ["vector", "string"]
              ],
              value),
          value);
    });
  });
}
