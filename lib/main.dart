import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'core/db/app_database.dart';

/// Entry point of TrainCenter.
///
/// The local database is opened *before* the first frame so the rest of the
/// application can work with a ready repository. There is no network call
/// anywhere in this bootstrap.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Open (and migrate) the on-device database.
  final database = AppDatabase();
  await database.open();

  runApp(TrainCenterApp(database: database));
}
