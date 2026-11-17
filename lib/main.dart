import 'package:flutter/material.dart';

import 'app.dart';
import 'l10n/app_language.dart';
import 'services/development_settings.dart';
import 'services/ad_free_service.dart';
import 'services/auth_service.dart';
import 'services/purchase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AppLanguage.instance.init();
  await DevelopmentSettings.instance.init();
  await AdFreeService.instance.init();
  await AuthService.instance.init();
  await PurchaseService.instance.init();

  runApp(const MyApp());

}
