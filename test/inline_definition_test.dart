
import 'package:bcs/bcs.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {

  dynamic serde(BCS bcs, type, data) {
    final ser = bcs.ser(type, data).encode(Encoding.hex);
    final de = bcs.de(type, ser, Encoding.hex);
    return de;
  }

  group("BCS: Inline struct defintestions", () {
    test("should de/serialize inline defintestion", () {
      final bcs =  BCS(getSuiMoveConfig());
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
          value
        )
     ,value);
    });

    test("should not contain a trace of the temp struct", () {
      final bcs =  BCS(getSuiMoveConfig());
      final _sr = bcs
        .ser({ "name": "string", "age": "u8" }, { "name": "Charlie", "age": 10 })
        .encode(Encoding.hex);

      expect(bcs.hasType("temp-struct"), false);
    });

    test("should avoid duplicate key", () {
      final bcs =  BCS(getSuiMoveConfig());

      bcs.registerStructType("temp-struct", { "a0": "u8" });

      final sr = serde(bcs, { "b0": "temp-struct" }, { "b0": { "a0": 0 } });

      expect(bcs.hasType("temp-struct"), true);
      expect(sr, { "b0": { "a0": 0 } });
    });
  });

}