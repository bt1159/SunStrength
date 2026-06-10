import 'dart:convert';

typedef LocationCallback = void Function({required Location location});

class Location {
  const Location({required this.name, required this.lat, required this.lon});
  Location.fromMap({required Map<String, dynamic> inputMap})
    : name = inputMap['name'],
      lat = inputMap['lat'],
      lon = inputMap['lon'];

  final String name;
  final num lat;
  final num lon;

  Map<String, dynamic> get toMap => {'name':name,'lat': lat,'lon': lon};
  String get toJSONString => jsonEncode(toMap);
}
