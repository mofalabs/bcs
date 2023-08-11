import 'dart:typed_data';

import 'package:bcs/base_x.dart';

final base58 = BaseXCodec('123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz');

String base58Encode(List<int> bytes) => base58.encode(Uint8List.fromList(bytes));

Uint8List base58Decode(String source) => base58.decode(source);