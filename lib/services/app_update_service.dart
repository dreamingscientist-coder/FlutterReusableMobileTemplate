import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import '../config/app_config.dart';
import 'store_links.dart';

int compareAppVersions(String a, String b) {
  List<int> parts(String value) {
    if (!RegExp(r'^\d+\.\d+\.\d+$').hasMatch(value)) {
      throw const FormatException('Expected major.minor.patch');
    }
    return value.split('.').map(int.parse).toList();
  }

  final left = parts(a), right = parts(b);
  for (var i = 0; i < 3; i++) {
    final order = left[i].compareTo(right[i]);
    if (order != 0) return order;
  }
  return 0;
}

class AppUpdateNotice {
  const AppUpdateNotice(
      {required this.latest,
      required this.required,
      required this.releasesBehind,
      required this.storeUrl,
      this.messages = const {}});
  final String latest;
  final bool required;
  final int releasesBehind;
  final Uri storeUrl;
  final Map<String, String> messages;
  bool get strongReminder => releasesBehind > 2;

  static AppUpdateNotice? evaluate(Map<String, dynamic> policy,
      {required String platform,
      required String installed,
      required DateTime now,
      String? bundleId}) {
    if (policy['schemaVersion'] != 1 ||
        policy['appId'] != (bundleId ?? AppConfig.bundleId)) {
      return null;
    }
    final data = (policy[platform] as Map?)?.cast<String, dynamic>();
    if (data == null ||
        data['enabled'] != true ||
        data['storeAvailable'] != true) {
      return null;
    }
    // An expired policy cannot indefinitely lock users out of a working app.
    final expires = DateTime.parse(data['expiresAt'] as String);
    if (!expires.isAfter(now.toUtc())) return null;
    final latest = data['latestVersion'] as String;
    final minimum = data['minimumSupportedVersion'] as String;
    final mode = data['mode'];
    if (mode != 'optional' && mode != 'required') return null;
    if (compareAppVersions(minimum, latest) > 0) return null;
    if (compareAppVersions(installed, latest) >= 0) return null;
    final releases = (data['publishedReleases'] as List).cast<String>();
    if (releases.isEmpty ||
        releases.last != latest ||
        releases.toSet().length != releases.length) {
      return null;
    }
    for (var i = 1; i < releases.length; i++) {
      if (compareAppVersions(releases[i - 1], releases[i]) >= 0) return null;
    }
    final index = releases.indexOf(installed);
    final behind = index < 0 ? 0 : releases.length - index - 1;
    final url = Uri.parse(data['storeUrl'] as String);
    final validStore = platform == 'ios'
        ? url.host == 'apps.apple.com' &&
            RegExp(r'^/app/(?:[^/]+/)?id[0-9]+$|^/[a-z]{2}/app/(?:[^/]+/)?id[0-9]+$')
                .hasMatch(url.path)
        : platform == 'android' &&
            url.host == 'play.google.com' &&
            url.path == '/store/apps/details' &&
            url.queryParameters['id'] == (bundleId ?? AppConfig.bundleId);
    if (url.scheme != 'https' ||
        !validStore ||
        url.userInfo.isNotEmpty ||
        url.hasPort) {
      return null;
    }
    final messages = <String, String>{};
    for (final code in ['en', 'vi', 'fr']) {
      final value = (data['messages'] as Map?)?[code];
      if (value is String && value.length <= 2000) messages[code] = value;
    }
    return AppUpdateNotice(
        latest: latest,
        required:
            mode == 'required' || compareAppVersions(installed, minimum) < 0,
        releasesBehind: behind,
        storeUrl: url,
        messages: messages);
  }
}

class AppUpdateService extends ChangeNotifier {
  AppUpdateService(
      {http.Client? client,
      Future<String> Function()? version,
      DateTime Function()? now,
      String? platform})
      : _client = client ?? http.Client(),
        _version =
            version ?? (() async => (await PackageInfo.fromPlatform()).version),
        _now = now ?? DateTime.now,
        _platform = platform ??
            (defaultTargetPlatform == TargetPlatform.iOS
                ? 'ios'
                : defaultTargetPlatform == TargetPlatform.android
                    ? 'android'
                    : 'unsupported');
  static final instance = AppUpdateService();
  static final policyUrl = Uri.parse(const String.fromEnvironment(
      'APP_UPDATE_POLICY_URL',
      defaultValue: '${AppConfig.legalPagesUrl}/app-update.json'));
  final http.Client _client;
  final Future<String> Function() _version;
  final DateTime Function() _now;
  final String _platform;
  DateTime? _checked;
  bool _busy = false, _disposed = false;
  final Set<String> _dismissed = {};
  AppUpdateNotice? notice;
  bool get busy => _busy;

  Future<void> check({bool force = false}) async {
    if (_busy || kIsWeb || _platform == 'unsupported' || _disposed) return;
    if (!force &&
        _checked != null &&
        _now().difference(_checked!) < const Duration(hours: 6)) {
      return;
    }
    _busy = true;
    _checked = _now();
    try {
      final results = await Future.wait<Object>([
        _client.get(policyUrl, headers: {'Cache-Control': 'no-cache'}),
        _version()
      ]).timeout(const Duration(seconds: 5));
      final response = results[0] as http.Response;
      if (response.statusCode != 200 || response.bodyBytes.length > 32768) {
        throw const FormatException('Policy unavailable');
      }
      var candidate = AppUpdateNotice.evaluate(
          (jsonDecode(utf8.decode(response.bodyBytes)) as Map)
              .cast<String, dynamic>(),
          platform: _platform,
          installed: results[1] as String,
          now: _now());
      final listing = const StoreLinks().listing(
          _platform == 'ios' ? TargetPlatform.iOS : TargetPlatform.android);
      if (candidate != null &&
          listing != null &&
          (candidate.storeUrl.host != listing.host ||
              candidate.storeUrl.path != listing.path ||
              candidate.storeUrl.query != listing.query)) {
        candidate = null;
      }
      if (!_disposed) {
        notice = candidate != null &&
                (candidate.required || !_dismissed.contains(candidate.latest))
            ? candidate
            : null;
      }
    } catch (_) {
      // Fail open for network, malformed policy, plugin and store config failures.
      if (!_disposed) notice = null;
    } finally {
      _busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  void dismiss() {
    if (notice == null || notice!.required) return;
    _dismissed.add(notice!.latest);
    notice = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _client.close();
    super.dispose();
  }
}
