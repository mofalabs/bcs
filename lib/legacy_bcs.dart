/// BCS implementation https://github.com/diem/bcs

import 'dart:convert';
import 'dart:typed_data';

import 'package:bcs/index.dart';
import 'package:bcs/consts.dart';
import 'package:bcs/reader.dart';
import 'package:bcs/utils.dart';
import 'package:bcs/writer.dart';
import 'package:flutter/foundation.dart';

const SUI_ADDRESS_LENGTH = 32;

/// Allows for array definitions for names.
/// ```dart
/// bcs.registerStructType(['vector', BCS.STRING], ...);
/// // equals
/// bcs.registerStructType('vector<string>', ...);
/// ```
typedef TypeName = dynamic;

/// Set of methods that allows data encoding/decoding as standalone
/// BCS value or a part of a composed structure/vector.
mixin TypeInterface {
  BcsWriter encode(dynamic data, BcsWriterOptions? options, List<TypeName> typeParams);
  dynamic decode(Uint8List data, List<TypeName> typeParams);

  BcsWriter encodeRaw(BcsWriter writer, dynamic data, List<TypeName> typeParams, Map<String, TypeName> typeMap);
  dynamic decodeRaw(BcsReader reader, List<TypeName> typeParams, Map<String, TypeName> typeMap);
}

typedef BcsWriter EncodeCb(BcsWriter writer, dynamic data, List<TypeName> typeParams, Map<String, TypeName> typeMap);
typedef dynamic DecodeCb(BcsReader reader, List<TypeName> typeParams, Map<String, TypeName> typeMap);
typedef bool ValidateCb(dynamic data);

class TypeEncodeDecode with TypeInterface {
  final LegacyBCS bcs;
  final List<dynamic> generics;
  final EncodeCb encodeCb;
  final DecodeCb decodeCb;
  final ValidateCb validateCb;

  TypeEncodeDecode(this.bcs, this.generics, this.encodeCb, this.decodeCb, this.validateCb);

  @override
  BcsWriter encode(data, options, typeParams) {
    final typeMap = <String, dynamic>{};
    for (var i = 0; i < generics.length; i++) {
      typeMap[generics[i]] = typeParams[i];
    }

    final bcsWriter = BcsWriter(
      size: options?.size ?? 4096, 
      maxSize: options?.maxSize, 
      allocateSize: options?.allocateSize ?? 1024);
    return encodeRaw(bcsWriter, data, typeParams, typeMap);
  }

  @override
  dynamic decode(data, typeParams) {
    final typeMap = <String, dynamic>{};
    for (var i = 0; i < generics.length; i++) {
      typeMap[generics[i]] = typeParams[i];
    }

    return decodeRaw(BcsReader(data), typeParams, typeMap);
  }

  // these methods should always be used with caution as they require pre-defined
  // reader and writer and mainly exist to allow multi-field (de)serialization;
  @override
  BcsWriter encodeRaw(writer, data, typeParams, typeMap) {
    if (validateCb(data)) {
      return encodeCb(writer, data, typeParams, typeMap);
    } else {
      throw ArgumentError("Validation failed for data: $data");
    }
  }

  @override
  dynamic decodeRaw(reader, typeParams, typeMap) {
    return decodeCb(reader, typeParams, typeMap);
  }

}

/// Struct type definition. Used as input format in BcsConfig.types
/// as well as an argument type for `bcs.registerStructType`.
typedef StructTypeDefinition = Map<String, dynamic>;

/// Enum type definition. Used as input format in BcsConfig.types
/// as well as an argument type for `bcs.registerEnumType`.
///
/// Value can be either `string` when invariant has a type or `null`
/// when invariant is empty.
///
/// ```dart
/// bcs.registerEnumType('Option<T>', {
///   'some': 'T',
///   'none': null
/// });
/// ```
typedef EnumTypeDefinition = Map<String, dynamic>;

class BcsConfigTypes {
  Map<String, StructTypeDefinition>? structs;
  Map<String, EnumTypeDefinition>? enums;
  Map<String, String>? aliases;

  BcsConfigTypes({this.structs, this.enums, this.aliases});
}

/// Configuration that is passed into BCS constructor.
class BcsConfig {
  /// Defines type name for the vector / array type.
  /// In Move: `vector<T>` or `vector`.
  String vectorType;

