import 'dart:math';
import 'dart:typed_data';

Uint8List randomBytes(int length, {bool secure = false}) {
  assert(length > 0);

  final out = Uint8List(length);
  final random = secure ? Random() : Random.secure();

  for (var i = 0; i < length; i++) {
    out[i] = random.nextInt(255);
  }

  return out;
}