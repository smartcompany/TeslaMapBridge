class Destination {
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final String? placeId;
  final DateTime? lastNavigatedAt;

  Destination({
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.placeId,
    this.lastNavigatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'placeId': placeId,
      'lastNavigatedAt': lastNavigatedAt?.toIso8601String(),
    };
  }

  factory Destination.fromMap(Map<String, dynamic> map) {
    return Destination(
      name: map['name'] as String? ?? 'Unknown place',
      address: map['address'] as String? ?? '',
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      placeId: map['placeId'] as String?,
      lastNavigatedAt: map['lastNavigatedAt'] != null
          ? DateTime.tryParse(map['lastNavigatedAt'] as String)
          : null,
    );
  }

  @override
  String toString() {
    return 'Destination(name: $name, address: $address, lat: $latitude, lng: $longitude)';
  }
}
