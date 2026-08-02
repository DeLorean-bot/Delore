import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flclashx/common/domain_routing.dart';
import 'package:flclashx/common/print.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BrowserTabInfo {
  const BrowserTabInfo({
    required this.id,
    required this.browser,
    required this.title,
    required this.url,
    required this.domain,
    required this.faviconUrl,
    required this.active,
    required this.windowId,
    required this.lastSeen,
  });

  factory BrowserTabInfo.fromJson(
    Map<String, dynamic> json, {
    required String browser,
    required DateTime seenAt,
  }) {
    final rawUrl = json['url']?.toString() ?? '';
    final uri = Uri.tryParse(rawUrl);
    final domain = uri == null ? '' : DomainRoutingStore.normalize(uri.host);
    return BrowserTabInfo(
      id: '${browser.toLowerCase()}:${json['id']}',
      browser: browser,
      title: (json['title']?.toString() ?? domain).trim(),
      url: rawUrl,
      domain: domain,
      faviconUrl: json['favIconUrl']?.toString() ?? '',
      active: json['active'] == true,
      windowId: int.tryParse('${json['windowId']}') ?? 0,
      lastSeen: seenAt,
    );
  }

  final String id;
  final String browser;
  final String title;
  final String url;
  final String domain;
  final String faviconUrl;
  final bool active;
  final int windowId;
  final DateTime lastSeen;
}

class BrowserBridgeService {
  BrowserBridgeService._();

  static const port = 47831;
  static const _tokenKey = 'browser_bridge_pairing_token_v1';
  static const _maxBodyBytes = 512 * 1024;

  static final instance = BrowserBridgeService._();

  final _controller = StreamController<List<BrowserTabInfo>>.broadcast();
  final Map<String, BrowserTabInfo> _tabs = {};
  HttpServer? _server;
  Future<void>? _starting;
  String? _token;

  Stream<List<BrowserTabInfo>> get stream => _controller.stream;
  List<BrowserTabInfo> get tabs => List.unmodifiable(_tabs.values);
  bool get isRunning => _server != null;

  Future<String> get pairingToken async {
    if (_token != null) return _token!;
    final preferences = await SharedPreferences.getInstance();
    var value = preferences.getString(_tokenKey);
    if (value == null || value.length < 32) {
      final random = Random.secure();
      value = base64UrlEncode(
        List<int>.generate(32, (_) => random.nextInt(256)),
      ).replaceAll('=', '');
      await preferences.setString(_tokenKey, value);
    }
    _token = value;
    return value;
  }

  Future<void> start() => _starting ??= _start();

  Future<void> _start() async {
    if (_server != null ||
        !Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) {
      return;
    }
    await pairingToken;
    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
      _server!.listen(_handle, onError: (Object error) {
        commonPrint.log('Browser Bridge error: $error');
      });
    } catch (error) {
      _starting = null;
      commonPrint.log('Browser Bridge could not bind 127.0.0.1:$port: $error');
    }
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _starting = null;
  }

  Future<void> _handle(HttpRequest request) async {
    _addCors(request.response);
    if (request.method == 'OPTIONS') {
      request.response
        ..statusCode = HttpStatus.noContent
        ..close();
      return;
    }
    if (request.uri.path == '/status' && request.method == 'GET') {
      _json(request.response, {'name': 'Delore Browser Bridge', 'ready': true});
      return;
    }
    if (request.uri.path == '/pair' && request.method == 'GET') {
      final origin = request.headers.value('origin') ?? '';
      if (!_isBrowserExtensionOrigin(origin)) {
        _json(
          request.response,
          {'error': 'extension_origin_required'},
          status: HttpStatus.forbidden,
        );
        return;
      }
      _json(request.response, {
        'token': await pairingToken,
        'expires': false,
      });
      return;
    }
    if (request.uri.path != '/tabs' || request.method != 'POST') {
      _json(request.response, {'error': 'not_found'},
          status: HttpStatus.notFound);
      return;
    }
    if (request.headers.value('x-delore-token') != _token) {
      _json(request.response, {'error': 'unauthorized'},
          status: HttpStatus.unauthorized);
      return;
    }
    final contentLength = request.contentLength;
    if (contentLength > _maxBodyBytes) {
      _json(request.response, {'error': 'payload_too_large'},
          status: HttpStatus.requestEntityTooLarge);
      return;
    }
    try {
      final body = await utf8.decoder.bind(request).join();
      if (body.length > _maxBodyBytes) {
        throw const FormatException('payload too large');
      }
      final data = jsonDecode(body) as Map<String, dynamic>;
      final browser = (data['browser']?.toString() ?? 'Browser').trim();
      final instance = (data['instanceId']?.toString() ?? 'default').trim();
      final values = data['tabs'] as List<dynamic>? ?? const [];
      final seenAt = DateTime.now();
      final prefix = '${browser.toLowerCase()}:$instance:';
      _tabs.removeWhere((key, _) => key.startsWith(prefix));
      for (final value in values.take(500)) {
        if (value is! Map) continue;
        final tab = BrowserTabInfo.fromJson(
          Map<String, dynamic>.from(value),
          browser: browser,
          seenAt: seenAt,
        );
        if (tab.domain.isEmpty ||
            !(tab.url.startsWith('http://') ||
                tab.url.startsWith('https://'))) {
          continue;
        }
        _tabs['$prefix${tab.id}'] = tab;
      }
      _tabs.removeWhere(
        (_, tab) =>
            seenAt.difference(tab.lastSeen) > const Duration(minutes: 2),
      );
      final snapshot = [...tabs]..sort((a, b) {
          if (a.active != b.active) return a.active ? -1 : 1;
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        });
      _controller.add(snapshot);
      _json(request.response, {'ok': true, 'accepted': values.length});
    } catch (error) {
      _json(request.response, {'error': 'invalid_payload', 'detail': '$error'},
          status: HttpStatus.badRequest);
    }
  }

  bool _isBrowserExtensionOrigin(String origin) {
    final uri = Uri.tryParse(origin);
    if (uri == null || uri.host.isEmpty) return false;
    return uri.scheme == 'chrome-extension' || uri.scheme == 'moz-extension';
  }

  void _addCors(HttpResponse response) {
    response.headers
      ..set('Access-Control-Allow-Origin', '*')
      ..set('Access-Control-Allow-Headers', 'Content-Type, X-Delore-Token')
      ..set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
      ..set('Cache-Control', 'no-store');
  }

  void _json(HttpResponse response, Object value,
      {int status = HttpStatus.ok}) {
    response
      ..statusCode = status
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(value))
      ..close();
  }
}

final browserBridge = BrowserBridgeService.instance;