  String? fixedArrayType;

  /// Address length. Varies depending on a platform and
  /// has to be specified for the `address` type.
  int addressLength;

  /// Custom encoding for address. Supported values are
  /// either 'hex' or 'base64'.
  Encoding? addressEncoding;

  /// Opening and closing symbol for type parameters. Can be
  /// any pair of symbols (eg `['(', ')']`); default value follows
  /// Rust and Move: `<` and `>`.
  (String, String)? genericSeparators;

  /// Type definitions for the BCS. This field allows spawning
  /// BCS instance from JSON or another prepared configuration.
  /// Optional.
  BcsConfigTypes? types;

  /// Whether to auto-register primitive types on launch.
  bool? withPrimitives;

  BcsConfig({
    required this.vectorType,
    required this.addressLength,
    this.fixedArrayType,
    this.addressEncoding,
    this.genericSeparators,
    this.types,
    this.withPrimitives
  });
}

/// BCS implementation for Move types and few additional built-ins.
class LegacyBCS {
  // Prefefined types constants
  static const String U8 = 'u8';
  static const String U16 = 'u16';
  static const String U32 = 'u32';
  static const String U64 = 'u64';
  static const String U128 = 'u128';
  static const String U256 = 'u256';
  static const String BOOL = 'bool';
  static const String VECTOR = 'vector';
  static const String FixedArray = 'array';
  static const String ADDRESS = 'address';
  static const String STRING = 'string';
  static const String HEX = "hex-string";
  static const String BASE58 = "base58-string";
  static const String BASE64 = "base64-string";

  /// Map of kind `TypeName => TypeInterface`. Holds all
  /// callbacks for (de)serialization of every registered type.
  ///
  /// If the value stored is a string, it is treated as an alias.
  Map<String, dynamic> types = {};

  /// Stored BcsConfig for the current instance of BCS.
  late BcsConfig schema;

  /// Count temp keys to generate a new one when requested.
  int counter = 0;

  /// Name of the key to use for temporary struct definitions.
  /// Returns a temp key + index (for a case when multiple temp
  /// structs are processed).
  String tempKey() {
    return "bcs-struct-${++counter}";
  }

  factory LegacyBCS.fromBCS(LegacyBCS bcs) {
    final tmp = LegacyBCS._();
    tmp.schema = bcs.schema;
    tmp.types = Map.of(bcs.types);
    return tmp;
  }

  LegacyBCS._();

  /// Construct a BCS instance with a prepared schema.
  LegacyBCS(BcsConfig scheme) {
    schema = scheme;

    // Register address type under key 'address'.
    registerAddressType(
      LegacyBCS.ADDRESS,
      schema.addressLength,
      schema.addressEncoding ?? Encoding.hex
    );
    registerVectorType(schema.vectorType);

    if (schema.fixedArrayType != null) {
      registerFixedArrayType(schema.fixedArrayType!);
    }

    // Register struct types if they were passed.
    if (schema.types?.structs != null) {
      for (var item in schema.types!.structs!.entries) {
        registerStructType(item.key, item.value);
      }
    }

    // Register enum types if they were passed.
    if (schema.types?.enums != null) {
      for (var item in schema.types!.enums!.entries) {
        registerEnumType(item.key, item.value);
      }
    }

    // Register aliases if they were passed.
    if (schema.types?.aliases != null) {
      for (var item in schema.types!.aliases!.entries) {
        registerAlias(item.key, item.value);
      }
    }

    if (schema.withPrimitives != false) {
      registerPrimitives(this);
    }
  }

  /// Serialize data into bcs.
  ///
  /// ```dart
  /// bcs.registerVectorType('vector<u8>');
  /// 
  /// final serialized = bcs
  ///   .ser('vector<u8>', [1,2,3,4,5,6])
  ///   .toBytes();
  /// 
  /// expect(toHEX(serialized), '06010203040506');
  /// ```
  BcsWriter ser(
    dynamic type,
    dynamic data,
    [BcsWriterOptions? options]
  ) {
    if (type is String || type is Iterable) {
      final (name, params) = parseTypeName(type);
      return getTypeInterface(name).encode(
        data,
        options,
        params
      );
    }

    // Quick serialization without registering the type in the main struct.
    if (type is StructTypeDefinition) {
      final key = tempKey();
      final temp = LegacyBCS.fromBCS(this);
      return temp.registerStructType(key, type).ser(key, data, options);
    }

    throw ArgumentError(
      "Incorrect type passed into the '.ser()' function. \n${jsonEncode(type)}"
    );
  }

