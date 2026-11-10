import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Local WebSocket bridge consumed by the TrainerCraft Minecraft add-on.
///
/// Minecraft Bedrock connects to port 8000 and receives a `scriptevent`
/// command with the current speed five times per second.
class TrainerCraftServerService {
  static const int port = 8000;
  static const Duration _broadcastInterval = Duration(milliseconds: 200);

  HttpServer? _server;
  StreamSubscription<WebSocket>? _serverSubscription;
  WebSocket? _clientSocket;
  StreamSubscription<dynamic>? _clientSubscription;
  Timer? _broadcastTimer;

  /// Whether the HTTP server is listening on [port].
  bool get isRunning => _server != null;

  /// Whether Minecraft is currently connected to the WebSocket.
  bool get hasClient =>
      _clientSocket != null && _clientSocket!.readyState == WebSocket.open;

  /// Starts the local server.
  ///
  /// Returns `false` when the port cannot be bound (for example because
  /// another instance of the bridge is already running).
  Future<bool> start({
    required double Function() getSpeed,
    required void Function(bool connected) onClientChanged,
  }) async {
    if (_server != null) return true;

    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    } catch (_) {
      _server = null;
      return false;
    }

    _serverSubscription = _server!
        .transform(WebSocketTransformer())
        .listen(
          (socket) => _handleClient(socket, getSpeed, onClientChanged),
          onError: (_) {
            // A malformed HTTP request must not take the bridge down.
          },
        );

    return true;
  }

  /// Stops broadcasting and closes the server.
  Future<void> stop() async {
    _broadcastTimer?.cancel();
    _broadcastTimer = null;

    final client = _clientSocket;
    _clientSocket = null;
    await _clientSubscription?.cancel();
    _clientSubscription = null;
    try {
      await client?.close();
    } catch (_) {
      // The client may already have disconnected.
    }

    final server = _server;
    _server = null;
    await _serverSubscription?.cancel();
    _serverSubscription = null;
    try {
      await server?.close(force: true);
    } catch (_) {
      // Ignore shutdown races.
    }
  }

  /// Registers the new client, replacing any previous connection.
  void _handleClient(
    WebSocket socket,
    double Function() getSpeed,
    void Function(bool connected) onClientChanged,
  ) {
    final previous = _clientSocket;
    _clientSubscription?.cancel();
    _clientSocket = socket;

    if (previous != null && !identical(previous, socket)) {
      previous.close();
    }

    onClientChanged(true);

    _clientSubscription = socket.listen(
      (_) {
        // Commands from Minecraft are not used yet.
      },
      onDone: () => _handleClientClosed(socket, onClientChanged),
      onError: (_) => _handleClientClosed(socket, onClientChanged),
      cancelOnError: true,
    );

    _startBroadcast(getSpeed);
  }

  /// Clears the client when its socket closes.
  void _handleClientClosed(
    WebSocket socket,
    void Function(bool connected) onClientChanged,
  ) {
    if (!identical(_clientSocket, socket)) return;
    _clientSocket = null;
    _broadcastTimer?.cancel();
    _broadcastTimer = null;
    onClientChanged(false);
  }

  /// Streams the current speed to the connected client.
  void _startBroadcast(double Function() getSpeed) {
    _broadcastTimer?.cancel();
    _broadcastTimer = Timer.periodic(_broadcastInterval, (_) {
      final socket = _clientSocket;
      if (socket == null || socket.readyState != WebSocket.open) return;

      final speed = getSpeed();
      try {
        socket.add(
          jsonEncode(<String, dynamic>{
            'header': <String, dynamic>{
              'version': 1,
              'requestId': '00000000-0000-0000-0000-000000000000',
              'messagePurpose': 'commandRequest',
            },
            'body': <String, dynamic>{
              'version': 1,
              'commandLine':
                  'scriptevent trainercraft:set_speed ${speed.toStringAsFixed(1)}',
            },
          }),
        );
      } catch (_) {
        // The socket may have closed between the check and the write.
      }
    });
  }
}
