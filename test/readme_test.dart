import 'dart:typed_data';

import 'package:bcs/bcs.dart';
import 'package:test/test.dart';

/// Keeps the code examples in README.md compiling and behaving as documented.
void main() {
  group('README examples', () {
    test('quickstart', () {
      final uid = Bcs.fixedArray(32, Bcs.u8()).transform(
        input: hexDecode,
        output: (id) => hexEncode(Uint8List.fromList(id)),
      );

      final coin = Bcs.struct('Coin', {
        'id': uid,
        'value': Bcs.u64(),
      });

      const id =
          '0000000000000000000000000000000000000000000000000000000000000001';
      final bytes = coin.serialize({'id': id, 'value': 1000000}).toBytes();
      final parsed = coin.parse(bytes);

      expect(parsed, {'id': id, 'value': BigInt.from(1000000)});
      expect(
          Bcs.option(coin).serialize(parsed).toHex(), '01${hexEncode(bytes)}');
    });

    test('compound types', () {
      final myEnum = Bcs.enumeration('MyEnum', {
        'NoType': null,
        'Int': Bcs.u8(),
        'String': Bcs.string(),
        'Array': Bcs.fixedArray(3, Bcs.u8()),
      });

      expect(myEnum.parse(myEnum.serialize({'NoType': null}).toBytes()),
          {'NoType': true, r'$kind': 'NoType'});
      expect(myEnum.parse(myEnum.serialize({'Int': 100}).toBytes()),
          {'Int': 100, r'$kind': 'Int'});
      expect(
          myEnum.parse(myEnum.serialize({
            'Array': [1, 2, 3]
          }).toBytes()),
          {
            'Array': [1, 2, 3],
            r'$kind': 'Array'
          });

      final myStruct = Bcs.struct('MyStruct', {
        'id': Bcs.u8(),
        'name': Bcs.string(),
      });
      final struct = myStruct.serialize({'id': 1, 'name': 'name'}).toBytes();
      expect(myStruct.parse(struct), {'id': 1, 'name': 'name'});

      final tuple =
          Bcs.tuple([Bcs.u8(), Bcs.string()]).serialize([1, 'name']).toBytes();
      expect(Bcs.tuple([Bcs.u8(), Bcs.string()]).parse(tuple), [1, 'name']);

      final map = Bcs.map(Bcs.u8(), Bcs.string())
          .serialize({1: 'one', 2: 'two'}).toBytes();
      expect(Bcs.map(Bcs.u8(), Bcs.string()).parse(map), {1: 'one', 2: 'two'});
    });

    test('generics', () {
      BcsType<Map<String, dynamic>, dynamic> container<T, Input>(
          BcsType<T, Input> inner) {
        return Bcs.struct('Container<${inner.name}>', {
          'contents': inner,
        });
      }

      final bytes = container(Bcs.u8()).serialize({'contents': 100}).toBytes();
      expect(container(Bcs.u8()).parse(bytes), {'contents': 100});

      BcsType<Map<String, dynamic>, dynamic> vecMap<K, V, InK, InV>(
          BcsType<K, InK> key, BcsType<V, InV> value) {
        return Bcs.struct('VecMap<${key.name}, ${value.name}>', {
          'keys': Bcs.vector(key),
          'values': Bcs.vector(value),
        });
      }

      final schema = vecMap(Bcs.string(), Bcs.string());
      final vecMapBytes = schema.serialize({
        'keys': ['key1', 'key2', 'key3'],
        'values': ['value1', 'value2', 'value3'],
      }).toBytes();

      expect(schema.parse(vecMapBytes), {
        'keys': ['key1', 'key2', 'key3'],
        'values': ['value1', 'value2', 'value3'],
      });
    });

    test('transforms', () {
      final address = Bcs.bytes(32).transform(
        name: 'address',
        input: hexDecode,
        output: hexEncode,
      );

      const hex =
          '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef';
      final serialized = address.serialize('0x$hex').toBytes();
      expect(address.parse(serialized), hex);
    });

    test('serialized formats', () {
      final serializedString = Bcs.string().serialize('this is a string');

      expect(
          Bcs.string().parse(serializedString.toBytes()), 'this is a string');
      expect(
          Bcs.string().fromHex(serializedString.toHex()), 'this is a string');
      expect(Bcs.string().fromBase64(serializedString.toBase64()),
          'this is a string');
      expect(Bcs.string().fromBase58(serializedString.toBase58()),
          'this is a string');
    });
  });
}
