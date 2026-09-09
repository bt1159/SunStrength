import 'package:flutter/material.dart';
import 'package:sun_strength_app/models/current_location_notifier.dart';
import 'package:sun_strength_app/models/helpers.dart';
import 'package:sun_strength_app/models/saved_settings_notifier.dart';
import 'package:sun_strength_app/screens/location_selector_route.dart';
import 'screens/chart_route.dart';
import 'package:provider/provider.dart';



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
            if (previous == null) {
              throw 'previous CurrentLocationNotifier is null';
            }
            if (!previous.savedChartSettingsLoaded &&
                savedLocationNotifier.isInitialized &&
                savedLocationNotifier.value != null) {
              return previous..updateWithInitialSaved(
                newLocation: savedLocationNotifier.value?.defaultLocation,
                newYear: savedLocationNotifier.value?.defaultYear,
              );
            } else if (savedLocationNotifier.value?.defaultYear !=
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
      child: MaterialApp(
        title: 'Flutter Demo',
        debugShowCheckedModeBanner: false,
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
            // This is the first update from SavedSettingsNotifier, start by recording initializtion
            previous.savedSettingsIsInitialized = true;

            // If there already is a location selected, presumably because we are well past the initial load OR
            // the default has been loaded and it is NOT null, which means that current location has been
            // updated or is about to be, just go to the chart page.
            

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
            title: const Text('Sun strength'),
            actions: [
              IconButton(
                onPressed: () => showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Information'),
                    content: SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: 600),
                        child: Column(
                          children: [
                            Text(
                              'Heatmap chart',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              'This chart shows the strength of the sun at every moment throughout '
                              'an entire year.  As you look across the chart from left to right, you '
                              'go from one day to the next, so the far left is January 1st.  As you go '
                              'up in the chart, from the bottom to the top, you go from the beginning '
                              'to the end of a single day.  You can hover your cursor over the chart '
                              'to see the time and date of any specific point and the strength of the '
                              'sun at that point.\n\n'
                              'The "strength" of the sun is always shown as a percentage of the '
                              'strongest sun strength the Earth ever gets, in other words when the sun '
                              'is straight up in the sky at the equator.\n\n'
                              'You may be suprised by how many places on Earth routinely get over 90% '
                              'of that max strength, but it\'s true!',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            SizedBox(height: 10),
                            Text(
                              'Visible light vs. UV bands',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              'There are three buttons that let you select why kind of sunlight the chart '
                              'is considering.  If you click "Visible light", you are essentially looking '
                              'at how much visible light your location is reciving. This is pretty much like '
                              'the calculators only that calculate your solar energy savings.\n\n'
                              'When you click UV-A or UV-B, you are only considering the sun\'s ultraviolet '
                              'light.  This is what really matters if you are focusing on skin health and '
                              'avoiding sunburn.\n\n'
                              'Within ultraviolet light, UV-B is the portion that is, by far, the most dangerous. '
                              'You should absolutely avoid a lot of UV-B exposure.  Luckily, most UV-B light gets '
                              'blocked whever the sun is a decent amount away from straight overhead.\n\n'
                              'Even though UV-A is not as harmful as UV-B, it is better at getting through the '
                              'atmosphere.  That means it is still dangerous even when the sun is much lower in '
                              'the sky.\n\n'
                              'So, what should you click?  Usually, looking at UV-A is the best bet if you are '
                              'trying to protect your skin.  That said, it is sometimes helpful to check out '
                              'UV-B to see the times you should definitely be the most careful.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            SizedBox(height: 10),
                            Text(
                              'Direction of the sun, the bottom chart',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              'The bottom chart primarily shows where the sun will be at any point '
                              'during one specific day.  The circular chart works like a compass, so if '
                              'it shows the sun at the far left edge at a certain time, that means the '
                              'sun will be due East in the sky when it rises.  As the sun gets higher in '
                              'the sky, it moves toward the center.  Basically, it\'s a bit like looking '
                              'down from a bird\'s eye view.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Ok'),
                      ),
                    ],
                  ),
                ),
                icon: Icon(Icons.info),
              ),
            ],
          ),
          const LocationAppBar(),
        ][currentIndexNotifier.value],
        drawer: const MainScaffoldDrawer(),
        body: IndexedStack(
          index: currentIndexNotifier.value,
          children: [const ChartHomePage(), const LocationSelectionScreen()],
        ),
      ),
    );
  }
}

class MainScaffoldDrawer extends StatelessWidget {
  const MainScaffoldDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        children: [
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
          ListTile(
            onTap: () async {
              final bool? yearChanged = await showDialog<bool>(
                context: context,
                builder: (BuildContext context) => YearPickerTile(),
              );
              if ((yearChanged ?? false) && context.mounted) {
                Navigator.of(context).pop();
              }
            },
            title: Text('Change Year'),
          ),
        ],
      ),
    );
  }
}

class LocationAppBar extends StatelessWidget implements PreferredSizeWidget {
  const LocationAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CurrentLocationNotifier>(
      builder: (context, currentLocationNotifier, child) {
        return AppBar(
          title: const Text("Select Your Location"),
          leading: currentLocationNotifier.value == null
              ? null
              : IconButton(
                  onPressed: () =>
                      context.read<CurrentIndexNotifier>().value = 0,
                  icon: const Icon(Icons.arrow_back),
                ),
        );
      },
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class YearPickerTile extends StatefulWidget {
  const YearPickerTile({super.key});

  @override
  State<YearPickerTile> createState() => _YearPickerTileState();
}

class _YearPickerTileState extends State<YearPickerTile> {
  DateTime currentYear = DateTime.now();

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
            if (currentYear.year !=
                context.read<SavedSettingsNotifier>().value?.defaultYear) {
              context.read<SavedSettingsNotifier>().updateYear(
                currentYear.year,
              );
            }
            Navigator.of(context).pop<bool>(true);
          },
          child: const Text('Ok'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop<bool>(false),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
