import 'dart:typed_data';

import 'package:bcs/bcs.dart';
import 'package:test/test.dart';

class _BadToJson {
  String toJson() => 'not a map';
}

void main() {
  // A Sui-style address: 32 bytes, represented as a hex string in Dart.
  final address = Bcs.bytes(32).transform(
    name: 'address',
    input: hexDecode,
    output: hexEncode,
  );

  group('BCS: wire format', () {
    test('u256 matches the Rust BCS output', () {
      expect(
        Bcs.u256().serialize('100000').toHex(),
        'a086010000000000000000000000000000000000000000000000000000000000',
      );
    });

    test('structs with address fields round-trip', () {
      final beep = Bcs.struct('Beep', {
        'id': address,
        'value': Bcs.u64(),
      });

      const id =
          '00000000000000000000000045aacd9ed90a5a8e211502ac3fa898a3819f23b2';
      final bytes = beep.serialize({'id': id, 'value': 10000000}).toBytes();
      final decoded = beep.parse(bytes);

      expect(decoded['id'], id);
      expect(decoded['value'], BigInt.from(10000000));
    });

    test('enums with and without payloads round-trip', () {
      final enumeration = Bcs.enumeration('Enum', {
        'with_value': address,
        'no_value': null,
      });

      const addr =
          'bb967ddbebfee8c40d8fdd2c24cb02452834cd3a7061d18564448f900eb9e66d';

      final withValue = enumeration
          .parse(enumeration.serialize({'with_value': addr}).toBytes());
      expect(withValue, {r'$kind': 'with_value', 'with_value': addr});

      final noValue = enumeration
          .parse(enumeration.serialize({'no_value': null}).toBytes());
      expect(noValue, {r'$kind': 'no_value', 'no_value': true});
    });

    test('maps serialize as vectors of tuples', () {
      final schema = Bcs.map(Bcs.u8(), Bcs.string());
      final serialized = schema.serialize({1: 'a', 2: 'b'});

      expect(serialized.toHex(), '02010161020162');
      expect(schema.parse(serialized.toBytes()), {1: 'a', 2: 'b'});
    });

    test('recursive schemas work through lazy', () {
      late final BcsType<Map<String, dynamic>, dynamic> tree;
      tree = Bcs.struct('Tree', {
        'value': Bcs.u8(),
        'children': Bcs.vector(Bcs.lazy(() => tree)),
      });

      final value = {
        'value': 1,
        'children': [
          {'value': 2, 'children': <Map<String, dynamic>>[]},
          {'value': 3, 'children': <Map<String, dynamic>>[]},
        ],
      };

      final serialized = tree.serialize(value);
      expect(serialized.toHex(), '010202000300');
      expect(tree.parse(serialized.toBytes()), value);
    });
  });

  group('BCS: input flexibility', () {
    test('u64 accepts int, BigInt and String inputs', () {
      final fromInt = Bcs.u64().serialize(1000).toHex();
      final fromBigInt = Bcs.u64().serialize(BigInt.from(1000)).toHex();
      final fromString = Bcs.u64().serialize('1000').toHex();

      expect(fromInt, 'e803000000000000');
      expect(fromBigInt, fromInt);
      expect(fromString, fromInt);
    });

    test('u64 rejects unsupported input types', () {
      expect(() => Bcs.u64().serialize(1.5), throwsArgumentError);
      expect(() => Bcs.u64().serialize(true), throwsArgumentError);
    });
  });

  group('BCS: validation', () {
    test('unsigned integers reject out-of-range values', () {
      expect(() => Bcs.u8().serialize(256), throwsArgumentError);
      expect(() => Bcs.u8().serialize(-1), throwsArgumentError);
      expect(() => Bcs.u16().serialize(65536), throwsArgumentError);
      expect(
          () => Bcs.u64().serialize(BigInt.two.pow(64)), throwsArgumentError);
      expect(() => Bcs.u64().serialize(-1), throwsArgumentError);
    });

    test('fixed-size types reject wrong lengths', () {
      expect(() => Bcs.bytes(4).serialize([1, 2, 3]), throwsArgumentError);
      expect(() => Bcs.bytes(2).serialize([256, 0]), throwsArgumentError);
      expect(() => Bcs.bytes(2).serialize([-1, 0]), throwsArgumentError);
      expect(() => Bcs.fixedArray(2, Bcs.u8()).serialize([1, 2, 3]),
          throwsArgumentError);
      expect(
          () => Bcs.tuple([Bcs.u8()]).serialize([1, 2]), throwsArgumentError);
    });

    test('enums reject values without exactly one variant', () {
      final enumeration = Bcs.enumeration('E', {'A': Bcs.u8(), 'B': null});
      expect(() => enumeration.serialize(<String, dynamic>{}),
          throwsArgumentError);
      expect(() => enumeration.serialize({'A': 1, 'B': null}),
          throwsArgumentError);
      expect(() => enumeration.serialize({'C': 1}), throwsArgumentError);
    });

    test('structs reject inputs that are not maps and name the type', () {
      final schema = Bcs.struct('Coin', {'value': Bcs.u8()});
      expect(
        () => schema.serialize('not a map'),
        throwsA(isA<ArgumentError>().having(
            (e) => e.message, 'message', contains('Coin'))),
      );
      expect(() => schema.serialize(_BadToJson()), throwsArgumentError);
    });

    test('custom validators run before writes', () {
      final positive = Bcs.u8(BcsTypeOptions(validate: (value) {
        if (value == 0) throw ArgumentError('Value must not be zero');
      }));
      expect(() => positive.serialize(0), throwsArgumentError);
      expect(positive.serialize(1).toHex(), '01');
    });
  });

  group('BCS: canonical decoding', () {
    test('booleans reject bytes other than 0 and 1', () {
      expect(Bcs.boolean().parse(Uint8List.fromList([0])), false);
      expect(Bcs.boolean().parse(Uint8List.fromList([1])), true);
      expect(() => Bcs.boolean().parse(Uint8List.fromList([2])),
          throwsFormatException);
    });

    test('enums reject unknown variant indexes', () {
      final enumeration = Bcs.enumeration('E', {'A': null});
      expect(() => enumeration.parse(Uint8List.fromList([5])),
          throwsFormatException);
    });

    test('reading past the end of the buffer throws', () {
      expect(
          () => Bcs.u32().parse(Uint8List.fromList([1, 2])), throwsRangeError);
      expect(() => Bcs.string().parse(Uint8List.fromList([5, 0x61])),
          throwsRangeError);
    });

    test('truncated ULEB128 throws', () {
      expect(() => Bcs.string().parse(Uint8List.fromList([0x80])),
          throwsFormatException);
    });

    test('ULEB128 values beyond u32 throw instead of overflowing', () {
      // 2^32 encoded as ULEB128 (5 bytes, exceeds the u32 cap by one).
      expect(
          () => Bcs.string()
              .parse(Uint8List.fromList([0x80, 0x80, 0x80, 0x80, 0x10])),
          throwsFormatException);
      // 6+ byte encodings are rejected before the value is even assembled.
      expect(
          () => Bcs.string().parse(
              Uint8List.fromList([0xff, 0xff, 0xff, 0xff, 0xff, 0x01])),
          throwsFormatException);
      // u32 max itself is still accepted by the decoder (fails later only
      // because the buffer does not actually hold that many bytes).
      expect(
          () => Bcs.vector(Bcs.u8())
              .parse(Uint8List.fromList([0xff, 0xff, 0xff, 0xff, 0x0f])),
          throwsFormatException);
    });

    test('hex decoding rejects signs, whitespace and non-hex characters', () {
      expect(() => hexDecode('-f'), throwsFormatException);
      expect(() => hexDecode('+f'), throwsFormatException);
      expect(() => hexDecode(' 1'), throwsFormatException);
      expect(() => hexDecode('1 2'), throwsFormatException);
      expect(() => hexDecode('0xzz'), throwsFormatException);
      expect(hexDecode('0xAbCd'), [0xab, 0xcd]);
    });

    test('vector lengths beyond the remaining input throw', () {
      // Claims 1000 elements but provides only two bytes of payload,
      // which must be rejected before any allocation happens.
      final bytes = Uint8List.fromList([0xe8, 0x07, 1, 2]);
      expect(
          () => Bcs.vector(Bcs.u8()).parse(bytes), throwsFormatException);
    });
  });

  group('BcsWriter: buffer growth', () {
    test('grows geometrically past the initial size', () {
      final schema = Bcs.vector(Bcs.u8());
      final value = List<int>.filled(100000, 0xab);
      final bytes = schema
          .serialize(value, options: const BcsWriterOptions(size: 1))
          .toBytes();
      expect(bytes.length, 100000 + 3);
      expect(schema.parse(bytes), value);
    });
  });
}
