import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/background_location_service.dart';
import '../../core/services/location_service.dart';
import '../../core/utils/geo_utils.dart';
import '../../data/models/activity.dart';
import '../../data/models/gear.dart';
import '../../data/models/segment_effort.dart';
import '../../data/models/track_point.dart';
import '../../data/repositories/activity_repository.dart';
import '../../data/repositories/gear_repository.dart';
import '../../data/services/segment_effort_service.dart';

/// Lifecycle of a recording session.
enum RecordingStatus {
  /// Nothing is being recorded.
  idle,

  /// The GPS stream has been requested but no fix has arrived yet.
  acquiring,

  /// The recording is running.
  recording,

  /// The recording is temporarily paused.
  paused,

  /// The recording has been stopped and awaits confirmation.
  finished;

  /// Whether the recording currently consumes GPS fixes.
  bool get isActive => this == RecordingStatus.recording || this == RecordingStatus.paused;
}

/// An immutable snapshot of a finished recording.
class RecordingSummary {
  /// The recorded GPS samples.
  final List<TrackPoint> points;

  /// Total distance (metres).
  final double distanceMeters;

  /// Time spent moving (milliseconds).
  final int movingTimeMs;

  /// Wall clock duration (milliseconds).
  final int elapsedTimeMs;

  /// Average moving speed (metres per second).
  final double avgSpeedMps;

  /// Highest instantaneous speed (metres per second).
  final double maxSpeedMps;

  /// Cumulative ascent (metres).
  final double elevationGainMeters;

  /// When the recording started.
  final DateTime startedAt;

  /// When the recording stopped.
  final DateTime endedAt;

  /// The gear selected when the recording started.
  final int? gearId;

  /// Segment efforts matched against the recorded track.
  final List<SegmentEffort> segmentEfforts;

  const RecordingSummary({
    required this.points,
    required this.distanceMeters,
    required this.movingTimeMs,
    required this.elapsedTimeMs,
    required this.avgSpeedMps,
    required this.maxSpeedMps,
    required this.elevationGainMeters,
    required this.startedAt,
    required this.endedAt,
    this.gearId,
    this.segmentEfforts = const <SegmentEffort>[],
  });

  /// Average speed derived from the distance and the moving time.
  double get averageSpeedMps => movingTimeMs > 0
      ? distanceMeters / (movingTimeMs / 1000.0)
      : avgSpeedMps;
}

/// Drives a GPS recording session.
///
/// The controller owns the whole recording pipeline: it subscribes to the
/// location stream, filters noisy fixes, accumulates distance / moving time /
/// elevation and finally persists the activity together with its GPS track.
class RecordController extends ChangeNotifier {
  /// Creates the controller.
  RecordController({
    required LocationService locationService,
    required BackgroundLocationService backgroundLocationService,
    required ActivityRepository activityRepository,
    required GearRepository gearRepository,
    required SegmentEffortService segmentEffortService,
  })  : _locationService = locationService,
        _backgroundLocationService = backgroundLocationService,
        _activityRepository = activityRepository,
        _gearRepository = gearRepository,
        _segmentEffortService = segmentEffortService;

  final LocationService _locationService;
  final BackgroundLocationService _backgroundLocationService;
  final ActivityRepository _activityRepository;
  final GearRepository _gearRepository;
  final SegmentEffortService _segmentEffortService;

  StreamSubscription<LocationFix>? _positionSubscription;
  Timer? _ticker;

  RecordingStatus _status = RecordingStatus.idle;
  final List<TrackPoint> _points = <TrackPoint>[];
  LocationFix? _currentFix;

  /// The first fix is held back until a second one confirms that the pair is
  /// physically plausible. Android can replay a cached last-known location
  /// with a fresh timestamp; appending it immediately would connect that old
  /// position to the real start with a phantom straight line.
  LocationFix? _pendingFirstFix;

  Gear? _selectedGear;

  double _distanceMeters = 0;
  int _movingTimeMs = 0;
  double _maxSpeedMps = 0;
  double _elevationGainMeters = 0;
  double _elevationReference = double.nan;
  DateTime? _startedAt;
  DateTime? _endedAt;
  int _pausedDurationMs = 0;
  DateTime? _pausedAt;
  DateTime? _stationarySince;
  bool _autoPause = false;
  String? _errorMessage;

  /// Current status of the recording.
  RecordingStatus get status => _status;

  /// Whether a recording is currently running.
  bool get isRecording => _status == RecordingStatus.recording;

  /// Whether the recording is paused.
  bool get isPaused => _status == RecordingStatus.paused;

  /// The most recent GPS fix.
  LocationFix? get currentFix => _currentFix;

  /// The recorded GPS samples.
  List<TrackPoint> get points => List<TrackPoint>.unmodifiable(_points);

  /// Total distance (metres).
  double get distanceMeters => _distanceMeters;

