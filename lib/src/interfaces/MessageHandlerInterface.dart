import 'dart:async';

import 'package:path/path.dart' as path;

import 'package:my_rpc/src/interfaces/MessageInterface.dart';
import 'package:my_rpc/src/predefinedHandlers/RootHandler.dart';

abstract class MessageHandlerInterface {
  final p = path.posix;

  late RootHandler rootHandler;

  final _controller = StreamController<MessageInterface>();

  Stream<MessageInterface> get stream => _controller.stream;
  StreamSink<MessageInterface> get sink => _controller.sink;

  void add(MessageInterface message) => sink.add(message);
  void init(RootHandler rootHandler) => this.rootHandler = rootHandler;

  String get basePath => rootHandler.basePath;
}