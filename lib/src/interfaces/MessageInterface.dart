import 'package:my_rpc/src/interfaces/ClientInterface.dart';

abstract class MessageInterface {
  Map<String, dynamic> headers;
  List<int> data;
  late ClientInterface client;

  MessageInterface(this.headers, this.data);

  String? get content;
  set content(String? string);

  List<int> get headerBytes;

  bool containsKey(String key);
  bool containsValue(dynamic value);

  dynamic operator [](String key);
  void operator []=(String key, dynamic value);
}