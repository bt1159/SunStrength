import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sun_strength_app/models/current_location_notifier.dart';
import 'package:sun_strength_app/models/helpers.dart';
import 'package:sun_strength_app/models/saved_location_notifier.dart';
import 'package:sun_strength_app/screens/chart_route.dart';

class LocationSelectionScreen extends StatelessWidget {
  final bool isChangeMode;
  const LocationSelectionScreen({super.key, this.isChangeMode = false});
  const LocationSelectionScreen.changeMode({super.key}) : isChangeMode = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Location'),
        // Hide back button if they are forced to pick a location on initial boot
        automaticallyImplyLeading: isChangeMode,
      ),
      body: Row(
        children: [
          ElevatedButton(
            onPressed: () async {
              final Location newLocation = Location(
                name: 'Phoenixville, PA',
                lat: 40.1332,
                lon: -75.5138,
              );

              // If they came here from the heatmap screen, pop back to it.
              // If they were on boot, the Gateway will automatically switch to the Heatmap screen.
              context.read<CurrentLocationNotifier>().value = newLocation;
              final Location? locationTest = context
                  .read<CurrentLocationNotifier>()
                  .value;
              if (locationTest?.name == newLocation.name) {
                print('new location set to phoenixville');
              } else {
                print('new location was not set correctly');
              }
              if (context.mounted) {
                print('context is mounted');
                if (isChangeMode) {
                  print('about to pop');
                  Navigator.pop(context);
                } else {
                  print('about to push ChartHomePage');
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ChartHomePage()),
                  );
                }
              }
            },
            child: const Text('Select Phoenixville, PA'),
          ),
          ElevatedButton(
            onPressed: () async {
              final Location newLocation = Location(
                name: 'Equator',
                lat: 0,
                lon: -75.5138,
              );

              // If they came here from the heatmap screen, pop back to it.
              // If they were on boot, the Gateway will automatically switch to the Heatmap screen.
              context.read<CurrentLocationNotifier>().value = newLocation;
              print('new location set to equator');
              if (context.mounted) {
                print('context is mounted');
                if (isChangeMode) {
                  print('about to pop');
                  Navigator.pop(context);
                } else {
                  print('about to push ChartHomePage');
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ChartHomePage()),
                  );
                }
              }
            },
            child: const Text('Select Equator'),
          ),
          ElevatedButton(
            onPressed: () async {
              await context.read<SavedLocationProvider>().clearLocation();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Location cleared'),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 2),
                    width: 200, // Narrows the width to look like a toast
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
              }
            },
            child: const Text('Remove saved location'),
          ),
        ],
      ),
    );
  }
}
