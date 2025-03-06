import 'package:http/http.dart' as http;

class FlutterReverbOptions {
  final String scheme;
  final String host;
  final String port;
  final String appKey;
  final dynamic? authToken;
  final String? authUrl;
  final String privatePrefix;
  final bool usePrefix;

  FlutterReverbOptions({
    required this.scheme,
    required this.host,
    required this.port,
    required this.appKey,
    this.authToken,
    this.authUrl = '/broadcasting/auth',
    this.privatePrefix = 'private-',
    this.usePrefix = true,
  });
}