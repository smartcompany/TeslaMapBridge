import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import '../models/tesla_navigation_mode.dart';
import '../services/navigation_service.dart';
import '../services/tesla_auth_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TeslaAuthService _teslaAuthService = TeslaAuthService();
  NavigationApp _selectedApp = NavigationApp.tmap;
  TeslaNavigationMode _navigationMode = TeslaNavigationMode.destination;
  bool _isLoading = true;
  bool _hasChanges = false;
  bool _isLoggingOut = false;
  List<Map<String, dynamic>> _vehicles = [];
  String? _selectedVehicleId;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(kDefaultNavigationAppKey);
    final modeMatch = await _teslaAuthService.getNavigationModePreference();
    final vehicles = await _teslaAuthService.getVehicles();
    final storedVehicleId = await _teslaAuthService.getSelectedVehicleId();

    final availableIds = <String>[];
    for (final vehicle in vehicles) {
      final id = _vehicleId(vehicle);
      if (id != null) {
        availableIds.add(id);
      }
    }

    String? resolvedVehicleId = storedVehicleId;
    if (availableIds.isEmpty) {
      resolvedVehicleId = null;
    } else if (resolvedVehicleId == null ||
        !availableIds.contains(resolvedVehicleId)) {
      resolvedVehicleId = availableIds.first;
    }

    if (!mounted) return;

    setState(() {
      if (stored != null) {
        final match = NavigationApp.values.firstWhere(
          (app) => app.name == stored,
          orElse: () => NavigationApp.tmap,
        );
        _selectedApp = match;
      }
      _navigationMode = modeMatch;
      _vehicles = vehicles;
      _selectedVehicleId = resolvedVehicleId;
      if (resolvedVehicleId != storedVehicleId) {
        _hasChanges = true;
      }
      _isLoading = false;
    });

    if (resolvedVehicleId != storedVehicleId) {
      await _teslaAuthService.setSelectedVehicleId(resolvedVehicleId);
    }
  }

  String? _vehicleId(Map<String, dynamic> vehicle) {
    final id = vehicle['id'] ?? vehicle['vehicle_id'];
    if (id != null) {
      return id.toString();
    }
    final vin = vehicle['vin'];
    if (vin is String && vin.isNotEmpty) {
      return vin;
    }
    return null;
  }

  String _vehicleDisplayName(
    Map<String, dynamic> vehicle,
    AppLocalizations loc,
  ) {
    final displayName = vehicle['display_name'];
    if (displayName is String && displayName.trim().isNotEmpty) {
      return displayName.trim();
    }
    final nickname = vehicle['name'];
    if (nickname is String && nickname.trim().isNotEmpty) {
      return nickname.trim();
    }
    final vin = vehicle['vin'];
    if (vin is String && vin.isNotEmpty) {
      return vin;
    }
    final id = _vehicleId(vehicle) ?? '';
    return loc.vehicleDefaultName(id);
  }

  String? _vehicleDetail(Map<String, dynamic> vehicle) {
    final vin = vehicle['vin'];
    if (vin is String && vin.isNotEmpty) {
      return vin;
    }
    final model = vehicle['trim_badging'] ?? vehicle['option_codes'];
    if (model is String && model.isNotEmpty) {
      return model;
    }
    return null;
  }

  Future<void> _setSelectedVehicle(String vehicleId) async {
    if (_selectedVehicleId == vehicleId) {
      return;
    }
    setState(() {
      _selectedVehicleId = vehicleId;
      _hasChanges = true;
      _isLoading = true;
    });
    await _teslaAuthService.setSelectedVehicleId(vehicleId);
    await _loadPreferences();
  }

  Future<void> _setDefaultNavigationApp(NavigationApp app) async {
    if (_selectedApp == app) return;

    setState(() {
      _selectedApp = app;
      _hasChanges = true;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kDefaultNavigationAppKey, app.name);

    if (!mounted) return;
    final loc = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          loc.navigationSetConfirmation(
            NavigationService().getAppName(context, app),
          ),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _setNavigationMode(TeslaNavigationMode mode) async {
    if (_navigationMode == mode) return;

    setState(() {
      _navigationMode = mode;
      _hasChanges = true;
    });

    await _teslaAuthService.setNavigationModePreference(mode);

    if (!mounted) return;
    final loc = AppLocalizations.of(context)!;
    final message = mode == TeslaNavigationMode.destination
        ? loc.teslaNavigationModeDestination
        : loc.teslaNavigationModeGps;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  Future<bool> _handleWillPop() async {
    Navigator.of(context).pop(_hasChanges);
    return false;
  }

  Future<void> _handleLogout() async {
    final loc = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loc.logoutTitle),
        content: Text(loc.logoutConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(loc.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(loc.logoutButton),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _isLoggingOut = true;
      });

      try {
        await _teslaAuthService.logout();
        if (!mounted) return;
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/login', (route) => false);
      } finally {
        if (mounted) {
          setState(() {
            _isLoggingOut = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final vehicleIds = _vehicles.map(_vehicleId).whereType<String>().toList();
    final dropdownInitialValue = vehicleIds.contains(_selectedVehicleId)
        ? _selectedVehicleId
        : null;
    return WillPopScope(
      onWillPop: _handleWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Text(loc.settingsTitle),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.of(context).pop(_hasChanges);
            },
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    loc.teslaVehicleSelection,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_vehicles.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          loc.noVehiclesMessage,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    )
                  else
                    DropdownButtonFormField<String>(
                      initialValue: dropdownInitialValue,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: _vehicles
                          .map((vehicle) {
                            final id = _vehicleId(vehicle);
                            if (id == null) return null;
                            final name = _vehicleDisplayName(vehicle, loc);
                            final detail = _vehicleDetail(vehicle);
                            final label = detail != null
                                ? '$name • $detail'
                                : name;
                            return DropdownMenuItem<String>(
                              value: id,
                              child: Text(label),
                            );
                          })
                          .whereType<DropdownMenuItem<String>>()
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          _setSelectedVehicle(value);
                        }
                      },
                    ),
                  const SizedBox(height: 32),
                  Text(
                    loc.defaultNavigationApp,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...NavigationApp.values.map(
                    (app) => RadioListTile<NavigationApp>(
                      title: Text(NavigationService().getAppName(context, app)),
                      value: app,
                      groupValue: _selectedApp,
                      onChanged: (value) {
                        if (value != null) {
                          _setDefaultNavigationApp(value);
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    loc.teslaNavigationModeTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  RadioListTile<TeslaNavigationMode>(
                    title: Text(loc.teslaNavigationModeDestination),
                    value: TeslaNavigationMode.destination,
                    groupValue: _navigationMode,
                    onChanged: (value) {
                      if (value != null) {
                        _setNavigationMode(value);
                      }
                    },
                  ),
                  RadioListTile<TeslaNavigationMode>(
                    title: Text(loc.teslaNavigationModeGps),
                    value: TeslaNavigationMode.gps,
                    groupValue: _navigationMode,
                    onChanged: (value) {
                      if (value != null) {
                        _setNavigationMode(value);
                      }
                    },
                  ),
                  const SizedBox(height: 32),
                  Card(
                    child: ListTile(
                      leading: _isLoggingOut
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.logout),
                      title: Text(loc.logoutTitle),
                      subtitle: Text(loc.logoutDescription),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _isLoggingOut ? null : _handleLogout,
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
      ),
    );
  }
}
