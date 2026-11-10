import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Reads speed from a Bluetooth LE cycling speed sensor (CSC service).
///
/// The service is deliberately UI-free: it reports data and lifecycle changes
/// through callbacks so the TrainerCraft controller can turn them into state
/// for the Material 3 screen.
class TrainerCraftBleService {
  /// Bluetooth SIG UUID of the Cycling Speed and Cadence service.
  static const String cscServiceUuid = '1816';

  /// Bluetooth SIG UUID of the CSC measurement characteristic.
  static const String cscMeasurementCharacteristicUuid = '2a5b';

  BluetoothDevice? _device;
  StreamSubscription<List<ScanResult>>? _scanResultsSubscription;
  StreamSubscription<List<int>>? _measurementSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  Timer? _scanTimeoutTimer;
  Timer? _speedTimeoutTimer;

  bool _connected = false;
  bool _connecting = false;
  bool _stopping = false;
  double _circumferenceMeters = 2.105;
  double _speedKmh = 0;
  int? _lastWheelRevolutions;
  int? _lastWheelEventTime;

  /// Whether a sensor is currently connected.
  bool get isConnected => _connected;

  /// Latest speed in km/h. Drops to zero when wheel events stop arriving.
  double get speedKmh => _speedKmh;

  /// Wheel circumference in metres used to convert revolutions to speed.
  double get circumferenceMeters => _circumferenceMeters;

  /// Updates the wheel circumference used for the speed calculation.
  void setCircumference(double meters) {
    if (meters <= 0) return;
    _circumferenceMeters = meters;
  }

