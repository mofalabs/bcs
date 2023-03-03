## BCS - Binary Canonical Serialization

[![Pub](https://img.shields.io/badge/pub-v0.0.1-blue)](https://pub.dev/packages/bcs)

This library implements [Binary Canonical Serialization (BCS)](https://github.com/diem/bcs) in Dart.

## Feature set

- Move's primitive types de/serialization: u8, u64, u128, bool
- Ability to define custom types such as `vector<T>` or `struct`
- Extendable and allows registering any custom types (e.g. vectors of structs)
- Custom addresses length. Example: `BCS.registerAddressType('Address', 20, 'hex')` - 20 bytes
- Built-in support for enums (and potentially tuples)

## Examples

At the high level, BCS gives a set of handy abstractions to (de)serialize data.

> Important: by default there's no type `address` in this library. To define it, use `registerAddressType`.
> Also, there's no built-in support for generics yet. For each `vector<T>` you have to define custom type
> using `registerVectorType('vector<u8>', 'u8')`. Default support for vectors is intentionally omitted (for now)
> because of type difference between Rust and Move vector types.

### Struct

In BCS structs are merely sequences of fields, they contain no type information but the order in
which fields are defined. It also means that you can use any field names - they won't affect serialization!
```
BCS.registerStructType(<TYPE>, {
    [<FIELD>]: <FIELD_TYPE>,
    ...
})
```

```dart
import 'package:bcs/bcs.dart';

// MyAddr is an address of 20 bytes; encoded and decoded as HEX
BCS.registerAddressType('MyAddr', 20, 'hex');
BCS.registerStructType('Item', {
    'owner': 'MyAddr',
    'price': 'u64'
});

// bcs preserves order of fields according to struct definition, so you're free to
// use any order while serializing your structs
final bcsBytes = BCS.ser('Item', {
    'price': '100000000000',
    'owner': '9c88e852aa66b346860ada31aa75c6c27695ae4b',
}).toBytes();
final item = BCS.de('Item', bcsBytes);

print(item);
```

### Vector

Vector generics are not supported by default. To use a vector type, add it first:
```
BCS.registerVectorType(<TYPE>, <ELEMENT_TYPE>);
```

```dart
import 'package:bcs/bcs.dart';

BCS.registerVectorType('vector<u8>', 'u8');
final array = BCS.de('vector<u8>', '06010203040506', 'hex'); // [1,2,3,4,5,6];
final again = BCS.ser('vector<u8>', [1,2,3,4,5,6]).toHexString();

assert(again == '06010203040506', 'Whoopsie!');
```

### Address

Even though the way of serializing Move addresses stays the same, the length of the address
varies depending on the network. To register an address type use:
```
BCS.registerAddressType(<TYPE>, <LENGTH>);
```

```dart
import 'package:bcs/bcs.dart';

BCS.registerAddressType('FiveBytes', 5);
BCS.registerAddressType('DiemAddress', 20);

final de = BCS.de('FiveBytes', '0x00C0FFEE00', 'hex');
final ser = BCS.ser('DiemAddress', '9c88e852aa66b346860ada31aa75c6c27695ae4b').toHexString();

assert(de == '00c0ffee00', 'Short address mismatch');
assert(ser == '9c88e852aa66b346860ada31aa75c6c27695ae4b', 'Long address mismatch');
```

### Primitive types

To deserialize data, use a `BCS.de(String type, Uint8List data)`. Type parameter is a name of the type; data is a BCS encoded as hex.

```dart
import 'package:bcs/bcs.dart';

// BCS has a set of built ins:
// U8, U32, U64, U128, BOOL, STRING
assert(BCS.U64 == 'u64');
assert(BCS.BOOL == 'bool');
assert(BCS.STRING == 'string');

// De/serialization of primitives is included by default;
final u8 = BCS.de(BCS.U8, '00', 'hex'); // '0'
final u32 = BCS.de(BCS.U32, '78563412', 'hex'); // '305419896'
final u64 = BCS.de(BCS.U64, 'ffffffffffffffff', 'hex'); // '18446744073709551615'
final u128 = BCS.de(BCS.U128, 'FFFFFFFF000000000000000000000000', 'hex'); // '4294967295'
final bool = BCS.de(BCS.BOOL, '00', 'hex'); // false

// There's also a handy built-in for ASCII strings (which are `vector<u8>` under the hood)
final str = BCS.de(BCS.STRING, '0a68656c6c6f5f6d6f7665', 'hex'); // hello_move

print(str);
```

To serialize any type, use `BCS.ser(String type, dynamic data)`. Type parameter is a name of the type to serialize, data is any data, depending on the type (can be object for structs or string for big integers - such as `u128`).

```dart
import 'package:bcs/bcs.dart';

final bcsU8 = BCS.ser('u8', 255).toHexString();
assert(bcsU8 == 'ff');

final bcsAscii = BCS.ser('string', 'hello_move').toHexString();
assert(bcsAscii == '0a68656c6c6f5f6d6f7665');
```

### Working with Move structs

```dart
import 'package:bcs/bcs.dart';

// Move / Rust struct
// struct Coin {
//   value: u64,
//   owner: vector<u8>, // name // Vec<u8> in Rust
//   is_locked: bool,
// }

BCS.registerStructType('Coin', {
    'value': BCS.U64,
    'owner': BCS.STRING,
    'is_locked': BCS.BOOL
});

// Created in Rust with diem/bcs
const rustBcsStr = '80d1b105600000000e4269672057616c6c65742047757900';

print(BCS.de('Coin', rustBcsStr, 'hex'));

// Let's encode the value as well
final test_ser = BCS.ser('Coin', {
    'owner': 'Big Wallet Guy',
    'value': '412412400000',
    'is_locked': false
});

print(test_ser.toBytes());
assert(test_ser.toHexString() == rustBcsStr, 'Whoopsie, result mismatch');
```
