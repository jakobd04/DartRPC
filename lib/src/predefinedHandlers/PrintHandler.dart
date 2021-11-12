import 'package:my_rpc/src/interfaces/MessageHandlerInterface.dart';
import 'package:my_rpc/src/predefinedHandlers/RootHandler.dart';

class PrintHandler extends MessageHandlerInterface {
  void init(RootHandler rootHandler) {
    super.init(rootHandler);
    stream.listen((event) {
      print(event.content);
    });
  }
}