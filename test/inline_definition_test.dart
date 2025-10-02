import 'package:bcs/legacy_bcs.dart';
import 'package:bcs/utils.dart';
import 'package:test/test.dart';

void main() {
  dynamic serde(LegacyBCS bcs, type, data) {
    final ser = bcs.ser(type, data).hex();
    final de = bcs.de(type, ser, Encoding.hex);
    return de;
  }

  group("BCS: Inline struct defintestions", () {
    test("should de/serialize inline defintestion", () {
      final bcs = LegacyBCS(getSuiMoveConfig());
      const value = {
        "t1": "Adam",
        "t2": "1000",
        "t3": ["aabbcc", "00aa00", "00aaffcc"],
      };

      expect(
          serde(
              bcs,
              {
                "t1": "string",
                "t2": "u64",
                "t3": "vector<hex-string>",
              },
              value),
          value);
    });

    test("should not contain a trace of the temp struct", () {
      final bcs = LegacyBCS(getSuiMoveConfig());
      final _sr = bcs.ser({"name": "string", "age": "u8"}, {"name": "Charlie", "age": 10}).hex();

      expect(bcs.hasType("temp-struct"), false);
    });

    test("should avoid duplicate key", () {
      final bcs = LegacyBCS(getSuiMoveConfig());

      bcs.registerStructType("temp-struct", {"a0": "u8"});

      final sr = serde(bcs, {
        "b0": "temp-struct"
      }, {
        "b0": {"a0": 0}
      });

      expect(bcs.hasType("temp-struct"), true);
      expect(sr, {
        "b0": {"a0": 0}
      });
    });
  });
}
