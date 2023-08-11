
import 'package:bcs/bcs.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  
  dynamic serde(BCS bcs, dynamic type, dynamic data) {
    final ser = bcs.ser(type, data).hex();
    final de = bcs.de(type, ser, Encoding.hex);
    return de;
  }

  group("BCS: Aliases", () {
    test("should support type aliases", () {
      final bcs = BCS(getSuiMoveConfig());
      const value = "this is a string";

      bcs.registerAlias("MyString", BCS.STRING);
      expect(serde(bcs, "MyString", value), value);
    });

    test("should support recursive definitions in structs", () {
      final bcs = BCS(getSuiMoveConfig());
      const value = { "name": "Billy" };

      bcs.registerAlias("UserName", BCS.STRING);
      expect(serde(bcs, { "name": "UserName" }, value), value);
    });

    test("should spot recursive definitions", () {
      final bcs = BCS(getSuiMoveConfig());
      const value = "this is a string";

      bcs.registerAlias("MyString", BCS.STRING);
      bcs.registerAlias(BCS.STRING, "MyString");

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