import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:bcs/bcs.dart';

void main() {

  group('Move BCS', () {

    test('test toBN', () {
      expect(toBN(true) == BigInt.one, true);
      expect(toBN(false) == BigInt.zero, true);
      expect(toBN(1) == BigInt.one, true);
      expect(toBN(0) == BigInt.zero, true);
      expect(toBN(BigInt.one) == BigInt.one, true);
      expect(toBN(BigInt.zero) == BigInt.zero, true);
      expect(toBN('1') == BigInt.one, true);
      expect(toBN('0') == BigInt.zero, true);
    });

    test('should de/ser primitives: u8', () {
      expect(BCS.de(BCS.U8, base64Decode('AQ==')) == 1, true);
      expect(BCS.de('u8', base64Decode('AA==')) == 0, true);
    });

    test('should ser/de u32', () {
      const exp = '/////w==';
      const num = 4294967295;
      final set = BCS.ser('u32', num).toBase64String();

      expect(set == exp, true);
      expect(BCS.de('u32', exp, 'base64') == num, true);
    });

    test('should ser/de u64', () {
      const exp = 'AO/Nq3hWNBI=';
      final num = BigInt.parse('1311768467750121216');
      final set = BCS.ser('u64', num).toBase64String();

      expect(set == exp, true);
      expect(BCS.de('u64', exp, 'base64') == BigInt.parse('1311768467750121216'), true);
    });

    test('should ser/de u128', () {
      const sample = 'AO9ld3CFjD48AAAAAAAAAA==';
      final num = BigInt.parse('1111311768467750121216');

      expect(BCS.de('u128', sample, 'base64').toString() == '1111311768467750121216', true);
      expect(BCS.ser('u128', num).toBase64String() == sample, true);
    });

    test('should de/ser custom objects', () {
      BCS.registerStructType('Coin', {
        'value': BCS.U64,
        'owner': BCS.STRING,
        'is_locked': BCS.BOOL,
      });

      const rustBcs = 'gNGxBWAAAAAOQmlnIFdhbGxldCBHdXkA';
      final expected = {
        'owner': 'Big Wallet Guy',
        'value': BigInt.parse('412412400000'),
        'is_locked': false,
      };

      final setBytes = BCS.ser('Coin', expected);
      final data = BCS.de('Coin', base64Decode(rustBcs));

      expect(data['owner'] == expected['owner'], true);
      expect(data['value'] == expected['value'], true);
      expect(data['is_locked'] == expected['is_locked'], true);
      expect(setBytes.toBase64String() == rustBcs, true);
    });

    test('should de/ser vectors', () {
      BCS.registerVectorType('vector<u8>', 'u8');

      String largebcsVec() {
        return '6Af/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////';
      }

      // Rust-BCS generated vector with 1000 u8 elements (FF)
      final sample = largebcsVec();

      // deserialize data with JS
      final deserialized = BCS.de('vector<u8>', base64Decode(sample));

      // create the same vec with 1000 elements
      final arr = List<int>.filled(1000, 255);
      final serialized = BCS.ser('vector<u8>', arr);

      expect(deserialized.length == 1000, true);
      expect(serialized.toBase64String() == largebcsVec(), true);
    });

    test('should de/ser enums', () {
      BCS.registerStructType('Coin', { 'value': 'u64' });
      BCS.registerVectorType('vector<Coin>', 'Coin');
      BCS.registerEnumType('Enum', {
        'single': 'Coin',
        'multi': 'vector<Coin>',
      });

      // prepare 2 examples from Rust BCS
      final example1 = base64Decode('AICWmAAAAAAA');
      final example2 = base64Decode('AQIBAAAAAAAAAAIAAAAAAAAA');

      // serialize 2 objects with the same data and signature
      final set1 = BCS.ser('Enum', { 'single': { 'value': 10000000 } }).toBytes();
      final set2 = BCS.ser('Enum', {
        'multi': [{ 'value': 1 }, { 'value': 2 }],
      }).toBytes();

      // deserialize and compare results
      expect(BCS.de('Enum', example1).toString() == BCS.de('Enum', set1).toString(), true);
      expect(BCS.de('Enum', example2).toString() == BCS.de('Enum', set2).toString(), true);
    });

    test('should de/ser addresses', () {
      // Move Kitty example:
      // Wallet { kitties: vector<Kitty>, owner: address }
      // Kitty { id: 'u8' }

      BCS.registerAddressType('address', 16);

      BCS.registerStructType('Kitty', { 'id': 'u8' });
      BCS.registerVectorType('vector<Kitty>', 'Kitty');
      BCS.registerStructType('Wallet', {
        'kitties': 'vector<Kitty>',
        'owner': 'address',
      });

      // Generated with Move CLI i.e. on the Move side
      const sample = 'AgECAAAAAAAAAAAAAAAAAMD/7g==';
      final data = BCS.de('Wallet', base64Decode(sample));

      expect(data['kitties'].length == 2, true);
      expect(data['owner'] == '00000000000000000000000000c0ffee', true);
    });

  });

}
