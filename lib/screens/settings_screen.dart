import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    if (!mounted) return;

    setState(() {
      if (stored != null) {
        final match = NavigationApp.values.firstWhere(
          (app) => app.name == stored,
          orElse: () => NavigationApp.tmap,
        );
        _selectedApp = match;
      }
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${NavigationService().getAppName(app)}가 기본 네비게이션으로 설정되었습니다.',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<bool> _handleWillPop() async {
    Navigator.of(context).pop(_hasChanges);
    return false;
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('로그아웃 하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('로그아웃'),
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
          title: const Text('설정'),
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
                  const Text(
                    '기본 네비게이션 앱',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...NavigationApp.values.map(
                    (app) => RadioListTile<NavigationApp>(
                      title: Text(NavigationService().getAppName(app)),
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
                  Card(
                    child: ListTile(
                      leading: _isLoggingOut
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.logout),
                      title: const Text('로그아웃'),
                      subtitle: const Text('계정에서 로그아웃합니다'),
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