  /// Time spent moving (milliseconds).
  int get movingTimeMs => _movingTimeMs;

  /// Wall clock duration (milliseconds), excluding paused time.
  int get elapsedTimeMs {
    final startedAt = _startedAt;
    if (startedAt == null) return 0;
    final end = _endedAt ?? DateTime.now();
    final paused = _pausedAt != null
        ? DateTime.now().difference(_pausedAt!).inMilliseconds
        : 0;
    return end.difference(startedAt).inMilliseconds - _pausedDurationMs - paused;
  }

  /// Average moving speed (metres per second).
  double get avgSpeedMps =>
      _movingTimeMs > 0 ? _distanceMeters / (_movingTimeMs / 1000.0) : 0;

  /// Highest instantaneous speed (metres per second).
  double get maxSpeedMps => _maxSpeedMps;

  /// Cumulative ascent (metres).
  double get elevationGainMeters => _elevationGainMeters;

  /// The gear selected for the current recording.
  Gear? get selectedGear => _selectedGear;

  /// The last error that occurred during the recording.
  String? get errorMessage => _errorMessage;

  /// The number of accepted GPS samples.
  int get sampleCount => _points.length;

  /// Selects the gear used for the next recording.
  void selectGear(Gear? gear) {
    _selectedGear = gear;
    notifyListeners();
  }

  /// Pre-selects the persisted default gear when nothing has been chosen yet.
  ///
  /// The record screen calls this on first build so the header already shows
  /// the default gear before the athlete taps "Start recording".
  Future<void> ensureDefaultGear() async {
    if (_selectedGear != null) return;

    final gear = await _gearRepository.defaultGear();
    if (gear == null || _selectedGear != null) return;

    _selectedGear = gear;
    notifyListeners();
  }

  /// Clears the last error.
  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  /// Requests the permissions and starts the GPS stream.
  ///
  /// Returns `true` when the recording actually started.
  Future<bool> start({
    required bool allowBackground,
    bool autoPause = false,
  }) async {
    if (_status.isActive) return true;

    _errorMessage = null;
    _autoPause = autoPause;

    final permission = await _locationService.requestPermission();
    if (permission == LocationPermissionState.serviceDisabled) {
      _errorMessage = 'Location services are turned off on this device.';
      notifyListeners();
      return false;
    }
    if (permission == LocationPermissionState.deniedForever) {
      _errorMessage =
          'Location permission was permanently denied. Enable it in the system settings.';
      notifyListeners();
      return false;
    }
    if (permission == LocationPermissionState.denied) {
      _errorMessage = 'Location permission is required to record an activity.';
      notifyListeners();
      return false;
    }

    if (allowBackground) {
      await _backgroundLocationService.prepare();
    }

    _resetSession();
    _status = RecordingStatus.acquiring;
    _startedAt = DateTime.now();
    notifyListeners();

    _ticker = Timer.periodic(AppConstants.tickerInterval, (_) {
      notifyListeners();
    });

    final options = LocationTrackingOptions(
      interval: AppConstants.gpsInterval,
      distanceFilterMeters: AppConstants.gpsDistanceFilterMeters,
      allowBackground: allowBackground && _backgroundLocationService.isSupported,
      notificationTitle: 'TrainCenter',
      notificationText: 'Recording your activity',
    );

    try {
      _positionSubscription = _locationService.watch(options).listen(
            _onFix,
            onError: (Object error) {
              _errorMessage = 'GPS error: $error';
              notifyListeners();
            },
            cancelOnError: false,
          );
    } on Object catch (error) {
      _errorMessage = 'Unable to start the GPS stream: $error';
      _status = RecordingStatus.idle;
      notifyListeners();
      return false;
    }

    // Pre-select the default gear for convenience.
    _selectedGear ??= await _gearRepository.defaultGear();

    return true;
  }

  /// Pauses the recording. The GPS stream keeps running so the app can resume
  /// instantly.
  void pause() {
    if (_status != RecordingStatus.recording) return;
    _status = RecordingStatus.paused;
    _pausedAt = DateTime.now();
    _stationarySince = null;
    notifyListeners();
  }

  /// Resumes a paused recording.
  void resume() {
    if (_status != RecordingStatus.paused) return;
    final pausedAt = _pausedAt;
    if (pausedAt != null) {
      _pausedDurationMs += DateTime.now().difference(pausedAt).inMilliseconds;
    }
    _pausedAt = null;
    _stationarySince = null;
    _status = RecordingStatus.recording;
    notifyListeners();
  }

