import 'package:flutter_test/flutter_test.dart';

import 'package:bcs/bcs.dart';

void main() {

  group('BCS: Primitives', () {
    test('should support growing size', () {
      final Coin = Bcs.struct('Coin', {
        "value": Bcs.u64(),
        "owner": Bcs.string(),
        "is_locked": Bcs.boolean(),
      });

      const rustBcs = 'gNGxBWAAAAAOQmlnIFdhbGxldCBHdXkA';
      final expected = {
        "owner": 'Big Wallet Guy',
        "value": BigInt.parse('412412400000'),
        "is_locked": false,
      };

      final setBytes = Coin.serialize(expected, options: BcsWriterOptions(size: 1, maxSize: 1024));

      expect(Coin.parse(fromB64(rustBcs)), expected);
      expect(setBytes.toBase64(), rustBcs);
    });

    test('should error when attempting to grow beyond the allowed size', () {
      final Coin = Bcs.struct('Coin', {
        "value": Bcs.u64(),
        "owner": Bcs.string(),
        "is_locked": Bcs.boolean(),
      });

      final expected = {
        "owner": 'Big Wallet Guy',
        "value": BigInt.parse('412412400000'),
        "is_locked": false,
      };

      expect(() => Coin.serialize(expected, options: BcsWriterOptions(size: 1, maxSize: 1)), throwsArgumentError);
    });
  });

}
