import 'dart:convert';
import 'dart:io';

import 'package:my_rpc/my_rpc.dart';
import 'package:my_rpc/src/interfaces/MessageHandlerInterface.dart';
import 'package:my_rpc/src/predefinedHandlers/RootHandler.dart';

class AuthenticationHandler extends MessageHandlerInterface {
  final MessageHandlerInterface child;

  late final List<String> registeredList;
  
  AuthenticationHandler({required this.child});

  void init(RootHandler rootHandler) {
    super.init(rootHandler);
    child.init(rootHandler);

    final registered = File(p.join(basePath, 'AuthenticationHandler/registered.txt'));
    final unknown = File(p.join(basePath, 'AuthenticationHandler/new.txt'));

    registered.createSync(recursive: true);
    unknown.createSync(recursive: true);

    registeredList = registered.readAsLinesSync();

    stream.listen((event) {
      if (registeredList.contains(event.client.remoteKeyHash)) {
        child.add(event);
      } else {
        unknown.writeAsString(event.client.remoteKeyHash + '\n', mode: FileMode.append);
        event.client.send(Message(
          headers: {
            'encoding': 'utf-8'
          },
          data: utf8.encode('You do not have permission to access this part of the server. Please contact the server owner for more information')
        ));
      }
    });
  }
}