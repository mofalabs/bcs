
import 'dart:typed_data';

import 'package:bcs/reader.dart';
import 'package:bcs/uleb.dart';
import 'package:bcs/utils.dart';
import 'package:bcs/writer.dart';

class BcsTypeOptions<T, Input> {
	final String? name;
	final void Function(Input)? validate;

  BcsTypeOptions({this.name, this.validate});
}

class BcsType<T, Input> {
	String name;
	T Function(BcsReader reader) read;
  late void Function(Input value, BcsWriter writer) _write;
  late Uint8List Function(Input value, [BcsWriterOptions? options]) _serialize;
  late int? Function(Input value, [BcsWriterOptions? options]) serializedSize;
  void Function(Input value) validate = (value) {};

  BcsType({
    required this.name,
    required this.read,
    required void Function(Input value, BcsWriter writer) write,
    Uint8List Function(Input value, [BcsWriterOptions? options])? serialize,
    int? Function(Input value, [BcsWriterOptions? options])? serializedSize,
    void Function(Input value)? validate,
    int? maxSize
  }) {
    this._write = write;
    this._serialize = serialize ??
			((value, [options]) {
        final size = serializedSize?.call(value);
				final writer = BcsWriter(size: size ?? 1024, maxSize: maxSize);
				write(value, writer);
				return writer.toBytes();
			});
    this.serializedSize = serializedSize ?? (_, [__]) => null;
    if (validate != null) this.validate = validate;
	}

	void write(Input value, BcsWriter writer) {
		this.validate(value);
		this._write(value, writer);
	}

	SerializedBcs serialize(Input value, [BcsWriterOptions? options]) {
		this.validate(value);
		return SerializedBcs(this, this._serialize(value, options));
	}

	T parse(Uint8List bytes) {
		final reader = BcsReader(bytes);
		return this.read(reader);
	}

	BcsType<T2, Input2> transform<T2, Input2>({
		required Input Function(Input2 val) input,
		required T2 Function(T value) output,
    void Function(Input value)? validate,
		String? name
	}) {
		return BcsType<T2, Input2>(
			name: name ?? this.name,
			read: (reader) => output(this.read(reader)),
			write: (value, writer) => this._write(input(value), writer),
			serializedSize: (value, [_]) => this.serializedSize(input(value)),
			serialize: (value, [options]) => this._serialize(input(value), options),
			validate: (value) => this.validate(input(value)),
		);
	}

}

class SerializedBcs<T, Input> {
	final BcsType<T, Input> _schema;
	final Uint8List _bytes;

	SerializedBcs(this._schema, this._bytes);

	Uint8List toBytes() {
		return this._bytes;
	}

	String toHex() {
		return toHEX(this._bytes);
	}

	String toBase64() {
		return toB64(this._bytes);
	}

	String toBase58() {
		return toB58(this._bytes);
	}

	T parse() {
		return this._schema.parse(this._bytes);
	}
}

BcsType<T, Input> fixedSizeBcsType<T, Input>({
	required String name,
	required int size,
	required T Function(BcsReader reader) read,
	required void Function(Input value, BcsWriter writer) write,
  void Function(Input value)? validate
}) {
	return BcsType<T, Input>(
    name: name,
    read: read,
    write: write,
		serializedSize: (_, [__]) => size
	);
}

BcsType<int, int> uIntBcsType({
  required String name,
	required int size,
	required String readMethod,
	required String writeMethod,
	required int maxValue,
  void Function(int value)? validate
}) {
	return fixedSizeBcsType<int, int>(
    name: name,
    size: size,
		read: (reader) {
      switch (readMethod) {
        case "read8":
          return reader.read8();
        case "read16":
          return reader.read16();
        case "read32":
          return reader.read32();
        default:
          throw ArgumentError.value(readMethod);
      }
    },
    write: (value, writer) {
      switch (writeMethod) {
        case "write8":
          writer.write8(value);
          break;
        case "write16":
          writer.write16(value);
          break;
        case "write32":
          writer.write32(value);
          break;
        default:
          throw ArgumentError.value(writeMethod);
      }
    },
		validate: (value) {
			if (value < 0 || value > maxValue) {
				throw ArgumentError(
					"Invalid $name value: $value. Expected value in range 0-$maxValue"
				);
			}
      if (validate != null) validate(value);
		},
	);
}

BcsType<String, BigInt> bigUIntBcsType({
  required String name,
	required int size,
	required String readMethod,
	required String writeMethod,
	required BigInt maxValue,
  void Function(BigInt value)? validate
}) {
  return fixedSizeBcsType<String, BigInt>(
    name: name,
    size: size,
		read: (reader) {
      switch (readMethod) {
        case "read64":
          return reader.read64().toString();
        case "read128":
          return reader.read128().toString();
        case "read256":
          return reader.read256().toString();
        default:
          throw ArgumentError.value(readMethod);
      }
    },
    write: (value, writer) {
      switch (writeMethod) {
        case "write64":
          writer.write64(value);
          break;
        case "write128":
          writer.write128(value);
          break;
        case "write256":
          writer.write256(value);
          break;
        default:
          throw ArgumentError.value(writeMethod);
      }
    },
		validate: (value) {
			if (value < BigInt.zero || value > maxValue) {
				throw ArgumentError(
					"Invalid $name value: $value. Expected value in range 0-$maxValue"
				);
			}
      if (validate != null) validate(value);
		},
	);
}

BcsType<T, Input> dynamicSizeBcsType<T, Input>({
  required String name,
  required T Function(BcsReader reader) read,
  required Uint8List Function(Input value, [BcsWriterOptions? options]) serialize,
  void Function(Input value)? validate
}) {
  late BcsType<T, Input> type;
	type = BcsType<T, Input>(
    name: name,
    read: read,
		serialize: serialize,
		write: (value, writer) {
			for (var byte in type.serialize(value).toBytes()) {
				writer.write8(byte);
			}
		},
	);

	return type;
}

BcsType<T, Input> stringLikeBcsType<T, Input>({
	required String name,
	required Uint8List Function(Input value) toBytes,
  required T Function(Uint8List bytes) fromBytes,
	int? Function(String value)? serializedSize,
  void Function(String value)? validate
}) {
	return BcsType<T, Input>(
    name: name,
		read: (reader) {
			final length = reader.readULEB();
			final bytes = reader.readBytes(length);
			return fromBytes(bytes);
		},
		write: (hex, writer) {
			final bytes = toBytes(hex);
			writer.writeULEB(bytes.length);
			for (int i = 0; i < bytes.length; i++) {
				writer.write8(bytes[i]);
			}
		},
		serialize: (value, [_]) {
			final bytes = toBytes(value);
			final size = ulebEncode(bytes.length);
			final result = Uint8List(size.length + bytes.length);
			result.setAll(0, size);
			result.setAll(size.length, bytes);
			return result;
		},
		validate: (value) {
			if (value is! String) {
				throw ArgumentError("Invalid $name value: $value. Expected string");
			}
			validate?.call(value);
		},
  );
}

BcsType<T, Input> lazyBcsType<T, Input>(BcsType<T, Input> Function() cb) {
	BcsType<T, Input>? lazyType = cb();
	return BcsType<T, Input>(
		name: 'lazy',
		read: (data) => lazyType.read(data),
		serializedSize: (value, [_]) => lazyType.serializedSize(value),
		write: (value, writer) => lazyType.write(value, writer),
		serialize: (value, [options]) => lazyType.serialize(value, options).toBytes(),
	);
}
