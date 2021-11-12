import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/export.dart' hide Mac;
import 'randomBytes.dart';

void main() async {
  final key = AesGcm.randomKey();
  final iv = AesGcm.randomIV();

  final crypto = AesGcm(key);

  final plain = 'Hello there!';
  final cipher = crypto.encrypt(Uint8List.fromList(utf8.encode(plain)), iv);
  print(crypto.decrypt(cipher, iv));

}

class AesGcm {
  static final _aes_gcm = GCMBlockCipher(AESFastEngine());

  final Uint8List key;

  AesGcm(this.key);

  static Uint8List randomKey() => randomBytes(16, secure: true);
  static Uint8List randomIV() => randomBytes(12, secure: true);

  Uint8List encrypt(Uint8List plainText, Uint8List iv) {
    _aes_gcm.init(true, ParametersWithIV(
      KeyParameter(key),
      iv
    ));
    return _aes_gcm.process(plainText);
  }

  Uint8List decrypt(Uint8List cipherText, Uint8List iv) {
    _aes_gcm.init(false, ParametersWithIV(
      KeyParameter(key),
      iv
    ));
    return _aes_gcm.process(cipherText);
  }

}