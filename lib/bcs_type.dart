
import 'dart:typed_data';
import 'package:bcs/index.dart';
import 'package:bcs/reader.dart';
import 'package:bcs/writer.dart';
import 'package:bcs/uleb.dart';
import 'package:bcs/utils.dart';

class BcsTypeOptions<T, Input> {
  final String? name;
  final void Function(Input value)? validate;

  BcsTypeOptions({
    this.name,
    this.validate
  });
}

class BcsType<T, Input> {
  T? _inferType;
  Input? _inferInput;
  final String name;
  final T Function(BcsReader) read;
  final int? Function(Input, {BcsWriterOptions? options}) serializedSize;
  final void Function(Input) validate;
  final void Function(Input, BcsWriter) _write;
  final Uint8List Function(Input, {BcsWriterOptions? options}) _serialize;

  BcsType({
    required this.name,
    required this.read,
    required void Function(Input, BcsWriter) write,
    Uint8List Function(Input, {BcsWriterOptions? options})? serialize,
    int? Function(Input, {BcsWriterOptions? options})? serializedSize,
    void Function(Input)? validate,
  }) : 
    this.serializedSize = serializedSize ?? ((_, {BcsWriterOptions? options}) => null),
    this._write = write,
    this._serialize = serialize ?? ((value, {options}) {
      final writer = BcsWriter(
        size: options?.size ?? serializedSize?.call(value) ?? 1024,
        maxSize: options?.maxSize,
        allocateSize: options?.allocateSize ?? 1024
      );
      write(value, writer);
      return writer.toBytes();
    }),
    this.validate = validate ?? ((_) {});

  void write(Input value, BcsWriter writer) {
    validate(value);
    _write(value, writer);
  }

  SerializedBcs serialize(Input value, {BcsWriterOptions? options}) {
    validate(value);
    return SerializedBcs(this, _serialize(value, options: options));
  }

  T parse(Uint8List bytes) {
    final reader = BcsReader(bytes);
    return read(reader);
  }

  T fromHex(String hex) {
    return parse(fromHEX(hex));
  }

  T fromBase58(String b58) {
    return parse(fromB58(b58));
  }

  T fromBase64(String b64) {
    return parse(fromB64(b64));
  }

  BcsType<T2, Input2> transform<T2, Input2>({
    String? name,
    required Input Function(Input2) input,
    required T2 Function(T) output,
    void Function(Input2)? validate,
  }) {
    return BcsType<T2, Input2>(
      name: name ?? this.name,
      read: (reader) => output(this.read(reader)),
      write: (value, writer) => this._write(input(value), writer),
      serializedSize: (value, {BcsWriterOptions? options}) => this.serializedSize(input(value)),
      serialize: (value, {options}) => this._serialize(input(value), options: options),
      validate: (value) {
        validate?.call(value);
        this.validate(input(value));
      },
    );
  }
}

class SerializedBcs<T, Input> {
  final BcsType<T, Input> _schema;
  final Uint8List _bytes;

  static const String SERIALIZED_BCS_BRAND = 'SERIALIZED_BCS_BRAND';

  bool get isSerializedBcs => true;

  SerializedBcs(this._schema, this._bytes);

  Uint8List toBytes() {
    return _bytes;
  }

  String toHex() {
    return toHEX(_bytes);
  }

  String toBase64() {
    return toB64(_bytes);
  }

  String toBase58() {
    return toB58(_bytes);
  }

  T parse() {
    return _schema.parse(_bytes);
  }
}

BcsType<T, Input> fixedSizeBcsType<T, Input>({
  required String name,
  required int size,
  required T Function(BcsReader) read,
  required void Function(Input, BcsWriter) write,
  void Function(Input)? validate,
}) {
  return BcsType<T, Input>(
    name: name,
    read: read,
    write: write,
    serializedSize: (_, {BcsWriterOptions? options}) => size,
    validate: validate,
  );
}

