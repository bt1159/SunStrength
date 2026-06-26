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
  Map<String, Object> get toObjMap => {'name':name,'lat': lat,'lon': lon};
  String get toJSONString => jsonEncode(toMap);


  @override
  bool operator ==(Object other) {
    // 1. Check for reference identity
    if (identical(this, other)) return true;

    // 2. Check type, runtimeType, and property values
    return other is Location &&
        other.runtimeType == runtimeType &&
        other.name == name &&
        other.lat == lat &&
        other.lon == lon;
  }

  @override
  // 3. Always override hashCode using the same properties
  int get hashCode => Object.hash(name, lat, lon);
}
