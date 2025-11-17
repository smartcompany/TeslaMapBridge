import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../l10n/app_localizations.dart';
import '../services/tesla_auth_service.dart';
import '../widgets/network_error_dialog.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  WebViewController? _webViewController;
  bool _isLoading = true;
  bool _isProcessingAuth = false;
  bool _isInitializing = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  Future<void> _initializeWebView({bool isRetry = false}) async {
    if (!isRetry) {
      setState(() {
        _isInitializing = true;
        _errorMessage = null;
      });
    }

    try {
      final authUrl = await TeslaAuthService.shared.getAuthorizationUrl();

      final webViewController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (String url) {
              if (mounted) {
                setState(() {
                  _isLoading = true;
                });
              }
            },
            onPageFinished: (String url) {
              if (mounted) {
                setState(() {
                  _isLoading = false;
                });
              }
            },
            onWebResourceError: (WebResourceError error) {
              if (mounted && !_isProcessingAuth) {
                final errorMessage = error.description.toLowerCase();
                final loc = AppLocalizations.of(context)!;
                if (errorMessage.contains('client_id') ||
                    errorMessage.contains("don't recognize")) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(loc.clientIdNotConfigured),
                      backgroundColor: Colors.orange,
                      duration: const Duration(seconds: 10),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(loc.errorWithMessage(error.description)),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            onUrlChange: (UrlChange change) async {
              if (change.url != null && !_isProcessingAuth) {
                await _handleUrlChange(change.url!);
              }
            },
          ),
        )
        ..loadRequest(Uri.parse(authUrl));

      if (mounted) {
        setState(() {
          _webViewController = webViewController;
          _isInitializing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _errorMessage = e.toString();
        });

        // Check if it's a network error
        if (isNetworkError(e)) {
          final shouldRetry = await showNetworkErrorDialog(
            context,
            onRetry: () => _initializeWebView(isRetry: true),
          );

          if (shouldRetry == true) {
            // Retry will be handled by onRetry callback
            return;
          }
        } else {
          // For non-network errors, show snackbar
          final loc = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(loc.errorWithMessage('$e')),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 10),
            ),
          );
        }
      }
    }
  }

  Future<void> _handleUrlChange(String url) async {
    // Check if this is the callback URL with authorization code
    if (url.contains('auth.tesla.com/void/callback') || url.contains('code=')) {
      final authCode = TeslaAuthService.shared.extractAuthorizationCode(url);

      if (authCode != null && !_isProcessingAuth) {
        setState(() {
          _isProcessingAuth = true;
        });

        try {
          final success = await TeslaAuthService.shared.exchangeCodeForToken(
            authCode,
          );

          if (mounted) {
            if (success) {
              Navigator.of(context).pushReplacementNamed('/home');
            } else {
              setState(() {
                _isProcessingAuth = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(AppLocalizations.of(context)!.loginFailed),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        } catch (e) {
          if (mounted) {
            setState(() {
              _isProcessingAuth = false;
            });
            final loc = AppLocalizations.of(context)!;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(loc.errorWithMessage('$e')),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(loc.loginTitle),
        automaticallyImplyLeading: false,
      ),
      body: _isInitializing
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    loc.initializing,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ],
              ),
            )
          : _webViewController == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      loc.webViewInitializationFailed,
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    if (isNetworkError(_errorMessage))
                      ElevatedButton.icon(
                        onPressed: () => _initializeWebView(isRetry: true),
                        icon: const Icon(Icons.refresh),
                        label: Text(loc.retry),
                      ),
                  ],
                ),
              ),
            )
          : Stack(
              children: [
                WebViewWidget(controller: _webViewController!),
                if (_isLoading || _isProcessingAuth)
                  Container(
                    color: Colors.white.withValues(alpha: 0.8),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(
                            _isProcessingAuth
                                ? loc.processingLogin
                                : loc.loading,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
