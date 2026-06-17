import 'dart:js_util' as js_util;
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:js_interop';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sun_strength_app/models/current_location_notifier.dart';
import 'package:sun_strength_app/models/helpers.dart';
import 'package:sun_strength_app/models/saved_location_notifier.dart';
import 'package:sun_strength_app/screens/chart_route.dart';
import 'dart:async';
import 'package:google_maps/google_maps_places.dart' as gmaps_places;
import 'package:google_maps/google_maps_core.dart' as gmaps;

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

class LocationSelectionScreen2 extends StatefulWidget {
  const LocationSelectionScreen2({super.key});

  @override
  State<LocationSelectionScreen2> createState() =>
      _LocationSelectionScreenState2();
}

class _LocationSelectionScreenState2 extends State<LocationSelectionScreen2> {
  final String apiKey =
      "AIzaSyA4jGoTQ5Gn_zW5xuXeMmb5BdYlAWG8_Bs"; // Use same key as index.html

  final TextEditingController _searchController = TextEditingController();
  GoogleMapController? _mapController;

  // Default map center (e.g., center of US or a starting city)
  LatLng _currentPosition = const LatLng(39.8283, -98.5795);
  Marker? _selectedMarker;

  @override
  void initState() {
    super.initState();
    _updateMarker(_currentPosition);
  }

  // Helper to place a visual pin on the map
  void _updateMarker(LatLng position) {
    setState(() {
      _currentPosition = position;
      _selectedMarker = Marker(
        markerId: const MarkerId('selected_location'),
        position: position,
      );
    });
  }

