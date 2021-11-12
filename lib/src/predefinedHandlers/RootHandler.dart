
import 'package:my_rpc/src/interfaces/MessageHandlerInterface.dart';

class RootHandler extends MessageHandlerInterface {
  @override
  late final rootHandler = this;

  final String basePath;

  final MessageHandlerInterface child;

  RootHandler({required this.basePath, required this.child}) {
    init(this);
  }

  void init(RootHandler rootHandler) {
    child.init(rootHandler);
    stream.pipe(child.sink);
  }
}