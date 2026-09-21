import 'package:flutter/material.dart';
import 'package:sun_strength_app/models/helpers.dart';
import 'package:sun_strength_app/screens/location_selection_route.dart';
import 'screens/chart_route.dart';
import 'package:provider/provider.dart';
import 'package:sun_strength_app/models/main_notifiers.dart';

class CurrentIndex {
  const CurrentIndex(this.value);
  final int value;
}

late final SavedSettingsNotifier savedSettings;

void main() {
  print('running main()');
  WidgetsFlutterBinding.ensureInitialized();
  savedSettings = SavedSettingsNotifier();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    print('Started build method for MyApp');
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SavedSettingsNotifier>.value(
          value: savedSettings,
        ),
        ChangeNotifierProxyProvider<
          SavedSettingsNotifier,
          CurrentChartSettingsNotifier
        >(
          create: (_) => CurrentChartSettingsNotifier(),
          update: (_, savedLocationNotifier, previous) {
            if (previous == null) {
              throw 'previous CurrentChartSettingsNotifier is null';
            }

            // If the saved settings were not loaded last time this was updated and now they are initialized and now it is not null, then make the current chart location & year match the defaults
            if (!previous.savedChartSettingsLoaded &&
                savedLocationNotifier.isInitialized &&
                savedLocationNotifier.value != null) {
              return previous..updateWithInitialSaved(
                newLocation: savedLocationNotifier.value?.defaultLocation,
                newYear: savedLocationNotifier.value?.defaultYear,
              );
            }
            // The only time these two could be different is if it was already loaded previously and matched and then the user changed the year.  The point to this is that the only time a user changes the default location other than the default's initial load should NOT result in a change to the current map location.
            else if (savedLocationNotifier.value?.defaultYear !=
                previous.value?.year) {
              return previous..updateCurrentChartSettings(
                newYear: savedLocationNotifier.value?.defaultYear,
              );
            } else {
              return previous;
            }
          },
        ),
      ],
      child: Selector<SavedSettingsNotifier, bool>(
        selector: (_, savedSettingsNotifier) =>
            savedSettingsNotifier.isInitialized,
        shouldRebuild: (previousIsInitialized, nextIsInitialized) =>
            !previousIsInitialized && nextIsInitialized,
        builder: (context, isInitialized, child) {
          if (!isInitialized) {
            return MaterialApp(
              title: 'Flutter Demo',
              debugShowCheckedModeBanner: false,
              theme: ThemeData(
                colorScheme: .fromSeed(seedColor: Colors.deepPurple),
              ),
              darkTheme: ThemeData(
                colorScheme: ColorScheme.fromSeed(
                  seedColor: Colors.deepPurple,
                  brightness:
                      Brightness.dark, // <-- This does the heavy lifting
                ),
              ),
              themeMode: ThemeMode.dark,
              home: const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              ),
            );
          } else {
            return MaterialApp(
              title: 'Flutter Demo',
              debugShowCheckedModeBanner: false,
              theme: ThemeData(
                colorScheme: .fromSeed(seedColor: Colors.deepPurple),
              ),
              darkTheme: ThemeData(
                colorScheme: ColorScheme.fromSeed(
                  seedColor: Colors.deepPurple,
                  brightness:
                      Brightness.dark, // <-- This does the heavy lifting
                ),
              ),
              themeMode: ThemeMode.dark,
              home: const InitScreen(),
            );
          }
        },
      ),
    );
  }
}

class InitScreen extends StatefulWidget {
  const InitScreen({super.key});

  @override
  State<InitScreen> createState() => _InitScreenState();
}

class _InitScreenState extends State<InitScreen> {
  @override
  void initState() {
    super.initState();

    // Wait for the first frame to finish before navigating
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentSettingsNotNull =
          context.read<CurrentChartSettingsNotifier>().value != null;

      if (currentSettingsNotNull) {
        // Replaces InitScreen with ChooseXyzScreen as the base route
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ChartRoute()),
        );
      } else {
        // Replaces InitScreen with ChartScreen as the base route
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const LocationSelectionRoute(isInitialLoad: true),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
