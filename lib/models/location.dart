class Location {
  final String? placeId;
  final String name;
  final String? formattedAddress;
  final double? latitude;
  final double? longitude;
  final LocationType type;

  const Location({
    this.placeId,
    required this.name,
    this.formattedAddress,
    this.latitude,
    this.longitude,
    this.type = LocationType.place,
  });

  Location copyWith({
    String? placeId,
    String? name,
    String? formattedAddress,
    double? latitude,
    double? longitude,
    LocationType? type,
  }) {
    return Location(
      placeId: placeId ?? this.placeId,
      name: name ?? this.name,
      formattedAddress: formattedAddress ?? this.formattedAddress,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      type: type ?? this.type,
    );
  }

  // Factory constructor for current location
  factory Location.currentLocation({
    required double latitude,
    required double longitude,
    String? formattedAddress,
  }) {
    return Location(
      name: 'Current Location',
      formattedAddress: formattedAddress ?? 'Your current location',
      latitude: latitude,
      longitude: longitude,
      type: LocationType.currentLocation,
    );
  }

  // Factory constructor for saved places
  factory Location.savedPlace({
    required String name,
    required double latitude,
    required double longitude,
    String? formattedAddress,
  }) {
    return Location(
      name: name,
      formattedAddress: formattedAddress ?? name,
      latitude: latitude,
      longitude: longitude,
      type: LocationType.savedPlace,
    );
  }

  // Factory constructor from Google Places API response
  factory Location.fromPlaceDetails({
    required String placeId,
    required String name,
    required String formattedAddress,
    required double latitude,
    required double longitude,
  }) {
    return Location(
      placeId: placeId,
      name: name,
      formattedAddress: formattedAddress,
      latitude: latitude,
      longitude: longitude,
      type: LocationType.place,
    );
  }

  bool get hasCoordinates => latitude != null && longitude != null;

  String get displayName => formattedAddress ?? name;

  Map<String, dynamic> toJson() => {
    'placeId': placeId,
    'name': name,
    'formattedAddress': formattedAddress,
    'latitude': latitude,
    'longitude': longitude,
    'type': type.toString(),
  };

  factory Location.fromJson(Map<String, dynamic> json) => Location(
    placeId: json['placeId'],
    name: json['name'] ?? '',
    formattedAddress: json['formattedAddress'],
    latitude: json['latitude']?.toDouble(),
    longitude: json['longitude']?.toDouble(),
    type: LocationType.values.firstWhere(
      (e) => e.toString() == json['type'],
      orElse: () => LocationType.place,
    ),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Location &&
          runtimeType == other.runtimeType &&
          placeId == other.placeId &&
          name == other.name &&
          latitude == other.latitude &&
          longitude == other.longitude;

  @override
  int get hashCode =>
      placeId.hashCode ^
      name.hashCode ^
      latitude.hashCode ^
      longitude.hashCode;

  @override
  String toString() => 'Location(name: $name, lat: $latitude, lng: $longitude)';
}

enum LocationType {
  currentLocation,
  savedPlace,
  place,
  recentPlace,
}