  /// Scans for the first cycling speed sensor and subscribes to its data.
  ///
  /// [onConnected] must return `true` when the rest of the bridge (the local
  /// WebSocket server) started successfully. Returning `false` aborts the
  /// connection so the UI can show the failure.
  Future<void> connect({
    required void Function(double speedKmh) onSpeed,
    required Future<bool> Function() onConnected,
    required void Function() onTimeout,
    required void Function(Object error) onError,
    required void Function() onDisconnected,
  }) async {
    await stop();
    _stopping = false;
    _connecting = false;
    _speedKmh = 0;

    try {
      if (!await FlutterBluePlus.isSupported) {
        onError(StateError('Bluetooth LE is not supported on this device.'));
        return;
      }

      // Reading the stream (instead of `adapterStateNow`) makes the plugin
      // fetch the real adapter state first. The cached getter stays `unknown`
      // until the adapter-state stream has been read once, which used to make
      // this check fail even when Bluetooth was already enabled.
      var adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        await FlutterBluePlus.turnOn();
        adapterState = await FlutterBluePlus.adapterState.first;
      }
      if (_stopping) return;
      if (adapterState != BluetoothAdapterState.on) {
        onError(StateError('Bluetooth is turned off.'));
        return;
      }

      // Some Android stacks need a moment after the adapter turns on.
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (_stopping) return;
      if (FlutterBluePlus.isScanningNow) {
        await FlutterBluePlus.stopScan();
      }

      _scanResultsSubscription = FlutterBluePlus.scanResults.listen(
        (results) => _handleScanResults(
          results,
          onSpeed: onSpeed,
          onConnected: onConnected,
          onError: onError,
          onDisconnected: onDisconnected,
        ),
        onError: onError,
      );

      const scanTimeout = Duration(seconds: 10);
      _scanTimeoutTimer = Timer(scanTimeout + const Duration(seconds: 1), () {
        if (_stopping || _connected || _connecting) return;
        FlutterBluePlus.stopScan();
        onTimeout();
      });

      await FlutterBluePlus.startScan(timeout: scanTimeout);
      if (_stopping) {
        await FlutterBluePlus.stopScan();
      }
    } catch (error) {
      await stop();
      onError(error);
    }
  }

  /// Stops scanning, cancels notifications and disconnects the sensor.
  Future<void> stop() async {
    _stopping = true;

    _scanTimeoutTimer?.cancel();
    _scanTimeoutTimer = null;
    _speedTimeoutTimer?.cancel();
    _speedTimeoutTimer = null;

    await _scanResultsSubscription?.cancel();
    _scanResultsSubscription = null;
    await _measurementSubscription?.cancel();
    _measurementSubscription = null;
    await _connectionSubscription?.cancel();
    _connectionSubscription = null;

    try {
      if (FlutterBluePlus.isScanningNow) {
        await FlutterBluePlus.stopScan();
      }
    } catch (_) {
      // The platform plugin is not available (desktop, tests, web).
    }

    final device = _device;
    _device = null;
    _connected = false;
    _connecting = false;
    _speedKmh = 0;
    _lastWheelRevolutions = null;
    _lastWheelEventTime = null;

    if (device != null) {
      try {
        await device.disconnect();
      } catch (_) {
        // The sensor may already be gone.
      }
    }
  }

  /// Picks the first advertised speed/cadence sensor and connects to it.
  Future<void> _handleScanResults(
    List<ScanResult> results, {
    required void Function(double speedKmh) onSpeed,
    required Future<bool> Function() onConnected,
    required void Function(Object error) onError,
    required void Function() onDisconnected,
  }) async {
    if (_connected || _connecting || _stopping) return;

    for (final result in results) {
      final name = result.device.platformName.toLowerCase();
      final advertisedServices = result.advertisementData.serviceUuids
          .map((uuid) => uuid.toString().toLowerCase())
          .join(' ');
      final isCscSensor =
          advertisedServices.contains(cscServiceUuid) ||
          name.contains('speed') ||
          name.contains('cadence');

      if (!isCscSensor) continue;

      _connecting = true;
      _scanTimeoutTimer?.cancel();
      _scanTimeoutTimer = null;
      await _scanResultsSubscription?.cancel();
      _scanResultsSubscription = null;
      try {
        await FlutterBluePlus.stopScan();
      } catch (_) {
        // Ignore: the scan may already have timed out.
      }

      try {
        final device = result.device;
        _device = device;
        await device.connect(license: License.nonprofit);

        if (_stopping) {
          await device.disconnect();
          return;
        }

        _connected = true;
        _connectionSubscription = device.connectionState.listen((state) {
          if (state == BluetoothConnectionState.disconnected && !_stopping) {
            _connected = false;
            _speedKmh = 0;
            onDisconnected();
          }
        });

        final serverStarted = await onConnected();
        if (!serverStarted) {
          await stop();
          return;
        }
        if (_stopping) return;

        final services = await device.discoverServices();
        BluetoothCharacteristic? measurement;
        for (final service in services) {
          if (!service.uuid.toString().contains(cscServiceUuid)) continue;
          for (final characteristic in service.characteristics) {
            if (characteristic.uuid.toString().contains(
              cscMeasurementCharacteristicUuid,
            )) {
              measurement = characteristic;
              break;
            }
          }
        }

        if (measurement == null) {
          throw StateError(
            'The sensor does not expose a CSC measurement characteristic.',
          );
        }

        await measurement.setNotifyValue(true);
        _measurementSubscription = measurement.lastValueStream.listen(
          (value) => _decodeCscData(value, onSpeed),
          onError: onError,
        );
      } catch (error) {
        await stop();
        onError(error);
      }

      break;
    }
  }

  /// Decodes a CSC measurement payload into km/h.
  ///
  /// Layout (Bluetooth SIG): flags, cumulative wheel revolutions (uint32,
  /// little endian), last wheel event time (uint16, 1/1024 s).
  void _decodeCscData(List<int> value, void Function(double speedKmh) onSpeed) {
    if (value.isEmpty) return;

    final flags = value[0];
    final hasWheelData = (flags & 0x01) != 0;
    if (!hasWheelData || value.length < 7) return;

    final wheelRevolutions =
        value[1] | (value[2] << 8) | (value[3] << 16) | (value[4] << 24);
    final wheelEventTime = value[5] | (value[6] << 8);

    if (_lastWheelRevolutions != null && _lastWheelEventTime != null) {
      var deltaRotations = wheelRevolutions - _lastWheelRevolutions!;
      var deltaEventTime = wheelEventTime - _lastWheelEventTime!;

      // Both counters are unsigned and wrap around; compensate the rollover.
      if (deltaRotations < 0) deltaRotations += 0x100000000;
      if (deltaEventTime < 0) deltaEventTime += 0x10000;

      if (deltaRotations > 0 && deltaEventTime > 0) {
        final seconds = deltaEventTime / 1024.0;
        final speedMps = (deltaRotations * _circumferenceMeters) / seconds;
        _speedKmh = speedMps * 3.6;
        onSpeed(_speedKmh);
      }
    }

    _lastWheelRevolutions = wheelRevolutions;
    _lastWheelEventTime = wheelEventTime;

    // No wheel event for a second means the wheel has stopped.
    _speedTimeoutTimer?.cancel();
    _speedTimeoutTimer = Timer(const Duration(seconds: 1), () {
      _speedKmh = 0;
      onSpeed(0);
    });
  }
}
