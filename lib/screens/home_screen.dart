import 'package:flutter/material.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/destination.dart';
import '../services/navigation_service.dart';
import '../services/tesla_auth_service.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const String _recentDestinationsKey = 'recent_destinations';

  final _navigationService = NavigationService();
  final _teslaAuthService = TeslaAuthService();
  final _placesController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  late final VoidCallback _focusListener;
  Destination? _selectedDestination;
  NavigationApp _selectedApp = NavigationApp.tmap;
  bool _isLoading = false;
  bool _isSendingToTesla = false;
  GoogleMapController? _mapController;
  String? _userEmail;
  List<Map<String, dynamic>> _vehicles = [];
  String? _selectedVehicleId;
  List<Destination> _recentDestinations = [];

  @override
  void initState() {
    super.initState();
    _focusListener = () => setState(() {});
    _searchFocusNode.addListener(_focusListener);
    _placesController.addListener(() {
      debugPrint('onChanged: ${_placesController.text}');
      if (mounted) {
        setState(() {});
      }
    });
    _loadDefaultNavigationApp();
    _loadUserEmail();
    _loadTeslaVehicles();
    _loadRecentDestinations();
  }

  Future<void> _loadDefaultNavigationApp() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(kDefaultNavigationAppKey);
    if (stored != null) {
      final app = NavigationApp.values.firstWhere(
        (item) => item.name == stored,
        orElse: () => NavigationApp.tmap,
      );
      if (mounted) {
        setState(() {
          _selectedApp = app;
        });
      }
    }
  }

  Future<void> _openSettings() async {
    final result = await Navigator.of(context).pushNamed('/settings');
    if (result == true) {
      await _loadDefaultNavigationApp();
    }
  }

  Future<void> _loadUserEmail() async {
    final email = await _teslaAuthService.getEmail();
    if (mounted) {
      setState(() {
        _userEmail = email;
      });
    }
  }

  Future<void> _loadRecentDestinations() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_recentDestinationsKey) ?? [];
    final destinations = stored
        .map((item) => Destination.fromMap(jsonDecode(item)))
        .toList();
    if (!mounted) return;
    setState(() {
      _recentDestinations = destinations;
    });
  }

  Future<void> _saveRecentDestination(Destination destination) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _recentDestinations.removeWhere((item) {
        if (item.placeId != null && destination.placeId != null) {
          return item.placeId == destination.placeId;
        }
        return item.latitude == destination.latitude &&
            item.longitude == destination.longitude;
      });
      _recentDestinations.insert(0, destination);
      if (_recentDestinations.length > 5) {
        _recentDestinations = _recentDestinations.sublist(0, 5);
      }
    });
    await prefs.setStringList(
      _recentDestinationsKey,
      _recentDestinations.map((d) => jsonEncode(d.toMap())).toList(),
    );
  }

  Future<void> _applySelectedDestination(Destination destination) async {
    setState(() {
      _isLoading = false;
      _selectedDestination = destination;
      _placesController.text = destination.name;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _moveCameraToSelectedDestination();
    });

    await _saveRecentDestination(destination);
  }

  Future<void> _moveCameraToSelectedDestination() async {
    if (_mapController != null && _selectedDestination != null) {
      final dest = _selectedDestination!;
      await _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(dest.latitude, dest.longitude), 15.0),
      );
    }
  }

  Future<void> _loadTeslaVehicles() async {
    final loggedIn = await _teslaAuthService.isLoggedIn();
    if (!loggedIn) {
      if (mounted) {
        setState(() {
          _vehicles = [];
          _selectedVehicleId = null;
        });
      }
      return;
    }

    final vehicles = await _teslaAuthService.getVehicles();
    if (mounted) {
      setState(() {
        _vehicles = vehicles;
        if (vehicles.isNotEmpty) {
          final firstValidId = vehicles
              .map(
                (vehicle) =>
                    (vehicle['id_s'] ?? vehicle['id']?.toString())?.toString(),
              )
              .firstWhere(
                (id) => id != null && id.isNotEmpty,
                orElse: () => null,
              );
          _selectedVehicleId ??= firstValidId;
        }
      });
    }
  }

  Future<void> _sendDestinationToTesla(Destination destination) async {
    if (_selectedVehicleId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('테슬라 차량을 먼저 선택해주세요.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    setState(() {
      _isSendingToTesla = true;
    });

    final vehicleId = _selectedVehicleId!;
    final success = await _teslaAuthService.sendDestinationToVehicle(
      vehicleId,
      destination.latitude,
      destination.longitude,
      destination.name,
    );

    if (mounted) {
      setState(() {
        _isSendingToTesla = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? '테슬라 차량에 목적지가 전송되었습니다.' : '테슬라 차량 전송에 실패했습니다.',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  // Google Places API key
  static const String _googlePlacesApiKey =
      'AIzaSyBb1IGpqLzKwdtAfyzsqP7YZpn0nQI9iQo';

  @override
  void dispose() {
    _searchFocusNode.removeListener(_focusListener);
    _placesController.dispose();
    _searchFocusNode.dispose();
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
        await _applySelectedDestination(placeDetails);
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

    setState(() {
      _isLoading = true;
    });

    try {
      if (_vehicles.isEmpty) {
        await _loadTeslaVehicles();
      }

      final navSuccess = await _navigationService.launchNavigation(
        _selectedApp,
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
          final destination = _selectedDestination!;
          if (_vehicles.isNotEmpty) {
            await _sendDestinationToTesla(destination);
          }
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
      appBar: AppBar(
        title: const Text('테슬라 맵 브릿지'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: '설정',
            onPressed: _openSettings,
          ),
          if (_userEmail != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Center(
                child: Text(_userEmail!, style: const TextStyle(fontSize: 12)),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: GooglePlaceAutoCompleteTextField(
                    textEditingController: _placesController,
                    googleAPIKey: _googlePlacesApiKey,
                    focusNode: _searchFocusNode,
                    textInputAction: TextInputAction.done,
                    formSubmitCallback: () {
                      _searchFocusNode.unfocus();
                      FocusManager.instance.primaryFocus?.unfocus();
                    },
                    boxDecoration: const BoxDecoration(
                      color: Colors.transparent,
                    ),
                    containerHorizontalPadding: 0,
                    containerVerticalPadding: 0,
                    inputDecoration: InputDecoration(
                      hintText: '목적지를 검색하세요',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    debounceTime: 400,
                    countries: const ['kr', 'us', 'jp', 'cn'],
                    isLatLngRequired: true,
                    getPlaceDetailWithLatLng: (prediction) {
                      _onPlaceSelected(prediction);
                    },
                    itemClick: (prediction) {
                      _placesController.text = prediction.description ?? '';
                      _searchFocusNode.unfocus();
                      FocusManager.instance.primaryFocus?.unfocus();
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
                  ),
                ),
                if (_recentDestinations.isNotEmpty &&
                    _searchFocusNode.hasFocus &&
                    _placesController.text.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Card(
                      elevation: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Padding(
                            padding: EdgeInsets.all(12.0),
                            child: Text(
                              '최근 검색한 장소',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          const Divider(height: 1),
                          ..._recentDestinations.map(
                            (destination) => ListTile(
                              leading: const Icon(Icons.history),
                              title: Text(destination.name),
                              subtitle: destination.address.isNotEmpty
                                  ? Text(destination.address)
                                  : null,
                              trailing: const Icon(Icons.north_east),
                              onTap: () {
                                debugPrint(
                                  '[Recent] tapped ${destination.name}',
                                );
                                _searchFocusNode.unfocus();
                                FocusManager.instance.primaryFocus?.unfocus();
                                _applySelectedDestination(destination);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                SizedBox(
                  height: 320,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: GoogleMap(
                      initialCameraPosition: const CameraPosition(
                        target: LatLng(37.5665, 126.9780),
                        zoom: 12,
                      ),
                      onMapCreated: (controller) {
                        _mapController = controller;
                        _moveCameraToSelectedDestination();
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
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_selectedDestination != null) ...[
                        Card(
                          child: ListTile(
                            leading: const Icon(
                              Icons.location_on,
                              color: Colors.red,
                            ),
                            title: Text(
                              _selectedDestination!.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(_selectedDestination!.address),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (_userEmail != null) ...[
                        const Text(
                          '테슬라 차량 선택',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_vehicles.isNotEmpty)
                          DropdownButtonFormField<String>(
                            value: _selectedVehicleId,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            items: _vehicles
                                .map((vehicle) {
                                  final id =
                                      (vehicle['id_s'] ??
                                              vehicle['id']?.toString())
                                          ?.toString();
                                  if (id == null || id.isEmpty) {
                                    return null;
                                  }
                                  final name =
                                      vehicle['display_name'] as String? ??
                                      vehicle['vin'] as String? ??
                                      '차량 ${vehicle['id']}';
                                  return DropdownMenuItem<String>(
                                    value: id,
                                    child: Text(name),
                                  );
                                })
                                .whereType<DropdownMenuItem<String>>()
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedVehicleId = value;
                              });
                            },
                          )
                        else
                          Card(
                            color: Colors.grey.shade200,
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Text(
                                '등록된 차량이 없거나 불러오지 못했습니다.\nTesla 앱에서 차량을 확인한 후 새로고침하세요.',
                                style: TextStyle(color: Colors.grey.shade700),
                              ),
                            ),
                          ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: _isLoading ? null : _loadTeslaVehicles,
                            icon: const Icon(Icons.refresh),
                            label: const Text('차량 새로고침'),
                          ),
                        ),
                        if (_isSendingToTesla)
                          Row(
                            children: const [
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 8),
                              Text('테슬라 차량으로 전송 중...'),
                            ],
                          ),
                        const SizedBox(height: 16),
                      ],
                      ElevatedButton.icon(
                        onPressed: _isLoading || _selectedDestination == null
                            ? null
                            : _startNavigation,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
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
          ),
        ),
      ),
    );
  }
}
