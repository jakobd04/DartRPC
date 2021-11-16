
import 'package:my_rpc/my_rpc.dart';
import 'package:my_rpc/src/interfaces/MessageHandlerInterface.dart';

class RootHandler extends MessageHandlerInterface {
  @override
  late final rootHandler = this;

  final String basePath;

  final MessageHandlerInterface child;

  Function(String?) loggerFunction;

  RootHandler({required this.basePath, required this.child, this.loggerFunction = print}) {
    init(this);
  }

  void init(RootHandler rootHandler) {
    child.init(rootHandler);
    stream.listen((event) {
      if (event['destination'] == 'logger') {
        if (event.containsKey('encoding')) {
          loggerFunction(event.content);
        } else {
          final response = Message(
            headers: {
              'encoding': 'utf-8',
              'destination': 'logger'
            }
          );
          response.content = 'Your logging message was missing the required encoding header';

          event.client.send(response);
        }
      } else {
        child.add(event);
      }
    });
  }
}