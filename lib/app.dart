import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'core/db/app_database.dart';
import 'core/services/background_location_service.dart';
import 'core/services/geolocator_location_service.dart';
import 'core/services/location_service.dart';
import 'core/services/offline_map_store.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/activity_repository.dart';
import 'data/repositories/gear_repository.dart';
import 'data/repositories/segment_repository.dart';
import 'data/repositories/settings_repository.dart';
import 'data/services/segment_effort_service.dart';
import 'features/activities/activities_controller.dart';
import 'features/gear/gear_controller.dart';
import 'features/record/record_controller.dart';
import 'features/segments/segments_controller.dart';
import 'features/settings/app_settings.dart';
import 'features/settings/offline_map_controller.dart';
import 'features/shell/home_shell.dart';
import 'features/trainercraft/trainercraft_controller.dart';

/// Root widget of TrainCenter.
///
/// The theme is built from the *dynamic* colour scheme provided by the
/// platform (Material You on Android 12+, accent colours on desktop). When
/// the platform does not expose one, a seeded fallback scheme is used.
class TrainCenterApp extends StatelessWidget {
  /// Creates the application.
  const TrainCenterApp({
    super.key,
    required this.database,
    this.locationService,
    this.backgroundLocationService,
  });

  /// The opened local database.
  final AppDatabase database;

  /// Optional override for the location service (e.g. in tests).
  final LocationService? locationService;

  /// Optional override for the background location service (e.g. in tests).
  final BackgroundLocationService? backgroundLocationService;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: <SingleChildWidget>[
        // --- Data layer ----------------------------------------------------
        Provider<AppDatabase>.value(value: database),
        Provider<ActivityRepository>(
          create: (context) => ActivityRepository(context.read<AppDatabase>()),
        ),
        Provider<GearRepository>(
          create: (context) => GearRepository(context.read<AppDatabase>()),
        ),
        Provider<SegmentRepository>(
          create: (context) => SegmentRepository(context.read<AppDatabase>()),
        ),
        Provider<SettingsRepository>(
          create: (context) => SettingsRepository(context.read<AppDatabase>()),
        ),
        Provider<SegmentEffortService>(
          create: (context) =>
              SegmentEffortService(context.read<SegmentRepository>()),
        ),

        // --- Platform services ---------------------------------------------
        Provider<LocationService>(
          create: (_) => locationService ?? GeolocatorLocationService(),
        ),
        Provider<BackgroundLocationService>(
          create: (_) =>
              backgroundLocationService ?? createBackgroundLocationService(),
        ),
        Provider<OfflineMapStore>.value(value: OfflineMapStore.instance),

        // --- State ----------------------------------------------------------
        ChangeNotifierProvider<AppSettings>(
          create: (context) =>
              AppSettings(context.read<SettingsRepository>())..load(),
        ),
        ChangeNotifierProvider<OfflineMapController>(
          create: (context) =>
              OfflineMapController(context.read<OfflineMapStore>())..load(),
        ),
        ChangeNotifierProvider<ActivitiesController>(
          create: (context) => ActivitiesController(
            context.read<ActivityRepository>(),
            context.read<GearRepository>(),
            context.read<SegmentRepository>(),
          )..load(),
        ),
        ChangeNotifierProvider<GearController>(
          create: (context) =>
              GearController(context.read<GearRepository>())..load(),
        ),
        ChangeNotifierProvider<SegmentsController>(
          create: (context) =>
              SegmentsController(context.read<SegmentRepository>())..load(),
        ),
        ChangeNotifierProvider<RecordController>(
          create: (context) => RecordController(
            locationService: context.read<LocationService>(),
            backgroundLocationService: context
                .read<BackgroundLocationService>(),
            activityRepository: context.read<ActivityRepository>(),
            gearRepository: context.read<GearRepository>(),
            segmentEffortService: context.read<SegmentEffortService>(),
          ),
        ),

        // --- TrainerCraft companion bridge ---------------------------------
        // Registered at the root so the local WebSocket server and BLE
        // connection keep running while the user visits the other tabs.
        ChangeNotifierProvider<TrainerCraftController>(
          create: (_) => TrainerCraftController(),
        ),
      ],
      child: Consumer<AppSettings>(
        builder: (context, settings, _) => DynamicColorBuilder(
          builder: (lightDynamic, darkDynamic) {
            final lightScheme =
                lightDynamic?.harmonized() ??
                AppTheme.fallbackScheme(Brightness.light);
            final darkScheme =
                darkDynamic?.harmonized() ??
                AppTheme.fallbackScheme(Brightness.dark);

            return MaterialApp(
              title: 'TrainCenter',
              debugShowCheckedModeBanner: false,
              themeMode: switch (settings.themeMode) {
                AppThemeMode.system => ThemeMode.system,
                AppThemeMode.light => ThemeMode.light,
                AppThemeMode.dark => ThemeMode.dark,
              },
              theme: AppTheme.build(lightScheme),
              darkTheme: AppTheme.build(darkScheme),
              home: const HomeShell(),
            );
          },
        ),
      ),
    );
  }
}
