import 'dart:js_interop';
import 'dart:js_interop_unsafe';
// import 'dart:nativewrappers/_internal/vm/lib/ffi_native_type_patch.dart';
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
import 'package:google_maps/google_maps_geocoding.dart' as gmaps_geo;

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
              await context.read<SavedLocationNotifier>().clearLocation();
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

    try {
      // 1. Prepare and send the Google Maps Autocomplete request across the JS bridge
      final gmaps_places.AutocompleteRequest request =
          gmaps_places.AutocompleteRequest()..input = input;

      // 2. Await the JS Promise and cast it to a generic JS value (JSAny)
      final JSAny? jsResponseAny =
          await (gmaps_places
                      .AutocompleteSuggestion.fetchAutocompleteSuggestions(
                    request,
                  )
                  as JSPromise<JSAny?>)
              .toDart;

      if (jsResponseAny == null) return [];

      // 3. Flatten the top-level response into a native Dart Map to read the list key safely
      final dynamic dartResponse = jsResponseAny.dartify();
      if (dartResponse is! Map) return [];

      // 4. Extract the list of raw underlying suggestions
      final dynamic rawSuggestions = dartResponse['suggestions'];
      if (rawSuggestions is! List) return [];

      final List<Map<String, String>> results = [];

      // 5. Iterate through each suggestion item
      for (final dynamic suggestion in rawSuggestions) {
        // Force-cast the item to a JSObject since Google Maps items bypass simple dartify structures
        final JSObject suggestionObj = suggestion as JSObject;

        // Extract the nested 'placePrediction' JS object if it exists
        if (suggestionObj.hasProperty('placePrediction'.toJS).toDart) {
          final JSObject? placePrediction =
              suggestionObj['placePrediction'] as JSObject?;

          if (placePrediction != null) {
            String textResult = '';
            String placeIdResult = '';

            // 6. Safely extract the readable description string
            if (placePrediction.hasProperty('text'.toJS).toDart) {
              final JSAny? rawTextValue = placePrediction['text'];
              if (rawTextValue != null) {
                final dynamic dartText = rawTextValue.dartify();

                // Google Maps 'text' properties can arrive as raw strings or nested objects (e.g. {string: "..."})
                if (dartText is Map) {
                  textResult =
                      dartText['string']?.toString() ??
                      dartText['text']?.toString() ??
                      '';
                } else {
                  textResult = dartText?.toString() ?? '';
                }
              }
            }

            // 7. Safely extract the matching Place ID string
            if (placePrediction.hasProperty('placeId'.toJS).toDart) {
              final JSAny? rawPlaceId = placePrediction['placeId'];
              if (rawPlaceId != null) {
                placeIdResult = rawPlaceId.dartify()?.toString() ?? '';
              }
            }

            // 8. Package the results for Flutter TypeAhead consumption
            results.add(<String, String>{
              'description': textResult,
              'place_id': placeIdResult,
            });
          }
        }
      }

      return results;
    } catch (e) {
      // Return empty list silently if any unexpected error occurs during network / parsing routines
      return [];
    }
  }

  // 2. Fetch Lat/Lng coordinates using a selected Place ID
  Future<LatLng?> _getLatLngFromPlaceId(String placeId) async {
    print('starting _getLatLngFromPlaceId.  placeId: $placeId');

    try {
      // Set up the API call.  You first instantiate the [gmaps_places.Place] using
      // [gmaps_places.PlaceOptions] to define the placeID.  Then, execute the API call to
      // actually fetch the information we want using [gmaps_places.FetchFieldsRequest] and then
      // [gmaps_places.Place.fetchFields].  In this case, we want the location field.
      final gmaps_places.PlaceOptions placeOptions = gmaps_places.PlaceOptions()
        ..id = placeId;
      final gmaps_places.Place place = gmaps_places.Place(placeOptions);
      final gmaps_places.FetchFieldsRequest fieldsRequest =
          gmaps_places.FetchFieldsRequest()..fields = ['location'];
      final JSAny? jsPromise = place.fetchFields(fieldsRequest);

      // Now that we have the promise of a response, we await it to get the actual response.
      // Then, since we know the response will be the equivalent of a Dart Map, we use dartify()
      // to convert the response to a Dart [Map].  Keep in mind, we are manipulating the direct
      // API response.  That response has one field that we care about, 'place'.  That holds the
      // actual Place object that was returned by the API.  Keep in mind, though, that this Place
      // object ONLY has the location property since that was the only property we asked for.
      // Instead of dartify(), we could instead use the .hasProperty method for the JS Interop,
      // but that does not actually seem better.
      if (jsPromise != null) {
        // 4. Await the JS Promise conversion into a usable Dart response
        final JSAny? jsResponseAny = await (jsPromise as JSPromise).toDart;
        if (jsResponseAny == null) {
          return null;
        }
        final dynamic dartResponse = jsResponseAny.dartify();
        if (dartResponse is Map && dartResponse.containsKey('place')) {
          final JSAny? dartPlaceAny = dartResponse['place'];
          if (dartPlaceAny == null) {
            print('dartPlaceAny is null');
            return null;
            // I should actually do something here.  Why would it return null?  If there is a legitimate reason, I need to accomodate that in the app.
          }
          final JSObject placeJSObject = dartPlaceAny as JSObject;
          final gmaps_places.Place placeGoogleObject =
              placeJSObject as gmaps_places.Place;

          // Now that the response is a [gmaps_places.Place] object, we can simply refer to its location property with a strongly typed getter.  The only type safety issue is to handle nulls.
          if (placeGoogleObject.location != null) {
            // Because resolvedPlace.location is a LegacyJavaScriptObject, we treat it as a JSObject, although we know that it is a LatLng.(_JSObject_)
            final JSObject locationObj =
                placeGoogleObject.location! as JSObject;

            // Since we know that locationObj is actually a LatLng.(_JSObject_), we know we can use these getter methods to get the coordinates.
            final JSNumber jsLat = locationObj.callMethod('lat'.toJS);
            final JSNumber jsLng = locationObj.callMethod('lng'.toJS);
            return LatLng(jsLat.toDartDouble, jsLng.toDartDouble);
          } else {
            print('placeGoogleObject did not work');
          }
        } else {
          if (dartResponse is Map) {
            print('dartPlace is Map: true');
            print(
              'dartPlace.containsKey('
              'place'
              '): ${dartResponse.containsKey('place')}',
            );
            print('dartPlace.keys.toList(): ${dartResponse.keys.toList()}');
          } else {
            print('dartPlace is Map: false');
          }
        }
      }
    } catch (e) {
      print("Error fetching modern place coordinates: $e");
    }

    return null;
  }

  // 3. Reverse Geocode: Get text address from map click coordinates
  Future<String?> _getAddressFromLatLng(LatLng position) async {
    print(
      'starting _getLatLngFromPlaceId.  position.latitude: ${position.latitude},   position.longitude: ${position.longitude}',
    );
try {
    // 1. Initialize the native JS Geocoder engine
    final gmaps_geo.Geocoder geocoder = gmaps_geo.Geocoder();

    // 2. Wrap your Flutter coordinate parameters into a native JS LatLng literal
    final gmaps.LatLng jsLatLng = gmaps.LatLng(
      position.latitude,
      position.longitude,
    );

    // 3. Configure the Geocoder request payload
    final gmaps_geo.GeocoderRequest request = gmaps_geo.GeocoderRequest()
      ..location = jsLatLng;

    // 4. Fire the geocode call across the interop bridge
    final Future<gmaps_geo.GeocoderResponse> jsPromise = geocoder.geocode(request);

    // 5. Await the response array
    final gmaps_geo.GeocoderResponse jsResponseAny = await jsPromise;
    
    // 6. Flatten the raw JS response map down to a native Dart structure
    final dynamic dartResponse = jsResponseAny.dartify();

    if (dartResponse is Map && dartResponse.containsKey('results')) {
      final dynamic resultsList = dartResponse['results'];

      // 7. Check that results were found, then pick the top/closest matches
      if (resultsList is List && resultsList.isNotEmpty) {
        final dynamic topResult = resultsList.first;

        if (topResult is Map && topResult.containsKey('formatted_address')) {
          // Return the complete physical human-readable address text
          return topResult['formatted_address']?.toString();
        }
      }
    }
    } catch (e) {
    // Catch networking anomalies or billing limit flags silently
    return null;
  }
  return null;



    // try {
    //   // 1. Create a modern JS LatLng object from your Flutter coordinates
    //   final gmaps_core.LatLng jsLatLng = gmaps_core.LatLng(
    //     position.latitude,
    //     position.longitude,
    //   );


    //   // 2. Instantiate a Place using the new coordinate options profile
    //   // final gmaps_places.PlaceOptions placeOptions = gmaps_places.PlaceOptions();

    //   // final JSObject jsOptions = placeOptions as JSObject;
    //   // jsOptions['location'] = jsLatLng as JSAny;

    //   // ..locationRestriction = jsLatLng;
    //   final gmaps_places.Place place = gmaps_places.Place(
    //     gmaps_places.PlaceOptions(),
    //   )..location = jsLatLng;

    //   // 3. Request the formatted address text field asynchronously
    //   final gmaps_places.FetchFieldsRequest fieldsRequest =
    //       gmaps_places.FetchFieldsRequest()..fields = ['formattedAddress'];

    //   // 4. Invoke the Promise-based API method
    //   final JSAny? jsPromise = place.fetchFields(fieldsRequest);

    //   if (jsPromise != null) {
    //     print('jsPromise is not null');
    //     // 5. Await the JS Promise conversion into a usable Dart response
    //     final JSAny? jsResponseAny = await (jsPromise as JSPromise).toDart;

    //     // 6. Cast the response to the correct Place type to extract the address text
    //     if (jsResponseAny != null) {
    //       print('jsResponseAny is not null');
    //       final dynamic dartResponse = jsResponseAny.dartify();
    //       if (dartResponse is Map && dartResponse.containsKey('place')) {
    //         final JSAny? dartPlaceAny = dartResponse['place'];
    //         if (dartPlaceAny == null) {
    //           print('dartPlaceAny is null');
    //           return null;
    //           // I should actually do something here.  Why would it return null?  If there is a legitimate reason, I need to accomodate that in the app.
    //         }
    //         final JSObject placeJSObject = dartPlaceAny as JSObject;
    //         final gmaps_places.Place resolvedPlace =
    //             placeJSObject as gmaps_places.Place;

    //         if (resolvedPlace.formattedAddress != null) {
    //           print(
    //             'finishing _getAddressFromLatLng.  It all seems to have worked.  Returning resolvedPlace.formattedAddress: ${resolvedPlace.formattedAddress}',
    //           );
    //           return resolvedPlace.formattedAddress;
    //         } else {
    //           print('resolvedPlace.formattedAddress is null');
    //         }
    //       } else {
    //         print('Something is not right with dartResponse');
    //       }
    //     } else {
    //       print('jsResponse is null');
    //     }
    //   }
    // } catch (e) {
    //   print("Error reverse geocoding with modern Place API: $e");
    // }

    // print(
    //   'finishing _getAddressFromLatLng.  Something did not work.  Returning null',
    // );
    // return null;
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
                print('Got address after clicking the map, address: $address');
                _searchController.text = address;
              } else {
                print('Clicked map but address was null');
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

// 1. Declare the global JS Object class wrapper
@JS('Object')
extension type JSObjectClass._(JSObject _) implements JSObject {
  // 2. Bind directly to JavaScript's native Object.keys() method
  external static JSArray<JSString> keys(JSObject object);
}

// --- Usage inside your function ---
List<String> inspectObject(JSObject someJsObject) {
  // Get the keys as a JavaScript Array of JS Strings
  final JSArray<JSString> jsKeys = JSObjectClass.keys(someJsObject);

  // Convert it cleanly to a standard Dart List<String> to view or loop over
  final List<String> dartKeys = jsKeys.toDart
      .map((jsStr) => jsStr.toDart)
      .toList();

  // Now you can safely use it like a regular list:
  // print("Available keys: $dartKeys"); // e.g. ['location', 'displayName']

  return dartKeys;
}
