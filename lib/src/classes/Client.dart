// ignore_for_file: annotate_overrides

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:async/async.dart';
import 'package:logging/logging.dart';
import 'package:encrypt/encrypt.dart';
import 'package:encrypt/encrypt_io.dart';
import 'package:my_rpc/src/predefinedHandlers/RootHandler.dart';
import 'package:pointycastle/export.dart' hide RSASigner;
import 'package:collection/collection.dart';
import 'package:path/path.dart' as p;
import 'package:crypto/crypto.dart';

import 'package:my_rpc/src/classes/Message.dart';
import 'package:my_rpc/src/interfaces/ClientInterface.dart';
import 'package:my_rpc/src/interfaces/MessageInterface.dart';
import 'package:my_rpc/src/interfaces/ServerInterface.dart';
import 'package:my_rpc/src/utils/AES-GCM.dart';
import 'package:my_rpc/src/utils/KeyHelperRSA.dart';

class Client implements ClientInterface{
  Logger _logger = Logger('Client');

  //JSON Message Header length
  int hLen;

  //Hostname, Port number and TCP-Connection object
  final dynamic host;
  final int port;
  RawSocket? connection;

  //Contains reference to parent Server
  ServerInterface? server;

  //The handler that all incoming Messages are passed to
  final RootHandler rootHandler;

  //The BasePath for actions like RSA-Key storage
  final String basePath;

  //Encryption helper
  late AesGcm aesGcm;

  //Both keys as KeyObjects and public key as String too
  late final RSAPrivateKey privateKey;
  late final RSAPublicKey publicKey;
  late final String publicKeyPem;

  //The hash of the public key of the remote end
  late String remoteKeyHash;

  //closed Future and close Function implemented via _closed Completer
  final Completer<RawSocketEvent> _closed = Completer();
  Future<RawSocketEvent> get closed => _closed.future;
  void close() => _closed.complete(RawSocketEvent.readClosed);

  //sendLock Future that is awaited before sending data that can stop the client from sending messages
  Completer<void> _sendLock = Completer();
  Future<void> get sendLock => _sendLock.future;
  void releaseSend() => _sendLock.complete();
  void lockSend() => _sendLock.isCompleted ? _sendLock = Completer() : null;

  //same as sendLock for receiving
  Completer<void> _receiveLock = Completer();
  Future<void> get receiveLock => _receiveLock.future;
  void releaseReceive() => _receiveLock.complete();
  void lockReceive() => _receiveLock.isCompleted ? _receiveLock = Completer() : null;

  Client({required this.host, required this.port, required this.rootHandler, this.basePath = './', this.hLen = 128}) {
    final logFile = File(p.join(basePath, 'logs/log.log'));
    logFile.createSync(recursive: true);
    logFile.writeAsStringSync('');
    _logger.onRecord.listen((LogRecord event) {
      final msg = '[${event.loggerName}][${event.level}]: ${event.message}';
      print(msg);
      logFile.writeAsString(msg + '\n', mode: FileMode.append);
    });
  }

  Client.fromExisting({required this.host, required this.port, required this.connection, this.basePath = './', required this.server}) :hLen = server!.hLen, rootHandler = server.rootHandler {
    _logger = Logger(connection!.hashCode.toString());
    server!.closed.then((value) => _closed.complete(value));
  }

  //Main Loop that handles all the RawSocketEvents
  void start() async {
    final server = this.server; //Server can be elevated to a non-nullable Type inside the else statement now
    if (server == null){ //Only if it is a standalone client
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
    } else {
      privateKey = server.privateKey;
      publicKey = server.publicKey;
      publicKeyPem = server.publicKeyPem;
    }

    //Creates the connection if it does not exist already
    connection ??= await RawSocket.connect(host, port, timeout: Duration(seconds: 3));

    //Adds the possibility to make the socket believe the other end closed the connection by calling close()
    final stream = StreamGroup.merge(<Stream<RawSocketEvent>>[connection!, Stream.fromFuture(closed)]);

    _logger.info('Started main loop');

    await for (RawSocketEvent event in stream) {
      switch (event) {
        //Gets triggered everytime there is data that can be read
        case RawSocketEvent.read:
          await _receive();
          break;
        //Gets triggered once the socket is ready for writing
        case RawSocketEvent.write:
          if (server != null) initKeyExchange();
          break;
        case RawSocketEvent.closed:
          _logger.info('Connection closed');
          return;
        //Gets triggered if either the other end closes the connection or close is called
        case RawSocketEvent.readClosed:
          connection!.shutdown(SocketDirection.both);
          break;
      }
    }
  }

