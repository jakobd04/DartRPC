import 'dart:io';

import 'package:my_rpc/src/interfaces/ClientInterface.dart';
import 'package:my_rpc/src/predefinedHandlers/RootHandler.dart';
import 'package:pointycastle/export.dart';

abstract class ServerInterface {
  final dynamic host;
  final int port;

  int hLen;

  late final RawServerSocket server;

  final RootHandler rootHandler;

  final connections = <ClientInterface>[];

  final String basePath;

  late final RSAPrivateKey privateKey;
  late final RSAPublicKey publicKey;
  late final String publicKeyPem;

  ServerInterface({required this.host, required this.port, required this.rootHandler, this.basePath = './', this.hLen = 128});

  void start();

  Future<RawSocketEvent> get closed;
  void close();
}