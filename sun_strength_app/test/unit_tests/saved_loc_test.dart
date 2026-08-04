import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sun_strength_app/models/current_location_notifier.dart';
import 'package:sun_strength_app/models/helpers.dart';
import 'package:sun_strength_app/models/saved_settings_notifier.dart';
import 'package:flutter_test/flutter_test.dart';
// import 'package:mocktail/mocktail.dart';

// class MockUserRepository extends Mock implements UserRepository {}

void main() {
  final Location locationPxv = Location(
    name: 'Phoenixville, PA',
    lat: 40.0,
    lon: -75.0,
  );
  final Map<String, Object> defaultPrefPxvMap = {
    'default_solar_location': jsonEncode(locationPxv.toObjMap),
  };

  final Location locationTest = Location(
    name: 'Test location',
    lat: 15,
    lon: 15,
  );

  // The function passed to setUp will be run one time before each test().
  // If it is called within a group, it applies only to tests within that group.
  // I'm not sure if that means that it is only called once per group or not.
  // It seems likely.  Also, the body will always be called AFTER anything in
  // the top level and anything in a parent group.
  setUp(() {});

  // Define any top-level variables here

  // A group of tests.  First parameter is any object used as a description.
  // Second is the function body of the group of tests.  if skip is a string,
  // the group will be skipped and it will do something with that string.
  // It must print it or log it or something.  So, skip should be an explanation
  // for why it skipped.  If skip is a bool, true, it will skip without logging.
  // If it is anything else, it will not skip.  IT IS NOT TREATED AS TRUTHY.
  // Retry is an int that defines the number of times to retry the group before
  // considering it a failure.
  group('SavedLocationNotifier test group:', () {
    // An actual test to run.  First is description, like for group().  Next is
    // the test body, like for group().  It also has named skip and retry, like
    // for group, but I am not taking the time to define those here.
    test('**SavedLocationNotifier with initial value is null**', () async {
      // Arrange
      // when(() => mockSavedLocationNotifier.notifyListeners()).thenReturn(mockSavedLocationNotifier.value == null ? 'null' : 'not null');

      // Act

      bool listenerCalled = false;
      SharedPreferences.setMockInitialValues({});

      final SavedSettingsNotifier savedLocationNotifier =
          SavedSettingsNotifier();
      savedLocationNotifier.addListener(() {
        listenerCalled = true;
      });
      await pumpEventQueue();

      // Assert

      // Assert that `actual` matches `matcher`.
      //
      // See [matcher_expect.expect] for details. This is a variant of that function
      // that additionally verifies that there are no asynchronous APIs
      // that have not yet resolved.
      //
      // See also:
      //
      //  * [expectLater] for use with asynchronous matchers.
      expect(savedLocationNotifier.value?.defaultLocation, isNull);
      expect(savedLocationNotifier.isInitialized, isTrue);
      expect(listenerCalled, isFalse);

      // Used to verify that a method on a mock object was called with the given
      // parameters.  You do this by passing verify the object and the method with
      // the parameter you are looking for.  You can also use verify(...).called(int)
      // to verify that the method was called int times.
      // verify();

      // I am not very clear on this, but it checks to make sure that the mock object
      // wasn't created as a duplicate or something.
      // verifyNoMoreInteractions(mockSavedLocationNotifier);
    });
    test('**SavedLocationNotifier with initial value is Phoenixville**', () async {
      // Arrange
      // when(() => mockSavedLocationNotifier.notifyListeners()).thenReturn(mockSavedLocationNotifier.value == null ? 'null' : 'not null');

      // Act

      print('defaultPrefMap: $defaultPrefPxvMap');
      SharedPreferences.setMockInitialValues(defaultPrefPxvMap);

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? savedJson = prefs.getString('default_solar_location');
      print('savedJson: $savedJson');

      final SavedSettingsNotifier savedLocationNotifier =
          SavedSettingsNotifier();
      bool listenerCalled = false;
      savedLocationNotifier.addListener(() {
        listenerCalled = true;
      });
      await pumpEventQueue();

      // Assert

      // Assert that `actual` matches `matcher`.
      //
      // See [matcher_expect.expect] for details. This is a variant of that function
      // that additionally verifies that there are no asynchronous APIs
      // that have not yet resolved.
      //
      // See also:
      //
      //  * [expectLater] for use with asynchronous matchers.
      expect(savedLocationNotifier.value?.defaultLocation, locationPxv);
      expect(savedLocationNotifier.isInitialized, isTrue);
      expect(listenerCalled, isTrue);

      // Used to verify that a method on a mock object was called with the given
      // parameters.  You do this by passing verify the object and the method with
      // the parameter you are looking for.  You can also use verify(...).called(int)
      // to verify that the method was called int times.
      // verify();

      // I am not very clear on this, but it checks to make sure that the mock object
      // wasn't created as a duplicate or something.
      // verifyNoMoreInteractions(mockSavedLocationNotifier);
    });
  });
  group('CurrentLocationNotifier test group', () {
    test('Initial setup', () async {
      // Test that the CurrentLocationNotifier is instantiated but does not have any location yet from the SavedLocationNotifier
      final CurrentLocationNotifier currentLocationNotifier =
          CurrentLocationNotifier();
      bool listenerCalled = false;
      currentLocationNotifier.addListener(() {
        listenerCalled = true;
      });
      await pumpEventQueue();
      expect(currentLocationNotifier.value, null);
      expect(listenerCalled, false);
    });
    test('Getting SavedLocation', () async {
      // Test that the CurrentLocationNotifier correctly gets initialk SavedLocation
      final CurrentLocationNotifier currentLocationNotifier =
          CurrentLocationNotifier();
      bool listenerCalled = false;
      currentLocationNotifier.addListener(() {
        listenerCalled = true;
      });

      SharedPreferences.setMockInitialValues(defaultPrefPxvMap);

      // final SharedPreferences prefs = await SharedPreferences.getInstance();
      // final String? savedJson = prefs.getString('default_solar_location');
      // print('savedJson: $savedJson');

      final SavedSettingsNotifier savedLocationNotifier =
          SavedSettingsNotifier();

      await pumpEventQueue();
      expect(savedLocationNotifier.value?.defaultLocation != null, true);
      expect(listenerCalled, false);
      expect(currentLocationNotifier.savedChartSettingsLoaded, false);
      currentLocationNotifier.updateWithInitialSaved(savedLocationNotifier.value?.defaultLocation);

      expect(currentLocationNotifier.value?.name, locationPxv.name);
      expect(listenerCalled, true);
    });
    test('Loading saved and updating to something else', () async {
      // Test that CurrentLocationNotifier correctly updates its location manually after it has already loaded the savedLocation.
      final CurrentLocationNotifier currentLocationNotifier =
          CurrentLocationNotifier();
      int listenerCalledCounter = 0;
      currentLocationNotifier.addListener(() {
        listenerCalledCounter++;
      });

      SharedPreferences.setMockInitialValues(defaultPrefPxvMap);

      final SavedSettingsNotifier savedLocationNotifier =
          SavedSettingsNotifier();

      await pumpEventQueue();
      currentLocationNotifier.updateWithInitialSaved(savedLocationNotifier.value?.defaultLocation);

      currentLocationNotifier.updateWithNewLocationLocalTZ(locationTest);
      print('listenerCalledCounter: $listenerCalledCounter');
      expect(listenerCalledCounter, 2);
      expect(currentLocationNotifier.value?.name, locationTest.name);
    });
    test('Changing location to null after a non-null', () async {
      // Test that CurrentLocationNotifier correctly updates to null after having a real location
      final CurrentLocationNotifier currentLocationNotifier =
          CurrentLocationNotifier();
      int listenerCalledCounter = 0;
      currentLocationNotifier.addListener(() {
        listenerCalledCounter++;
        print('inside currentLocationNotifier, this should be running immediately after notifyListeners.  new value?.name: ${currentLocationNotifier.value?.name}');
      });

      SharedPreferences.setMockInitialValues(defaultPrefPxvMap);

      final SavedSettingsNotifier savedLocationNotifier =
          SavedSettingsNotifier();

      await pumpEventQueue();
      currentLocationNotifier.updateWithInitialSaved(savedLocationNotifier.value?.defaultLocation);

      currentLocationNotifier.updateWithNewLocationLocalTZ(locationTest);

      currentLocationNotifier.updateWithNewLocationLocalTZ(null);

      print('listenerCalledCounter: $listenerCalledCounter');
      expect(listenerCalledCounter, 3);

      expect(currentLocationNotifier.value, null);
    });
    test('Testing that running update with the same location does NOT call listeners', () async { 

      // Test that CurrentLocationNotifier correctly updates its location manually after it has already loaded the savedLocation.
      final CurrentLocationNotifier currentLocationNotifier =
          CurrentLocationNotifier();
      int listenerCalledCounter = 0;
      currentLocationNotifier.addListener(() {
        listenerCalledCounter++;
      });

      SharedPreferences.setMockInitialValues(defaultPrefPxvMap);

      final SavedSettingsNotifier savedLocationNotifier =
          SavedSettingsNotifier();

      await pumpEventQueue();
      currentLocationNotifier.updateWithInitialSaved(savedLocationNotifier.value?.defaultLocation);
      print('listenerCalledCounter: $listenerCalledCounter');
      final int lockedCounter = listenerCalledCounter;
      currentLocationNotifier.updateWithNewLocationLocalTZ(savedLocationNotifier.value?.defaultLocation);
      print('listenerCalledCounter: $listenerCalledCounter');
      expect(listenerCalledCounter, lockedCounter);
      expect(currentLocationNotifier.value?.name, savedLocationNotifier.value?.defaultLocation?.name);
    });
  });
}
