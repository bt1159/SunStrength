// flutter run -d web-server --web-hostname=0.0.0.0 --web-port=8080
import 'package:flutter/material.dart';
import 'package:sun_strength_app/models/current_location_notifier.dart';
import 'package:sun_strength_app/models/saved_settings_notifier.dart';
import 'package:sun_strength_app/screens/location_selector_route.dart';
import 'screens/chart_route.dart';
import 'package:provider/provider.dart';

// TODO: Make sure, at some point, to go to Google Cloud Console, go to my Google Maps API key,
// and restrict it to HTTP Referrers and add your local development URL
// (http://localhost:*) and your production domain so others cannot steal it.

// TODO: My chart is always displayed in Eastern time (not sure if I hardcoded that or it is using the PC's locat time).
// It should default to local time for that location but give an option.

// TODO: Convert saved location notifier to a more broad settings notifier.  Should it be a custom class for settings and maintain
// a ValueNotifier, or just make each setting a separate thing.  On the other hand, should they even be seperate settings?

void main() {
  print('running main()');
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
        ChangeNotifierProvider<SavedSettingsNotifier>(
          create: (_) => SavedSettingsNotifier(),
        ),
        ChangeNotifierProxyProvider<
          SavedSettingsNotifier,
          CurrentLocationNotifier
        >(
          create: (_) => CurrentLocationNotifier(),
          update: (_, savedLocationNotifier, previous) {
            final CurrentLocationNotifier? updatedWidget;
            if (savedLocationNotifier.isInitialized &&
                savedLocationNotifier.value != null) {
              updatedWidget = previous
                ?..updateWithInitialSaved(
                  newLocation: savedLocationNotifier.value?.defaultLocation,
                  newYear: savedLocationNotifier.value?.defaultYear,
                );
            } else {
              updatedWidget = previous;
            }
            if (updatedWidget != null) {
              return updatedWidget;
            } else {
              throw ('No widget returned');
            }
          },
        ),
      ],
      child: MaterialApp(
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

/// Widget that handles loading the saved settings and chooses what to display based on that loading process.
///
/// {@macro AppGatewayBuild}
class AppGateway extends StatelessWidget {
  const AppGateway({super.key});

  /// {@template AppGatewayBuild}
  /// Because the [SavedSettingsNotifier] is referenced with a [Provider.of], this build method will be
  /// triggered any time it calls its NotifyListeners().  That is only ever used, however, in the
  /// initial loading of the Provider.  After that, if the default location is cleared or overwritten,
  /// it does not NotifyListeners, so this build method will not be re-called.  There could be a
  /// risk, however, if this widget is rebuilt for some reason after the user has manually looked
  /// up a location different than the saved default location.
  /// {@endtemplate}
  // TODO: update this after looking at todo on notifier.  It actually does call notifyListeners() every time a setting is updated.
  @override
  Widget build(BuildContext context) {
    print('running AppGateway.build');
    // Listen to the location provider
    final SavedSettingsNotifier locationProvider =
        Provider.of<SavedSettingsNotifier>(context);

    final int childStartingIndex;

    // Still waiting for SharedPreferences to read from disk
    if (!locationProvider.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Only gets here if locationProvider is initialized.  BUT, if there is a current location set, we don't care about whether there is a saved default.
    // TODO: Why do we wait to check this until after the settings are initialized?
    if (context.read<CurrentLocationNotifier>().value != null ||
        locationProvider.value?.defaultLocation != null) {
      // return const ChartHomePage();
      childStartingIndex = 0;
    } else {
      // No location saved (or error when loading saved settings)-> Send them straight to the selection screen
      print('in AppGateway.build, locationProvider.value == null');
      // return const LocationSelectionScreen();
      childStartingIndex = 1;
    }
    return MainShellScreen(startingIndex: childStartingIndex);
  }
}

// TODO I don't like how this works right now.  Passing these update functions is super clunky and dumb.  Consider a Provider since the function will never change.

// TODO I also need to update the two children here to get rid of their own Scaffolds.
class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key, this.startingIndex = 0});

  final int startingIndex;

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.startingIndex;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: [
        AppBar(
          // TRY THIS: Try changing the color here to a specific color (to
          // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
          // change color while the other colors stay the same.
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          // Here we take the value from the MyHomePage object that was created by
          // the App.build method, and use it to set our appbar title.
          title: Text('UV strength'),
        ),
        AppBar(title: const Text("Select Your Location")),
      ][_currentIndex],
      drawer: Drawer(
        child: ListView(
          children: [
            ListTile(onTap: () {}, title: Text('Change default time zone')),
            ListTile(onTap: () {}, title: Text('Change default location')),
            ListTile(
              onTap: () {
                final bool currentTwelveHour =
                    context.read<SavedSettingsNotifier>().value?.twelveHour ??
                    true;
                print('currentTwelveHour: $currentTwelveHour');
                context.read<SavedSettingsNotifier>().updateTwelveHour(
                  !currentTwelveHour,
                );
                Navigator.of(context).pop();
              },
              title: Text('Toggle AM/PM vs. 24 hour display'),
            ),
          ],
        ),
      ),
      body: Provider<UpdateCurrentIndex>(
        create: (_) => (int newIndex) {
          print(
            'Just received call to switch stack index to: $newIndex, with _currentIndex: $_currentIndex',
          );
          if (newIndex == _currentIndex) return;
          setState(() {
            _currentIndex = newIndex;
          });
        },
        child: IndexedStack(
          index: _currentIndex,
          children: [const ChartHomePage(), const LocationSelectionScreen()],
        ),
      ),
    );
  }
}

typedef UpdateCurrentIndex = void Function(int newIndex);
