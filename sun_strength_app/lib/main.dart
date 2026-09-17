import 'package:flutter/material.dart';
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
        // ChangeNotifierProxyProvider<SavedSettingsNotifier, PageIndexNotifier>(
        //   create: (context) => PageIndexNotifier(),
        //   update: (context, savedSettingsNotifier, previous) {
        //     if (previous == null) throw 'previous is null';
        //     // If SavedSettingsNotifier still is not initialized, don't do anything
        //     if (!savedSettingsNotifier.isInitialized) return previous;
        //     // If SavedSettingsNotifier was already initialized the last time this update ran, don't do anything
        //     if (previous.savedSettingsIsInitialized) return previous;
        //     // This is the first update from SavedSettingsNotifier, start by recording initializtion
        //     previous.savedSettingsIsInitialized = true;

        //     // If there already is a location selected, presumably because we are well past the initial load OR
        //     // the default has been loaded and it is NOT null, which means that current location has been
        //     // updated or is about to be, just go to the chart page.

        //     if (context.read<CurrentChartSettingsNotifier>().value != null) {
        //       previous.value = 0;
        //     } else {
        //       previous.value = 1;
        //     }
        //     return previous;
        //   },
        // ),
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

// /// Widget that handles loading the saved settings and chooses what to display based on that loading process.
// ///
// /// {@macro AppGatewayBuild}
// class SettingsLoadingHandler extends StatelessWidget {
//   const SettingsLoadingHandler({super.key});

//   /// {@template AppGatewayBuild}
//   /// Because the [SavedSettingsNotifier] is referenced with a [Provider.of], this build method will be
//   /// triggered any time it calls its NotifyListeners().  That is only ever used, however, in the
//   /// initial loading of the Provider.  After that, if the default location is cleared or overwritten,
//   /// it does not NotifyListeners, so this build method will not be re-called.  There could be a
//   /// risk, however, if this widget is rebuilt for some reason after the user has manually looked
//   /// up a location different than the saved default location.
//   /// {@endtemplate}
//   @override
//   Widget build(BuildContext context) {
//     print('running AppGateway.build');
//     // Selector is used here so that the child is built the first time and then ONLY rebuilt when isInitialized goes from false to true.  Any other update to SavedSettingsNotifer is ignored.
//     return Selector<SavedSettingsNotifier, bool>(
//       selector: (_, savedSettingsNotifier) =>
//           savedSettingsNotifier.isInitialized,
//       shouldRebuild: (previousIsInitialized, nextIsInitialized) =>
//           !previousIsInitialized && nextIsInitialized,
//       builder: (context, isInitialized, child) {
//         if (!isInitialized) {
//           return const Scaffold(
//             body: Center(child: CircularProgressIndicator()),
//           );
//         } else {
//           return const MainScaffoldAndIndexedStack();
//         }
//       },
//     );
//   }
// }

// class MainScaffoldAndIndexedStack extends StatelessWidget {
//   const MainScaffoldAndIndexedStack({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return Consumer<PageIndexNotifier>(
//       builder: (context, currentIndexNotifier, child) => Scaffold(
//         appBar: <PreferredSizeWidget>[
//           const ChartAppBar(),
//           const LocationAppBar(),
//         ][currentIndexNotifier.value],
//         drawer: const MainScaffoldDrawer(),
//         body: IndexedStack(
//           index: currentIndexNotifier.value,
//           children: [const ChartHomePage(), const LocationSelectionScreen()],
//         ),
//       ),
//     );
//   }
// }
