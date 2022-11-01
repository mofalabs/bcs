/// BCS implementation https://github.com/diem/bcs

import 'dart:convert';
import 'dart:typed_data';

import 'package:bcs/consts.dart';
import 'package:bcs/hex.dart';


/// Class used for reading BCS data chunk by chunk. Meant to be used
/// by some wrapper, which will make sure that data is valid and is
/// matching the desired format.
///
///```dart
/// // data for this example is:
/// // { a: u8, b: u32, c: bool, d: u64 }
/// final reader = BcsReader("647f1a060001ffffe7890423c78a050102030405");
/// final field1 = reader.read8();
/// final field2 = reader.read32();
/// final field3 = reader.read8() == '1'; // bool
/// final field4 = reader.read64();
///```
///
/// Reading vectors is another deal in bcs. To read a vector, you first need to read
/// its length using [readULEB]. Here's an example:
/// 
///```dart
/// // data encoded: { field: [1, 2, 3, 4, 5] }
/// final reader = BcsReader("050102030405");
/// final vec_length = reader.readULEB();
/// final elements = [];
/// for (int i = 0; i < vec_length; i++) {
///   elements.push(reader.read8());
/// }
/// print(elements); // [1,2,3,4,5]
/// ```
class BcsReader {
  late ByteData _dataView;
  int _bytePosition = 0;

  BcsReader(Uint8List data) {
    _dataView = ByteData.sublistView(data);
  }

  /// Shift current cursor position by [bytes].
  BcsReader shift(int bytes) {
    _bytePosition += bytes;
    return this;
  }

  /// Read U8 value from the buffer and shift cursor by 1.
  int read8() {
    final value = _dataView.getUint8(_bytePosition);
    shift(1);
    return value;
  }

  /// Read U16 value from the buffer and shift cursor by 2.
  int read16() {
    final value = _dataView.getUint16(_bytePosition, Endian.little);
    shift(2);
    return value;
  }

  /// Read U32 value from the buffer and shift cursor by 4.
  int read32() {
    final value = _dataView.getUint32(_bytePosition, Endian.little);
    shift(4);
    return value;
  }

  /// Read U64 value from the buffer and shift cursor by 8.
  BigInt read64() {
    final value1 = read32();
    final value2 = read32();
    final result = value2.toRadixString(16) + value1.toRadixString(16).padLeft(8, '0');

    return BigInt.parse(result, radix: 16);
  }

  /// Read U128 value from the buffer and shift cursor by 16.
  BigInt read128() {
    final value1 = read64();
    final value2 = read64();
    final result = value2.toRadixString(16) + value1.toRadixString(16).padLeft(8, '0');

    return BigInt.parse(result, radix: 16);
  }

  /// Read `num` number of bytes from the buffer and shift cursor by `num`.
  Uint8List readBytes(int num) {
    int start = _bytePosition + _dataView.offsetInBytes;
    final value = Uint8List.view(_dataView.buffer, start, num);

    shift(num);

    return value;
  }

  /// Read ULEB value - an integer of varying size. Used for enum indexes and
  /// vector lengths.
  int readULEB() {
    int start = _bytePosition + _dataView.offsetInBytes;
    final buffer = Uint8List.view(_dataView.buffer, start);
    List<int> data = ulebDecode(buffer);

    shift(data[1]);

    return data[0];
  }

  /// Read a BCS vector: read a length and then apply function `cb` X times
  /// where X is the length of the vector, defined as ULEB in BCS bytes.
  /// 
  /// Array of the resulting values, returned by callback.
  List<dynamic> readVec(dynamic Function(BcsReader reader, int i, int length) cb) {
    int length = readULEB();
    final result = <dynamic>[];
    for (int i = 0; i < length; i++) {
      result.add(cb(this, i, length));
    }
    return result;
  }
}


/// Class used to write BCS data into a buffer. Initializer requires
/// some size of a buffer to init; default value for this buffer is 1KB.
///
/// Most methods are chainable, so it is possible to write them in one go.
///
/// ```dart
/// final serialized = BcsWriter()
///   .write8(10)
///   .write32(1000000)
///   .write64(10000001000000)
///   .hex();
/// ```
class BcsWriter with Iterator<int> {
  late ByteData _dataView;
  int _bytePosition = 0;

  /// [size=1024] Size of the buffer to reserve for serialization.
  BcsWriter([int size = 1024]) {
    _dataView = ByteData.sublistView(Uint8List(size));
  }

  /// Shift current cursor position by [bytes].
  BcsWriter shift(int bytes) {
    _bytePosition += bytes;
    return this;
  }

