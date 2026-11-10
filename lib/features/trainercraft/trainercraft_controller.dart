import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'services/trainercraft_ble_service.dart';
import 'services/trainercraft_server_service.dart';

/// A wheel/tyre combination used to convert wheel revolutions to distance.
@immutable
class TirePreset {
  /// Creates a tyre preset.
  const TirePreset({required this.label, required this.circumferenceMeters});

  /// Human readable size, e.g. `700 × 25c`.
  final String label;

  /// Rolling circumference in metres.
  final double circumferenceMeters;
}

/// Presets copied from the TrainerCraft app bridge.
const List<TirePreset> trainerCraftTirePresets = <TirePreset>[
  TirePreset(label: '700 × 23c', circumferenceMeters: 2.097),
  TirePreset(label: '700 × 25c (road)', circumferenceMeters: 2.105),
  TirePreset(label: '700 × 28c', circumferenceMeters: 2.136),
  TirePreset(label: '26" × 2.0" (MTB)', circumferenceMeters: 2.068),
  TirePreset(label: '27.5" × 2.1" (MTB)', circumferenceMeters: 2.148),
  TirePreset(label: '29" × 2.1" (MTB)', circumferenceMeters: 2.288),
];

/// Lifecycle of the TrainerCraft bridge.
enum TrainerCraftPhase {
  /// No sensor or server is active.
  idle,

  /// The bridge is looking for a Bluetooth speed sensor.
  scanning,

  /// The sensor is connected and speed is being streamed to Minecraft.
  running,

  /// The scan finished without finding a sensor.
  timeout,

  /// Something went wrong (Bluetooth, sensor or port).
  error,
}

/// State and orchestration of the TrainerCraft companion feature.
///
/// The controller is registered once at the application root so the bridge can
/// keep running while the user switches back to the TrainCenter tabs.
class TrainerCraftController extends ChangeNotifier {
  /// Creates the controller.
  TrainerCraftController({
    TrainerCraftBleService? bleService,
    TrainerCraftServerService? serverService,
  }) : _bleService = bleService ?? TrainerCraftBleService(),
       _serverService = serverService ?? TrainerCraftServerService();

  final TrainerCraftBleService _bleService;
  final TrainerCraftServerService _serverService;

  TrainerCraftPhase _phase = TrainerCraftPhase.idle;
  double _speedKmh = 0;
  double _topSpeedKmh = 0;
  bool _serverRunning = false;
  bool _gameConnected = false;
  bool? _minecraftInstalled;
  bool _checkingMinecraft = false;
  String? _errorMessage;
  TirePreset _tirePreset = trainerCraftTirePresets[1];
  int _generation = 0;

  /// Current bridge phase.
  TrainerCraftPhase get phase => _phase;

  /// Current speed reported by the sensor.
  double get speedKmh => _speedKmh;

  /// Highest speed since the bridge was started.
  double get topSpeedKmh => _topSpeedKmh;

  /// Whether the local WebSocket server is listening.
  bool get serverRunning => _serverRunning;

  /// Whether Minecraft is connected to the WebSocket.
  bool get gameConnected => _gameConnected;

  /// Whether Minecraft is installed. `null` means the check is unavailable or
  /// has not completed yet.
  bool? get minecraftInstalled => _minecraftInstalled;

  /// Whether the Minecraft installation check is running.
  bool get checkingMinecraft => _checkingMinecraft;

  /// Selected wheel circumference preset.
  TirePreset get tirePreset => _tirePreset;

  /// Last error message, if any.
  String? get errorMessage => _errorMessage;

  /// Whether the bridge is currently scanning.
  bool get isScanning => _phase == TrainerCraftPhase.scanning;

  /// Whether the bridge is running.
  bool get isRunning => _phase == TrainerCraftPhase.running;

