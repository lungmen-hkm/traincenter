import 'package:flutter/foundation.dart';

import '../../data/models/activity.dart';
import '../../data/repositories/activity_repository.dart';
import '../../data/repositories/gear_repository.dart';
import '../../data/repositories/segment_repository.dart';

/// Holds the list of recorded activities and the global statistics.
class ActivitiesController extends ChangeNotifier {
  /// Creates the controller.
  ActivitiesController(
    this._repository,
    this._gearRepository,
    this._segmentRepository,
  );

  final ActivityRepository _repository;
  final GearRepository _gearRepository;
  final SegmentRepository _segmentRepository;

  List<Activity> _activities = <Activity>[];
  bool _loading = true;

  /// The recorded activities, newest first.
  List<Activity> get activities => List<Activity>.unmodifiable(_activities);

  /// Whether the initial load is still running.
  bool get isLoading => _loading;

  /// Sum of the distance of every activity (metres).
  double get totalDistanceMeters => _activities.fold<double>(
        0,
        (sum, activity) => sum + activity.distanceMeters,
      );

  /// Sum of the moving time of every activity (milliseconds).
  int get totalMovingTimeMs => _activities.fold<int>(
        0,
        (sum, activity) => sum + activity.movingTimeMs,
      );

  /// Sum of the elevation gain of every activity (metres).
  double get totalElevationGainMeters => _activities.fold<double>(
        0,
        (sum, activity) => sum + activity.elevationGainMeters,
      );

  /// Reloads the activities from the local database.
  Future<void> load() async {
    _activities = await _repository.listActivities();
    _loading = false;
    notifyListeners();
  }

  /// Deletes an activity and its GPS track.
  Future<void> delete(Activity activity) async {
    final id = activity.id;
    if (id == null) return;
    final gearId = activity.gearId;
    await _repository.deleteActivity(id);

    // The mileage of the gear is a running total; deleting an activity must
    // remove the distance it contributed to it.
    if (gearId != null) {
      await _gearRepository.subtractDistance(gearId, activity.distanceMeters);
    }

    // If the deleted activity held a segment PR, promote the next-fastest
    // remaining effort so the badge stays correct.
    await _segmentRepository.recalculatePersonalBests();

    _activities = _activities.where((a) => a.id != id).toList(growable: false);
    notifyListeners();
  }

  /// Persists changes made to an activity.
  Future<void> update(Activity activity) async {
    await _repository.updateActivity(activity);
    final index = _activities.indexWhere((a) => a.id == activity.id);
    if (index == -1) return;
    final updated = List<Activity>.of(_activities);
    updated[index] = activity;
    _activities = updated;
    notifyListeners();
  }
}