  /// Write a U8 value into a buffer and shift cursor position by 1.
  BcsWriter write8(int value) {
    _dataView.setUint8(_bytePosition, value);
    return shift(1);
  }

  /// Write a U16 value into a buffer and shift cursor position by 2.
  BcsWriter write16(int value) {
    _dataView.setUint16(_bytePosition, value, Endian.little);
    return shift(2);
  }

  /// Write a U32 value into a buffer and shift cursor position by 4.
  BcsWriter write32(int value) {
    _dataView.setUint32(_bytePosition, value, Endian.little);
    return shift(4);
  }

  /// Write a U64 value into a buffer and shift cursor position by 8.
  BcsWriter write64(BigInt value) {
    final low = value & BigInt.from(MAX_U32_NUMBER);
    final high = value >> 32;

    // write little endian number
    write32(low.toInt());
    write32(high.toInt());

    return this;
  }

  /// Write a U128 value into a buffer and shift cursor position by 16.
  BcsWriter write128(BigInt value) {
    final low = value & MAX_U64_BIG_INT;
    final high = value >> 64;

    // write little endian number
    write64(low);
    write64(high);

    return this;
  }

  /// Write a ULEB value into a buffer and shift cursor position by number of bytes
  /// written.
  BcsWriter writeULEB(int value) {
    final data = ulebEncode(value);
    for (var item in data) {
      write8(item);
    }
    return this;
  }

  /// Write a vector into a buffer by first writing the vector length and then calling
  /// a callback on each passed value.
  BcsWriter writeVec(
    dynamic vector,
    dynamic Function(BcsWriter writer, dynamic el, int i, int len) cb
  ) {
    writeULEB(vector.length);
    for (int i = 0; i < vector.length; i++) {
      cb(this, vector[i], i, vector.length);
    }
    return this;
  }

  /// Get underlying buffer taking only value bytes (in case initial buffer size was bigger).
  Uint8List toBytes() {
    return Uint8List.sublistView(_dataView, 0, _bytePosition);
  }

  /// Represent data as 'hex' or 'base64'
  String toStringEncoding(String encoding) {
    return encodeStr(toBytes(), encoding);
  }

  String toHexString() {
    return encodeStr(toBytes(), 'hex');
  }

  String toBase64String() {
    return encodeStr(toBytes(), 'base64');
  }

  @override
  int get current => _dataView.getUint8(_bytePosition);

  @override
  bool moveNext() {
    if (_bytePosition >= _dataView.buffer.lengthInBytes) {
      return false;
    }

    shift(1);
    return false;
  }
}

// Helper utility: write number as an ULEB array.
List<int> ulebEncode(int num) {
  final arr = <int>[];
  var len = 0;

  if (num == 0) {
    return [0];
  }

  while (num > 0) {
    arr.add(num & 0x7f);
    if ((num >>= 7) != 0) {
      arr[len] |= 0x80;
    }
    len += 1;
  }

  return arr;
}

// Helper utility: decode ULEB as an array of numbers.
List<int> ulebDecode(Uint8List arr) {
  int total = 0;
  int shift = 0;
  int len = 0;

  while (true) {
    int byte = arr[len];
    len += 1;
    total |= (byte & 0x7f) << shift;
    if ((byte & 0x80) == 0) {
      break;
    }
    shift += 7;
  }

  // [value, length]
  return [total, len];
}

/// Set of methods that allows data encoding/decoding as standalone
/// BCS value or a part of a composed structure/vector.
mixin TypeInterface {
  BcsWriter encode(dynamic data, int size);
  dynamic decode(Uint8List data);

  BcsWriter _encodeRaw(BcsWriter writer, dynamic data);
  dynamic _decodeRaw(BcsReader reader);
}

typedef BcsWriter EncodeCb(BcsWriter writer, dynamic data);
typedef dynamic DecodeCb(BcsReader reader);
typedef bool ValidateCb(dynamic data);

class TypeEncodeDecode with TypeInterface {
  final String name;
  final EncodeCb encodeCb;
  final DecodeCb decodeCb;
  final ValidateCb validateCb;

  TypeEncodeDecode(this.name, this.encodeCb, this.decodeCb, this.validateCb);

  @override
  BcsWriter encode(data, [int size = 1024]) {
    return _encodeRaw(BcsWriter(size), data);
  }

  @override
  dynamic decode(data) {
    return _decodeRaw(BcsReader(data));
  }

  // these methods should always be used with caution as they require pre-defined
  // reader and writer and mainly exist to allow multi-field (de)serialization;
  @override
  BcsWriter _encodeRaw(writer, data) {
    if (validateCb(data)) {
      return encodeCb(writer, data);
    } else {
      throw ArgumentError("Validation failed for type $name, data: $data");
    }
  }