  /// Starts scanning for a sensor and, once connected, the WebSocket server.
  Future<void> start() async {
    if (_phase == TrainerCraftPhase.scanning ||
        _phase == TrainerCraftPhase.running) {
      return;
    }

    _phase = TrainerCraftPhase.scanning;
    _speedKmh = 0;
    _topSpeedKmh = 0;
    _serverRunning = false;
    _gameConnected = false;
    _errorMessage = null;
    final generation = ++_generation;
    notifyListeners();

    await _bleService.connect(
      onSpeed: (speed) {
        if (generation != _generation) return;
        _speedKmh = speed;
        if (speed > _topSpeedKmh) _topSpeedKmh = speed;
        notifyListeners();
      },
      onConnected: () async {
        if (generation != _generation) return false;
        final started = await _serverService.start(
          getSpeed: () => _bleService.speedKmh,
          onClientChanged: (connected) {
            if (generation != _generation) return;
            _gameConnected = connected;
            notifyListeners();
          },
        );
        if (generation != _generation) {
          await _serverService.stop();
          return false;
        }
        _serverRunning = started;
        if (!started) {
          _errorMessage =
              'Port ${TrainerCraftServerService.port} is already in use. '
              'Stop the other bridge and try again.';
          _phase = TrainerCraftPhase.error;
          notifyListeners();
          return false;
        }
        _phase = TrainerCraftPhase.running;
        notifyListeners();
        return true;
      },
      onTimeout: () {
        if (generation != _generation) return;
        _phase = TrainerCraftPhase.timeout;
        _speedKmh = 0;
        notifyListeners();
      },
      onDisconnected: () async {
        if (generation != _generation) return;
        await _serverService.stop();
        if (generation != _generation) return;
        _serverRunning = false;
        _gameConnected = false;
        _speedKmh = 0;
        if (_phase == TrainerCraftPhase.running) {
          _phase = TrainerCraftPhase.error;
          _errorMessage = 'The speed sensor disconnected.';
        }
        notifyListeners();
      },
      onError: (error) async {
        if (generation != _generation) return;
        await _serverService.stop();
        if (generation != _generation) return;
        _serverRunning = false;
        _gameConnected = false;
        _speedKmh = 0;
        _phase = TrainerCraftPhase.error;
        _errorMessage = _describeError(error);
        notifyListeners();
      },
    );
  }

  /// Stops scanning, disconnects the sensor and closes the server.
  Future<void> stop() async {
    _generation++;
    await _bleService.stop();
    await _serverService.stop();
    _phase = TrainerCraftPhase.idle;
    _speedKmh = 0;
    _serverRunning = false;
    _gameConnected = false;
    _errorMessage = null;
    notifyListeners();
  }

  /// Selects a new wheel circumference preset.
  void setTirePreset(TirePreset preset) {
    if (_tirePreset == preset) return;
    _tirePreset = preset;
    _bleService.setCircumference(preset.circumferenceMeters);
    notifyListeners();
  }

  /// Refreshes whether Minecraft Bedrock is installed.
  ///
  /// The platform channel only exists on Android; on every other platform the
  /// result stays `null` and the UI explains that the game can be launched from
  /// the device instead.
  Future<void> refreshMinecraftInstallation() async {
    if (_checkingMinecraft) return;
    _checkingMinecraft = true;
    notifyListeners();

    try {
      final installed = await const MethodChannel(
        'com.previx.traincenter/minecraft',
      ).invokeMethod<bool>('isInstalled');
      _minecraftInstalled = installed;
    } on MissingPluginException {
      _minecraftInstalled = null;
    } on PlatformException {
      _minecraftInstalled = null;
    } catch (_) {
      _minecraftInstalled = null;
    } finally {
      _checkingMinecraft = false;
      notifyListeners();
    }
  }

  /// Opens Minecraft, or the Play Store page when it is not installed.
  ///
  /// Returns `false` when the platform cannot handle the request.
  Future<bool> launchMinecraft() async {
    try {
      final opened = await const MethodChannel(
        'com.previx.traincenter/minecraft',
      ).invokeMethod<bool>('open');
      if (opened == false) {
        _errorMessage =
            'Minecraft is not installed and the Play Store could not be '
            'opened.';
        notifyListeners();
        return false;
      }
      return true;
    } on MissingPluginException {
      _errorMessage = 'Opening Minecraft is only available on Android.';
      notifyListeners();
      return false;
    } on PlatformException catch (error) {
      _errorMessage = error.message ?? 'Could not open Minecraft.';
      notifyListeners();
      return false;
    }
  }

  String _describeError(Object error) {
    if (error is MissingPluginException) {
      return 'Bluetooth is not available on this platform.';
    }
    if (error is PlatformException) {
      return error.message ?? error.code;
    }
    final message = error.toString();
    for (final prefix in <String>['Exception: ', 'Bad state: ']) {
      if (message.startsWith(prefix)) {
        return message.substring(prefix.length);
      }
    }
    return message;
  }

  @override
  void dispose() {
    // The app is shutting down: clean up without notifying a disposed
    // ChangeNotifier.
    _generation++;
    unawaited(_bleService.stop());
    unawaited(_serverService.stop());
    super.dispose();
  }
}
