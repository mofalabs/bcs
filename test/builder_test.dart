import 'dart:typed_data';

import 'package:bcs/index.dart';
import 'package:bcs/bcs_type.dart';
import 'package:bcs/reader.dart';
import 'package:bcs/utils.dart';
import 'package:bcs/writer.dart';
import 'package:test/test.dart';

void main() {
  void testType<T, Input>(String name, BcsType<T, Input> schema, Input value, String hex,
      [T? expected]) {
    expected ??= value as T;

    test(name, () {
      final serialized = schema.serialize(value);
      final bytes = serialized.toBytes();
      expect(toHEX(bytes), hex);
      expect(serialized.toHex(), hex);
      expect(serialized.toBase64(), toB64(bytes));
      expect(serialized.toBase58(), toB58(bytes));

      final deserialized = schema.parse(bytes);
      expect(deserialized, expected);

      final writer = BcsWriter(size: bytes.length);
      schema.write(value, writer);
      expect(toHEX(writer.toBytes()), hex);

      final reader = BcsReader(bytes);

      expect(schema.read(reader), expected);
    });
  }

  group('bcs', () {
    group('base types', () {
      testType('true', Bcs.boolean(), true, '01');
      testType('false', Bcs.boolean(), false, '00');
      testType('uleb128 0', Bcs.uleb128(), 0, '00');
      testType('uleb128 1', Bcs.uleb128(), 1, '01');
      testType('uleb128 127', Bcs.uleb128(), 127, '7f');
      testType('uleb128 128', Bcs.uleb128(), 128, '8001');
      testType('uleb128 255', Bcs.uleb128(), 255, 'ff01');
      testType('uleb128 256', Bcs.uleb128(), 256, '8002');
      testType('uleb128 16383', Bcs.uleb128(), 16383, 'ff7f');
      testType('uleb128 16384', Bcs.uleb128(), 16384, '808001');
      testType('uleb128 2097151', Bcs.uleb128(), 2097151, 'ffff7f');
      testType('uleb128 2097152', Bcs.uleb128(), 2097152, '80808001');
      testType('uleb128 268435455', Bcs.uleb128(), 268435455, 'ffffff7f');
      testType('uleb128 268435456', Bcs.uleb128(), 268435456, '8080808001');
      testType('u8 0', Bcs.u8(), 0, '00');
      testType('u8 1', Bcs.u8(), 1, '01');
      testType('u8 255', Bcs.u8(), 255, 'ff');
      testType('u16 0', Bcs.u16(), 0, '0000');
      testType('u16 1', Bcs.u16(), 1, '0100');
      testType('u16 255', Bcs.u16(), 255, 'ff00');
      testType('u16 256', Bcs.u16(), 256, '0001');
      testType('u16 65535', Bcs.u16(), 65535, 'ffff');
      testType('u32 0', Bcs.u32(), 0, '00000000');
      testType('u32 1', Bcs.u32(), 1, '01000000');
      testType('u32 255', Bcs.u32(), 255, 'ff000000');
      testType('u32 256', Bcs.u32(), 256, '00010000');
      testType('u32 65535', Bcs.u32(), 65535, 'ffff0000');
      testType('u32 65536', Bcs.u32(), 65536, '00000100');
      testType('u32 16777215', Bcs.u32(), 16777215, 'ffffff00');
      testType('u32 16777216', Bcs.u32(), 16777216, '00000001');
      testType('u32 4294967295', Bcs.u32(), 4294967295, 'ffffffff');
      testType('u64 0', Bcs.u64(), BigInt.zero, '0000000000000000', BigInt.zero);
      testType('u64 1', Bcs.u64(), BigInt.one, '0100000000000000', BigInt.one);
      testType('u64 255', Bcs.u64(), BigInt.from(255), 'ff00000000000000', BigInt.from(255));
      testType('u64 256', Bcs.u64(), BigInt.from(256), '0001000000000000', BigInt.from(256));
      testType('u64 65535', Bcs.u64(), BigInt.from(65535), 'ffff000000000000', BigInt.from(65535));
      testType('u64 65536', Bcs.u64(), BigInt.from(65536), '0000010000000000', BigInt.from(65536));
      testType('u64 16777215', Bcs.u64(), BigInt.from(16777215), 'ffffff0000000000',
          BigInt.from(16777215));
      testType('u64 16777216', Bcs.u64(), BigInt.from(16777216), '0000000100000000',
          BigInt.from(16777216));
      testType('u64 4294967295', Bcs.u64(), BigInt.from(4294967295), 'ffffffff00000000',
          BigInt.from(4294967295));
      testType('u64 4294967296', Bcs.u64(), BigInt.from(4294967296), '0000000001000000',
          BigInt.from(4294967296));
      testType('u64 1099511627775', Bcs.u64(), BigInt.parse('1099511627775'), 'ffffffffff000000',
          BigInt.parse('1099511627775'));
      testType('u64 1099511627776', Bcs.u64(), BigInt.parse('1099511627776'), '0000000000010000',
          BigInt.parse('1099511627776'));
      testType(
        'u64 281474976710655',
        Bcs.u64(),
        BigInt.parse('281474976710655'),
        'ffffffffffff0000',
        BigInt.parse('281474976710655'),
      );
      testType(
        'u64 281474976710656',
        Bcs.u64(),
        BigInt.parse('281474976710656'),
        '0000000000000100',
        BigInt.parse('281474976710656'),
      );
      testType(
        'u64 72057594037927935',
        Bcs.u64(),
        BigInt.parse('72057594037927935'),
        'ffffffffffffff00',
        BigInt.parse('72057594037927935'),
      );
      testType(
        'u64 72057594037927936',
        Bcs.u64(),
        BigInt.parse('72057594037927936'),
        '0000000000000001',
        BigInt.parse('72057594037927936'),
      );
      testType(
        'u64 18446744073709551615',
        Bcs.u64(),
        BigInt.parse('18446744073709551615'),
        'ffffffffffffffff',
        BigInt.parse('18446744073709551615'),
      );
      testType('u128 0', Bcs.u128(), BigInt.parse('0'), '00000000000000000000000000000000',
          BigInt.parse('0'));
      testType('u128 1', Bcs.u128(), BigInt.parse('1'), '01000000000000000000000000000000',
          BigInt.parse('1'));
      testType('u128 255', Bcs.u128(), BigInt.parse('255'), 'ff000000000000000000000000000000',
          BigInt.parse('255'));
      testType(
        'u128 18446744073709551615',
        Bcs.u128(),
        BigInt.parse('18446744073709551615'),
        'ffffffffffffffff0000000000000000',
        BigInt.parse('18446744073709551615'),
      );
      testType(
        'u128 18446744073709551615',
        Bcs.u128(),
        BigInt.parse('18446744073709551616'),
        '00000000000000000100000000000000',
        BigInt.parse('18446744073709551616'),
      );
      testType(
        'u128 340282366920938463463374607431768211455',
        Bcs.u128(),
        BigInt.parse('340282366920938463463374607431768211455'),
        'ffffffffffffffffffffffffffffffff',
        BigInt.parse('340282366920938463463374607431768211455'),
      );
    });

    group('vector', () {
      testType('vector([])', Bcs.vector(Bcs.u8()), <int>[], '00');
      testType('vector([1, 2, 3])', Bcs.vector(Bcs.u8()), [1, 2, 3], '03010203');
      testType(
        'vector([1, null, 3])',
        Bcs.vector(Bcs.option(Bcs.u8())),
        [1, null, 3],
        '03' + '0101' + '00' + '0103',
      );
    });

    group('fixedVector', () {
      testType('fixedVector([])', Bcs.fixedArray(0, Bcs.u8()), <int>[], '');
      testType('vector([1, 2, 3])', Bcs.fixedArray(3, Bcs.u8()), [1, 2, 3], '010203');
      testType(
        'fixedVector([1, null, 3])',
        Bcs.fixedArray(3, Bcs.option(Bcs.u8())),
        [1, null, 3],
        // eslint-disable-next-line no-useless-concat
        '0101' + '00' + '0103',
      );
    });

    group('options', () {
      testType('optional u8 undefined', Bcs.option(Bcs.u8()), null, '00', null);
      testType('optional u8 null', Bcs.option(Bcs.u8()), null, '00');
      testType('optional u8 0', Bcs.option(Bcs.u8()), 0, '0100');
      testType('optional vector(null)', Bcs.option(Bcs.vector(Bcs.u8())), null, '00');
      testType(
        'optional vector([1, 2, 3])',
        Bcs.option(Bcs.vector(Bcs.option(Bcs.u8()))),
        [1, null, 3],
        '01' + '03' + '0101' + '00' + '0103',
      );
    });

    group('string', () {
      testType('string empty', Bcs.string(), '', '00');
      testType('string hello', Bcs.string(), 'hello', '0568656c6c6f');
      testType(
        'string çå∞≠¢õß∂ƒ∫',
        Bcs.string(),
        'çå∞≠¢õß∂ƒ∫',
        '18c3a7c3a5e2889ee289a0c2a2c3b5c39fe28882c692e288ab',
      );
    });

    group('bytes', () {
      testType('bytes', Bcs.bytes(4), Uint8List.fromList([1, 2, 3, 4]), '01020304');
    });

    group('tuples', () {
      testType('tuple(u8, u8)', Bcs.tuple([Bcs.u8(), Bcs.u8()]), <dynamic>[1, 2], '0102');
      testType(
        'tuple(u8, string, boolean)',
        Bcs.tuple([Bcs.u8(), Bcs.string(), Bcs.boolean()]),
        [1, 'hello', true],
        '010568656c6c6f01',
      );

      testType(
        'tuple(null, u8)',
        Bcs.tuple([Bcs.option(Bcs.u8()), Bcs.option(Bcs.u8())]),
        [null, 1],
        '000101',
      );
    });

    group('structs', () {
      final MyStruct = Bcs.struct('MyStruct', {
        "boolean": Bcs.boolean(),
        "bytes": Bcs.vector(Bcs.u8()),
        "label": Bcs.string(),
      });

      final Wrapper = Bcs.struct('Wrapper', {
        "inner": MyStruct,
        "name": Bcs.string(),
      });

      testType(
        'struct { boolean: bool, bytes: Vec<u8>, label: String }',
        MyStruct,
        {
          "boolean": true,
          "bytes": Uint8List.fromList([0xc0, 0xde]),
          "label": 'a',
        },
        '0102c0de0161',
        {
          "boolean": true,
          "bytes": [0xc0, 0xde],
          "label": 'a',
        },
      );

      testType(
        'struct { inner: MyStruct, name: String }',
        Wrapper,
        {
          "inner": {
            "boolean": true,
            "bytes": Uint8List.fromList([0xc0, 0xde]),
            "label": 'a',
          },
          "name": 'b',
        },
        '0102c0de01610162',
        {
          "inner": {
            "boolean": true,
            "bytes": [0xc0, 0xde],
            "label": 'a',
          },
          "name": 'b',
        },
      );
    });

    group('enums', () {
      final E = Bcs.enumeration('E', {
        "Variant0": Bcs.u16(),
        "Variant1": Bcs.u8(),
        "Variant2": Bcs.string(),
      });

      testType(
          'Enum::Variant0(1)', E, {"Variant0": 1}, '000100', {"\$kind": 'Variant0', "Variant0": 1});
      testType(
          'Enum::Variant1(1)', E, {"Variant1": 1}, '0101', {"\$kind": 'Variant1', "Variant1": 1});
      testType(
          'Enum::Variant2("hello")',
          E,
          {"Variant2": 'hello'},
          '020568656c6c6f',
          {
            "\$kind": 'Variant2',
            "Variant2": 'hello',
          });
    });
  });
}
