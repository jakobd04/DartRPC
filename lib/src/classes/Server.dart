// ignore_for_file: annotate_overrides

import 'dart:async';
import 'dart:io';

import 'package:encrypt/encrypt_io.dart';
import 'package:logging/logging.dart';
import 'package:my_rpc/src/predefinedHandlers/RootHandler.dart';
import 'package:path/path.dart' as p;

import 'package:my_rpc/src/interfaces/ClientInterface.dart';
import 'package:my_rpc/src/interfaces/ServerInterface.dart';
import 'package:my_rpc/src/utils/KeyHelperRSA.dart';
import 'package:pointycastle/export.dart';
import 'Client.dart';

class Server implements ServerInterface {
  final Logger _logger = Logger('Server');

  //Host and port that the server listens on
  final dynamic host;
  final int port;
  late final RawServerSocket server;

  int hLen;

  //The handler that all incoming Messages are passed to
  final RootHandler rootHandler;

  final connections = <ClientInterface>[];

  final String basePath;

  late final RSAPrivateKey privateKey;
  late final RSAPublicKey publicKey;
  late final String publicKeyPem;

  final bool authenticate;

  Server({required this.host, required this.port, required this.rootHandler, this.basePath = './', this.authenticate = false, this.hLen = 128}) {
    final logFile = File(p.join(basePath, 'logs/log.log'));
    logFile.createSync(recursive: true);
    logFile.writeAsStringSync(''); //Clear the log file
    _logger.onRecord.listen((LogRecord event) {
      final msg = '[${event.loggerName}][${event.level}]: ${event.message}';
      print(msg);
      logFile.writeAsString(msg + '\n', mode: FileMode.append);
    });

    closed.then((value) => _logger.info('Shutting down server'));
    closed.then((value) => server.close());
  }

  void start() async {
    final newPair = !File(p.join(basePath, 'RSA/public.pem')).existsSync() || !File(p.join(basePath, 'RSA/private.pem')).existsSync();

    if (newPair) generateNewPair();

    try {
      privateKey = await parseKeyFromFile(p.join(basePath, 'RSA/private.pem'));
      publicKey = await parseKeyFromFile(p.join(basePath, 'RSA/public.pem'));
    } on FormatException { //In case the key files are corrupted
      _logger.warning('The key files are corrupted, creating new ones');
      generateNewPair();
      privateKey = await parseKeyFromFile(p.join(basePath, 'RSA/private.pem'));
      publicKey = await parseKeyFromFile(p.join(basePath, 'RSA/public.pem'));
    }
    publicKeyPem = await File(p.join(basePath, 'RSA/public.pem')).readAsString();

    server = await RawServerSocket.bind(host, port);

    _logger.info('Started main loop');
    await for (RawSocket connection in server) {
      final client = Client.fromExisting(host: host, port: port, connection: connection, server: this);
      connections.add(client);
      client.start();
    }
  }

  //closed Future and close Function implemented via _closed Completer. If the server is closed, so are all ongoing connections
  final Completer<RawSocketEvent> _closed = Completer();
  Future<RawSocketEvent> get closed => _closed.future;
  void close() => _closed.complete(RawSocketEvent.readClosed);

  void generateNewPair() {
    final publicFile = File(p.join(basePath, 'RSA/public.pem'));
    final privateFile = File(p.join(basePath, 'RSA/private.pem'));

    publicFile.createSync(recursive: true);
    privateFile.createSync(recursive: true);

    final pair = generateKeyPair();

    publicFile.writeAsStringSync(encodeRsaPublicKey(pair.publicKey as RSAPublicKey));
    privateFile.writeAsStringSync(encodeRsaPrivateKey(pair.privateKey as RSAPrivateKey));
  }
}