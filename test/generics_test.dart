
import 'package:bcs/legacy_bcs.dart';
import 'package:bcs/utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {

  group("BCS: Generics", () {
    test("should handle generics", () {
      final bcs = LegacyBCS(getSuiMoveConfig());

      bcs.registerEnumType("base::Option<T>", {
        "none": null,
        "some": "T",
      });

      expect(bcs.de("base::Option<u8>", "00", Encoding.hex),{ "none": true });
    });

    test("should handle nested generics", () {
      final bcs = LegacyBCS(getSuiMoveConfig());

      bcs.registerEnumType("base::Option<T>", {
        "none": null,
        "some": "T",
      });

      bcs.registerStructType("base::Container<T, S>", {
        "tag": "T",
        "data": "base::Option<S>",
      });

      expect(bcs.de("base::Container<bool, u8>", "0000", Encoding.hex),{
        "tag": false,
        "data": { "none": true },
      });

      bcs.registerStructType("base::Wrapper", {
        "wrapped": "base::Container<bool, u8>",
      });

      expect(bcs.de("base::Wrapper", "0000", Encoding.hex),{
        "wrapped": {
          "tag": false,
          "data": { "none": true },
        },
      });
    });
  });

}