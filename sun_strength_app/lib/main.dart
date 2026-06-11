// flutter run -d web-server --web-hostname=0.0.0.0 --web-port=8080
import 'package:flutter/material.dart';
import 'package:sun_strength_app/models/current_location_notifier.dart';
import 'package:sun_strength_app/models/saved_location_notifier.dart';
import 'package:sun_strength_app/screens/location_selector_route.dart';
import 'screens/chart_route.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(
    ChangeNotifierProvider<SavedLocationProvider>(
      create: (_) => SavedLocationProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    print('Started build method for MyApp');
    return ChangeNotifierProxyProvider<
      SavedLocationProvider,
      CurrentLocationNotifier
    >(
      create: (_) => CurrentLocationNotifier(),
      update: (_, savedLocationProvider, previous) {
        final CurrentLocationNotifier? updatedWidget = previous
          ?..update(savedLocationProvider.value);
        if (updatedWidget != null) {
          return updatedWidget;
        } else {
          throw ('No widget returned');
        }
      },
      builder: (_, _) => MaterialApp(
        title: 'Flutter Demo',
        theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.deepPurple)),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurple,
            brightness: Brightness.dark, // <-- This does the heavy lifting
          ),
        ),
        themeMode: ThemeMode.dark,
        home: const AppGateway(),
      ),
    );
  }
}

/// {@macro AppGatewayBuild}
class AppGateway extends StatelessWidget {
  const AppGateway({super.key});

  /// {@template AppGatewayBuild}
  /// Because the [SavedLocationProvider] is referenced with a [Provider.of], this build method will be
  /// triggered any time it calls its NotifyListeners().  That is only ever used, however, in the
  /// initial loading of the Provider.  After that, if the default location is cleared or overwritten,
  /// it does not NotifyListeners, so this build method will not be re-called.  There could be a
  /// risk, however, if this widget is rebuilt for some reason after the user has manually looked
  /// up a location different than the saved default location.
  /// {@endtemplate}
  @override
  Widget build(BuildContext context) {
    print('running AppGateway.build');
    // Listen to the location provider
    final locationProvider = Provider.of<SavedLocationProvider>(context);

    // 1. Still waiting for SharedPreferences to read from disk
    if (!locationProvider.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (context.read<CurrentLocationNotifier>().value != null) {
      return const ChartHomePage();
    }

    // 2. No location saved -> Send them straight to the selection screen
    if (locationProvider.value == null) {
      print('in AppGateway.build, locationProvider.value == null');
      return const LocationSelectionScreen();
    }

    // 3. Location exists -> Open directly to the Heatmap

    print(
      'in AppGateway.build passed all if statements, which implies that locationProvider.value != null, locationProvider.value?.name: ${locationProvider.value?.name}',
    );
    return const ChartHomePage();
  }
}
