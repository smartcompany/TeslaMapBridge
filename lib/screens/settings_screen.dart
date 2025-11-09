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

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(kDefaultNavigationAppKey);
    final modeMatch = await _teslaAuthService.getNavigationModePreference();

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
      _isLoading = false;
    });
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
    return WillPopScope(
      onWillPop: _handleWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context)!.settingsTitle),
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
                    AppLocalizations.of(context)!.defaultNavigationApp,
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
                    AppLocalizations.of(context)!.teslaNavigationModeTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  RadioListTile<TeslaNavigationMode>(
                    title: Text(
                      AppLocalizations.of(
                        context,
                      )!.teslaNavigationModeDestination,
                    ),
                    value: TeslaNavigationMode.destination,
                    groupValue: _navigationMode,
                    onChanged: (value) {
                      if (value != null) {
                        _setNavigationMode(value);
                      }
                    },
                  ),
                  RadioListTile<TeslaNavigationMode>(
                    title: Text(
                      AppLocalizations.of(context)!.teslaNavigationModeGps,
                    ),
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
                      title: Text(AppLocalizations.of(context)!.logoutTitle),
                      subtitle: Text(
                        AppLocalizations.of(context)!.logoutDescription,
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _isLoggingOut ? null : _handleLogout,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
