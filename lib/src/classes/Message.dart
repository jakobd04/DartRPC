// ignore_for_file: annotate_overrides

import 'dart:convert';

import 'package:my_rpc/src/interfaces/ClientInterface.dart';
import 'package:my_rpc/src/interfaces/MessageInterface.dart';

class Message implements MessageInterface {
  Map<String, dynamic> headers;
  List<int> data;
  late ClientInterface client;

  Message({Map<String, dynamic>? headers, this.data = const <int>[]}) : headers = headers != null ? headers : {};

  String? get content => Encoding.getByName(headers['encoding'])?.decode(data);
  set content(String? string) {
    if(!headers.containsKey('encoding') || string == null) return;
    final newData = Encoding.getByName(headers['encoding'])?.encode(string);
    if(newData != null)  data = newData;
  }

  List<int> get headerBytes {
    var jsonString = jsonEncode(headers);
    jsonString += ' ' * (client.hLen - jsonString.length);

    return utf8.encode(jsonString);
  }

  bool containsKey(String key) => headers.containsKey(key);
  bool containsValue(dynamic value) => headers.containsValue(value);

  dynamic operator [](String key) => headers[key];
  void operator []=(String key, dynamic value) => headers[key] = value;
}