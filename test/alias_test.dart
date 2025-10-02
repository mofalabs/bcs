import 'package:bcs/bcs.dart';
import 'package:test/test.dart';

void main() {
  dynamic serde(LegacyBCS bcs, dynamic type, dynamic data) {
    final ser = bcs.ser(type, data).hex();
    final de = bcs.de(type, ser, Encoding.hex);
    return de;
  }

  group("BCS: Aliases", () {
    test("should support type aliases", () {
      final bcs = LegacyBCS(getSuiMoveConfig());
      const value = "this is a string";

      bcs.registerAlias("MyString", LegacyBCS.STRING);
      expect(serde(bcs, "MyString", value), value);
    });

    test("should support recursive definitions in structs", () {
      final bcs = LegacyBCS(getSuiMoveConfig());
      const value = {"name": "Billy"};

      bcs.registerAlias("UserName", LegacyBCS.STRING);
      expect(serde(bcs, {"name": "UserName"}, value), value);
    });

    test("should spot recursive definitions", () {
      final bcs = LegacyBCS(getSuiMoveConfig());
      const value = "this is a string";

      bcs.registerAlias("MyString", LegacyBCS.STRING);
      bcs.registerAlias(LegacyBCS.STRING, "MyString");

      var error = null;
      try {
        serde(bcs, "MyString", value);
      } catch (e) {
        error = e;
      }

      expect(error is ArgumentError, true);
    });
  });
}
