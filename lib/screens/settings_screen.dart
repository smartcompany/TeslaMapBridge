import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../models/tesla_navigation_mode.dart';
import '../services/subscription_service.dart';
import '../services/theme_service.dart';
import '../services/navigation_service.dart';
import '../services/tesla_auth_service.dart';
import '../services/usage_limit_service.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../widgets/subscription_sheet.dart';
import '../widgets/rewarded_ad_sheet.dart';
import '../widgets/credit_purchase_sheet.dart';
import '../models/purchase_mode.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.initialQuota});

  final int initialQuota;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TeslaAuthService _teslaAuthService = TeslaAuthService();
  final UsageLimitService _usageLimitService = UsageLimitService();
  late final SubscriptionService _subscriptionService;
  late final ThemeService _themeService;
  NavigationApp _selectedApp = NavigationApp.tmap;
  TeslaNavigationMode _navigationMode = TeslaNavigationMode.destination;
  bool _isLoading = true;
  bool _hasChanges = false;
  bool _isLoggingOut = false;
  List<Map<String, dynamic>> _vehicles = [];
  String? _selectedVehicleId;
  String? _debugAccessToken;
  late ThemePreset _themePreset;
  late int _quota;
  int _lastRewardCredits = 0;
  bool _showRewardAnim = false;

  @override
  void initState() {
    super.initState();
    _subscriptionService = Provider.of<SubscriptionService>(
      context,
      listen: false,
    );
    _themeService = Provider.of<ThemeService>(context, listen: false);
    _themePreset = _themeService.preset;
    _quota = widget.initialQuota;
    _loadPreferences();
    if (kDebugMode) {
      _loadDebugAccessToken();
    }
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
      _themePreset = _themeService.preset;
      if (resolvedVehicleId != storedVehicleId) {
        _hasChanges = true;
      }
      _isLoading = false;
    });

    if (resolvedVehicleId != storedVehicleId) {
      await _teslaAuthService.setSelectedVehicleId(resolvedVehicleId);
    }
    if (kDebugMode) {
      _loadDebugAccessToken();
    }
  }

  Future<void> _loadDebugAccessToken() async {
    final token = await _teslaAuthService.getAccessToken();
    if (!mounted) return;
    setState(() {
      _debugAccessToken = token;
    });
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

  Future<void> _setThemePreset(ThemePreset preset) async {
    if (_themePreset == preset) return;
    setState(() {
      _themePreset = preset;
    });
    await _themeService.setPreset(preset);
    if (!mounted) return;
    final loc = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(loc.themeChangedMessage),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _showSubscriptionSheet() async {
    if (!mounted) {
      return;
    }

    if (_subscriptionService.isAvailable && !_subscriptionService.isLoading) {
      debugPrint(
        '[Settings] Refreshing products... mode=${_subscriptionService.purchaseMode}',
      );
      // Fetch dynamic credit pack IDs from server before querying store
      try {
        final map = _teslaAuthService.creditPackProductIdToCredits;
        if (map.isNotEmpty) {
          _subscriptionService.setCreditPackProducts(map);
        }
      } catch (e) {
        debugPrint('[Settings] Failed to load credit packs: $e');
      }
      await _subscriptionService.refreshProducts();
    }

    if (!mounted) {
      return;
    }

    try {
      debugPrint(
        '[Settings] Opening purchase sheet '
        'mode=${_subscriptionService.purchaseMode} '
        'available=${_subscriptionService.isAvailable} '
        'count=${_subscriptionService.products.length} '
        'ids=${_subscriptionService.products.map((p) => p.id).join(', ')}',
      );
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (sheetContext) =>
            _subscriptionService.purchaseMode == PurchaseMode.creditPack
            ? CreditPurchaseSheet(quota: _quota)
            : SubscriptionSheet(quota: _quota),
      );
    } finally {
      _subscriptionService.resetTransientState();
    }
  }

  Future<void> _startRewardedFlow() async {
    if (!mounted) return;
    final loc = AppLocalizations.of(context)!;
    try {
      final adUnitId = TeslaAuthService().getRewardedAdUnitId(
        preferTestIfMissing: true,
      );
      if (adUnitId.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(loc.rewardAdLoadFailed)));
        return;
      }

      bool rewardedGiven = false;
      await RewardedAd.load(
        adUnitId: adUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            ad.fullScreenContentCallback = FullScreenContentCallback(
              onAdFailedToShowFullScreenContent: (ad, error) {
                ad.dispose();
              },
              onAdDismissedFullScreenContent: (ad) {
                ad.dispose();
                if (!rewardedGiven && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(loc.rewardAdMustFinish)),
                  );
                }
              },
            );
            ad.show(
              onUserEarnedReward: (ad, reward) async {
                if (rewardedGiven) return;
                rewardedGiven = true;
                final userId = await _teslaAuthService.getEmail();
                final token = await _teslaAuthService.getAccessToken();
                if (userId == null || token == null) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(loc.errorWithMessage('Not signed in')),
                    ),
                  );
                  return;
                }
                try {
                  final rewardCredits = _teslaAuthService
                      .getRewardCreditsPerAd();

                  final usage = await _usageLimitService.addCredits(
                    userId: userId,
                    accessToken: token,
                    credits: rewardCredits,
                  );
                  if (!mounted) return;
                  setState(() {
                    _quota = usage.quota;
                    _lastRewardCredits = rewardCredits;
                    _showRewardAnim = true;
                  });
                  Future.delayed(const Duration(milliseconds: 900), () {
                    if (!mounted) return;
                    setState(() {
                      _showRewardAnim = false;
                    });
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(loc.rewardEarned(rewardCredits))),
                  );
                } catch (_) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(loc.rewardAdLoadFailed)),
                  );
                }
              },
            );
          },
          onAdFailedToLoad: (error) {
            if (!mounted) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(loc.rewardAdLoadFailed)));
          },
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(loc.rewardAdLoadFailed)));
    }
  }

  (String title, String subtitle) _purchaseCardTexts(AppLocalizations loc) {
    final isCredit =
        _subscriptionService.purchaseMode == PurchaseMode.creditPack;
    final titleText = isCredit
        ? loc.creditsSectionTitle
        : loc.subscriptionSectionTitle;
    final subtitleText = _subscriptionService.isSubscribed
        ? loc.subscriptionActiveLabel
        : (isCredit
              ? loc.oneTimePurchaseButton
              : loc.subscriptionUpgradeButton);
    return (titleText, subtitleText);
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
        if (kDebugMode) {
          setState(() {
            _debugAccessToken = null;
          });
        }
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
                  Card(
                    child: Builder(
                      builder: (context) {
                        if (!_subscriptionService.purchasingAvailable) {
                          return const SizedBox.shrink();
                        }
                        final isCredit =
                            _subscriptionService.purchaseMode ==
                            PurchaseMode.creditPack;
                        // Server `/api/quota/add` already returns the total credits,
                        // so use `_quota` directly without client-side math.
                        final currentCredits = _quota;
                        if (!isCredit) {
                          final texts = _purchaseCardTexts(loc);
                          return ListTile(
                            leading: const Icon(Icons.star),
                            title: Text(texts.$1),
                            subtitle: Text(texts.$2),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _showSubscriptionSheet(),
                          );
                        }
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.star),
                                      const SizedBox(width: 8),
                                      Text(
                                        loc.creditsSectionTitle,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    AppLocalizations.of(
                                      context,
                                    )!.creditsOwnedLabel(currentCredits),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Card(
                                child: ListTile(
                                  leading: const Icon(Icons.shopping_cart),
                                  title: Text(loc.buyCredits),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: _showSubscriptionSheet,
                                ),
                              ),
                              Card(
                                child: ListTile(
                                  leading: const Icon(Icons.ondemand_video),
                                  title: Text(loc.earnFreeCredits),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () {
                                    showModalBottomSheet<void>(
                                      context: context,
                                      isScrollControlled: true,
                                      shape: const RoundedRectangleBorder(
                                        borderRadius: BorderRadius.vertical(
                                          top: Radius.circular(24),
                                        ),
                                      ),
                                      builder: (c) => RewardedAdSheet(
                                        onWatchPressed: _startRewardedFlow,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
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
                  Text(
                    loc.themeSectionTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  RadioListTile<ThemePreset>(
                    title: Text(loc.themeDarkLabel),
                    value: ThemePreset.dark,
                    groupValue: _themePreset,
                    onChanged: (value) {
                      if (value != null) {
                        _setThemePreset(value);
                      }
                    },
                  ),
                  RadioListTile<ThemePreset>(
                    title: Text(loc.themeLightLabel),
                    value: ThemePreset.light,
                    groupValue: _themePreset,
                    onChanged: (value) {
                      if (value != null) {
                        _setThemePreset(value);
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
                  Text(
                    loc.legalSectionTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.description),
                      title: Text(loc.termsOfUse),
                      trailing: const Icon(Icons.open_in_new),
                      onTap: () async {
                        final url = Uri.parse(
                          'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/',
                        );
                        if (await canLaunchUrl(url)) {
                          await launchUrl(
                            url,
                            mode: LaunchMode.externalApplication,
                          );
                        }
                      },
                    ),
                  ),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.privacy_tip),
                      title: Text(loc.privacyPolicy),
                      trailing: const Icon(Icons.open_in_new),
                      onTap: () async {
                        final locale = Localizations.localeOf(context);
                        final baseUrl =
                            'https://smartcompany.github.io/TeslaMapBridge/privacy.html';
                        final url = Uri.parse(
                          locale.languageCode == 'ko' ? '$baseUrl#ko' : baseUrl,
                        );
                        if (await canLaunchUrl(url)) {
                          await launchUrl(
                            url,
                            mode: LaunchMode.externalApplication,
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 32),
                  if (kDebugMode)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              loc.debugAccessTokenTitle,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if ((_debugAccessToken ?? '').isEmpty)
                              Text(
                                loc.debugAccessTokenEmpty,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context).hintColor,
                                    ),
                              )
                            else
                              SelectableText(
                                _debugAccessToken!,
                                style: const TextStyle(fontSize: 12),
                              ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () async {
                                    if (!mounted) return;
                                    final messenger = ScaffoldMessenger.of(
                                      context,
                                    );
                                    final localized = AppLocalizations.of(
                                      context,
                                    )!;
                                    await _loadDebugAccessToken();
                                    if (!mounted) return;
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          localized.debugAccessTokenRefreshed,
                                        ),
                                      ),
                                    );
                                  },
                                  child: Text(loc.debugAccessTokenRefresh),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: (_debugAccessToken ?? '').isEmpty
                                      ? null
                                      : () async {
                                          if (!mounted) return;
                                          final messenger =
                                              ScaffoldMessenger.of(context);
                                          final localized = AppLocalizations.of(
                                            context,
                                          )!;
                                          await Clipboard.setData(
                                            ClipboardData(
                                              text: _debugAccessToken!,
                                            ),
                                          );
                                          if (!mounted) return;
                                          messenger.showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                localized
                                                    .debugAccessTokenCopied,
                                              ),
                                            ),
                                          );
                                        },
                                  child: Text(loc.debugAccessTokenCopy),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (kDebugMode) const SizedBox(height: 32),
                ],
              ),
      ),
    );
  }
}
