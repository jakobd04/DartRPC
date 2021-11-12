import 'package:my_rpc/src/interfaces/MessageHandlerInterface.dart';
import 'package:my_rpc/src/predefinedHandlers/RootHandler.dart';

class RoutingHandler extends MessageHandlerInterface {
  Map<String, MessageHandlerInterface> children = {};

  RoutingHandler({Map<String, MessageHandlerInterface> children = const {}}) {
    this.children = children;
  }

  void init(RootHandler rootHandler) {
    super.init(rootHandler);
    children.values.forEach((element) => element.init(rootHandler));

    stream.listen((event) {
      var path = p.split(event.headers['destination']);
      final nextHop = path.first;
      path = path.sublist(1);
      event.headers['destination'] = p.joinAll(path);
      this.children[nextHop]?.add(event);
    });
  }

  void registerHandler(String name, MessageHandlerInterface handler) {
    children[name] ??= handler;
    handler.rootHandler = rootHandler;
  }
}