// =====================================================================
// link_service.dart — opens web pages and the email app safely.
// Every method returns true/false and NEVER throws, so screens can
// simply show "Could not open" when it returns false.
// =====================================================================
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class LinkService {
  LinkService._();

  /// Opens a web page in the phone's browser.
  static Future<bool> openWeb(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('LinkService.openWeb failed for $url: $e');
      return false;
    }
  }

  /// Opens the email app with a pre-filled message.
  static Future<bool> sendEmail({
    required String to,
    required String subject,
    String body = '',
  }) async {
    // Encode by hand: Uri(queryParameters) turns spaces into "+",
    // which some mail apps show literally.
    final query =
        'subject=${Uri.encodeComponent(subject)}'
        '&body=${Uri.encodeComponent(body)}';
    final uri = Uri.parse('mailto:$to?$query');
    try {
      return await launchUrl(uri);
    } catch (e) {
      debugPrint('LinkService.sendEmail failed: $e');
      return false;
    }
  }

  /// "1.0.0 (7)" — shown in Settings and added to support emails.
  static Future<String> appVersionLabel() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return '${info.version} (${info.buildNumber})';
    } catch (_) {
      return '?';
    }
  }

  /// Technical details that help you answer a support email.
  static Future<String> deviceInfoForSupport() async {
    final version = await appVersionLabel();
    return 'App version: $version\n'
        'System: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}\n';
  }
}
