import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../activities/activities_screen.dart';
import '../gear/gear_controller.dart';
import '../gear/gear_screen.dart';
import '../record/record_screen.dart';
import '../segments/segments_controller.dart';
import '../segments/segments_screen.dart';
import '../settings/settings_screen.dart';
import '../trainercraft/trainercraft_controller.dart';
import '../trainercraft/trainercraft_screen.dart';

/// The Material 3 shell of the application.
///
/// A [NavigationBar] switches between the four main destinations. Settings and
/// the TrainerCraft bridge live on their own routes reachable from the app bar.
class HomeShell extends StatefulWidget {
  /// Creates the shell.
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const List<Widget> _destinations = <Widget>[
    RecordScreen(),
    ActivitiesScreen(),
    SegmentsScreen(),
    GearScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final trainerCraftActive = context.select<TrainerCraftController, bool>(
      (controller) => controller.isRunning,
    );

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            _TopAppBar(
              title: switch (_index) {
                0 => 'TrainCenter',
                1 => 'Activities',
                2 => 'Segments',
                _ => 'Gear',
              },
              trainerCraftActive: trainerCraftActive,
              onOpenTrainerCraft: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const TrainerCraftScreen(),
                ),
              ),
              onOpenSettings: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
              ),
            ),
            Expanded(
              child: IndexedStack(index: _index, children: _destinations),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) {
          setState(() => _index = value);

          // The IndexedStack keeps every tab mounted, so data changed while
          // another tab was visible would otherwise stay stale. Recordings
          // update segment PRs and gear mileage; refresh those lists when
          // they are opened.
          if (value == 2) {
            context.read<SegmentsController>().load();
          } else if (value == 3) {
            context.read<GearController>().load();
          }
        },
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.radio_button_unchecked_rounded),
            selectedIcon: Icon(Icons.radio_button_checked_rounded),
            label: 'Record',
          ),
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list_alt_rounded),
            label: 'Activities',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_road_outlined),
            selectedIcon: Icon(Icons.add_road_rounded),
            label: 'Segments',
          ),
          NavigationDestination(
            icon: Icon(Icons.pedal_bike_outlined),
            selectedIcon: Icon(Icons.pedal_bike_rounded),
            label: 'Gear',
          ),
        ],
      ),
      backgroundColor: colorScheme.surface,
    );
  }
}

/// The compact app bar shown above the destinations.
class _TopAppBar extends StatelessWidget {
  const _TopAppBar({
    required this.title,
    required this.trainerCraftActive,
    required this.onOpenTrainerCraft,
    required this.onOpenSettings,
  });

  final String title;
  final bool trainerCraftActive;
  final VoidCallback onOpenTrainerCraft;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ),
          IconButton(
            tooltip: 'TrainerCraft',
            onPressed: onOpenTrainerCraft,
            icon: Badge(
              isLabelVisible: trainerCraftActive,
              smallSize: 8,
              backgroundColor: colorScheme.primary,
              child: const Icon(Icons.sports_esports_outlined),
            ),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: onOpenSettings,
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
    );
  }
}