  /// Deserialize BCS into a Dart type.
  ///```dart
  /// final num = bcs.ser('u64', '4294967295').hex();
  /// final deNum = bcs.de('u64', num, Encoding.hex);
  /// expect(deNum.toString(), '4294967295');
  ///```
  dynamic de(
    dynamic type,
    dynamic data,
    [Encoding? encoding]
  ) {
    if (data is String) {
      if (encoding != null) {
        data = decodeStr(data, encoding);
      } else {
        throw ArgumentError("To pass a string to `bcs.de`, specify encoding");
      }
    }

    // In case the type specified is already registered.
    if (type is String || type is Iterable) {
      final (name, params) = parseTypeName(type);
      return getTypeInterface(name).decode(data, params);
    }

    // Deserialize without registering a type using a temporary clone.
    if (type is StructTypeDefinition) {
      final temp = LegacyBCS.fromBCS(this);
      final key = tempKey();
      return temp.registerStructType(key, type).de(key, data, encoding);
    }

    throw ArgumentError(
      "Incorrect type passed into the '.de()' function. \n${jsonDecode(type)}"
    );
  }

  /// Check whether a `TypeInterface` has been loaded for a `type`.
  bool hasType(String type) {
    return types.containsKey(type);
  }

  /// Create an alias for a type.
  /// WARNING: this can potentially lead to recursion
  ///
  /// ```dart
  /// final bcs = BCS(getSuiMoveConfig());
  /// bcs.registerAlias('ObjectDigest', BCS.BASE58);
  /// final b58_digest = bcs.de('ObjectDigest', '<digest_bytes>', Encoding.base64);
  /// ```
  LegacyBCS registerAlias(String name, String forType) {
    types[name] = forType;
    return this;
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
  /// bcs.registerType('number_string',
  ///     (writer, data, _, __) => writer.writeVec(data, (w, el, _, __) => w.write8(int.parse(el.toString()))),
  ///     (reader, _, __) => reader.readVec((r, _, __) => r.read8()).join(''), // read each value as u8
  ///     (value) => RegExp("[0-9]+").hasMatch(value) // test that it has at least one digit
  /// );
  /// expect(bcs.ser('number_string', '12345').toBytes(), [5,1,2,3,4,5]);
  /// ```
  LegacyBCS registerType(
    TypeName typeName,
    EncodeCb encodeCb,
    DecodeCb decodeCb,
    [ValidateCb? validateCb]
  ) {
    validateCb ??= (data) => true;

    final (name, generics) = parseTypeName(typeName);

    types[name] = TypeEncodeDecode(this, generics, encodeCb, decodeCb, validateCb);

    return this;
  }

  /// Register an address type which is a sequence of U8s of specified length.
  /// ```dart
  /// bcs.registerAddressType('address', SUI_ADDRESS_LENGTH);
  /// final addr = bcs.de('address', 'c3aca510c785c7094ac99aeaa1e69d493122444df50bb8a99dfa790c654a79af', Encoding.hex);
  /// ```
  LegacyBCS registerAddressType(
    String name,
    int length,
    [Encoding encoding = Encoding.hex]
  ) {

    switch (encoding) {
      case Encoding.base64:
        return registerType(
          name,
          (writer, data, _, __) { 
            fromB64(data).forEach((el) => writer.write8(el));
            return writer;
          },
          (reader, _, __) => toB64(reader.readBytes(length))
        );
      case Encoding.hex:
        return registerType(
          name,
          (writer, data, _, __) { 
            fromHEX(data).forEach((el) => writer.write8(el));
            return writer;
          },
          (reader, _, __) => toHEX(reader.readBytes(length))
        );
      default:
        throw ArgumentError("Unsupported encoding! Use either hex or base64");
    }
  }

  /// Register custom vector type inside the bcs.
  ///
  /// ```dart
  /// bcs.registerVectorType('vector<T>'); // generic registration
  /// final array = bcs.de('vector<u8>', '06010203040506', Encoding.hex); // [1,2,3,4,5,6];
  /// final again = bcs.ser('vector<u8>', [1,2,3,4,5,6]).hex();
  /// ```
  LegacyBCS registerVectorType(String typeName) {
    final (name, params) = parseTypeName(typeName);
    if (params.length > 1) {
      throw ArgumentError("Vector can have only one type parameter; got " + name);
    }

    return registerType(
      typeName,
      (writer, data, typeParams, typeMap) {
        return writer.writeVec(data, (writer, el, _, __) {
          if (typeParams.isEmpty) {
            throw ArgumentError(
              "Incorrect number of type parameters passed a to vector '$typeName'"
            );
          }

          final elementType = typeParams[0];
          final (name, params) = parseTypeName(elementType);
          if (hasType(name)) {
            return getTypeInterface(name).encodeRaw(
              writer,
              el,
              params,
              typeMap
            );
          }

          if (!(typeMap.containsKey(name))) {
            throw ArgumentError(
              "Unable to find a matching type definition for $name in vector; make sure you passed a generic"
            );
          }

          final (innerName, innerParams) = parseTypeName(
            typeMap[name]
          );

          return getTypeInterface(innerName).encodeRaw(
            writer,
            el,
            innerParams,
            typeMap
          );
        });
      },
      (reader, typeParams, typeMap) { 
        return reader.readVec((reader, _, __) {
          if (typeParams.isEmpty) {
            throw ArgumentError(
              "Incorrect number of type parameters passed to a vector '$typeName'"
            );
          }

          final elementType = typeParams[0];
          final (name, params) = parseTypeName(elementType);
          if (hasType(name)) {
            return getTypeInterface(name).decodeRaw(
              reader,
              params,
              typeMap
            );
          }

          if (!(typeMap.containsKey(name))) {
            throw ArgumentError(
              "Unable to find a matching type definition for $name in vector; make sure you passed a generic"
            );
          }

          final (innerName, innerParams) = parseTypeName(
            typeMap[name]
          );
          getTypeInterface(innerName).decodeRaw(
            reader,
            innerParams,
            typeMap
          );
        });
      }
    );
  }

  /// Register custom fixed array type inside the bcs.
  ///
  /// ```dart
  /// bcs.registerFixedArrayType('array<T>'); // generic registration
  /// final array = bcs.de('array<u8, 6>', '06010203040506', Encoding.hex); // [1,2,3,4,5,6];
  /// final again = bcs.ser('array<u8>', [1,2,3,4,5,6]).hex();
  /// ```
  LegacyBCS registerFixedArrayType(String typeName) {
    final (name, params) = parseTypeName(typeName);
    if (params.length > 1) {
      throw ArgumentError("Vector can have only one type parameter; got " + name);
    }

    return registerType(
      typeName,
      (writer, data, typeParams, typeMap) {
        int? size = typeParams.length > 1 ? int.parse(typeParams[1].toString()) : null;
        return writer.writeFixedArray(data, size, (writer, el, _, __) {
          if (typeParams.isEmpty) {
            throw ArgumentError(
              "Incorrect number of type parameters passed a to vector '$typeName'"
            );
          }

          final elementType = typeParams[0];
          final (name, params) = parseTypeName(elementType);
          if (hasType(name)) {
            return getTypeInterface(name).encodeRaw(
              writer,
              el,
              params,
              typeMap
            );
          }

          if (!(typeMap.containsKey(name))) {
            throw ArgumentError(
              "Unable to find a matching type definition for $name in vector; make sure you passed a generic"
            );
          }

          final (innerName, innerParams) = parseTypeName(
            typeMap[name]
          );

          return getTypeInterface(innerName).encodeRaw(
            writer,
            el,
            innerParams,
            typeMap
          );
        });
      },
      (reader, typeParams, typeMap) { 
        final size = int.parse(typeParams[1].toString());
        return reader.readFixedArray(size, (reader, _, __) {
          if (typeParams.isEmpty) {
            throw ArgumentError(
              "Incorrect number of type parameters passed to a vector '$typeName'"
            );
          }

          final elementType = typeParams[0];
          final (name, params) = parseTypeName(elementType);
          if (hasType(name)) {
            return getTypeInterface(name).decodeRaw(
              reader,
              params,
              typeMap
            );
          }

          if (!(typeMap.containsKey(name))) {
            throw ArgumentError(
              "Unable to find a matching type definition for $name in vector; make sure you passed a generic"
            );
          }

          final (innerName, innerParams) = parseTypeName(
            typeMap[name]
          );
          getTypeInterface(innerName).decodeRaw(
            reader,
            innerParams,
            typeMap
          );
        });
      }
    );
  }

  /// Safe method to register a custom Move struct. The first argument is a name of the
  /// struct which is only used on the FrontEnd and has no affect on serialization results,
  /// and the second is a struct description passed as an Object.
  ///
  /// The description object MUST have the same order on all of the platforms (ie in Move
  /// or in Rust).
  ///
  /// ```dart
  /// // Move / Rust struct
  /// // struct Coin {
  /// //   value: u64,
  /// //   owner: vector<u8>, // name // Vec<u8> in Rust
  /// //   is_locked: bool,
  /// // }
  ///
  /// bcs.registerStructType('Coin', {
  ///   'value': BCS.U64,
  ///   'owner': BCS.STRING,
  ///   'is_locked': BCS.BOOL
  /// });
  ///
  /// // Created in Rust with diem/bcs
  /// // const rust_bcs_str = '80d1b105600000000e4269672057616c6c65742047757900';
  /// final rust_bcs_str = [ // using an Array here as BCS works with Uint8List
  ///  128, 209, 177,   5,  96,  0,  0,
  ///    0,  14,  66, 105, 103, 32, 87,
  ///   97, 108, 108, 101, 116, 32, 71,
  ///  117, 121,   0
  /// ];
  ///
  /// // Let's encode the value as well
  /// final test_set = bcs.ser('Coin', {
  ///   'owner': 'Big Wallet Guy',
  ///   'value': '412412400000',
  ///   'is_locked': false,
  /// });
  ///
  /// expect(test_set.toBytes(), rust_bcs_str);
  /// ```
  LegacyBCS registerStructType(
    TypeName typeName,
    StructTypeDefinition fields
  ) {
    // When an Object is passed, we register it under a new key and store it
    // in the registered type system. This way we allow nested inline definitions.
    final fieldsTmp = <String, dynamic>{}; // fix dynamic change value type of Map
    for (final key in fields.keys) {
      final internalName = tempKey();
      final value = fields[key];

      // TODO: add a type guard here?
      if (value is! String && value is! Iterable) {
        fieldsTmp[key] = internalName;
        registerStructType(internalName, value as StructTypeDefinition);
      } else {
        fieldsTmp[key] = value;
      }
    }
    fields = fieldsTmp;

    // Make sure the order doesn't get changed
    final struct = Map<String, dynamic>.from(fields);

    // IMPORTANT: we need to store canonical order of fields for each registered
    // struct so we maintain it and allow developers to use any field ordering in
    // their code (and not cause mismatches based on field order).
    final canonicalOrder = struct.keys;

    // Holds generics for the struct definition. At this stage we can check that
    // generic parameter matches the one defined in the struct.
    final (structName, generics) = parseTypeName(typeName);

    // Make sure all the types in the fields description are already known
    // and that all the field types are strings.
    return registerType(
      typeName,
      (writer, data, typeParams, typeMap) {
        if (data == null) {
          throw ArgumentError(
            "Expected $structName to be an Object, got: $data"
          );
        }

        if (typeParams.length != generics.length) {
          throw ArgumentError(
            "Incorrect number of generic parameters passed; expected: ${generics.length}, got: ${typeParams.length}"
          );
        }

        if (data is! Map) {
          data = data.toJson();
        }

        // follow the canonical order when serializing
        for (String key in canonicalOrder) {
          if (!data.containsKey(key)) {
            throw Exception('Struct $structName requires field $key:${data[key]}');
          }

          // Before deserializing, read the canonical field type.
          final (fieldType, fieldParams) = parseTypeName(
            struct[key] as TypeName
          );

          // Check whether this type is a generic defined in this struct.
          // If it is -> read the type parameter matching its index.
          // If not - tread as a regular field.
          if (!generics.contains(fieldType)) {
            getTypeInterface(fieldType).encodeRaw(
              writer,
              data[key],
              fieldParams,
              typeMap
            );
          } else {
            final paramIdx = generics.indexOf(fieldType);
            final (name, params) = parseTypeName(typeParams[paramIdx]);

            // If the type from the type parameters already exists
            // and known -> proceed with type decoding.
            if (hasType(name)) {
              getTypeInterface(name).encodeRaw(
                writer,
                data[key],
                params,
                typeMap
              );
              continue;
            }

            // Alternatively, if it's a global generic parameter...
            if (!(typeMap.containsKey(name))) {
              throw ArgumentError(
                "Unable to find a matching type definition for ${name} in ${structName}; make sure you passed a generic"
              );
            }

            final (innerName, innerParams) = parseTypeName(
              typeMap[name]
            );
            getTypeInterface(innerName).encodeRaw(
              writer,
              data[key],
              innerParams,
              typeMap
            );
          }
        }
        return writer;
      },
      (reader, typeParams, typeMap) {
        if (typeParams.length != generics.length) {
          throw ArgumentError(
            "Incorrect number of generic parameters passed; expected: ${generics.length}, got: ${typeParams.length}"
          );
        }

        final result = <String, dynamic>{};
        for (String key in canonicalOrder) {
          final(fieldName, fieldParams) = parseTypeName(
            struct[key] as TypeName
          );

          // if it's not a generic
          if (!generics.contains(fieldName)) {
            result[key] = getTypeInterface(fieldName).decodeRaw(
              reader,
              fieldParams,
              typeMap
            );
          } else {
            final paramIdx = generics.indexOf(fieldName);
            final (name, params) = parseTypeName(typeParams[paramIdx]);

            // If the type from the type parameters already exists
            // and known -> proceed with type decoding.
            if (hasType(name)) {
              result[key] = getTypeInterface(name).decodeRaw(
                reader,
                params,
                typeMap
              );
              continue;
            }

            if (!(typeMap.containsKey(name))) {
              throw ArgumentError(
                "Unable to find a matching type definition for ${name} in ${structName}; make sure you passed a generic"
              );
            }

            final (innerName, innerParams) = parseTypeName(
              typeMap[name]
            );
            result[key] = getTypeInterface(innerName).decodeRaw.call(
              reader,
              innerParams,
              typeMap
            );
          }
        }
        return result;
      }
    );
  }

  /// Safe method to register custom enum type where each invariant holds the value of another type.
  /// ```dart
  /// bcs.registerStructType('Coin', { 'value': 'u64' });
  /// bcs.registerEnumType('MyEnum', {
  ///  'single': 'Coin',
  ///  'multi': 'vector<Coin>',
  ///  'empty': null
  /// });
  ///
  /// bcs.de('MyEnum', 'AICWmAAAAAAA', 'base64'), // { single: { value: 10000000 } }
  /// bcs.de('MyEnum', 'AQIBAAAAAAAAAAIAAAAAAAAA', 'base64')  // { multi: [ { value: 1 }, { value: 2 } ] }
  ///
  /// // and serialization
  /// bcs.ser('MyEnum', { 'single': { 'value': 10000000 } }).toBytes();
  /// bcs.ser('MyEnum', { 'multi': [ { 'value': 1 }, { 'value': 2 } ] });
  /// ```
  LegacyBCS registerEnumType(
    TypeName typeName,
    EnumTypeDefinition variants
  ) {
    // When an Object is passed, we register it under a new key and store it
    // in the registered type system. This way we allow nested inline definitions.
    for (final key in variants.keys) {
      final internalName = tempKey();
      final value = variants[key];

      if (
        value != null &&
        (value is! Iterable) &&
        value is! String
      ) {
        variants[key] = internalName;
        registerStructType(internalName, value as StructTypeDefinition);
      }

    }

    // Make sure the order doesn't get changed
    final struct = Map<String, dynamic>.from(variants);

    // IMPORTANT: enum is an ordered type and we have to preserve ordering in BCS
    var canonicalOrder = struct.keys;

    // Parse type parameters in advance to know the index of each generic parameter.
    final (name, canonicalTypeParams) = parseTypeName(typeName);

    return registerType(
      typeName,
      (writer, data, typeParams, typeMap) {
        if (data == null) {
          throw ArgumentError(
            'Unable to write enum "$name", missing data.\nReceived: "$data'
          );
        }
        if (data is! Map) {
          throw ArgumentError(
            'Incorrect data passed into enum "$name", expected object with properties: "${canonicalOrder.join(
              " | "
            )}".\nReceived: "${jsonEncode(data)}"'
          );
        }
        
        if (data.isEmpty) {
          throw ArgumentError(
            'Empty object passed as invariant of the enum "$name"'
          );
        }

        final key = data.keys.first;
        final orderByte = canonicalOrder.toList().indexOf(key);
        if (orderByte == -1) {
          throw ArgumentError(
            'Unknown invariant of the enum "$name", allowed values: "${canonicalOrder.join(
              " | "
            )}"; received "$key"'
          );
        }
        final invariant = canonicalOrder.toList()[orderByte];
        final invariantType = struct[invariant];

