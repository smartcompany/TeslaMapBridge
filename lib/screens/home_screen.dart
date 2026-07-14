import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import '../models/destination.dart';
import '../models/tesla_navigation_mode.dart';
import '../models/purchase_mode.dart';
import '../services/navigation_service.dart';
import '../services/subscription_service.dart';
import '../services/tesla_auth_service.dart';
import '../services/usage_limit_service.dart';
import '../widgets/subscription_sheet.dart';
import '../widgets/credit_purchase_sheet.dart';
import 'dart:ui' as ui;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  static const String _recentDestinationsKey = 'recent_destinations';
  static const String _favoriteDestinationsKey = 'favorite_destinations';
  static const String _superchargerCacheKey = 'supercharger_poi_cache';
  static const int _superchargerCacheMax = 500;
  static const String _favoriteDestinationLabelsKey =
      'favorite_destination_labels';

  final _navigationService = NavigationService();
  final _placesController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  late final VoidCallback _focusListener;
  Destination? _selectedDestination;
  NavigationApp _selectedApp = NavigationService.defaultNavigationAppForLocale(
    WidgetsBinding.instance.platformDispatcher.locale,
    isIOS: Platform.isIOS,
  );
  TeslaNavigationMode _navigationMode = TeslaNavigationMode.destination;
  bool _isLoading = false;
  bool _isSendingToTesla = false;
  GoogleMapController? _mapController;
  String? _selectedVehicleId;
  List<Destination> _recentDestinations = [];
  List<Destination> _favoriteDestinations = [];
  Set<String> _favoriteDestinationKeys = {};
  Map<String, String> _favoriteNameToAddress = {};
  String? _userId;
  bool _isQuotaLoaded = false;
  bool _locationPermissionGranted = false;
  int _quota = 0;
  late TabController _overlayTabController;
  List<Destination> _textSearchResults = [];
  bool _showTextSearchResults = false;
  bool _isTextSearching = false;
  List<Destination> _superchargerResults = [];
  List<Destination> _superchargerCache = [];
  bool _isLoadingSuperchargers = false;
  bool _showSuperchargerPois = false;
  BitmapDescriptor? _superchargerMarkerIcon;
  BitmapDescriptor? _superchargerSelectedMarkerIcon;
  String? _selectedSuperchargerKey;
  final GlobalKey _searchFieldKey = GlobalKey();
  /// 검색창 포커스/텍스트 변화 시 AppBar 전체 setState 대신 오버레이만 갱신
  final ValueNotifier<int> _searchUiTick = ValueNotifier<int>(0);

  bool get _shouldShowRecentSuggestions =>
      !_showTextSearchResults &&
      _searchFocusNode.hasFocus &&
      _placesController.text.isEmpty;

  bool get _shouldShowTextSearchResults => _showTextSearchResults;
  NavigationApp get _defaultNavigationApp =>
      NavigationService.defaultNavigationAppForLocale(
        WidgetsBinding.instance.platformDispatcher.locale,
        isIOS: Platform.isIOS,
      );

  List<Destination> get _recentDestinationsForDisplay {
    if (_recentDestinations.isEmpty) return const <Destination>[];

    Destination? prioritized;
    int? minDifference;
    final now = DateTime.now();
    final nowMinutes = _minutesSinceMidnight(now);

    for (final destination in _recentDestinations) {
      final navigatedAt = destination.lastNavigatedAt;
      if (navigatedAt == null) continue;
      final diff = _timeOfDayDifference(
        nowMinutes,
        _minutesSinceMidnight(navigatedAt),
      );
      if (minDifference == null || diff < minDifference) {
        minDifference = diff;
        prioritized = destination;
      }
    }

    if (prioritized == null) {
      return List.unmodifiable(_recentDestinations);
    }

    final remaining = _recentDestinations
        .where((destination) => destination != prioritized)
        .toList();
    return [prioritized, ...remaining];
  }

  @override
  void initState() {
    super.initState();
    _overlayTabController = TabController(length: 2, vsync: this);
    _overlayTabController.addListener(() {
      if (!mounted) return;
      setState(() {});
      _searchUiTick.value++;
    });
    _quota = UsageLimitService.shared.userStatus?.quota ?? _quota;
    _focusListener = () {
      if (mounted) {
        _searchUiTick.value++;
      }
    };
    _searchFocusNode.addListener(_focusListener);
    _placesController.addListener(() {
      print('onChanged: ${_placesController.text}');
      if (!mounted) return;
      // 입력 중이면 엔터 검색 결과 오버레이는 닫고 자동완성으로 전환
      if (_showTextSearchResults) {
        setState(() {
          _showTextSearchResults = false;
          _textSearchResults = [];
        });
      } else {
        _searchUiTick.value++;
      }
    });
    _loadDefaultNavigationApp();
    _loadNavigationMode();
    _loadRecentDestinations();
    _loadFavoriteDestinations();
    _loadSuperchargerCache();
    _loadSelectedVehicleId();
    _initLocationServices();
    _initializeUsageTracking();
    // marker icon needs context for pixel ratio — load after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSuperchargerMarkerIcon();
    });
  }

  @override
  void dispose() {
    _overlayTabController.dispose();
    _searchFocusNode.removeListener(_focusListener);
    _searchUiTick.dispose();
    _placesController.dispose();
    _searchFocusNode.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadDefaultNavigationApp() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(kDefaultNavigationAppKey);
    if (stored != null) {
      final app = NavigationApp.values.firstWhere(
        (item) => item.name == stored,
        orElse: () => _defaultNavigationApp,
      );
      if (mounted) {
        setState(() {
          _selectedApp = app;
        });
      }
    }
  }

  Future<void> _loadNavigationMode() async {
    final mode = await TeslaAuthService.shared.getNavigationModePreference();
    if (mounted) {
      setState(() {
        _navigationMode = mode;
      });
    }
  }

  Future<void> _openSettings() async {
    final result = await Navigator.of(
      context,
    ).pushNamed('/settings', arguments: _quota);
    if (result == true) {
      await _loadDefaultNavigationApp();
      await _loadNavigationMode();
      await _loadSelectedVehicleId();
      await _loadUsageData();
    }

    setState(() {
      _quota = UsageLimitService.shared.userStatus?.quota ?? 0;
    });
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

  Future<void> _recordDrivenDestination(Destination destination) async {
    final prefs = await SharedPreferences.getInstance();
    final timestamped = Destination(
      name: destination.name,
      address: destination.address,
      latitude: destination.latitude,
      longitude: destination.longitude,
      placeId: destination.placeId,
      lastNavigatedAt: DateTime.now(),
    );
    setState(() {
      _recentDestinations.removeWhere((item) {
        if (item.placeId != null && timestamped.placeId != null) {
          return item.placeId == timestamped.placeId;
        }
        return item.latitude == timestamped.latitude &&
            item.longitude == timestamped.longitude;
      });
      _recentDestinations.insert(0, timestamped);

      // 최대 50개로 제한
      if (_recentDestinations.length > 50) {
        _recentDestinations = _recentDestinations.sublist(0, 50);
      }
    });
    await prefs.setStringList(
      _recentDestinationsKey,
      _recentDestinations.map((d) => jsonEncode(d.toMap())).toList(),
    );
  }

  Future<void> _removeRecentDestination(Destination destination) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _recentDestinations.removeWhere((item) {
        if (item.placeId != null && destination.placeId != null) {
          return item.placeId == destination.placeId;
        }
        return item.latitude == destination.latitude &&
            item.longitude == destination.longitude;
      });
    });
    await prefs.setStringList(
      _recentDestinationsKey,
      _recentDestinations.map((d) => jsonEncode(d.toMap())).toList(),
    );
  }

  Future<void> _loadFavoriteDestinations() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_favoriteDestinationsKey) ?? [];
    final favorites = stored
        .map((item) => Destination.fromMap(jsonDecode(item)))
        .toList();
    final labelsRaw = prefs.getString(_favoriteDestinationLabelsKey);
    final labelMap = <String, String>{};
    if (labelsRaw != null && labelsRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(labelsRaw);
        if (decoded is Map<String, dynamic>) {
          for (final entry in decoded.entries) {
            final value = entry.value;
            if (value is String) {
              labelMap[entry.key] = value;
            }
          }
        }
      } catch (error) {
        debugPrint('[Favorites] Failed to decode labels: $error');
      }
    }
    if (!mounted) return;
    setState(() {
      _favoriteDestinations = favorites;
      _favoriteDestinationKeys = favorites
          .map(_destinationKey)
          .whereType<String>()
          .toSet();
      _favoriteNameToAddress = labelMap;
    });
  }

  Future<void> _toggleFavorite(Destination destination) async {
    final key = _destinationKey(destination);
    if (key == null) return;

    final existingIndex = _favoriteDestinations.indexWhere(
      (item) => _destinationKey(item) == key,
    );
    if (existingIndex >= 0) {
      setState(() {
        _favoriteDestinations.removeAt(existingIndex);
        _favoriteDestinationKeys.remove(key);
        _favoriteNameToAddress.removeWhere(
          (label, address) => address == destination.address,
        );
      });
      await _persistFavoriteData();
      return;
    }

    final favoriteName = await _promptFavoriteName(destination);
    if (favoriteName == null || favoriteName.trim().isEmpty) {
      return;
    }
    final trimmedName = favoriteName.trim();

    setState(() {
      _favoriteDestinations.removeWhere((item) => _destinationKey(item) == key);
      _favoriteDestinations.add(destination);
      _favoriteDestinationKeys.add(key);
      _favoriteNameToAddress[trimmedName] = destination.address;
    });

    await _persistFavoriteData();
  }

  Future<void> _persistFavoriteData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _favoriteDestinationsKey,
      _favoriteDestinations.map((d) => jsonEncode(d.toMap())).toList(),
    );
    await prefs.setString(
      _favoriteDestinationLabelsKey,
      jsonEncode(_favoriteNameToAddress),
    );
  }

  Future<void> _removeFavorite(Destination destination) async {
    final key = _destinationKey(destination);
    if (key == null) return;

    setState(() {
      _favoriteDestinations.removeWhere((item) => _destinationKey(item) == key);
      _favoriteDestinationKeys.remove(key);
      _favoriteNameToAddress.removeWhere(
        (label, address) => address == destination.address,
      );
    });

    await _persistFavoriteData();
  }

  bool _isFavoriteDestination(Destination destination) {
    final key = _destinationKey(destination);
    if (key == null) return false;
    return _favoriteDestinationKeys.contains(key);
  }

  String? _destinationKey(Destination destination) {
    if (destination.placeId != null && destination.placeId!.isNotEmpty) {
      return 'place:${destination.placeId}';
    }
    return 'coord:${destination.latitude}_${destination.longitude}';
  }

  Future<String?> _promptFavoriteName(Destination destination) async {
    final loc = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: destination.name);
    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final trimmed = controller.text.trim();
            return AlertDialog(
              title: Text(loc.favoriteNameDialogTitle),
              content: TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: loc.favoriteNameDialogHint,
                ),
                onChanged: (_) => setModalState(() {}),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(loc.favoriteNameDialogCancel),
                ),
                FilledButton(
                  onPressed: trimmed.isEmpty
                      ? null
                      : () => Navigator.of(dialogContext).pop(trimmed),
                  child: Text(loc.favoriteNameDialogSave),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _loadSelectedVehicleId() async {
    final storedId = await TeslaAuthService.shared.getSelectedVehicleId();
    if (!mounted) return;
    setState(() {
      _selectedVehicleId = storedId;
    });
  }

  Future<void> _applySelectedDestination(
    Destination destination, {
    bool fillSearchField = true,
  }) async {
    setState(() {
      _isLoading = false;
      _selectedDestination = destination;
      if (fillSearchField) {
        _placesController.text = destination.name;
      } else {
        _placesController.clear();
      }
      // 일반 목적지 선택 시 슈퍼차저 POI 전부 숨김
      _showSuperchargerPois = false;
      _superchargerResults = [];
      _selectedSuperchargerKey = null;
    });

    // 목적지 UI가 뜬 시점에 남은 횟수가 보이도록 쿼터 재동기화
    if (!_isQuotaLoaded || _quota <= 0) {
      unawaited(_loadUsageData());
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _moveCameraToSelectedDestination();
    });
  }

  String _poiKey(Destination destination) {
    if (destination.placeId != null && destination.placeId!.isNotEmpty) {
      return 'place:${destination.placeId}';
    }
    return 'coord:${destination.latitude}_${destination.longitude}';
  }

  Future<void> _selectSuperchargerPoi(Destination destination) async {
    setState(() {
      _isLoading = false;
      _selectedDestination = destination;
      _placesController.clear();
      _selectedSuperchargerKey = _poiKey(destination);
    });

    if (!_isQuotaLoaded || _quota <= 0) {
      unawaited(_loadUsageData());
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _moveCameraToSelectedDestination();
    });
  }

  Future<void> _initializeUsageTracking() async {
    await _loadUsageData();
  }

  Future<String?> _ensureUserId() async {
    if (_userId != null && _userId!.isNotEmpty) {
      return _userId;
    }

    final email = await TeslaAuthService.shared.getEmail();
    if (email != null && email.isNotEmpty) {
      if (mounted) {
        setState(() {
          _userId = email.trim().toLowerCase();
        });
      } else {
        _userId = email.trim().toLowerCase();
      }
      return _userId;
    }
    return null;
  }

  void _syncQuotaFromShared() {
    final shared = UsageLimitService.shared.userStatus;
    if (shared == null || !mounted) return;
    setState(() {
      _quota = shared.quota;
      _isQuotaLoaded = true;
    });
  }

  Future<void> _loadUsageData() async {
    final userId = await _ensureUserId();
    if (userId == null) {
      // 로그인 전이면 "로드 완료"로 표시하지 않음 → 이후 재시도
      _syncQuotaFromShared();
      return;
    }

    final accessToken = await TeslaAuthService.shared.getAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      debugPrint('[Usage] Missing access token when loading quota');
      // 토큰 없어도 공유 캐시가 있으면 그걸 쓰고, 없으면 미로드 상태 유지
      _syncQuotaFromShared();
      return;
    }

    try {
      final userStatus = await UsageLimitService.shared.fetchStatus(
        userId: userId,
        accessToken: accessToken,
      );

      if (!mounted) return;
      setState(() {
        _isQuotaLoaded = true;
        _quota = userStatus.quota;
      });
    } on UsageLimitException catch (error) {
      debugPrint('[Usage] Failed to load quota: $error');
      _syncQuotaFromShared();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (error) {
      debugPrint('[Usage] Failed to load quota: $error');
      _syncQuotaFromShared();
    }
  }

  /// Check if user has quota (without consuming)
  Future<bool> _checkNavigationQuota() async {
    // 안내 시작 직마다 최신 쿼터를 다시 불러 오래된 0값으로 구매 시트를 띄우지 않음
    await _loadUsageData();
    _syncQuotaFromShared();

    if (_quota <= 0) {
      await _showSubscriptionDialog();
      return false;
    }

    return true;
  }

  /// Consume navigation quota (called after successful Tesla API call)
  Future<void> _consumeNavigationQuota() async {
    final userId = await _ensureUserId();
    if (userId == null || userId.isEmpty) {
      debugPrint('[Usage] consume skipped: missing userId');
      return;
    }

    final accessToken = await TeslaAuthService.shared.getAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      debugPrint('[Usage] consume skipped: missing access token');
      return;
    }

    try {
      final userStatusResult = await UsageLimitService.shared.consume(
        userId: userId,
        accessToken: accessToken,
      );

      if (!userStatusResult.success) {
        debugPrint(
          '[Usage] consume unsuccessful: ${userStatusResult.errorMessage}',
        );
        return;
      }

      if (mounted) {
        setState(() {
          _isQuotaLoaded = true;
          _quota = userStatusResult.status.quota;
        });
      }
      debugPrint('[Usage] consume ok, remaining=$_quota');
    } on UsageLimitException catch (error) {
      debugPrint('[Usage] consume failed: $error');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _showSubscriptionDialog() async {
    if (!mounted) {
      return;
    }

    final parentContext = context;
    final subscriptionService = context.read<SubscriptionService>();

    // If purchasing is disabled by server settings, do not show UI
    if (!subscriptionService.purchasingAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(
              context,
            )!.errorWithMessage('Purchases are not available.'),
          ),
        ),
      );
      return;
    }

    if (subscriptionService.isAvailable &&
        !subscriptionService.isLoading &&
        subscriptionService.products.isEmpty) {
      await subscriptionService.refreshProducts();
    }

    await showModalBottomSheet<void>(
      context: parentContext,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) =>
          subscriptionService.purchaseMode == PurchaseMode.creditPack
          ? CreditPurchaseSheet(quota: _quota)
          : SubscriptionSheet(quota: _quota),
    );
    subscriptionService.resetTransientState();
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

  Future<void> _moveCameraToUserLocation() async {
    if (!_locationPermissionGranted || _mapController == null) {
      return;
    }

    try {
      Position? position = await Geolocator.getLastKnownPosition();
      position ??= await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final target = LatLng(position.latitude, position.longitude);
      double? zoom;
      try {
        zoom = await _mapController!.getZoomLevel();
      } catch (_) {
        zoom = null;
      }

      await _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(target, zoom ?? 15),
      );
    } catch (e, stack) {
      debugPrint('[Location] Failed to move camera to user location: $e');
      debugPrint('$stack');
    }
  }

  Future<void> _initLocationServices() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[Location] Services are disabled.');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        debugPrint('[Location] Permission denied: $permission');
        if (mounted) {
          setState(() {
            _locationPermissionGranted = false;
          });
        }
        return;
      }

      if (!mounted) return;
      setState(() {
        _locationPermissionGranted = true;
      });

      await _moveCameraToUserLocation();
    } catch (e, stack) {
      debugPrint('[Location] Error initializing location services: $e');
      debugPrint('$stack');
    }
  }

  Locale getLocaleByRegion() {
    final region = ui.PlatformDispatcher.instance.locale.countryCode;
    switch (region) {
      case 'KR':
        return const Locale('ko', 'KR');
      case 'JP':
        return const Locale('ja', 'JP');
      case 'CN':
        return const Locale('zh', 'CN');
      default:
        return const Locale('en', 'US');
    }
  }

  String _currentLocaleLanguageCode() {
    final locale = getLocaleByRegion();
    return locale.languageCode;
  }

  /// Places 검색 국가 제한: 폰 지역 설정(countryCode) 기준.
  List<String> _countriesForPlacesSearch() {
    final locale = Localizations.localeOf(context);
    final countryCode =
        locale.countryCode ?? ui.PlatformDispatcher.instance.locale.countryCode;
    if (countryCode != null && countryCode.isNotEmpty) {
      return [countryCode.toLowerCase()];
    }
    // countryCode 없으면 언어 코드로 추정
    switch (locale.languageCode.toLowerCase()) {
      case 'ko':
        return const ['kr'];
      case 'ja':
        return const ['jp'];
      case 'zh':
        return const ['cn'];
      default:
        return const [];
    }
  }

  Future<bool> _sendDestinationToTesla(Destination destination) async {
    if (_selectedVehicleId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.teslaVehicleRequired),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return false;
    }

    setState(() {
      _isSendingToTesla = true;
    });

    final vehicleId = _selectedVehicleId!;
    final success = await TeslaAuthService.shared.sendDestinationToVehicle(
      vehicleId,
      destination.latitude,
      destination.longitude,
      destination.name,
      mode: _navigationMode,
      destinationAddress: destination.address,
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
      final colorScheme = Theme.of(context).colorScheme;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? loc.sendToTeslaSuccess : loc.sendToTeslaFailure,
          ),
          backgroundColor: success ? colorScheme.primary : colorScheme.error,
        ),
      );
    }

    return success;
  }

  // Google Places API key
  static const String _googlePlacesApiKey =
      'AIzaSyBb1IGpqLzKwdtAfyzsqP7YZpn0nQI9iQo';

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
      final languageParam = _currentLocaleLanguageCode();
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
      final languageParam = _currentLocaleLanguageCode();
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
    // 검색/자동완성 중 지도 탭 → 오버레이만 닫고 목적지는 설정하지 않음
    final wasSearching =
        _searchFocusNode.hasFocus || _showTextSearchResults;

    _searchFocusNode.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
    if (_showTextSearchResults) {
      setState(() {
        _showTextSearchResults = false;
        _textSearchResults = [];
      });
    }

    if (wasSearching) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final destination = await _getDestinationFromLatLng(latLng);
      if (destination != null) {
        await _applySelectedDestination(
          destination,
          fillSearchField: false,
        );
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
      final languageParam = _currentLocaleLanguageCode();
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

    // Check quota before sending (but don't consume yet)
    final canNavigate = await _checkNavigationQuota();
    if (!canNavigate) {
      return;
    }

    final destination = _selectedDestination!;
    final teslaSuccess = await _sendDestinationToTesla(destination);

    // Only consume quota if Tesla API call was successful
    if (teslaSuccess) {
      await _consumeNavigationQuota();
      await _recordDrivenDestination(destination);
    }

    setState(() {
      _isLoading = true;
    });

    double? startLat;
    double? startLng;
    if (_locationPermissionGranted) {
      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
        );
        startLat = position.latitude;
        startLng = position.longitude;
      } catch (error) {
        debugPrint('[Navigation] Failed to fetch current location: $error');
      }
    }

    try {
      final navSuccess = await _navigationService.launchNavigation(
        _selectedApp,
        _selectedDestination!.latitude,
        _selectedDestination!.longitude,
        _selectedDestination!.name,
        startLat: startLat,
        startLng: startLng,
      );

      if (mounted) {
        final loc = AppLocalizations.of(context)!;
        final colorScheme = Theme.of(context).colorScheme;
        if (navSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(loc.navigationStarted),
              backgroundColor: colorScheme.primary,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(loc.navigationFailed),
              backgroundColor: colorScheme.error,
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

  /// Places Text Search API — query 로 장소 목록 조회.
  Future<List<Destination>> _fetchTextSearchResults(
    String query, {
    LatLng? locationBias,
    int radiusMeters = 50000,
    bool useLocationBias = true,
    bool fetchAllPages = false,
  }) async {
    final languageParam = _currentLocaleLanguageCode();
    final countries = _countriesForPlacesSearch();
    final region = countries.isNotEmpty ? countries.first : languageParam;

    final params = <String, String>{
      'query': query,
      'key': _googlePlacesApiKey,
      'language': languageParam,
      'region': region,
    };

    LatLng? bias = locationBias;
    if (useLocationBias && bias == null && _locationPermissionGranted) {
      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
        );
        bias = LatLng(position.latitude, position.longitude);
      } catch (e) {
        debugPrint('[TextSearch] location bias skipped: $e');
      }
    }

    if (useLocationBias && bias != null) {
      params['location'] = '${bias.latitude},${bias.longitude}';
      params['radius'] = '$radiusMeters';
    }

    final destinations = <Destination>[];
    final unknown = AppLocalizations.of(context)?.unknownPlace ?? 'Unknown';
    String? pageToken;

    do {
      final pageParams = Map<String, String>.from(params);
      if (pageToken != null && pageToken.isNotEmpty) {
        // next_page_token 은 발급 직후 바로 쓰면 INVALID_REQUEST 날 수 있음
        await Future<void>.delayed(const Duration(milliseconds: 2000));
        pageParams['pagetoken'] = pageToken;
      }

      final uri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/place/textsearch/json',
        pageParams,
      );
      debugPrint('[TextSearch] GET $uri');
      final response = await http.get(uri);

      if (response.statusCode != 200) {
        debugPrint(
          '[TextSearch] HTTP ${response.statusCode}: ${response.body}',
        );
        throw Exception('HTTP ${response.statusCode}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final status = data['status'] as String? ?? '';
      final results = data['results'] as List<dynamic>? ?? [];
      debugPrint('[TextSearch] status=$status count=${results.length}');

      if (status != 'OK' && status != 'ZERO_RESULTS') {
        if (destinations.isEmpty) {
          throw Exception('Places Text Search failed: $status');
        }
        break;
      }

      for (final item in results) {
        if (item is! Map<String, dynamic>) continue;
        final geometry = item['geometry'] as Map<String, dynamic>?;
        final location = geometry?['location'] as Map<String, dynamic>?;
        if (location == null) continue;
        final lat = (location['lat'] as num?)?.toDouble();
        final lng = (location['lng'] as num?)?.toDouble();
        if (lat == null || lng == null) continue;

        destinations.add(
          Destination(
            name: item['name'] as String? ?? unknown,
            address: item['formatted_address'] as String? ?? '',
            latitude: lat,
            longitude: lng,
            placeId: item['place_id'] as String?,
          ),
        );
      }

      pageToken = fetchAllPages
          ? data['next_page_token'] as String?
          : null;
    } while (pageToken != null && pageToken.isNotEmpty);

    return destinations;
  }

  Future<void> _loadSuperchargerMarkerIcon() async {
    if (!mounted) return;
    try {
      final icons = await Future.wait([
        BitmapDescriptor.asset(
          const ImageConfiguration(size: Size(48, 48)),
          'assets/images/supercharger_icon.png',
        ),
        BitmapDescriptor.asset(
          const ImageConfiguration(size: Size(64, 64)),
          'assets/images/supercharger_icon_selected.png',
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _superchargerMarkerIcon = icons[0];
        _superchargerSelectedMarkerIcon = icons[1];
      });
    } catch (e) {
      debugPrint('[Supercharger] marker icon load failed: $e');
    }
  }

  Future<({LatLng center, int radiusMeters})?> _currentMapViewportSearch() async {
    final controller = _mapController;
    if (controller == null) return null;
    try {
      final bounds = await controller.getVisibleRegion();
      final center = LatLng(
        (bounds.northeast.latitude + bounds.southwest.latitude) / 2,
        (bounds.northeast.longitude + bounds.southwest.longitude) / 2,
      );
      final diagonalMeters = Geolocator.distanceBetween(
        bounds.northeast.latitude,
        bounds.northeast.longitude,
        bounds.southwest.latitude,
        bounds.southwest.longitude,
      );
      final radiusMeters = (diagonalMeters / 2).clamp(3000, 50000).round();
      return (center: center, radiusMeters: radiusMeters);
    } catch (e) {
      debugPrint('[Supercharger] viewport failed: $e');
      return null;
    }
  }

  Future<LatLng?> _currentMapCenter() async {
    final viewport = await _currentMapViewportSearch();
    return viewport?.center;
  }

  Future<void> _loadSuperchargerCache() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_superchargerCacheKey) ?? [];
    final cached = <Destination>[];
    for (final item in stored) {
      try {
        cached.add(Destination.fromMap(jsonDecode(item) as Map<String, dynamic>));
      } catch (e) {
        debugPrint('[Supercharger] cache parse skip: $e');
      }
    }
    if (!mounted) return;
    setState(() {
      _superchargerCache = cached;
    });
    debugPrint('[Supercharger] cache loaded=${cached.length}');
  }

  Future<void> _persistSuperchargerCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _superchargerCacheKey,
      _superchargerCache.map((d) => jsonEncode(d.toMap())).toList(),
    );
  }

  /// [incoming] 을 앞에 두고 placeId/좌표 기준 중복 제거 후 캐시 상한 적용.
  List<Destination> _mergeSuperchargerCache(List<Destination> incoming) {
    final merged = <Destination>[];
    final seen = <String>{};
    for (final item in [...incoming, ..._superchargerCache]) {
      final key = _poiKey(item);
      if (!seen.add(key)) continue;
      merged.add(item);
      if (merged.length >= _superchargerCacheMax) break;
    }
    return merged;
  }

  /// 검색바 슈퍼차저 버튼: 현재 지도 영역 조회 + 캐시 전체 POI 표시/숨김.
  Future<void> _toggleSuperchargersOnMap() async {
    if (_isLoadingSuperchargers) return;

    _searchFocusNode.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();

    if (_showSuperchargerPois) {
      setState(() {
        _showSuperchargerPois = false;
        _superchargerResults = [];
        _selectedSuperchargerKey = null;
      });
      return;
    }

    await _loadSuperchargersForViewport();
  }

  Future<void> _loadSuperchargersForViewport() async {
    if (_isLoadingSuperchargers) return;

    setState(() {
      _isLoadingSuperchargers = true;
      _showSuperchargerPois = true;
      // 캐시가 있으면 먼저 전부 표시한 뒤 영역 검색으로 보강
      if (_superchargerCache.isNotEmpty) {
        _superchargerResults = List<Destination>.from(_superchargerCache);
      }
    });

    try {
      if (_superchargerMarkerIcon == null) {
        await _loadSuperchargerMarkerIcon();
      }
      final viewport = await _currentMapViewportSearch();
      final destinations = await _fetchTextSearchResults(
        'Tesla Supercharger',
        locationBias: viewport?.center,
        radiusMeters: viewport?.radiusMeters ?? 30000,
        useLocationBias: true,
        fetchAllPages: true,
      );
      if (!mounted) return;
      if (!_showSuperchargerPois) return;

      final merged = _mergeSuperchargerCache(destinations);
      setState(() {
        _superchargerCache = merged;
        _superchargerResults = List<Destination>.from(merged);
      });
      await _persistSuperchargerCache();
      debugPrint(
        '[Supercharger] viewport POIs=${destinations.length} '
        'cache=${merged.length} '
        'center=${viewport?.center} radius=${viewport?.radiusMeters}',
      );
    } catch (e, st) {
      debugPrint('[Supercharger] error: $e');
      debugPrint('$st');
      if (mounted) {
        // 캐시로 이미 표시 중이면 유지, 없으면 숨김
        if (_superchargerResults.isEmpty) {
          setState(() {
            _showSuperchargerPois = false;
          });
          final loc = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(loc.errorWithMessage('$e'))),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingSuperchargers = false;
        });
      }
    }
  }

  Set<Marker> _buildMapMarkers() {
    final markers = <Marker>{};
    final selectedScKey = _selectedSuperchargerKey;

    // 슈퍼차저 POI가 선택된 경우 기본 destination 마커는 그리지 않음
    final hideDefaultDestination =
        selectedScKey != null && _showSuperchargerPois;

    if (_selectedDestination != null && !hideDefaultDestination) {
      final dest = _selectedDestination!;
      markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: LatLng(dest.latitude, dest.longitude),
          infoWindow: InfoWindow(
            title: dest.name,
            snippet: dest.address,
          ),
          zIndexInt: 2,
        ),
      );
    }

    if (_showSuperchargerPois) {
      final normalIcon = _superchargerMarkerIcon;
      final selectedIcon =
          _superchargerSelectedMarkerIcon ?? _superchargerMarkerIcon;
      for (var i = 0; i < _superchargerResults.length; i++) {
        final sc = _superchargerResults[i];
        final key = _poiKey(sc);
        final isSelected = key == selectedScKey;
        markers.add(
          Marker(
            markerId: MarkerId('supercharger_$i'),
            position: LatLng(sc.latitude, sc.longitude),
            icon: (isSelected ? selectedIcon : normalIcon) ??
                BitmapDescriptor.defaultMarkerWithHue(
                  isSelected
                      ? BitmapDescriptor.hueYellow
                      : BitmapDescriptor.hueRed,
                ),
            anchor: const Offset(0.5, 1.0),
            infoWindow: const InfoWindow(),
            consumeTapEvents: true,
            onTap: () => _selectSuperchargerPoi(sc),
            zIndexInt: isSelected ? 3 : 1,
          ),
        );
      }
    }

    return markers;
  }

  /// Places Text Search — 엔터(검색) 시 자동완성이 아닌 검색 결과 사용.
  Future<void> _performTextSearch() async {
    final query = _placesController.text.trim();
    if (query.isEmpty) return;

    _searchFocusNode.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      _isTextSearching = true;
      _showTextSearchResults = true;
      _textSearchResults = [];
    });
    _searchUiTick.value++;

    try {
      final center = await _currentMapCenter();
      final destinations = await _fetchTextSearchResults(
        query,
        locationBias: center,
      );
      if (!mounted) return;
      setState(() {
        _textSearchResults = destinations;
        _showTextSearchResults = true;
      });
      _searchUiTick.value++;
    } catch (e, st) {
      debugPrint('[TextSearch] error: $e');
      debugPrint('$st');
      if (mounted) {
        final loc = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.errorWithMessage('$e'))),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTextSearching = false;
        });
        _searchUiTick.value++;
      }
    }
  }

  Widget _buildTextSearchResultsOverlay(AppLocalizations loc) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;
    final availableHeight = screenHeight - keyboardHeight - 200;
    final maxHeight = availableHeight.clamp(200.0, 400.0);

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      loc.searchResultsTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      setState(() {
                        _showTextSearchResults = false;
                        _textSearchResults = [];
                      });
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            if (_isTextSearching)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_textSearchResults.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  loc.searchNoResults,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).hintColor,
                      ),
                ),
              )
            else
              Flexible(
                fit: FlexFit.loose,
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: 8),
                  itemCount: _textSearchResults.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final destination = _textSearchResults[index];
                    return ListTile(
                      leading: const Icon(Icons.place),
                      title: Text(destination.name),
                      subtitle: destination.address.isNotEmpty
                          ? Text(destination.address)
                          : null,
                      onTap: () {
                        setState(() {
                          _showTextSearchResults = false;
                          _textSearchResults = [];
                        });
                        _applySelectedDestination(destination);
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuperchargerSearchSuffix(AppLocalizations loc) {
    return IconButton(
      tooltip: loc.superchargerTab,
      onPressed: _isLoadingSuperchargers ? null : _toggleSuperchargersOnMap,
      icon: _isLoadingSuperchargers
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFFE82127),
              ),
            )
          : Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.bolt,
                size: 20,
                color: Color(0xFFE82127),
              ),
            ),
    );
  }

  Widget _buildSearchField(AppLocalizations loc) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final borderColor = colorScheme.outline.withOpacity(0.35);
    final fillColor =
        theme.inputDecorationTheme.fillColor ??
        (theme.brightness == Brightness.dark
            ? const Color(0xFF1F252C)
            : Colors.white);
    final language = _currentLocaleLanguageCode();

    return GooglePlaceAutoCompleteTextField(
      key: _searchFieldKey,
      textEditingController: _placesController,
      googleAPIKey: _googlePlacesApiKey,
      language: language,
      focusNode: _searchFocusNode,
      textInputAction: TextInputAction.search,
      keyboardType: TextInputType.text,
      formSubmitCallback: () {
        _performTextSearch();
      },
      boxDecoration: const BoxDecoration(color: Colors.transparent),
      containerHorizontalPadding: 0,
      containerVerticalPadding: 0,
      suffixIcon: _buildSuperchargerSearchSuffix(loc),
      inputDecoration: InputDecoration(
        hintText: _isLoadingSuperchargers
            ? loc.superchargerSearchingHint
            : loc.searchHint,
        prefixIcon: const Icon(Icons.search),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary),
        ),
        filled: true,
        fillColor: fillColor,
        contentPadding: const EdgeInsets.symmetric(vertical: 0),
      ),
      debounceTime: 400,
      countries: _countriesForPlacesSearch(),
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
            _moveCameraToUserLocation();
          },
          onTap: _onMapTapped,
          myLocationEnabled: _locationPermissionGranted,
          myLocationButtonEnabled: _locationPermissionGranted,
          markers: _buildMapMarkers(),
        ),
      ),
    );
  }

  Widget _buildRecentDestinationsOverlay(AppLocalizations loc) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;
    final availableHeight = screenHeight - keyboardHeight - 200;
    final maxHeight = availableHeight.clamp(200.0, 400.0);

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TabBar(
              controller: _overlayTabController,
              tabs: [
                Tab(text: loc.recentSearches),
                Tab(text: loc.favorites),
              ],
            ),
            const Divider(height: 1),
            Flexible(
              fit: FlexFit.loose,
              child: _overlayTabController.index == 0
                  ? _buildRecentDestinationsList(loc)
                  : _buildFavoritesList(loc),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentDestinationsList(AppLocalizations loc) {
    if (_recentDestinationsForDisplay.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Text(
          loc.noRecentDestinations,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).hintColor),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: _recentDestinationsForDisplay.length,
      itemBuilder: (context, index) {
        final destination = _recentDestinationsForDisplay[index];
        return ListTile(
          leading: const Icon(Icons.history),
          title: Text(destination.name),
          subtitle: destination.address.isNotEmpty
              ? Text(destination.address)
              : null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: loc.deleteRecentDestination,
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(loc.confirmDeleteRecentDestination),
                      content: Text(
                        loc.confirmDeleteRecentDestinationMessage(
                          destination.name,
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: Text(loc.cancel),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          style: TextButton.styleFrom(
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.error,
                          ),
                          child: Text(loc.delete),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true && mounted) {
                    await _removeRecentDestination(destination);
                  }
                },
              ),
              const Icon(Icons.north_east),
            ],
          ),
          onTap: () {
            print('[Recent] tapped ${destination.name}');
            _searchFocusNode.unfocus();
            FocusManager.instance.primaryFocus?.unfocus();
            _applySelectedDestination(destination);
          },
        );
      },
    );
  }

  Widget _buildFavoritesList(AppLocalizations loc) {
    if (_favoriteDestinations.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Text(
          loc.noFavorites,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).hintColor),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: _favoriteDestinations.length,
      itemBuilder: (context, index) {
        final destination = _favoriteDestinations[index];
        final favoriteName = _favoriteNameToAddress.entries
            .firstWhere(
              (entry) => entry.value == destination.address,
              orElse: () => MapEntry('', ''),
            )
            .key;
        return ListTile(
          leading: const Icon(Icons.favorite, color: Colors.red),
          title: Text(
            favoriteName.isNotEmpty ? favoriteName : destination.name,
          ),
          subtitle: Text(destination.address),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: loc.deleteFavorite,
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(loc.confirmDeleteFavorite),
                      content: Text(
                        loc.confirmDeleteFavoriteMessage(
                          favoriteName.isNotEmpty
                              ? favoriteName
                              : destination.name,
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: Text(loc.cancel),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          style: TextButton.styleFrom(
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.error,
                          ),
                          child: Text(loc.delete),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true && mounted) {
                    await _removeFavorite(destination);
                  }
                },
              ),
              const Icon(Icons.north_east),
            ],
          ),
          onTap: () {
            print('[Favorite] tapped ${destination.name}');
            _searchFocusNode.unfocus();
            FocusManager.instance.primaryFocus?.unfocus();
            _applySelectedDestination(destination);
          },
        );
      },
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  _selectedDestination!.address,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  icon: Icon(
                    _isFavoriteDestination(_selectedDestination!)
                        ? Icons.favorite
                        : Icons.favorite_border,
                    color: _isFavoriteDestination(_selectedDestination!)
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).iconTheme.color,
                  ),
                  tooltip: _isFavoriteDestination(_selectedDestination!)
                      ? loc.removeFavoriteTooltip
                      : loc.addFavoriteTooltip,
                  onPressed: () => _toggleFavorite(_selectedDestination!),
                ),
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
          if (_isQuotaLoaded && _quota > 0)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                loc.subscriptionUsageStatus(_quota),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
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
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [Positioned.fill(child: _buildMap())],
                  ),
                ),
                _buildBottomSection(loc),
              ],
            ),
            ValueListenableBuilder<int>(
              valueListenable: _searchUiTick,
              builder: (context, _, __) {
                if (_shouldShowTextSearchResults) {
                  return Stack(
                    children: [
                      Positioned.fill(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _showTextSearchResults = false;
                              _textSearchResults = [];
                            });
                          },
                          child: Container(color: Colors.transparent),
                        ),
                      ),
                      Positioned(
                        left: 16,
                        right: 16,
                        top: 0,
                        child: GestureDetector(
                          onTap: () {},
                          child: _buildTextSearchResultsOverlay(loc),
                        ),
                      ),
                    ],
                  );
                }
                if (_shouldShowRecentSuggestions) {
                  return Stack(
                    children: [
                      Positioned.fill(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            _searchFocusNode.unfocus();
                            FocusManager.instance.primaryFocus?.unfocus();
                          },
                          child: const SizedBox.expand(),
                        ),
                      ),
                      Positioned(
                        left: 16,
                        right: 16,
                        top: 0,
                        child: GestureDetector(
                          onTap: () {},
                          child: _buildRecentDestinationsOverlay(loc),
                        ),
                      ),
                    ],
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
      ),
    );
  }

  int _minutesSinceMidnight(DateTime time) => time.hour * 60 + time.minute;

  int _timeOfDayDifference(int lhsMinutes, int rhsMinutes) {
    final diff = (lhsMinutes - rhsMinutes).abs();
    return diff > 720 ? 1440 - diff : diff;
  }
}
