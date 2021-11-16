import 'package:my_rpc/src/interfaces/MessageHandlerInterface.dart';
import 'package:my_rpc/src/predefinedHandlers/RootHandler.dart';

class SendBackHandler extends MessageHandlerInterface {
  void init(RootHandler rootHandler) {
    super.init(rootHandler);

    stream.listen((event) {
      event.headers['destination'] = event.headers.remove('respDest') ?? 'logger';
      event.content = 'Sent back:\n' + event.content!;
      event.client.send(event);
    });
  }
}