        // write order byte
        writer.write8(orderByte);

        // When { "key": null } - empty value for the invariant.
        if (invariantType == null) {
          return writer;
        }

        final paramIndex = canonicalTypeParams.indexOf(invariantType);
        final typeOrParam =
          paramIndex == -1 ? invariantType : typeParams[paramIndex];

        {
          final (name, params) = parseTypeName(typeOrParam);
          return getTypeInterface(name).encodeRaw(
            writer,
            data[key],
            params,
            typeMap
          );
        }
      },
      (reader, typeParams, typeMap) {
        final orderByte = reader.readULEB();
        final invariant = canonicalOrder.toList()[orderByte];
        final invariantType = struct[invariant];

        if (orderByte == -1) {
          throw ArgumentError(
            'Decoding type mismatch, expected enum "$name" invariant index, received "$orderByte"'
          );
        }

        // Encode an empty value for the enum.
        if (invariantType == null) {
          return { invariant: true };
        }

        final paramIndex = canonicalTypeParams.indexOf(invariantType);
        final typeOrParam =
          paramIndex == -1 ? invariantType : typeParams[paramIndex];

        {
          final (name, params) = parseTypeName(typeOrParam);
          return {
            invariant: getTypeInterface(name).decodeRaw(
              reader,
              params,
              typeMap
            ),
          };
        }
      }
    );
  }

  /// Get a set of encoders/decoders for specific type.
  /// Mainly used to define custom type de/serialization logic.
  TypeInterface getTypeInterface(String type) {
    var typeInterface = types[type];

    // Special case - string means an alias.
    // Goes through the alias chain and tracks recursion.
    if (typeInterface is String) {
      List<String> chain = [];
      while (typeInterface is String) {
        if (chain.contains(typeInterface)) {
          throw ArgumentError(
            'Recursive definition found: ${chain.join(
              " -> "
            )} -> $typeInterface'
          );
        }
        chain.add(typeInterface);
        typeInterface = types[typeInterface];
      }
    }

    if (typeInterface == null) {
      throw ArgumentError("Type $type is not registered");
    }

    return typeInterface;
  }

  /// Parse a type name and get the type's generics.
  /// ```dart
  /// final (typeName, typeParams) = parseTypeName('Option<Coin<SUI>>');
  /// // typeName: Option
  /// // typeParams: [ 'Coin<SUI>' ]
  /// ```
  (String, List<dynamic>) parseTypeName(TypeName name) {
    if (name is Iterable) {
      final nameList = name.toList();
      return (nameList[0], nameList.sublist(1));
    }

    if (name is! String) {
      throw ArgumentError("Illegal type passed as a name of the type: $name");
    }

    final (left, right) = schema.genericSeparators ?? ("<", ">");

    final l_bound = name.indexOf(left);
    final r_bound = name.split("").reversed.toList().indexOf(right);

    // if there are no generics - exit gracefully.
    if (l_bound == -1 && r_bound == -1) {
      return (name, []);
    }

    // if one of the bounds is not defined - throw an Error.
    if (l_bound == -1 || r_bound == -1) {
      throw ArgumentError("Unclosed generic in name '$name'");
    }

    final typeName = name.substring(0, l_bound);
    final params = name
      .substring(l_bound + 1, name.length - r_bound - 1)
      .split(",")
      .map((e) => e.trim())
      .toList();

    return (typeName, params);
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

/// Register the base set of primitive and common types.
/// Is called in the `BCS` constructor automatically but can
/// be ignored if the `withPrimitives` argument is not set.
void registerPrimitives(LegacyBCS bcs) {
  bcs.registerType(
    LegacyBCS.U8,
    (writer, data, _, __) {
      return writer.write8(int.parse(data.toString()));
    },
    (reader, _, __) {
      return reader.read8();
    },
    (u8) => toBN(u8) <= BigInt.from(MAX_U8_NUMBER)
  );

  bcs.registerType(
    LegacyBCS.U16,
    (writer, data, _, __) {
      return writer.write16(int.parse(data.toString()));
    },
    (reader, _, __) {
      return reader.read16();
    },
    (u16) => toBN(u16) <= BigInt.from(MAX_U16_NUMBER)
  );

  bcs.registerType(
    LegacyBCS.U32,
    (writer, data, _, __) {
      return writer.write32(int.parse(data.toString()));
    },
    (reader, _, __) {
      return reader.read32();
    },
    (u32) => toBN(u32) <= BigInt.from(MAX_U32_NUMBER)
  );

  bcs.registerType(
    LegacyBCS.U64,
    (writer, data, _, __) {
      return writer.write64(BigInt.parse(data.toString()));
    },
    (reader, _, __) {
      return reader.read64().toString();
    }
  );

  bcs.registerType(
    LegacyBCS.U128,
    (writer, data, _, __) {
      return writer.write128(BigInt.parse(data.toString()));
    },
    (reader, _, __) {
      return reader.read128().toString();
    }
  );

  bcs.registerType(
    LegacyBCS.U256,
    (writer, data, _, __) {
      return writer.write256(BigInt.parse(data.toString()));
    },
    (reader, _, __) {
      return reader.read256().toString();
    }
  );

  bcs.registerType(
    LegacyBCS.BOOL,
    (writer, data, _, __) {
      return writer.write8(data == true ? 1 : 0);
    },
    (reader, _, __) {
      return reader.read8().toString() == "1";
    }
  );

  bcs.registerType(
    LegacyBCS.STRING,
    (writer, data, _, __) =>
      writer.writeVec(data.split(""), (writer, el, a, b) {
        writer.write8(utf8.encode(el)[0]);
      }),
    (reader, _, __) {
      final data = reader
        .readVec((reader, a, b) => reader.read8())
        .map<int>((item) => item.toInt()).toList();
      return utf8.decode(data);
    },
    (_str) => true
  );

  bcs.registerType(
    LegacyBCS.HEX,
    (writer, data, _, __) {
      return writer.writeVec(fromHEX(data), (writer, el, _, __) =>
        writer.write8(el)
      );
    },
    (reader, _, __) {
      final bytes = reader.readVec((reader, _, __) => reader.read8());
      return toHEX(Uint8List.fromList(bytes.cast<int>()));
    }
  );

  bcs.registerType(
    LegacyBCS.BASE58,
    (writer, data, _, __) {
      return writer.writeVec(fromB58(data), (writer, el, _, __) =>
        writer.write8(el)
      );
    },
    (reader, _, __) {
      final bytes = reader.readVec((reader, _, __) => reader.read8());
      return toB58(Uint8List.fromList(bytes.cast<int>()));
    }
  );

  bcs.registerType(
    LegacyBCS.BASE64,
    (writer, data, _, __) {
      return writer.writeVec(fromB64(data), (writer, el, _, __) =>
        writer.write8(el)
      );
    },
    (reader, _, __) {
      final bytes = reader.readVec((reader, _, __) => reader.read8());
      return toB64(Uint8List.fromList(bytes.cast<int>()));
    }
  );
}

BcsConfig getRustConfig() {
  return BcsConfig(
    vectorType: "Vec",
    addressLength: SUI_ADDRESS_LENGTH,
    genericSeparators: ("<", ">"),
    addressEncoding: Encoding.hex
  );
}

BcsConfig getSuiMoveConfig() {
  return BcsConfig(
    vectorType: LegacyBCS.VECTOR,
    fixedArrayType: LegacyBCS.FixedArray,
    addressLength: SUI_ADDRESS_LENGTH,
    genericSeparators: ("<", ">"),
    addressEncoding: Encoding.hex
  );
}