  Future<void> _receive() async {
    final iv = connection!.read(12);

    //Check if the IV actually contains a key exchange command instead and handle it
    if (iv?[0] == 47 && iv?[1] == 47) {
      if (listEquals(initBytes, iv)) {
        //Key exchange initialization
        lockSend();
        lockReceive();
        _acceptKeyExchange();
        return;
      } else if (listEquals(continueBytes, iv)) {
        //Key exchange continuing
        _continueKeyExchange();
        return;
      } else if(listEquals(finalizeBytes, iv)) {
        //Key exchange finalization
        _finalizeKeyExchange();
        return;
      } else {
        _logger.warning('Something went wrong during the receiving of the message, clearing buffer');
        clearingBuffer();
        return;
      }
    }

    Map<String, dynamic> headers;
    try {
      //Read header length + 16 MAC bytes from AES-GCM
      var bytes = connection!.read(hLen + 16);
      bytes = aesGcm.decrypt(bytes!, iv!);

      headers = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;

    } on FormatException {
      _logger.warning('Error trying to parse headers, clearing buffer');
      clearingBuffer();
      return;

    } on InvalidCipherTextException {
      _logger.shout('The encrypted header data is corrupted, clearing buffer');
      clearingBuffer();
      return;
    }

    Uint8List? data = Uint8List(0);
    if (headers['dataLen'] != 0){
      try {
        data = connection!.read(headers['dataLen'] + 16); //Read the length of the data + the 16 bytes MAC
        data = aesGcm.decrypt(data!, Uint8List.fromList(headers['iv'].cast<int>()));

      } on TypeError {
        _logger.warning('No "dataLen" header available, clearing buffer');
        clearingBuffer();
        return;

      } on InvalidCipherTextException {
        _logger.shout('The encrypted body data is corrupted, clearing buffer');
        clearingBuffer();
        return;
      }
    }

    final MessageInterface message = Message(headers: headers, data: data);
    message.client = this;
    _logger.fine('Message Received');
    rootHandler.add(message); //Adding the Message Object to the root handler for processing
  }

  Future<void> send(MessageInterface message) async {
    _logger.finer('Waiting for send lock');
    await sendLock;

    message.headers['dataLen'] = message.data.length;

    message.client = this;
    if (message.data.isNotEmpty){
      final bodyIv = AesGcm.randomIV();
      message.data = aesGcm.encrypt(Uint8List.fromList(message.data), bodyIv);
      message.headers['iv'] = bodyIv;
    }
    final headerIV = AesGcm.randomIV();
    final encryptedHeader = aesGcm.encrypt(Uint8List.fromList(message.headerBytes), headerIV);
    connection!.write(headerIV + encryptedHeader + message.data);
    _logger.config('Message Sent');
  }

  void initKeyExchange() {
    //This is on initiator side
    _logger.info('Started Key Exchange');

    lockSend();
    lockReceive();

    var formattedKey = publicKeyPem.length.toString().padRight(hLen);
    formattedKey += publicKeyPem; //Actual publicKey in Pem format

    final out = initString + formattedKey;

    _logger.fine('Sent the public key out');
    connection!.write(utf8.encode(out));
  }

