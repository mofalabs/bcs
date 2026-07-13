/// Binary Canonical Serialization (BCS) for Dart.
///
/// Build schemas with the factories on [Bcs], then use them to serialize and
/// deserialize BCS-encoded data:
///
/// ```dart
/// import 'package:bcs/bcs.dart';
///
/// final coin = Bcs.struct('Coin', {
///   'value': Bcs.u64(),
///   'owner': Bcs.string(),
/// });
///
/// final bytes = coin.serialize({'value': 1000000, 'owner': 'Alice'}).toBytes();
/// final decoded = coin.parse(bytes);
/// ```
library;

export 'src/bcs.dart' show Bcs;
export 'src/bcs_type.dart' show BcsType, BcsTypeOptions, SerializedBcs;
export 'src/encoding.dart'
    show base58Decode, base58Encode, hexDecode, hexEncode;
export 'src/reader.dart' show BcsReader;
export 'src/writer.dart' show BcsWriter, BcsWriterOptions;
