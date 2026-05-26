// webview_screen.dart — production WebView wrapper.
//
// - URL allowlist (host-pinned)
// - JS bridge registered BEFORE loadRequest (per pitfall #4)
// - Android back → WebView history
// - Error / offline state

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class HostedWebViewScreen extends StatefulWidget {
  const HostedWebViewScreen({
    super.key,
    required this.url,
    required this.allowedHosts,
    this.title,
    this.onBridgeMessage,
  });

  /// Initial URL to load (must be HTTPS).
  final String url;

  /// Allowed hosts. Navigation outside this set → blocked + opened in system browser.
  final Set<String> allowedHosts;

  /// AppBar title (optional).
  final String? title;

  /// JS bridge callback. From JS:
  ///   window.AppBridge.postMessage(JSON.stringify({...}));
  final void Function(String message)? onBridgeMessage;

  @override
  State<HostedWebViewScreen> createState() => _HostedWebViewScreenState();
}

class _HostedWebViewScreenState extends State<HostedWebViewScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      // Register JS bridge BEFORE loadRequest — otherwise first message lost
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          if (mounted) setState(() { _loading = true; _error = null; });
        },
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
        },
        onWebResourceError: (err) {
          if (mounted) setState(() {
            _loading = false;
            _error = err.description;
          });
        },
        onNavigationRequest: (req) {
          final uri = Uri.tryParse(req.url);
          if (uri == null) return NavigationDecision.prevent;
          if (!widget.allowedHosts.contains(uri.host)) {
            // Off-domain → open in external browser, block in-app navigation
            // (use url_launcher; omitted for brevity)
            return NavigationDecision.prevent;
          }
          // HTTPS only
          if (uri.scheme != 'https') return NavigationDecision.prevent;
          return NavigationDecision.navigate;
        },
      ));
    if (widget.onBridgeMessage != null) {
      c.addJavaScriptChannel('AppBridge',
          onMessageReceived: (msg) => widget.onBridgeMessage!(msg.message));
    }
    _controller = c;
    // Load AFTER channel + delegate set
    _controller.loadRequest(Uri.parse(widget.url));
  }

  Future<bool> _onBackPressed() async {
    if (await _controller.canGoBack()) {
      await _controller.goBack();
      return false;  // don't pop the route
    }
    return true;  // pop
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (!didPop && await _onBackPressed() && mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: widget.title == null ? null : AppBar(title: Text(widget.title!)),
        body: Stack(
          children: [
            if (_error == null) WebViewWidget(controller: _controller),
            if (_loading) const LinearProgressIndicator(),
            if (_error != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48),
                      const SizedBox(height: 12),
                      Text('Sayfa yüklenemedi: $_error', textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () {
                          setState(() { _error = null; _loading = true; });
                          _controller.loadRequest(Uri.parse(widget.url));
                        },
                        child: const Text('Yeniden dene'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
