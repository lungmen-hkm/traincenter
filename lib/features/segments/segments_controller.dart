import 'package:flutter/foundation.dart';

import '../../data/models/segment.dart';
import '../../data/models/segment_effort.dart';
import '../../data/repositories/segment_repository.dart';

/// Holds the locally defined segments and their effort history.
class SegmentsController extends ChangeNotifier {
  /// Creates the controller.
  SegmentsController(this._repository);

  final SegmentRepository _repository;

  List<Segment> _segments = <Segment>[];
  final Map<int, List<SegmentEffort>> _efforts = <int, List<SegmentEffort>>{};
  bool _loading = true;

  /// The defined segments.
  List<Segment> get segments => List<Segment>.unmodifiable(_segments);

  /// Whether the initial load is still running.
  bool get isLoading => _loading;

  /// The effort history of a segment, fastest first.
  List<SegmentEffort> effortsFor(int segmentId) =>
      List<SegmentEffort>.unmodifiable(_efforts[segmentId] ?? const <SegmentEffort>[]);

  /// The personal best effort of a segment, or `null`.
  SegmentEffort? personalBest(int segmentId) {
    final efforts = _efforts[segmentId];
    if (efforts == null || efforts.isEmpty) return null;
    return efforts.first;
  }

  /// Reloads the segments and their effort history from the local database.
  ///
  /// The efforts have to be loaded eagerly: the list screen shows the current
  /// personal best for every segment, and the database is the only source of
  /// truth after a recording has been saved.
  Future<void> load() async {
    final segments = await _repository.listSegments();

    final efforts = <int, List<SegmentEffort>>{};
    for (final segment in segments) {
      efforts[segment.id!] = await _repository.effortsFor(segment.id!);
    }

    _segments = segments;
    _efforts
      ..clear()
      ..addAll(efforts);
    _loading = false;
    notifyListeners();
  }

  /// Loads the effort history of a segment.
  Future<void> loadEfforts(int segmentId) async {
    _efforts[segmentId] = await _repository.effortsFor(segmentId);
    notifyListeners();
  }

  /// Inserts or updates a segment.
  Future<int> save(Segment segment) async {
    if (segment.id == null) {
      final id = await _repository.insertSegment(segment);
      await load();
      return id;
    }
    await _repository.updateSegment(segment);
    await load();
    return segment.id!;
  }

  /// Deletes a segment and its efforts.
  Future<void> delete(Segment segment) async {
    final id = segment.id;
    if (id == null) return;
    await _repository.deleteSegment(id);
    _efforts.remove(id);
    await load();
  }
}
