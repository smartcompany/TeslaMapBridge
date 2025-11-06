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

  @override
  String toString() {
    return 'Destination(name: $name, address: $address, lat: $latitude, lng: $longitude)';
  }
}