  void _acceptKeyExchange() {
    //This is on acceptor side
    _logger.info('Accepted Key Exchange');

    //Reading all the data
    final len = int.parse(utf8.decode(connection!.read(hLen)!));
    final remotePublicKeyBytes = connection!.read(len);
    final remotePublicKeyString = utf8.decode(remotePublicKeyBytes!);

    _logger.finest('Assigned hashed remote public key');
    remoteKeyHash = sha256.convert(remotePublicKeyBytes).toString();

    //Parsing the publicKey and creating the decrypter from it
    final remotePublicKey = RSAKeyParser().parse(remotePublicKeyString) as RSAPublicKey;
    final encryptor = RSA(publicKey: remotePublicKey);
    final signer = RSASigner(RSASignDigest.SHA256, privateKey: privateKey);

    //Create a random key and assign the AES-GCM engine
    final key = AesGcm.randomKey();
    aesGcm = AesGcm(key);

    final keyEncrypted = encryptor.encrypt(key).bytes; //Encrypt the just created key with the remote public key
    final keySignature = signer.sign(keyEncrypted).bytes; //The key signed with the own private key

    _logger.finest('Encrypted and signed the random key');

    var keyLenPadded = keyEncrypted.length.toString();
    keyLenPadded = keyLenPadded.padRight(hLen);

    var signatureLenPadded = keySignature.length.toString();
    signatureLenPadded = signatureLenPadded.padRight(hLen);

    var publicKeyLenPadded = publicKeyPem.length.toString();
    publicKeyLenPadded = publicKeyLenPadded.padRight(hLen);

    final out = continueBytes +
        utf8.encode(publicKeyLenPadded + publicKeyPem) +
        utf8.encode(signatureLenPadded) + keySignature +
        utf8.encode(keyLenPadded) + keyEncrypted;

    connection!.write(out);

    _logger.finest('Sent out public key, random key signature, encrypted random key');
  }

  void _continueKeyExchange() {
    //This is on initiator side
    _logger.config('Continuing Key Exchange');

    //Reading all the data
    var len = int.parse(utf8.decode(connection!.read(hLen)!));
    final remotePublicKeyBytes = connection!.read(len);
    final remotePublicKeyString = utf8.decode(remotePublicKeyBytes!);
    final remotePublicKey = RSAKeyParser().parse(remotePublicKeyString) as RSAPublicKey;

    _logger.finest('Assigned hashed remote public key');
    remoteKeyHash = sha256.convert(remotePublicKeyBytes).toString();

    len = int.parse(utf8.decode(connection!.read(hLen)!));
    final keySignature = connection!.read(len);

    len = int.parse(utf8.decode(connection!.read(hLen)!));
    final keyEncrypted = connection!.read(len);

    //Create the RSA engine
    final encryptor = RSA(privateKey: privateKey);
    
    final signer = RSASigner(RSASignDigest.SHA256, publicKey: remotePublicKey);

    if (signer.verify(remotePublicKeyBytes, Encrypted(keySignature!))) throw UnsupportedError('Could not authenticate remote end');
    _logger.finest('Authenticated the remote end');
    final key = encryptor.decrypt(Encrypted(keyEncrypted!));
    _logger.finest('Decrypted the random key');
    aesGcm = AesGcm(key);
    
    final iv = AesGcm.randomIV();
    final out = finalizeBytes + iv + aesGcm.encrypt(Uint8List.fromList(finalizeBytes), iv);

    connection!.write(out);

    releaseSend();
    releaseReceive();
    
    _logger.info('Finished key exchange');
  }

  void _finalizeKeyExchange() {
    //This is on acceptor side

    _logger.finest('Finalizing key exchange');

    final iv = connection!.read(12);
    final cipher = connection!.read(finalizeBytes.length + 16);

    if (!listEquals(aesGcm.decrypt(cipher!, iv!), finalizeBytes)) {
      _logger.severe('Something went wrong with the key exchange, shutting down the connection');
      close();
      return;
    }

    releaseSend();
    releaseReceive();

    _logger.info('Finished key exchange');
  }

  void clearingBuffer() {
    connection!.read(connection!.available() + 1);
  }

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

Function listEquals = ListEquality().equals;
const initString = '//INIT      ';
const initBytes = <int>[47, 47, 73, 78, 73, 84, 32, 32, 32, 32, 32, 32];
const continueString = '//CONTINUE  ';
const continueBytes = <int>[47, 47, 67, 79, 78, 84, 73, 78, 85, 69, 32, 32];
const finalizeString = '//FINALIZE  ';
const finalizeBytes = <int>[47, 47, 70, 73, 78, 65, 76, 73, 90, 69, 32, 32];