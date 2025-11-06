import 'package:flutter/material.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';
import '../models/destination.dart';
import '../services/navigation_service.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _navigationService = NavigationService();
  final _placesController = TextEditingController();
  Destination? _selectedDestination;
  NavigationApp? _selectedApp;
  bool _isLoading = false;
  GoogleMapController? _mapController;

  // Google Places API key
  static const String _googlePlacesApiKey =
      'AIzaSyBb1IGpqLzKwdtAfyzsqP7YZpn0nQI9iQo';

  @override
  void dispose() {
    _placesController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _onPlaceSelected(Prediction prediction) async {
    if (prediction.placeId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Get place details
      final placeDetails = await _getPlaceDetails(prediction.placeId!);

      if (placeDetails != null) {
        setState(() {
          _selectedDestination = placeDetails;
          _placesController.text = placeDetails.name;
        });

        // Move map camera to destination
        if (_mapController != null) {
          await _mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(
              LatLng(placeDetails.latitude, placeDetails.longitude),
              15,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('장소 정보를 가져오는데 실패했습니다: $e')));
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<Destination?> _getPlaceDetails(String placeId) async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&key=$_googlePlacesApiKey&language=ko',
        ),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final result = data['result'] as Map<String, dynamic>;

        final name = result['name'] as String? ?? '알 수 없는 장소';
        final address = result['formatted_address'] as String? ?? '';
        final geometry = result['geometry'] as Map<String, dynamic>;
        final location = geometry['location'] as Map<String, dynamic>;
        final lat = (location['lat'] as num).toDouble();
        final lng = (location['lng'] as num).toDouble();

        return Destination(
          name: name,
          address: address,
          latitude: lat,
          longitude: lng,
          placeId: placeId,
        );
      }
    } catch (e) {
      print('Error getting place details: $e');
    }
    return null;
  }

  Future<void> _startNavigation() async {
    if (_selectedDestination == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('목적지를 선택해주세요')));
      return;
    }

    if (_selectedApp == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('네비게이션 앱을 선택해주세요')));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Start navigation in selected app
      final navSuccess = await _navigationService.launchNavigation(
        _selectedApp!,
        _selectedDestination!.latitude,
        _selectedDestination!.longitude,
        _selectedDestination!.name,
      );

      if (mounted) {
        if (navSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('길 안내가 시작되었습니다'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('길 안내를 시작하지 못했습니다'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('오류 발생: $e')));
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('테슬라 맵 브릿지')),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: GooglePlaceAutoCompleteTextField(
              textEditingController: _placesController,
              googleAPIKey: _googlePlacesApiKey,
              inputDecoration: InputDecoration(
                hintText: '목적지를 검색하세요',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              debounceTime: 400,
              countries: const ['kr'],
              isLatLngRequired: true,
              getPlaceDetailWithLatLng: (prediction) {
                _onPlaceSelected(prediction);
              },
              itemClick: (prediction) {
                _placesController.text = prediction.description ?? '';
                _onPlaceSelected(prediction);
              },
              itemBuilder: (context, index, prediction) {
                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      const Icon(Icons.place, size: 20),
                      const SizedBox(width: 8),
                      Expanded(child: Text(prediction.description ?? '')),
                    ],
                  ),
                );
              },
              seperatedBuilder: const Divider(),
              containerHorizontalPadding: 10,
            ),
          ),
          // Map
          Expanded(
            flex: 2,
            child: GoogleMap(
              initialCameraPosition: const CameraPosition(
                target: LatLng(37.5665, 126.9780), // Seoul
                zoom: 12,
              ),
              onMapCreated: (controller) {
                _mapController = controller;
              },
              markers: _selectedDestination != null
                  ? {
                      Marker(
                        markerId: const MarkerId('destination'),
                        position: LatLng(
                          _selectedDestination!.latitude,
                          _selectedDestination!.longitude,
                        ),
                        infoWindow: InfoWindow(
                          title: _selectedDestination!.name,
                          snippet: _selectedDestination!.address,
                        ),
                      ),
                    }
                  : {},
            ),
          ),
          // Navigation app selection
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_selectedDestination != null) ...[
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.location_on, color: Colors.red),
                      title: Text(
                        _selectedDestination!.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(_selectedDestination!.address),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                const Text(
                  '네비게이션 앱 선택',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildAppButton(
                        NavigationApp.tmap,
                        'T맵',
                        Icons.directions,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildAppButton(
                        NavigationApp.naver,
                        '네이버 네비',
                        Icons.navigation,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildAppButton(
                        NavigationApp.kakao,
                        '카카오 네비',
                        Icons.map,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed:
                      _isLoading ||
                          _selectedDestination == null ||
                          _selectedApp == null
                      ? null
                      : _startNavigation,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.directions_car),
                  label: const Text('길 안내 시작'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppButton(NavigationApp app, String label, IconData icon) {
    final isSelected = _selectedApp == app;
    return OutlinedButton(
      onPressed: () {
        setState(() {
          _selectedApp = app;
        });
      },
      style: OutlinedButton.styleFrom(
        backgroundColor: isSelected
            ? Theme.of(context).colorScheme.primaryContainer
            : null,
        side: BorderSide(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Colors.grey.shade300,
          width: isSelected ? 2 : 1,
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.grey,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
}
