import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/tesla_auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _teslaAuthService = TeslaAuthService();
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

  Future<void> _initializeWebView() async {
    try {
      final authUrl = await _teslaAuthService.getAuthorizationUrl();

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
                if (errorMessage.contains('client_id') ||
                    errorMessage.contains("don't recognize")) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text(
                        'Client ID가 설정되지 않았습니다.\n'
                        'lib/services/tesla_auth_service.dart 파일에서\n'
                        '_clientId를 Tesla Developer Portal에서 발급받은 값으로 설정하세요.',
                      ),
                      backgroundColor: Colors.orange,
                      duration: const Duration(seconds: 10),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('오류 발생: ${error.description}'),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('오류: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 10),
          ),
        );
      }
    }
  }

  Future<void> _handleUrlChange(String url) async {
    // Check if this is the callback URL with authorization code
    if (url.contains('auth.tesla.com/void/callback') || url.contains('code=')) {
      final authCode = _teslaAuthService.extractAuthorizationCode(url);

      if (authCode != null && !_isProcessingAuth) {
        setState(() {
          _isProcessingAuth = true;
        });

        try {
          final success = await _teslaAuthService.exchangeCodeForToken(
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
                const SnackBar(
                  content: Text('로그인에 실패했습니다. 다시 시도해주세요.'),
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
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('오류 발생: $e'), backgroundColor: Colors.red),
            );
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('테슬라 로그인'),
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
                    '초기화 중...',
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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'WebView 초기화 실패',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ],
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
                            _isProcessingAuth ? '로그인 처리 중...' : '로딩 중...',
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
