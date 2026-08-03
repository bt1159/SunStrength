import 'package:flutter/material.dart';
import 'package:sun_strength_app/models/helpers.dart';

class CurrentLocationNotifier extends ValueNotifier<Location?> {
  CurrentLocationNotifier() : super(null) {
    print(
      'running CurrentLocationNotifier constructor, with value.name: ${value?.name}',
    );
  }

  bool savedLocationLoaded = false;

  void updateWithInitialSaved(Location? savedLocation) {
    if (savedLocationLoaded) return;
    print(
      'Before assignment: Equal? ${value == savedLocation} and value?.name: ${value?.name}, savedLocation?.name: ${savedLocation?.name}',
    );
    if (value != savedLocation) {
      value = savedLocation;
    }
    savedLocationLoaded = true;
    print('CurrentLocationNotifier just updated from savedLocation');
  }

  void updateWithNewLocation(Location? newLocation) {
    print(
      'Before assignment: Equal? ${value == newLocation}, value?.name: ${value?.name}, newLocation?.name: ${newLocation?.name}',
    ); // If this is true, it won't rebuild!
    value = newLocation;
    print('CurrentLocationNotifier just updated from new Location?');
  }
}