  /// Stops the recording and returns a summary of the session.
  ///
  /// The data is *not* persisted yet — the finish screen asks the user to
  /// confirm with the slide-to-save interaction first.
  RecordingSummary stop() {
    // Calling stop again (for example after closing the summary with the
    // system back gesture and tapping "Review summary") must not move the
    // end timestamp. Otherwise the elapsed time would keep growing while the
    // recording is already complete.
    if (_status == RecordingStatus.finished ||
        _status == RecordingStatus.idle) {
      return _buildSummary();
    }

    _ticker?.cancel();
    _ticker = null;
    _positionSubscription?.cancel();
    _positionSubscription = null;

    final now = DateTime.now();
    _endedAt = now;
    _status = RecordingStatus.finished;
    notifyListeners();

    return _buildSummary();
  }

  /// Discards the current session without saving anything.
  void discard() {
    _ticker?.cancel();
    _ticker = null;
    _positionSubscription?.cancel();
    _positionSubscription = null;

    _resetSession();
    _status = RecordingStatus.idle;
    notifyListeners();
  }

  /// Persists the finished recording and returns the stored activity.
  ///
  /// Also updates the accumulated distance of the selected gear and computes
  /// the local segment efforts (including personal bests).
  Future<Activity> save({
    String? title,
    String? note,
    int? gearId,
  }) async {
    final summary = _buildSummary();
    final startedAt = summary.startedAt;
    final endedAt = summary.endedAt;

    final activity = Activity(
      title: title?.trim().isEmpty == true ? null : title?.trim(),
      gearId: gearId ?? _selectedGear?.id,
      startedAt: startedAt,
      endedAt: endedAt,
      distanceMeters: summary.distanceMeters,
      movingTimeMs: summary.movingTimeMs,
      elapsedTimeMs: summary.elapsedTimeMs,
      avgSpeedMps: summary.avgSpeedMps,
      maxSpeedMps: summary.maxSpeedMps,
      elevationGainMeters: summary.elevationGainMeters,
      note: note?.trim().isEmpty == true ? null : note?.trim(),
      createdAt: DateTime.now(),
    );

    final activityId = await _activityRepository.insertActivity(activity, summary.points);

    final resolvedGearId = activity.gearId;
    if (resolvedGearId != null) {
      await _gearRepository.addDistance(resolvedGearId, summary.distanceMeters);
    }

    // Compute the local segment efforts / personal bests.
    await _segmentEffortService.recordEffortsForActivity(activityId, summary.points);

    final saved = activity.copyWith(id: activityId);
    _resetSession();
    _status = RecordingStatus.idle;
    notifyListeners();

    return saved;
  }

  /// Handles a single GPS fix.
  void _onFix(LocationFix fix) {
    _currentFix = fix;

    if (_status == RecordingStatus.acquiring) {
      _status = RecordingStatus.recording;
    }

    if (_status != RecordingStatus.recording) {
      notifyListeners();
      return;
    }

    if (_points.isEmpty) {
      _considerFirstFix(fix);
    } else if (_isAcceptable(fix)) {
      _appendPoint(fix);
      _handleAutoPause(fix);
    }

    notifyListeners();
  }

  /// Validates the first two fixes before starting the track.
  ///
  /// The first candidate is buffered. If the second fix is physically
  /// reachable from it, both are kept; otherwise the first one is assumed to
  /// be a cached last-known location and is discarded. This catches stale
  /// fixes even when the platform refreshes their timestamp.
  void _considerFirstFix(LocationFix fix) {
    final pending = _pendingFirstFix;
    if (pending == null) {
      if (_isAcceptable(fix)) _pendingFirstFix = fix;
      return;
    }

    if (!_isAcceptable(fix)) return;

    final distance = GeoUtils.distanceMeters(
      lat1: pending.latitude,
      lon1: pending.longitude,
      lat2: fix.latitude,
      lon2: fix.longitude,
    );
    final deltaSeconds =
        fix.timestamp.difference(pending.timestamp).inMilliseconds / 1000.0;

    if (deltaSeconds > 0 &&
        distance / deltaSeconds <= AppConstants.maxPlausibleSpeedMps) {
      _appendPoint(pending);
      _appendPoint(fix);
      _pendingFirstFix = null;
      _handleAutoPause(fix);
    } else {
      // The buffered fix was stale; make the current one the new candidate.
      _pendingFirstFix = fix;
    }
  }

  /// Pauses the recording automatically when the athlete stops moving.
  ///
  /// The pause only happens after [AppConstants.autoPauseDelay] of continuous
  /// standstill so a short stop at a traffic light does not interrupt the
  /// moving time.
  void _handleAutoPause(LocationFix fix) {
    if (!_autoPause) return;

    final speed = fix.speedMps ?? 0;
    if (speed >= AppConstants.movingSpeedThresholdMps) {
      _stationarySince = null;
      return;
    }

    _stationarySince ??= fix.timestamp;
    final stationary = fix.timestamp.difference(_stationarySince!);
    if (stationary >= AppConstants.autoPauseDelay) {
      pause();
    }
  }