  // Jumps the map view smoothly to the target coordinate
  void _moveMapTo(LatLng position) {
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: position, zoom: 15),
      ),
    );
  }

  // 1. Fetch autocomplete suggestions as the user types
  Future<List<Map<String, String>>> _getAutocompleteSuggestions(
    String input,
  ) async {
    if (input.isEmpty) return [];
    int pseudoLine = 0;
    try {
      final gmaps_places.AutocompleteRequest request =
          gmaps_places.AutocompleteRequest()..input = input;
      pseudoLine++;

      // The extension layer in the package returns a Future<AutocompleteResponse>
      // if you don't supply a callback argument.
      final dynamic jsResponse =
          await (gmaps_places
                      .AutocompleteSuggestion.fetchAutocompleteSuggestions(
                    request,
                  )
                  as JSPromise<JSAny?>)
              .toDart;

      final dynamic rawPredictions = js_util.getProperty<dynamic>(
        jsResponse,
        'predictions',
      );
      if (rawPredictions == null) {
        return <Map<String, String>>[];
      }
      pseudoLine++;

      final List<dynamic> predictionsList = rawPredictions as List<dynamic>;
      pseudoLine++;
      final List<Map<String, String>> results = <Map<String, String>>[];
      pseudoLine++;
      print('results: $results');

      int j = 0;
      for (final dynamic suggestion in predictionsList) {
        j++;
        // 5. Dig down into the 'placePrediction' nested JS object
        final dynamic placePrediction = js_util.getProperty<dynamic>(
          suggestion,
          'placePrediction',
        );
        if (placePrediction != null) {
          final String text =
              js_util.getProperty<String>(placePrediction, 'text') ?? '';
          final String placeId =
              js_util.getProperty<String>(placePrediction, 'placeId') ?? '';

          results.add(<String, String>{
            'description': text,
            'place_id': placeId,
          });
        }
      }

      print('j: $j');
      pseudoLine++;
      return results;
    } catch (e) {
      print(
        "Error fetching autocomplete predictions.  pseudoLine: $pseudoLine, e: $e",
      );
      return <Map<String, String>>[];
    }
  }

  // 2. Fetch Lat/Lng coordinates using a selected Place ID
  Future<LatLng?> _getLatLngFromPlaceId(String placeId) async {
    print('starting _getLatLngFromPlaceId.  placeId: $placeId');

    try {
      // 1. Instantiate the modern Place configuration options using the selected ID
      final gmaps_places.PlaceOptions placeOptions = gmaps_places.PlaceOptions()
        ..id = placeId;
      final gmaps_places.Place place = gmaps_places.Place(placeOptions);

      // 2. Build the request asking strictly for the location coordinates field
      final gmaps_places.FetchFieldsRequest fieldsRequest =
          gmaps_places.FetchFieldsRequest()..fields = ['location'];

      // 3. Invoke the Promise-based API method
      final JSAny? jsPromise = place.fetchFields(fieldsRequest);

      if (jsPromise != null) {
        // 4. Await the JS Promise conversion into a usable Dart response
        final dynamic jsResponse = await (jsPromise as JSPromise).toDart;

        // 5. Cast the response to the correct Place type to extract the coordinates safely
        final gmaps_places.Place resolvedPlace =
            jsResponse as gmaps_places.Place;

        if (resolvedPlace.location != null) {
          final double lat = resolvedPlace.location!.lat.toDouble();
          final double lng = resolvedPlace.location!.lng.toDouble();

          return LatLng(lat, lng);
        }
      }
    } catch (e) {
      print("Error fetching modern place coordinates: $e");
    }

    return null;
  }

  // 3. Reverse Geocode: Get text address from map click coordinates
  Future<String?> _getAddressFromLatLng(LatLng position) async {
    try {
      // 1. Create a modern JS LatLng object from your Flutter coordinates
      final gmaps.LatLng jsLatLng = gmaps.LatLng(
        position.latitude,
        position.longitude,
      );

      // 2. Instantiate a Place using the new coordinate options profile
      // final gmaps_places.PlaceOptions placeOptions = gmaps_places.PlaceOptions();

      // final JSObject jsOptions = placeOptions as JSObject;
      // jsOptions['location'] = jsLatLng as JSAny;

      // ..locationRestriction = jsLatLng;
      final gmaps_places.Place place = gmaps_places.Place(
        gmaps_places.PlaceOptions(),
      )..location = jsLatLng;

      // 3. Request the formatted address text field asynchronously
      final gmaps_places.FetchFieldsRequest fieldsRequest =
          gmaps_places.FetchFieldsRequest()..fields = ['formattedAddress'];

      // 4. Invoke the Promise-based API method
      final JSPromise? jsPromise =
          place.fetchFields(fieldsRequest) as JSPromise?;

      if (jsPromise != null) {
        // 5. Await the JS Promise conversion into a usable Dart response
        final JSAny? jsResponse = await jsPromise.toDart;

        // 6. Cast the response to the correct Place type to extract the address text
        if (jsResponse != null) {
          final gmaps_places.Place resolvedPlace =
              jsResponse as gmaps_places.Place;

          if (resolvedPlace.formattedAddress != null) {
            print(
              'finishing _getAddressFromLatLng.  It all seems to have worked.  Returning resolvedPlace.formattedAddress: ${resolvedPlace.formattedAddress}',
            );
            return resolvedPlace.formattedAddress;
          }
        }
      }
    } catch (e) {
      print("Error reverse geocoding with modern Place API: $e");
    }

    print(
      'finishing _getAddressFromLatLng.  Something did not work.  Returning null',
    );
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Select Your Location")),
      body: Stack(
        children: [
          // THE MAP (Fills the background)
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentPosition,
              zoom: 4,
            ),
            onMapCreated: (controller) => _mapController = controller,
            markers: _selectedMarker != null ? {_selectedMarker!} : {},

            // ACTION: User clicks a spot on the map
            onTap: (LatLng tappedPosition) async {
              _updateMarker(tappedPosition);
              _moveMapTo(tappedPosition);

              // Automatically fill the search bar text
              String? address = await _getAddressFromLatLng(tappedPosition);
              if (address != null) {
                _searchController.text = address;
              }
            },
          ),

          // THE FLOATING SEARCH BAR
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: TypeAheadField<Map<String, dynamic>>(
                  controller: _searchController,
                  builder: (context, controller, focusNode) {
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: const InputDecoration(
                        hintText: 'Search address or city...',
                        border: InputBorder.none,
                        icon: Icon(Icons.search),
                      ),
                    );
                  },
                  // Calls Google API as user types
                  suggestionsCallback: (search) =>
                      _getAutocompleteSuggestions(search),

                  // Renders the dropdown items
                  itemBuilder: (context, suggestion) {
                    return ListTile(
                      leading: const Icon(Icons.location_on),
                      title: Text(suggestion['description']!),
                    );
                  },

                  // ACTION: User selects an address suggestion
                  onSelected: (suggestion) async {
                    _searchController.text = suggestion['description']!;

                    LatLng? targetCoordinates = await _getLatLngFromPlaceId(
                      suggestion['place_id']!,
                    );
                    if (targetCoordinates != null) {
                      _updateMarker(targetCoordinates);
                      _moveMapTo(targetCoordinates);
                    }
                  },
                ),
              ),
            ),
          ),

          // "GO" BUTTON TO NAVIGATE TO HEATMAP
          Positioned(
            bottom: 30,
            left: 50,
            right: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              onPressed: () {
                // Pass _currentPosition (LatLng) to your next 2D heatmap screen
                print("Proceeding with coordinates: $_currentPosition");
                // Navigator.push(...)
              },
              child: const Text(
                "Generate Sun Strength Heatmap",
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// extension type Prediction._(JSObject _) implements JSObject {
//   // 2. Define the Object Literal Constructor using named parameters
//   external Prediction({required String name, required int age, bool? isActive});

//   // 3. Define the external getters for the keys
//   external String get name;
//   external int get age;
//   external bool? get isActive;
// }


//     // (prediction['description'] as JSString?)?.toDart ?? '';
//     //       final placeId = (prediction['place_id']