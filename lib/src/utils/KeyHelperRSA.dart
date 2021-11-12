import 'dart:convert';

import 'package:pointycastle/asn1.dart';
import 'package:pointycastle/export.dart';

import 'randomBytes.dart';

AsymmetricKeyPair generateKeyPair() {
  final generator = RSAKeyGenerator();
  final param = RSAKeyGeneratorParameters(BigInt.from(65537), 1024, 5);
  final random = FortunaRandom();
  random.seed(KeyParameter(randomBytes(32, secure: true)));
  generator.init(ParametersWithRandom(param, random));

  final pair = generator.generateKeyPair();
  return pair;
}

String encodeRsaPrivateKey(RSAPrivateKey key) {
  final sequence = ASN1Sequence();
  sequence.add(ASN1Integer(BigInt.from(0)));
  sequence.add(ASN1Integer(key.n));
  sequence.add(ASN1Integer(key.publicExponent));
  sequence.add(ASN1Integer(key.privateExponent));
  sequence.add(ASN1Integer(key.p));
  sequence.add(ASN1Integer(key.q));
  sequence.add(ASN1Integer(key.privateExponent! % (key.p! - BigInt.from(1))));
  sequence.add(ASN1Integer(key.privateExponent! % (key.q! - BigInt.from(1))));
  sequence.add(ASN1Integer(key.q!.modInverse(key.p!)));
  var out = base64Encode(sequence.encode());

  final lines = <String>[];
  final step = 40;
  int i;
  for (i = 0; i < out.length - step; i += step) {
    lines.add(out.substring(i, i + step));
  }
  lines.add(out.substring(i));
  out = lines.join('\n');

  return '-----BEGIN RSA PRIVATE KEY-----\n$out\n-----END RSA PRIVATE KEY-----';
}

String encodeRsaPublicKey(RSAPublicKey key) {
  final sequence = ASN1Sequence();
  sequence.add(ASN1Integer(key.modulus));
  sequence.add(ASN1Integer(key.publicExponent));
  var out = base64Encode(sequence.encode());

  final lines = <String>[];
  final step = 40;
  int i;
  for (i = 0; i < out.length - step; i += step) {
    lines.add(out.substring(i, i + step));
  }
  lines.add(out.substring(i));
  out = lines.join('\n');

  return '-----BEGIN RSA PUBLIC KEY-----\n$out\n-----END RSA PUBLIC KEY-----';
}