  /// Decides whether a fix is good enough to be recorded.
  bool _isAcceptable(LocationFix fix) {
    final accuracy = fix.accuracyMeters;
    if (accuracy != null && accuracy > AppConstants.maxAcceptedAccuracyMeters) {
      return false;
    }

    if (_points.isEmpty) {
      // Ignore a stale cached fix at the start of a recording. Without this
      // check the old location becomes the first sample and the first fresh
      // fix is joined to it by a long phantom line.
      final age = DateTime.now().difference(fix.timestamp);
      return age <= AppConstants.maxInitialFixAge;
    }

    final previous = _points.last;
    final distance = GeoUtils.distanceMeters(
      lat1: previous.latitude,
      lon1: previous.longitude,
      lat2: fix.latitude,
      lon2: fix.longitude,
    );

    // Reject teleports caused by a GPS re-acquisition and out-of-order fixes.
    final deltaSeconds =
        fix.timestamp.difference(previous.timestamp).inMilliseconds / 1000.0;
    if (deltaSeconds <= 0) return false;
    if (distance / deltaSeconds > AppConstants.maxPlausibleSpeedMps) {
      return false;
    }

    return true;
  }

  /// Appends a fix to the track and updates the live statistics.
  void _appendPoint(LocationFix fix) {
    final isFirst = _points.isEmpty;
    TrackPoint? previous;

    if (!isFirst) {
      previous = _points.last;
      final distance = GeoUtils.distanceMeters(
        lat1: previous.latitude,
        lon1: previous.longitude,
        lat2: fix.latitude,
        lon2: fix.longitude,
      );

      // Ignore GPS jitter while standing still.
      if (distance < AppConstants.minPointDistanceMeters) {
        return;
      }

      _distanceMeters += distance;

      final deltaMs = fix.timestamp.difference(previous.timestamp).inMilliseconds;
      if (deltaMs > 0) {
        final impliedSpeed = distance / (deltaMs / 1000.0);
        // Some platforms report 0 (or an otherwise stale value) for the
        // instantaneous speed. Use the larger of the reported and the
        // distance-derived speed so the maximum can never fall below the
        // average speed shown on the summary.
        final measuredSpeed = math.max(fix.speedMps ?? 0, impliedSpeed);
        if (measuredSpeed > _maxSpeedMps) {
          _maxSpeedMps = measuredSpeed;
        }
        if (impliedSpeed >= AppConstants.movingSpeedThresholdMps) {
          _movingTimeMs += deltaMs;
        }
      }
    }

    _points.add(
      TrackPoint(
        seq: _points.length,
        latitude: fix.latitude,
        longitude: fix.longitude,
        altitude: fix.altitude,
        speed: fix.speedMps,
        accuracy: fix.accuracyMeters,
        timestamp: fix.timestamp,
      ),
    );

    _updateElevation(fix.altitude);
  }

  /// Accumulates the ascent with a simple noise gate.
  void _updateElevation(double? altitude) {
    if (altitude == null) return;

    if (_elevationReference.isNaN) {
      _elevationReference = altitude;
      return;
    }

    final delta = altitude - _elevationReference;
    if (delta.abs() < AppConstants.minElevationDeltaMeters) return;

    if (delta > 0) {
      _elevationGainMeters += delta;
    }
    _elevationReference = altitude;
  }

  /// Builds an immutable snapshot of the current session.
  RecordingSummary _buildSummary() {
    final startedAt = _startedAt ?? DateTime.now();
    final endedAt = _endedAt ?? DateTime.now();

    return RecordingSummary(
      points: List<TrackPoint>.unmodifiable(_points),
      distanceMeters: _distanceMeters,
      movingTimeMs: _movingTimeMs,
      elapsedTimeMs: endedAt.difference(startedAt).inMilliseconds -
          _pausedDurationMs -
          (_pausedAt != null
              ? DateTime.now().difference(_pausedAt!).inMilliseconds
              : 0),
      avgSpeedMps: avgSpeedMps,
      maxSpeedMps: _maxSpeedMps,
      elevationGainMeters: _elevationGainMeters,
      startedAt: startedAt,
      endedAt: endedAt,
      gearId: _selectedGear?.id,
    );
  }

  /// Clears every accumulated metric.
  void _resetSession() {
    _points.clear();
    _currentFix = null;
    _pendingFirstFix = null;
    _distanceMeters = 0;
    _movingTimeMs = 0;
    _maxSpeedMps = 0;
    _elevationGainMeters = 0;
    _elevationReference = double.nan;
    _startedAt = null;
    _endedAt = null;
    _pausedDurationMs = 0;
    _pausedAt = null;
    _stationarySince = null;
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _positionSubscription?.cancel();
    _locationService.dispose();
    _backgroundLocationService.dispose();
    super.dispose();
  }
}
