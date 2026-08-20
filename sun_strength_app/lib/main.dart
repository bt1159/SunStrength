// flutter run -d web-server --web-hostname=0.0.0.0 --web-port=8080
import 'package:flutter/material.dart';
import 'package:sun_strength_app/models/current_location_notifier.dart';
import 'package:sun_strength_app/models/helpers.dart';
import 'package:sun_strength_app/models/saved_settings_notifier.dart';
import 'package:sun_strength_app/screens/location_selector_route.dart';
import 'screens/chart_route.dart';
import 'package:provider/provider.dart';

// TODO: Make sure, at some point, to go to Google Cloud Console, go to my Google Maps API key,
// and restrict it to HTTP Referrers and add your local development URL
// (http://localhost:*) and your production domain so others cannot steal it.

class CurrentIndex {
  const CurrentIndex(this.value);
  final int value;
}

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
            if (!(previous?.savedChartSettingsLoaded ?? false) &&
                savedLocationNotifier.isInitialized &&
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
        home: ChangeNotifierProxyProvider<SavedSettingsNotifier, CurrentIndexNotifier>(
          create: (context) => CurrentIndexNotifier(),
          update: (context, savedSettingsNotifier, previous) {
            if (previous == null) throw 'previous is null';
            // If SavedSettingsNotifier still is not initialized, don't do anything
            if (!savedSettingsNotifier.isInitialized) return previous;
            // If SavedSettingsNotifier was already initialized the last time this update ran, don't do anything
            if (previous.savedSettingsIsInitialized) return previous;
            // This is the first update from SavedSettingsNotifier, so make change if needed and record initializtion
            previous.savedSettingsIsInitialized = true;

            // If there already is a location selected, presumably because we are well past the initial load OR
            // the default has been loaded and it is NOT null, which means that current location has been
            // updated or is about to be, just go to the chart page.
            // TODO: Why do I check for non null default location?  If there is one, that means is has been
            // loaded, and current location notifier should have been called.  The only reason that would be
            // true but current location notifier value is null would be if the user somehow wiped the current
            // location (not sure if that is possible) or if the current location notifier just hasn't loaded
            // yet.  Maybe that is indeed why.  On the other hand, what is the harm?  Just processing time.

            if (context.read<CurrentLocationNotifier>().value != null ||
                savedSettingsNotifier.value?.defaultLocation != null) {
              previous.value = 0;
            } else {
              previous.value = 1;
            }
            return previous;
          },
          child: const SettingsLoadingHandler(),
        ),
      ),
    );
  }
}

/// Widget that handles loading the saved settings and chooses what to display based on that loading process.
///
/// {@macro AppGatewayBuild}
class SettingsLoadingHandler extends StatelessWidget {
  const SettingsLoadingHandler({super.key});

  /// {@template AppGatewayBuild}
  /// Because the [SavedSettingsNotifier] is referenced with a [Provider.of], this build method will be
  /// triggered any time it calls its NotifyListeners().  That is only ever used, however, in the
  /// initial loading of the Provider.  After that, if the default location is cleared or overwritten,
  /// it does not NotifyListeners, so this build method will not be re-called.  There could be a
  /// risk, however, if this widget is rebuilt for some reason after the user has manually looked
  /// up a location different than the saved default location.
  /// {@endtemplate}
  @override
  Widget build(BuildContext context) {
    print('running AppGateway.build');
    // Selector is used here so that the child is built the first time and then ONLY rebuilt when isInitialized goes from false to true.  Any other update to SavedSettingsNotifer is ignored.
    return Selector<SavedSettingsNotifier, bool>(
      selector: (_, savedSettingsNotifier) =>
          savedSettingsNotifier.isInitialized,
      shouldRebuild: (previousIsInitialized, nextIsInitialized) =>
          !previousIsInitialized && nextIsInitialized,
      builder: (context, isInitialized, child) {
        if (!isInitialized) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        } else {
          return const MainScaffoldAndIndexedStack();
        }
      },
    );
  }
}

class MainScaffoldAndIndexedStack extends StatelessWidget {
  const MainScaffoldAndIndexedStack({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CurrentIndexNotifier>(
      builder: (context, currentIndexNotifier, child) => Scaffold(
        appBar: [
          AppBar(
            backgroundColor: Theme.of(context).colorScheme.inversePrimary,
            title: const Text('UV strength'),
          ),
          AppBar(title: const Text("Select Your Location")),
        ][currentIndexNotifier.value],
        drawer: Drawer(
          child: ListView(
            children: [
              ListTile(
                onTap: () {},
                title: const Text('Change default time zone'),
              ),
              ListTile(
                onTap: () {},
                title: const Text('Change default location'),
              ),
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
              Selector<SavedSettingsNotifier, int?>(
                selector: (_, savedSettingsNotifier) =>
                    savedSettingsNotifier.value?.defaultYear,
                builder: (_, _, _) => YearPickerTile(),
              ),
            ],
          ),
        ),
        body: IndexedStack(
          index: currentIndexNotifier.value,
          children: [const ChartHomePage(), const LocationSelectionScreen()],
        ),
      ),
    );
  }
}

class YearPickerTile extends StatefulWidget {
  const YearPickerTile({super.key});

  @override
  State<YearPickerTile> createState() => _YearPickerTileState();
}

class _YearPickerTileState extends State<YearPickerTile> {
  DateTime currentYear = DateTime.now();

  Future<void> showYearPickerDialog() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Year'),
          content: SizedBox(
            width: 300,
            height: 300,
            child: YearPicker(
              firstDate: DateTime(1900),
              lastDate: DateTime(2100),
              selectedDate: currentYear,
              onChanged: (DateTime dateTime) => setState(() {
                currentYear = dateTime;
              }),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (currentYear.year != context.read<SavedSettingsNotifier>().value?.defaultYear) {
                  context.read<SavedSettingsNotifier>().updateYear(
                    currentYear.year,
                  );
                }
                Navigator.of(context).pop();
              },
              child: const Text('Ok'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    int? potentialSavedYear = context
        .read<SavedSettingsNotifier>()
        .value
        ?.defaultYear;
    if (potentialSavedYear != null) {
      currentYear = DateTime(potentialSavedYear);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(onTap: showYearPickerDialog, title: Text('Change Year'));
  }
}
