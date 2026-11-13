import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'core/db/app_database.dart';
import 'core/services/offline_map_store.dart';

/// Entry point of TrainCenter.
///
/// The local database is opened *before* the first frame so the rest of the
/// application can work with a ready repository. There is no network call
/// anywhere in this bootstrap.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // The record screen is designed for portrait. Allowing landscape without a
  // dedicated side-by-side layout made the statistics panel cover the map and
  // clip its own header on short screens, so keep the app portrait-only until
  // a proper landscape layout exists.
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
  ]);

  // Open (and migrate) the on-device database.
  final database = AppDatabase();
  await database.open();

  // Resolve the app-support directory before the first map is built. This
  // only creates a local folder; it never touches the network.
  await OfflineMapStore.instance.initialize();

  runApp(TrainCenterApp(database: database));
}
