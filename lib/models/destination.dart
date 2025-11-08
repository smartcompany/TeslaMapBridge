class Destination {
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final String? placeId;

  Destination({
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.placeId,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'placeId': placeId,
    };
  }

  factory Destination.fromMap(Map<String, dynamic> map) {
    return Destination(
      name: map['name'] as String? ?? '알 수 없는 장소',
      address: map['address'] as String? ?? '',
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      placeId: map['placeId'] as String?,
    );
  }

  @override
  String toString() {
    return 'Destination(name: $name, address: $address, lat: $latitude, lng: $longitude)';
  }
}
