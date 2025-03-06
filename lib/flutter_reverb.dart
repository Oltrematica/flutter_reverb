import 'dart:convert';

import 'package:flutter_reverb/flutter_reverb_options.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:web_socket_channel/web_socket_channel.dart';

abstract class ReverbService {
  Future<String?> authenticate(String socketId, String channelName);
  void subscribe(String channelName, {bool isPrivate = false});
  void listen(void Function(dynamic) onData, String channelName);
  void close();
}

class FlutterReverb implements ReverbService {
  late final WebSocketChannel _channel;
  final FlutterReverbOptions options;
  final Logger _logger = Logger();

  FlutterReverb({required this.options}) {
    try {
      final wsUrl = _constructWebSocketUrl();
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
    } catch (e) {
      _logger.e('Failed to connect to WebSocket: $e');
      rethrow;
    }
  }

  String _constructWebSocketUrl() {
    return '${options.scheme}://${options.host}:${options.port}/app/${options.appKey}';
  }

  @override
  void subscribe(String channelName, {bool isPrivate = false}) {
    final prefix = options.usePrefix ? options.privatePrefix : '';
    final channel = isPrivate ? '$prefix$channelName' : channelName;
    final subscription = {
      "event": "pusher:subscribe",
      "data": {"channel": channel},
    };
    _channel.sink.add(jsonEncode(subscription));
  }

  @override
  void listen(void Function(dynamic) onData, String channelName) {
    _channel.stream.listen(
          (message) async {
        _logger.i('Received message: $message');
        final Map<String, dynamic> jsonMessage = jsonDecode(message);
        final response = WebsocketResponse.fromJson(jsonMessage);

        if (response.event == 'pusher:connection_established') {
          final socketId = response.data?['socket_id'];
          if (socketId != null) {
            final authToken = await authenticate(socketId, channelName);
            if (authToken != null) {
              subscribe(channelName, isPrivate: true);
            }
          }
        } else if (response.event == 'pusher:ping') {
          _channel.sink.add(jsonEncode({'event': 'pusher:pong'}));
        }
        onData(response);
      },
      onError: (error) => _logger.e('WebSocket error: $error'),
      onDone: () => _logger.i('Connection closed: $channelName'),
    );
  }

  @override
  Future<String?> authenticate(String socketId, String channelName) async {
    if (options.authUrl == null || options.authToken == null) {
      throw Exception('Authentication URL or Token is missing');
    }

    try {
      final response = await (options.httpClient ?? http.Client()).post(
        Uri.parse(options.authUrl!),
        headers: {'Authorization': 'Bearer ${options.authToken}'},
        body: {'socket_id': socketId, 'channel_name': channelName},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body)['auth'];
      } else {
        throw Exception('Authentication failed: ${response.statusCode}');
      }
    } catch (e) {
      _logger.e('Authentication error: $e');
      return null;
    }
  }

  @override
  void close() {
    try {
      _channel.sink.close(status.goingAway);
    } catch (e) {
      _logger.e('Failed to close WebSocket: $e');
    }
  }
}

class WebsocketResponse {
  final String event;
  final Map<String, dynamic>? data;

  WebsocketResponse({required this.event, this.data});

  factory WebsocketResponse.fromJson(Map<String, dynamic> json) {
    return WebsocketResponse(
      event: json['event'],
      data: json['data'] != null ? jsonDecode(json['data']) : null,
    );
  }
}