  @override
  dynamic _decodeRaw(reader) {
    return decodeCb(reader);
  }

}

 /// BCS implementation for Move types and few additional built-ins.
 class BCS {
  // Prefefined types constants
  static const String U8 = 'u8';
  static const String U32 = 'u32';
  static const String U64 = 'u64';
  static const String U128 = 'u128';
  static const String BOOL = 'bool';
  static const String VECTOR = 'vector';
  static const String ADDRESS = 'address';
  static const String STRING = 'string';

  static var _hasRegisterPrimitives = false;

  static final Map<String, TypeInterface> _types = {};

  static Map<String, TypeInterface> get types {
    if (!_hasRegisterPrimitives) {
      registerPrimitives();
      _hasRegisterPrimitives = true;
    }
    return _types;
  }

  /// Serialize data into bcs.
  ///
  /// ```dart
  /// BCS.registerVectorType('vector<u8>', 'u8');
  ///
  /// final serialized = BCS
  ///   .set('vector<u8>', [1,2,3,4,5,6])
  ///   .toBytes();
  ///
  /// assert(Hex.encode(serialized) === '06010203040506');
  /// ```
  static BcsWriter ser(String type, dynamic data, [int size = 1024]) {
    return getTypeInterface(type).encode(data, size);
  }

  /// Deserialize BCS into a Dart type.
  ///
  /// ```dart
  /// final num = BCS.ser('u64', '4294967295').toHexString();
  /// final deNum = BCS.de('u64', num, 'hex');
  /// assert(deNum.toString() === '4294967295');
  ///```
  static dynamic de(
    String type,
    dynamic data,
    [String? encoding]
  ) {
    if (data is String) {
      if (encoding != null) {
        data = decodeStr(data, encoding);
      } else {
        throw ArgumentError('To pass a string to `bcs.de`, specify encoding');
      }
    }

    return getTypeInterface(type).decode(data);
  }

  /// Check whether a TypeInterface has been loaded for the `Type`
  static bool hasType(String type) {
    return types.containsKey(type);
  }

  /// Method to register new types for BCS internal representation.
  /// For each registered type 2 callbacks must be specified and one is optional:
  ///
  /// - encodeCb(writer, data) - write a way to serialize data with BcsWriter;
  /// - decodeCb(reader) - write a way to deserialize data with BcsReader;
  /// - validateCb(data) - validate data - either return bool or throw an error
  ///
  /// ```dart
  /// // our type would be a string that consists only of numbers
  /// BCS.registerType('number_string',
  ///    (writer, data) => writer.writeVec(data, (w, el, _a, _b) => w.write8(el)),
  ///    (reader) => reader.readVec((r, _a, _b) => r.read8()).join(''), // read each value as u8
  ///    (value) => RegExp(r'[0-9]+').hasMatch(value) // test that it has at least one digit
  /// );
  /// print(Hex.encode(BCS.ser('number_string', '12345').toBytes()) == Hex.encode([5,1,2,3,4,5]));
  /// ```
  static void registerType(
    String name,
    EncodeCb encodeCb,
    DecodeCb decodeCb,
    [ValidateCb? validateCb]
  ) {
    validateCb ??= (data) => true;

    _types[name] = TypeEncodeDecode(name, encodeCb, decodeCb, validateCb);
  }

  /// Register an address type which is a sequence of U8s of specified length.
  /// ```dart
  /// BCS.registerAddressType('address', 20);
  /// final addr = BCS.de('address', 'ca27601ec5d915dd40d42e36c395d4a156b24026');
  /// ```
  static registerAddressType(
    String name,
    int length,
    [String encoding = 'hex']
  ) {
    switch (encoding) {
      case 'base64':
        return registerType(
          name,
          (writer, data) {
            base64Decode(data).forEach((element) {
              writer.write8(element);
            });
            return writer;
          },
          (reader) => base64Encode(reader.readBytes(length))
        );
      case 'hex':
        return registerType(
          name,
          (writer, data) {
            Hex.decode(data).forEach((element) {
              writer.write8(element);
            });
            return writer;
          },
          (reader) => Hex.encode(reader.readBytes(length))
        );
      default:
        throw ArgumentError('Unsupported encoding! Use either hex or base64');
    }
  }

  /// Register custom vector type inside the BCS.
  ///
  /// ```dart
  /// BCS.registerVectorType('vector<u8>', 'u8');
  /// final array = BCS.de('vector<u8>', '06010203040506', 'hex'); // [1,2,3,4,5,6];
  /// final again = BCS.ser('vector<u8>', [1,2,3,4,5,6]).toHexString();
  /// ```
  static registerVectorType(
    String name,
    String elementType
  ) {
    return registerType(
      name,
      (writer, data) =>
        writer.writeVec(data, (writer, el, a, b) {
          return BCS.getTypeInterface(elementType)._encodeRaw(writer, el);
        }),
      (reader) =>
        reader.readVec((reader, a, b) {
          return BCS.getTypeInterface(elementType)._decodeRaw(reader);
        })
    );
  }

  /// Safe method to register a custom Move struct. The first argument is a name of the
  /// struct which is only used on the FrontEnd and has no affect on serialization results,
  /// and the second is a struct description passed as an Object.
  ///
  /// The description object MUST have the same order on all of the platforms (ie in Move
  /// or in Rust).
  ///
  /// ```
  /// // Move / Rust struct
  /// // struct Coin {
  /// //   value: u64,
  /// //   owner: vector<u8>, // name // Vec<u8> in Rust
  /// //   is_locked: bool,
  /// // }
  /// ```
  ///
  /// ```dart
  /// BCS.registerStructType('Coin', {
  ///   'value': BCS.U64,
  ///   'owner': BCS.STRING,
  ///   'is_locked': BCS.BOOL
  /// });
  ///
  /// // Created in Rust with diem/bcs
  /// // final rust_bcs_str = '80d1b105600000000e4269672057616c6c65742047757900';
  /// final rust_bcs_str = [ // using an Array here as BCS works with Uint8Array
  ///  128, 209, 177,   5,  96,  0,  0,
  ///    0,  14,  66, 105, 103, 32, 87,
  ///   97, 108, 108, 101, 116, 32, 71,
  ///  117, 121,   0
  /// ];
  ///
  /// // Let's encode the value as well
  /// final test_set = BCS.ser('Coin', {
  ///   'owner': 'Big Wallet Guy',
  ///   'value': '412412400000',
  ///   'is_locked': false,
  /// });
  ///
  /// assert(Hex.encode(test_set.toBytes()) == Hex.encode(rust_bcs_str), 'Whoopsie, result mismatch');
  /// ```
  static registerStructType(
    String name,
    Map<String, String> fields
  ) {
    // Make sure the order doesn't get changed
    final struct = Map.of(fields);

    // IMPORTANT: we need to store canonical order of fields for each registered
    // struct so we maintain it and allow developers to use any field ordering in
    // their code (and not cause mismatches based on field order).
    var canonicalOrderKeys = struct.keys;

    // Make sure all the types in the fields description are already known
    // and that all the field types are strings.
    return registerType(
      name,
      (writer, data) {
        if (data == null) {
          throw ArgumentError("Expected $name to be an Object, got: $data");
        }

        for (var key in canonicalOrderKeys.toList()) {
          if (data[key] != null) {
            BCS.getTypeInterface(struct[key]!)._encodeRaw(writer, data[key]);
          } else {
            throw ArgumentError(
              "Struct $name requires field $key:${struct[key]}"
            );
          }
        }
        return writer;
      },
      (reader) {
        final result = <String, dynamic>{};
        for (var key in canonicalOrderKeys.toList()) {
          result[key] = BCS.getTypeInterface(struct[key]!)._decodeRaw(reader);
        }
        return result;
      }
    );
  }

  /// Safe method to register custom enum type where each invariant holds the value of another type.
  /// ```dart
  /// BCS.registerStructType('Coin', { 'value': 'u64' });
  /// BCS.registerVectorType('vector<Coin>', 'Coin');
  /// BCS.registerEnumType('MyEnum', {
  ///  'single': 'Coin',
  ///  'multi': 'vector<Coin>'
  /// });
  ///
  /// print(BCS.de('MyEnum', 'AICWmAAAAAAA', 'base64')); // { single: { value: 10000000 } }
  /// print(BCS.de('MyEnum', 'AQIBAAAAAAAAAAIAAAAAAAAA', 'base64'));  // { multi: [ { value: 1 }, { value: 2 } ] }
  ///
  /// // and serialization
  /// BCS.ser('MyEnum', { 'single': { 'value': 10000000 } }).toBytes();
  /// BCS.ser('MyEnum', { 'multi': [ { 'value': 1 }, { 'value': 2 } ] });
  /// ```
  static registerEnumType(
    String name,
    Map<String, dynamic> variants
  ) {
    // Make sure the order doesn't get changed
    final struct = Map<String, dynamic>.from(variants);

    // IMPORTANT: enum is an ordered type and we have to preserve ordering in BCS
    var canonicalOrderKeys = struct.keys;

    return registerType(
      name,
      (writer, data) {
        if (data == null) {
          throw ArgumentError("Unable to write enum $name, missing data");
        }

        if ((data as Map<String, dynamic>).isEmpty) {
          throw ArgumentError("Unknown invariant of the enum $name");
        }

        String key = data.keys.first;
        List<String> canonicalOrder = canonicalOrderKeys.toList();
        int orderByte = canonicalOrder.indexOf(key);
        if (orderByte == -1) {
          throw ArgumentError(
            "Unknown invariant of the enum $name, allowed values: $canonicalOrder"
          );
        }
        String invariant = canonicalOrder[orderByte];
        String? invariantType = struct[invariant];

        writer.write8(orderByte); // write order byte

        // Allow empty Enum values!
        return invariantType != null
          ? BCS.getTypeInterface(invariantType)._encodeRaw(writer, data[key])
          : writer;
      },
      (reader) {
        int orderByte = reader.readULEB();
        List<String> canonicalOrder = canonicalOrderKeys.toList();
        String invariant = canonicalOrder[orderByte];
        String? invariantType = struct[invariant];

        if (orderByte == -1) {
          throw ArgumentError(
            "Decoding type mismatch, expected enum $name invariant index, received $orderByte"
          );
        }

        return {
          [invariant]:
            invariantType != null
              ? BCS.getTypeInterface(invariantType)._decodeRaw(reader)
              : true,
        };
      }
    );
  }

  /// Get a set of encoders/decoders for specific type.
  /// Mainly used to define custom type de/serialization logic.
  static TypeInterface getTypeInterface(String type) {
    final typeInterface = BCS.types[type];
    if (typeInterface == null) {
      throw ArgumentError("Type $type is not registered");
    }
    return typeInterface;
  }
}

