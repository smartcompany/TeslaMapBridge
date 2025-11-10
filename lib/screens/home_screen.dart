import 'package:flutter/material.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_localizations.dart';
import '../models/destination.dart';
import '../models/tesla_navigation_mode.dart';
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
  TeslaNavigationMode _navigationMode = TeslaNavigationMode.destination;
  bool _isLoading = false;
  bool _isSendingToTesla = false;
  GoogleMapController? _mapController;
  String? _userEmail;
  String? _selectedVehicleId;
  List<Destination> _recentDestinations = [];

  bool get _shouldShowRecentSuggestions =>
      _recentDestinations.isNotEmpty &&
      _searchFocusNode.hasFocus &&
      _placesController.text.isEmpty;

  @override
  void initState() {
    super.initState();
    _focusListener = () => setState(() {});
    _searchFocusNode.addListener(_focusListener);
    _placesController.addListener(() {
      print('onChanged: ${_placesController.text}');
      if (mounted) {
        setState(() {});
      }
    });
    _loadDefaultNavigationApp();
    _loadNavigationMode();
    _loadUserEmail();
    _loadRecentDestinations();
    _loadSelectedVehicleId();
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

  Future<void> _loadNavigationMode() async {
    final mode = await _teslaAuthService.getNavigationModePreference();
    if (mounted) {
      setState(() {
        _navigationMode = mode;
      });
    }
  }

  Future<void> _openSettings() async {
    final result = await Navigator.of(context).pushNamed('/settings');
    if (result == true) {
      await _loadDefaultNavigationApp();
      await _loadNavigationMode();
      await _loadSelectedVehicleId();
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

  Future<void> _loadSelectedVehicleId() async {
    final storedId = await _teslaAuthService.getSelectedVehicleId();
    if (!mounted) return;
    setState(() {
      _selectedVehicleId = storedId;
    });
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
    if (_mapController == null || _selectedDestination == null) {
      return;
    }
    final dest = _selectedDestination!;
    final controller = _mapController!;
    final currentZoom = await controller.getZoomLevel();
    await controller.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(dest.latitude, dest.longitude),
        currentZoom,
      ),
    );
  }

  String _currentLanguageParam() {
    if (!mounted) {
      return 'en';
    }
    final locale = Localizations.localeOf(context);
    final tag = locale.toLanguageTag();
    if (tag.isNotEmpty) {
      return tag;
    }
    final code = locale.languageCode;
    return code.isNotEmpty ? code : 'en';
  }

  Future<void> _sendDestinationToTesla(Destination destination) async {
    if (_selectedVehicleId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.teslaVehicleRequired),
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
      mode: _navigationMode,
    );

    if (mounted) {
      print(
        '[TeslaSend] vehicleId=$vehicleId '
        'lat=${destination.latitude} lon=${destination.longitude} '
        'name=${destination.name} success=$success',
      );
      setState(() {
        _isSendingToTesla = false;
      });
      final loc = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? loc.sendToTeslaSuccess : loc.sendToTeslaFailure,
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
        final loc = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.failedToFetchPlaceDetails('$e'))),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<Destination?> _getDestinationFromLatLng(LatLng latLng) async {
    try {
      final languageParam = _currentLanguageParam();
      final response = await http.get(
        Uri.parse(
          'https://maps.googleapis.com/maps/api/geocode/json'
          '?latlng=${latLng.latitude},${latLng.longitude}'
          '&key=$_googlePlacesApiKey&language=$languageParam',
        ),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final results = data['results'] as List<dynamic>? ?? [];
        debugPrint(
          '[ReverseGeocode] got ${results.length} results for '
          '${latLng.latitude},${latLng.longitude}',
        );
        if (results.isNotEmpty) {
          Map<String, dynamic>? pick;
          for (final result in results) {
            if (result is! Map<String, dynamic>) continue;
            final types = result['types'] as List<dynamic>? ?? const [];
            if (types.contains('point_of_interest') ||
                types.contains('establishment') ||
                types.contains('transit_station')) {
              pick = result;
              debugPrint(
                '[ReverseGeocode] selected by type: ${pick['name']} '
                'types=$types place_id=${pick['place_id']}',
              );
              break;
            }
          }
          pick ??= results.first as Map<String, dynamic>;

          final placeId = pick['place_id'] as String?;
          if (placeId != null) {
            debugPrint('[ReverseGeocode] fetching details for $placeId');
            final details = await _getPlaceDetails(placeId);
            if (details != null) {
              return details;
            }
            debugPrint('[ReverseGeocode] details lookup returned null');
          }

          final address = pick['formatted_address'] as String? ?? '';
          String name = address;
          if (pick['address_components'] is List) {
            final components = pick['address_components'] as List<dynamic>;
            if (components.isNotEmpty) {
              name = components.first['long_name'] as String? ?? address;
            }
          }
          debugPrint(
            '[ReverseGeocode] fallback name=$name address=$address '
            'placeId=$placeId',
          );

          return Destination(
            name: name.isEmpty
                ? AppLocalizations.of(context)!.unknownPlace
                : name,
            address: address,
            latitude: latLng.latitude,
            longitude: latLng.longitude,
            placeId: placeId,
          );
        }
      }
      if (response.statusCode != 200) {
        debugPrint(
          '[ReverseGeocode] HTTP ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e, st) {
      debugPrint('Error reverse geocoding: $e');
      debugPrint('$st');
    }

    final nearby = await _getNearbyPlace(latLng);
    if (nearby != null) {
      return nearby;
    }

    return Destination(
      name: AppLocalizations.of(context)!.unknownPlace,
      address:
          '${latLng.latitude.toStringAsFixed(5)}, ${latLng.longitude.toStringAsFixed(5)}',
      latitude: latLng.latitude,
      longitude: latLng.longitude,
    );
  }

  Future<Destination?> _getNearbyPlace(LatLng latLng) async {
    try {
      final languageParam = _currentLanguageParam();
      final response = await http.get(
        Uri.parse(
          'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
          '?location=${latLng.latitude},${latLng.longitude}'
          '&rankby=distance'
          '&key=$_googlePlacesApiKey'
          '&language=$languageParam'
          '&type=point_of_interest',
        ),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final results = data['results'] as List<dynamic>? ?? [];
        debugPrint(
          '[NearbySearch] got ${results.length} results for '
          '${latLng.latitude},${latLng.longitude}',
        );
        if (results.isNotEmpty) {
          final first = results.first as Map<String, dynamic>;
          debugPrint(
            '[NearbySearch] picked ${first['name']} '
            'place_id=${first['place_id']} types=${first['types']}',
          );
          final placeId = first['place_id'] as String?;
          if (placeId != null) {
            final details = await _getPlaceDetails(placeId);
            if (details != null) {
              return details;
            }
          }

          final name =
              first['name'] as String? ??
              AppLocalizations.of(context)!.unknownPlace;
          final vicinity = first['vicinity'] as String? ?? '';
          return Destination(
            name: name,
            address: vicinity.isNotEmpty ? vicinity : name,
            latitude: latLng.latitude,
            longitude: latLng.longitude,
            placeId: placeId,
          );
        }
      } else {
        debugPrint(
          '[NearbySearch] HTTP ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e, st) {
      debugPrint('Error nearby search: $e');
      debugPrint('$st');
    }
    return null;
  }

  Future<void> _onMapTapped(LatLng latLng) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final destination = await _getDestinationFromLatLng(latLng);
      if (destination != null) {
        await _applySelectedDestination(destination);
      }
    } catch (e) {
      if (mounted) {
        final loc = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(loc.errorWithMessage('$e'))));
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<Destination?> _getPlaceDetails(String placeId) async {
    try {
      final languageParam = _currentLanguageParam();
      final response = await http.get(
        Uri.parse(
          'https://maps.googleapis.com/maps/api/place/details/json'
          '?place_id=$placeId&key=$_googlePlacesApiKey&language=$languageParam',
        ),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final result = data['result'] as Map<String, dynamic>;

        final name =
            result['name'] as String? ??
            AppLocalizations.of(context)!.unknownPlace;
        debugPrint('[PlaceDetails] $placeId name=$name');
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
      debugPrint('Error getting place details: $e');
    }
    return null;
  }

  Future<void> _startNavigation() async {
    if (_selectedDestination == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.selectDestinationPrompt),
        ),
      );
      return;
    }

    final destination = _selectedDestination!;
    await _sendDestinationToTesla(destination);

    setState(() {
      _isLoading = true;
    });

    try {
      final navSuccess = await _navigationService.launchNavigation(
        _selectedApp,
        _selectedDestination!.latitude,
        _selectedDestination!.longitude,
        _selectedDestination!.name,
      );

      if (mounted) {
        final loc = AppLocalizations.of(context)!;
        if (navSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(loc.navigationStarted),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(loc.navigationFailed),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        final loc = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(loc.errorWithMessage('$e'))));
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildSearchField(AppLocalizations loc) {
    return GooglePlaceAutoCompleteTextField(
      textEditingController: _placesController,
      googleAPIKey: _googlePlacesApiKey,
      focusNode: _searchFocusNode,
      textInputAction: TextInputAction.done,
      formSubmitCallback: () {
        _searchFocusNode.unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      boxDecoration: const BoxDecoration(color: Colors.transparent),
      containerHorizontalPadding: 0,
      containerVerticalPadding: 0,
      inputDecoration: InputDecoration(
        hintText: loc.searchHint,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _placesController.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  setState(() {
                    _placesController.clear();
                  });
                  _searchFocusNode.requestFocus();
                },
              ),
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
          borderSide: BorderSide(color: Theme.of(context).primaryColor),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 0),
      ),
      debounceTime: 400,
      countries: const ['kr', 'us', 'jp', 'cn'],
      isLatLngRequired: true,
      isCrossBtnShown: false,
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
    );
  }

  Widget _buildMap() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
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
          onTap: _onMapTapped,
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
    );
  }

  Widget _buildRecentDestinationsOverlay(AppLocalizations loc) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 320),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Text(
                  loc.recentSearches,
                  style: const TextStyle(fontWeight: FontWeight.bold),
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
                    print('[Recent] tapped ${destination.name}');
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
    );
  }

  Widget _buildBottomSection(AppLocalizations loc) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
          if (_isSendingToTesla)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Text(loc.sendingToTesla),
                ],
              ),
            ),
          ElevatedButton.icon(
            onPressed: _isLoading || _selectedDestination == null
                ? null
                : _startNavigation,
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.directions_car),
            label: Text(loc.startNavigation),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        titleSpacing: 0,
        toolbarHeight: 72,
        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SizedBox(height: 48, child: _buildSearchField(loc)),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: loc.settingsTitle,
            onPressed: _openSettings,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(child: _buildMap()),
                  if (_shouldShowRecentSuggestions)
                    Positioned(
                      left: 16,
                      right: 16,
                      top: 0,
                      child: _buildRecentDestinationsOverlay(loc),
                    ),
                ],
              ),
            ),
            _buildBottomSection(loc),
          ],
        ),
      ),
    );
  }
}
