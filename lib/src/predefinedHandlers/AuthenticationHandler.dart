import 'dart:convert';
import 'dart:io';

import 'package:my_rpc/my_rpc.dart';
import 'package:my_rpc/src/interfaces/MessageHandlerInterface.dart';
import 'package:my_rpc/src/interfaces/MessageInterface.dart';
import 'package:my_rpc/src/predefinedHandlers/RootHandler.dart';

class AuthenticationHandler extends MessageHandlerInterface {
  final MessageHandlerInterface child;

  late final File registered;
  late final File unknown;

  late List<String> registeredList;

  Function(MessageInterface message)? unregisteredCallback;

  String directoryPath;
  
  AuthenticationHandler({required this.child, this.unregisteredCallback, this.directoryPath = 'AuthenticationHandler'}) {
    unregisteredCallback ??= (MessageInterface event) {
      event.client.send(Message(
        headers: {
          'encoding': 'utf-8',
          'destination': 'print'
        },
        data: utf8.encode('You do not have permission to access this part of the server. Please contact the server owner for more information')
      ));
    };
  }

  void init(RootHandler rootHandler) {
    super.init(rootHandler);
    child.init(rootHandler);

    registered = File(p.join(basePath, directoryPath, 'registered'));
    unknown = File(p.join(basePath, directoryPath, 'unknown'));

    if(!registered.existsSync()) registered.createSync(recursive: true);
    if(!unknown.existsSync()) unknown.createSync(recursive: true);

    loadData();

    stream.listen((event) {
      if (registeredList.contains(event.client.remoteKeyHash)) {
        child.add(event);
      } else {
        unknown.writeAsString(event.client.remoteKeyHash + '\n', mode: FileMode.append);
        unregisteredCallback!(event);
      }
    });
  }

  void loadData() => registeredList = registered.readAsLinesSync();
}