/// Encode [data] with either `hex` or `base64`.
String encodeStr(Uint8List data, String encoding) {
  switch (encoding) {
    case 'base64':
      return base64Encode(data);
    case 'hex':
      return Hex.encode(data);
    default:
      throw ArgumentError('Unsupported encoding, supported values are: base64, hex');
  }
}

/// Decode [data] either `base64` or `hex` data.
Uint8List decodeStr(String data, String encoding) {
  switch (encoding) {
    case 'base64':
      return base64Decode(data);
    case 'hex':
      return Hex.decode(data);
    default:
      throw ArgumentError('Unsupported encoding, supported values are: base64, hex');
  }
}

/// Unify argument types by converting them to BigInt.
BigInt toBN(dynamic number) {
  if (number is bool) {
    return number ? BigInt.one : BigInt.zero;
  } else if (number is int) {
    return BigInt.from(number);
  } else if (number is BigInt) {
    return number;
  } else {
    return BigInt.parse(number);
  }
}

void registerPrimitives() {
  BCS.registerType(
    BCS.U8,
    (BcsWriter writer, dynamic data) => writer.write8(data),
    (BcsReader reader) => reader.read8(),
    (u8) => toBN(u8) <= BigInt.from(MAX_U8_NUMBER)
  );

  BCS.registerType(
    BCS.U32,
    (BcsWriter writer, dynamic data) => writer.write32(data),
    (BcsReader reader) => reader.read32(),
    (u32) => toBN(u32) <= BigInt.from(MAX_U32_NUMBER)
  );

  BCS.registerType(
    BCS.U64,
    (BcsWriter writer, dynamic data) => writer.write64(BigInt.parse(data.toString())),
    (BcsReader reader) => reader.read64(),
    (_u64) => toBN(_u64) <= MAX_U64_BIG_INT
  );

  BCS.registerType(
    BCS.U128,
    (BcsWriter writer, dynamic data) => writer.write128(BigInt.parse(data.toString())),
    (BcsReader reader) => reader.read128(),
    (_u128) => toBN(_u128) <= MAX_U128_BIG_INT
  );

  BCS.registerType(
    BCS.BOOL,
    (BcsWriter writer, dynamic data) => writer.write8(data ? 1 : 0),
    (BcsReader reader) => reader.read8() == BigInt.one,
    (_bool) => true
  );

  BCS.registerType(
    BCS.STRING,
    (writer, data) =>
      writer.writeVec(data, (writer, el, a, b) {
        writer.write8(utf8.encode(el)[0]);
      }),
    (BcsReader reader) {
      final data = reader
        .readVec((reader, a, b) => reader.read8())
        .map<int>((item) => item.toInt()).toList();
      return utf8.decode(data);
    },
    (_str) => true
  );
}