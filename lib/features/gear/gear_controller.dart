import 'package:flutter/foundation.dart';

import '../../data/models/gear.dart';
import '../../data/repositories/gear_repository.dart';

/// Holds the equipment list.
class GearController extends ChangeNotifier {
  /// Creates the controller.
  GearController(this._repository);

  final GearRepository _repository;

  List<Gear> _gear = <Gear>[];
  bool _loading = true;

  /// The registered equipment.
  List<Gear> get gear => List<Gear>.unmodifiable(_gear);

  /// Whether the initial load is still running.
  bool get isLoading => _loading;

  /// The gear flagged as default, or `null` when there is none.
  Gear? get defaultGear {
    for (final item in _gear) {
      if (item.isDefault) return item;
    }
    return null;
  }

  /// Reloads the equipment from the local database.
  Future<void> load() async {
    _gear = await _repository.listGear();
    _loading = false;
    notifyListeners();
  }

  /// Inserts or updates a piece of equipment.
  ///
  /// Returns the identifier of the stored gear.
  Future<int> save(Gear gear) async {
    if (gear.id == null) {
      final id = await _repository.insertGear(gear);
      await load();
      return id;
    }
    await _repository.updateGear(gear);
    await load();
    return gear.id!;
  }

  /// Deletes a piece of equipment.
  Future<void> delete(Gear gear) async {
    final id = gear.id;
    if (id == null) return;
    await _repository.deleteGear(id);
    await load();
  }

  /// Marks a piece of equipment as the default one.
  Future<void> setDefault(Gear gear) async {
    final id = gear.id;
    if (id == null) return;
    await _repository.setDefaultGear(id);
    await load();
  }

  /// Resets the accumulated distance of a piece of equipment.
  Future<void> resetDistance(Gear gear) async {
    final id = gear.id;
    if (id == null) return;
    await _repository.resetDistance(id);
    await load();
  }
}
