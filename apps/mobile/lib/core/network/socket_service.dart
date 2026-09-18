import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;

import '../constants/app_constants.dart';

/// One socket connection for the whole app, opened right after login (or on
/// app start if a token is already stored) and closed on logout. Screens
/// attach/detach their own event listeners as they mount/unmount — they
/// never own the connection lifecycle themselves.
class SocketService {
  socket_io.Socket? _socket;

  bool get isConnected => _socket?.connected ?? false;

  void connect(String token) {
    disconnect();
    _socket = socket_io.io(
      AppConstants.wsUrl,
      socket_io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .disableAutoConnect()
          .build(),
    );
    _socket!.connect();
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
  }

  void emit(String event, Map<String, dynamic> data) {
    _socket?.emit(event, data);
  }

  void on(String event, void Function(dynamic data) handler) {
    _socket?.on(event, handler);
  }

  void off(String event, [void Function(dynamic data)? handler]) {
    _socket?.off(event, handler);
  }
}

final socketServiceProvider = Provider<SocketService>((ref) => SocketService());
