import 'dart:io';

import 'package:my_rpc/src/interfaces/MessageInterface.dart';
import 'package:my_rpc/src/predefinedHandlers/RootHandler.dart';
import 'package:pointycastle/export.dart';

abstract class ClientInterface {
  int hLen;

  final dynamic host;
  final int port;
  RawSocket? connection;

  final String basePath;

  final RootHandler rootHandler;

  late final RSAPrivateKey privateKey;
  late final RSAPublicKey publicKey;
  late final String publicKeyPem;

  late String remoteKeyHash;

  final bool authenticate;

  ClientInterface({required this.host, required this.port, required this.rootHandler, this.basePath = './', this.authenticate = false, this.hLen = 128});

  void start();

  void send(MessageInterface message);

  void lockSend();
  void releaseSend();

  void lockReceive();
  void releaseReceive();

  void close();

  void initKeyExchange();
}