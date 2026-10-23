import '../../data/models/segment_effort.dart';
import '../../data/models/track_point.dart';
import '../../data/repositories/segment_repository.dart';
import '../../domain/services/segment_matcher.dart';

/// Orchestrates the local personal best (PR) bookkeeping for segments.
///
/// The matching itself is pure logic (see [SegmentMatcher]); this service
/// only takes care of persisting the results and maintaining the PR flags.
class SegmentEffortService {
  /// Creates the service.
  SegmentEffortService(this._repository);

  final SegmentRepository _repository;

  /// Matches the given [points] against every stored segment and persists the
  /// resulting efforts.
  ///
  /// Returns the efforts that were created, including the ones that earned a
  /// new personal best.
  Future<List<SegmentEffort>> recordEffortsForActivity(
    int activityId,
    List<TrackPoint> points,
  ) async {
    final segments = await _repository.listSegments();
    if (segments.isEmpty || points.length < 2) return const <SegmentEffort>[];

    final bestEfforts = <int, SegmentEffort>{};
    for (final segment in segments) {
      final best = await _repository.bestEffort(segment.id!);
      if (best != null) bestEfforts[segment.id!] = best;
    }

    final matches = SegmentMatcher.match(
      segments: segments,
      points: points,
      bestEfforts: bestEfforts,
    );

    final created = <SegmentEffort>[];

    for (final match in matches) {
      final segmentId = match.segment.id!;

      if (match.isPersonalBest) {
        // Demote the previous personal best before storing the new one.
        final previous = bestEfforts[segmentId];
        if (previous != null && previous.isPersonalBest) {
          await _repository.updateEffort(previous.copyWith(isPersonalBest: false));
        }
      }

      final effort = SegmentEffort(
        segmentId: segmentId,
        activityId: activityId,
        timeMs: match.timeMs,
        avgSpeedMps: match.avgSpeedMps,
        isPersonalBest: match.isPersonalBest,
        achievedAt: points.isEmpty ? DateTime.now() : points.last.timestamp,
      );

      final id = await _repository.insertEffort(effort);
      created.add(effort.copyWith(id: id));
    }

    return created;
  }

  /// Returns the personal best effort of a segment, or `null`.
  Future<SegmentEffort?> personalBest(int segmentId) =>
      _repository.bestEffort(segmentId);

  /// Returns every effort recorded on a segment, fastest first.
  Future<List<SegmentEffort>> history(int segmentId) =>
      _repository.effortsFor(segmentId);
}
