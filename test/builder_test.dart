import 'package:bcs/index.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fixedVector', () {
    final bcs = BCS(getSuiMoveConfig());

    expect(bcs.ser('array<u8>', [1, 2, 3]).hex(), '010203');
    expect(bcs.ser('array<u8,1>', [1, 2, 3]).hex(), '01');
    expect(bcs.ser('array<u8,2>', [1, 2, 3]).hex(), '0102');
    expect(bcs.ser('array<u8,3>', [1, 2, 3]).hex(), '010203');
    expect(bcs.de("array<u8,3>", '010203', Encoding.hex), [1, 2, 3]);
  });
}
