
import 'dart:typed_data';

import 'package:bcs/bcs.dart';
import 'package:bcs/bcs_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {

  group('test bcs', () {

    group('test bcs base types', () {
      
      testType('true', bcs.boolType(), true, '01');
      testType('false', bcs.boolType(), false, '00');
      testType('uleb128 0', bcs.uleb128(), 0, '00');
      testType('uleb128 1', bcs.uleb128(), 1, '01');
      testType('uleb128 127', bcs.uleb128(), 127, '7f');
      testType('uleb128 128', bcs.uleb128(), 128, '8001');
      testType('uleb128 255', bcs.uleb128(), 255, 'ff01');
      testType('uleb128 256', bcs.uleb128(), 256, '8002');
      testType('uleb128 16383', bcs.uleb128(), 16383, 'ff7f');
      testType('uleb128 16384', bcs.uleb128(), 16384, '808001');
      testType('uleb128 2097151', bcs.uleb128(), 2097151, 'ffff7f');
      testType('uleb128 2097152', bcs.uleb128(), 2097152, '80808001');
      testType('uleb128 268435455', bcs.uleb128(), 268435455, 'ffffff7f');
      testType('uleb128 268435456', bcs.uleb128(), 268435456, '8080808001');
      testType('u8 0', bcs.u8(), 0, '00');
      testType('u8 1', bcs.u8(), 1, '01');
      testType('u8 255', bcs.u8(), 255, 'ff');
      testType('u16 0', bcs.u16(), 0, '0000');
      testType('u16 1', bcs.u16(), 1, '0100');
      testType('u16 255', bcs.u16(), 255, 'ff00');
      testType('u16 256', bcs.u16(), 256, '0001');
      testType('u16 65535', bcs.u16(), 65535, 'ffff');
      testType('u32 0', bcs.u32(), 0, '00000000');
      testType('u32 1', bcs.u32(), 1, '01000000');
      testType('u32 255', bcs.u32(), 255, 'ff000000');
      testType('u32 256', bcs.u32(), 256, '00010000');
      testType('u32 65535', bcs.u32(), 65535, 'ffff0000');
      testType('u32 65536', bcs.u32(), 65536, '00000100');
      testType('u32 16777215', bcs.u32(), 16777215, 'ffffff00');
      testType('u32 16777216', bcs.u32(), 16777216, '00000001');
      testType('u32 4294967295', bcs.u32(), 4294967295, 'ffffffff');
      testType('u64 0', bcs.u64(), BigInt.zero, '0000000000000000', '0');
      testType('u64 1', bcs.u64(), BigInt.one, '0100000000000000', '1');
      testType('u64 255', bcs.u64(), BigInt.from(255), 'ff00000000000000', '255');
      testType('u64 256', bcs.u64(), BigInt.from(256), '0001000000000000', '256');
      testType('u64 65535', bcs.u64(), BigInt.from(65535), 'ffff000000000000', '65535');
      testType('u64 65536', bcs.u64(), BigInt.from(65536), '0000010000000000', '65536');
      testType('u64 16777215', bcs.u64(), BigInt.from(16777215), 'ffffff0000000000', '16777215');
      testType('u64 16777216', bcs.u64(), BigInt.from(16777216), '0000000100000000', '16777216');
      testType('u64 4294967295', bcs.u64(), BigInt.from(4294967295), 'ffffffff00000000', '4294967295');
      testType('u64 4294967296', bcs.u64(), BigInt.from(4294967296), '0000000001000000', '4294967296');
      testType('u64 1099511627775', bcs.u64(), BigInt.from(1099511627775), 'ffffffffff000000', '1099511627775');
      testType('u64 1099511627776', bcs.u64(), BigInt.from(1099511627776), '0000000000010000', '1099511627776');
      testType(
        'u64 281474976710655',
        bcs.u64(),
        BigInt.from(281474976710655),
        'ffffffffffff0000',
        '281474976710655',
      );
      testType(
        'u64 281474976710656',
        bcs.u64(),
        BigInt.from(281474976710656),
        '0000000000000100',
        '281474976710656',
      );
      testType(
        'u64 72057594037927935',
        bcs.u64(),
        BigInt.from(72057594037927935),
        'ffffffffffffff00',
        '72057594037927935',
      );
      testType(
        'u64 72057594037927936',
        bcs.u64(),
        BigInt.from(72057594037927936),
        '0000000000000001',
        '72057594037927936',
      );
      testType(
        'u64 18446744073709551615',
        bcs.u64(),
        BigInt.parse("18446744073709551615"),
        'ffffffffffffffff',
        '18446744073709551615',
      );
      testType('u128 0', bcs.u128(), BigInt.zero, '00000000000000000000000000000000', '0');
      testType('u128 1', bcs.u128(), BigInt.one, '01000000000000000000000000000000', '1');
      testType('u128 255', bcs.u128(), BigInt.from(255), 'ff000000000000000000000000000000', '255');
      testType(
        'u128 18446744073709551615',
        bcs.u128(),
        BigInt.parse("18446744073709551615"),
        'ffffffffffffffff0000000000000000',
        '18446744073709551615',
      );
      testType(
        'u128 18446744073709551615',
        bcs.u128(),
        BigInt.parse("18446744073709551616"),
        '00000000000000000100000000000000',
        '18446744073709551616',
      );
      testType(
        'u128 340282366920938463463374607431768211455',
        bcs.u128(),
        BigInt.parse("340282366920938463463374607431768211455"),
        'ffffffffffffffffffffffffffffffff',
        '340282366920938463463374607431768211455',
      );

    });

  group('vector', () {
		testType('vector([])', bcs.vector(bcs.u8()), <int>[], '00');
		testType('vector([1, 2, 3])', bcs.vector(bcs.u8()), [1, 2, 3], '03010203');
		testType(
			'vector([1, null, 3])',
			bcs.vector(bcs.option(bcs.u8())),
			[1, null, 3],
			// eslint-disable-next-line no-useless-concat
			'03' + '0101' + '00' + '0103',
		);
	});

	group('fixedVector', () {
		testType('fixedVector([])', bcs.fixedArray(0, bcs.u8()), <int>[], '');
		testType('vector([1, 2, 3])', bcs.fixedArray(3, bcs.u8()), [1, 2, 3], '010203');
		testType(
			'fixedVector([1, null, 3])',
			bcs.fixedArray(3, bcs.option(bcs.u8())),
			[1, null, 3],
			// eslint-disable-next-line no-useless-concat
			'0101' + '00' + '0103',
		);
	});

	group('options', () {
		testType('optional u8 null', bcs.option(bcs.u8()), null, '00');
		testType('optional u8 0', bcs.option(bcs.u8()), 0, '0100');
		testType('optional vector(null)', bcs.option(bcs.vector(bcs.u8())), null, '00');
		testType(
			'optional vector([1, 2, 3])',
			bcs.option(bcs.vector(bcs.option(bcs.u8()))),
			[1, null, 3],
			// eslint-disable-next-line no-useless-concat
			'01' + '03' + '0101' + '00' + '0103',
		);
	});

	group('string', () {
		testType('string empty', bcs.string(), '', '00');
		testType('string hello', bcs.string(), 'hello', '0568656c6c6f');
		testType(
			'string çå∞≠¢õß∂ƒ∫',
			bcs.string(),
			'çå∞≠¢õß∂ƒ∫',
			'18c3a7c3a5e2889ee289a0c2a2c3b5c39fe28882c692e288ab',
		);
	});

	group('bytes', () {
		testType('bytes', bcs.bytes(4), Uint8List.fromList([1, 2, 3, 4]), '01020304');
	});

  group('tuples', () {
    testType('tuple(u8, u8)', bcs.tuple([bcs.u8(), bcs.u8()]), [1, 2], '0102');
    testType(
      'tuple(u8, string, boolean)',
      bcs.tuple([bcs.u8(), bcs.string(), bcs.boolType()]),
      [1, 'hello', true],
      '010568656c6c6f01',
    );

    testType(
      'tuple(null, u8)',
      bcs.tuple([bcs.option(bcs.u8()), bcs.option(bcs.u8())]),
      [null, 1],
      '000101',
    );
  });

	group('structs', () {
		final MyStruct = bcs.struct('MyStruct', {
			"boolean": bcs.boolType(),
			"bytes": bcs.vector(bcs.u8()),
			"label": bcs.string(),
		});

		final Wrapper = bcs.struct('Wrapper', {
			"inner": MyStruct,
			"name": bcs.string(),
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
		final E = bcs.enumType('E', {
			"Variant0": bcs.u16(),
			"Variant1": bcs.u8(),
			"Variant2": bcs.string(),
		});

		testType('Enum::Variant0(1)', E, { "Variant0": 1 }, '000100');
		testType('Enum::Variant1(1)', E, { "Variant1": 1 }, '0101');
		testType('Enum::Variant2("hello")', E, { "Variant2": 'hello' }, '020568656c6c6f');
	});

  group('maps', () {
    final IntStringMap = bcs.map(bcs.u8(), bcs.string());
    final IntBoolMap = bcs.map(bcs.u8(), bcs.boolType());

    testType('map { u8: string }', IntStringMap, {2: 'a'}, '01020161');
    testType('map { u8: string, u8: string }', IntStringMap, {1: 'one', 2: 'two'}, '0201036f6e65020374776f');

    testType('map { u8: bool }', IntBoolMap, {0: false}, '010000');
    testType('map { u8: bool }', IntBoolMap, {1: true}, '010101');
    testType('map { u8: bool, u8, bool }', IntBoolMap, {0: false, 1: true}, '0200000101');

  });

  group('generics', () {
    final VecMap = bcs.generic(['K', 'V'], (List<BcsType> KV) =>
      bcs.struct('VecMap<K, V>', {
        "keys": bcs.vector(KV[0]),
        "values": bcs.vector(KV[1]),
      })
    );

    final Generics = VecMap([bcs.string(), bcs.string()]);

    final value = {
      "keys": ['key1', 'key2', 'key3'],
      "values": ['value1', 'value2', 'value3'],
    };
    testType('generic <string, string>', Generics, value, '03046b657931046b657932046b657933030676616c7565310676616c7565320676616c756533');

    });

  });

  test('test demo', () {
    expect(bcs.u8().serialize(255).toBytes(), [255]);
    expect(bcs.u16().serialize(65535).toBytes(), [255, 255]);
    expect(bcs.u32().serialize(4294967295).toBytes(), [255, 255, 255, 255]);
    expect(bcs.u64().serialize(BigInt.one).toBytes(), [1, 0, 0, 0, 0, 0, 0, 0]);
    expect(bcs.u128().serialize(BigInt.one).toBytes(), [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]);
    expect(bcs.u256().serialize(BigInt.one).toBytes(), [1] + List<int>.filled(31, 0));
    expect(bcs.boolType().serialize(true).toBytes(), [1]);
    expect(bcs.uleb128().serialize(1).toBytes(), [1]);
    expect(bcs.bytes(3).serialize(Uint8List.fromList([1, 2, 3])).toBytes(), [1, 2, 3]);
    expect(bcs.string().serialize('a').toBytes(), [1, 97]);
    expect(bcs.fixedArray(3, bcs.u8()).serialize([1, 2, 3]).toBytes(), [1, 2, 3]);
    expect(bcs.option(bcs.u8()).serialize(null).toBytes(), [0]);
    expect(bcs.option(bcs.u8()).serialize(1).toBytes(), [1, 1]);
    expect(bcs.vector(bcs.u8()).serialize([1, 2, 3]).toBytes(), [3, 1, 2, 3]);
    final tuple = bcs.tuple([bcs.u8(), bcs.string(), bcs.boolType()]);
    expect(tuple.serialize([1, 'a', true]).toBytes(), [1, 1, 97, 1]);
	  final struct = bcs.struct('MyStruct', {
	    "a": bcs.u8(),
	    "b": bcs.string(),
	  });
	  expect(struct.serialize({ "a": 1, "b": 'a' }).toBytes(), [ 1, 1, 97 ]);

    final enumType = bcs.enumType('MyEnum', {
      "A": bcs.u8(),
      "B": bcs.string(),
      "C": null,
    });
    expect(enumType.serialize({ "A": 1 }).toBytes(), [ 0, 1 ]);
    expect(enumType.serialize({ "B": 'a' }).toBytes(), [ 1, 1, 97 ]);
    expect(enumType.serialize({ "C": true }).toBytes(), [ 2 ]);

    final map = bcs.map(bcs.u8(), bcs.string());
    expect(map.serialize({2: 'a'}).toBytes(), [ 1, 2, 1, 97 ]);

    final MyStruct = bcs.generic(['T'], (List<BcsType> T) => bcs.struct('MyStruct', { "inner": T[0] }));
    expect(MyStruct([bcs.u8()]).serialize({ "inner": 1 }).toBytes(), [ 1 ]);
    expect(MyStruct([bcs.string()]).serialize({ "inner": 'a' }).toBytes(), [ 1, 97 ]);

  });

}

void testType<T, Input>(
	String name,
	BcsType<T, Input> schema,
	Input value,
	String hex,
	[dynamic expected]
) {
  expected ??= value;
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