BcsType<int, dynamic> uIntBcsType({
  required String name,
  required int size,
  required String readMethod,
  required String writeMethod,
  required int maxValue,
  void Function(int)? validate,
}) {
  return fixedSizeBcsType<int, dynamic>(
    name: name,
    size: size,
    read: (reader) {
      switch (readMethod) {
        case 'read8':
          return reader.read8();
        case 'read16':
          return reader.read16();
        case 'read32':
          return reader.read32();
        default:
          throw ArgumentError('Invalid read type $readMethod');
      }
    },
    write: (value, writer) {
      switch (writeMethod) {
        case 'write8':
          writer.write8(value);
          break;
        case 'write16':
          writer.write16(value);
          break;
        case 'write32':
          writer.write32(value);
          break;
        default:
          throw ArgumentError('Invalid read type $readMethod');
      }
    },
    validate: (val) {
      final value = int.parse(val.toString());
      if (value < 0 || value > maxValue) {
        throw ArgumentError('Invalid $name value: $value. Expected value in range 0-$maxValue');
      }
      validate?.call(value);
    },
  );
}

BcsType<BigInt, dynamic> bigUIntBcsType({
  required String name,
  required int size,
  required String readMethod,
  required String writeMethod,
  required BigInt maxValue,
  void Function(BigInt)? validate,
}) {
  return fixedSizeBcsType<BigInt, dynamic>(
    name: name,
    size: size,
    read: (reader) {
      switch (readMethod) {
        case 'read64':
          return reader.read64();
        case 'read128':
          return reader.read128();
        case 'read256':
          return reader.read256();
        default:
          throw ArgumentError('Invalid read type $readMethod');
      }
    },
    write: (value, writer) {
      final val = BigInt.parse(value.toString());
      switch (writeMethod) {
        case 'write64':
          writer.write64(val);
          break;
        case 'write128':
          writer.write128(val);
          break;
        case 'write256':
          writer.write256(val);
          break;
        default:
          throw ArgumentError('Invalid read type $readMethod');
      }
    },
    validate: (val) {
      final value = BigInt.parse(val.toString());
      if (value < BigInt.zero || value > maxValue) {
        throw ArgumentError('Invalid $name value: $value. Expected value in range 0-$maxValue');
      }
      validate?.call(value);
    },
  );
}

BcsType<T, Input> dynamicSizeBcsType<T, Input>({
  required String name,
  required T Function(BcsReader) read,
  required Uint8List Function(Input, {BcsWriterOptions? options}) serialize,
  void Function(Input)? validate,
}) {
  final type = BcsType<T, Input>(
    name: name,
    read: read,
    write: (value, writer) {
      for (final byte in serialize(value).toList()) {
        writer.write8(byte);
      }
    },
    serialize: serialize,
    validate: validate,
  );
  return type;
}

BcsType<String, dynamic> stringLikeBcsType({
  required String name,
  required Uint8List Function(String) toBytes,
  required String Function(Uint8List) fromBytes,
  int? Function(dynamic, {BcsWriterOptions? options})? serializedSize,
  void Function(String)? validate,
}) {
  return BcsType<String, dynamic>(
    name: name,
    read: (reader) {
      final length = reader.readULEB();
      final bytes = reader.readBytes(length);
      return fromBytes(bytes);
    },
    write: (value, writer) {
      final bytes = toBytes(value);
      writer.writeULEB(bytes.length);
      for (final byte in bytes) {
        writer.write8(byte);
      }
    },
    serialize: (value, {BcsWriterOptions? options}) {
      final bytes = toBytes(value);
      final size = ulebEncode(bytes.length);
      final result = Uint8List(size.length + bytes.length);
      result.setRange(0, size.length, size);
      result.setRange(size.length, result.length, bytes);
      return result;
    },
    serializedSize: serializedSize,
    validate: (value) {
      if (value is! String) {
        throw ArgumentError("Invalid $name value: $value. Expected string");
      }
      validate?.call(value);
    },
  );
}

BcsType<T, Input> lazyBcsType<T, Input>(BcsType<T, Input> Function() cb) {
  BcsType<T, Input>? lazyType;
  BcsType<T, Input> getType() {
    lazyType ??= cb();
    return lazyType!;
  }

  return BcsType<T, Input>(
    name: 'lazy',
    read: (data) => getType().read(data),
    serializedSize: (value, {BcsWriterOptions? options}) => getType().serializedSize(value),
    write: (value, writer) => getType().write(value, writer),
    serialize: (value, {options}) => getType().serialize(value, options: options).toBytes(),
  );
}