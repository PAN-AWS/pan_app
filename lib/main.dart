// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'firebase_options.dart';
import 'app/app.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/date_symbol_data_local.dart';
import 'utils/app_logger.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final recaptchaKey =
      const String.fromEnvironment('FIREBASE_APPCHECK_RECAPTCHA_KEY');
  if (kIsWeb && recaptchaKey.isEmpty) {
    AppLogger.warn('App Check web key missing: FIREBASE_APPCHECK_RECAPTCHA_KEY');
  }
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.playIntegrity,
    appleProvider: AppleProvider.deviceCheck,
    webProvider:
        kIsWeb && recaptchaKey.isNotEmpty ? ReCaptchaV3Provider(recaptchaKey) : null,
  );

  final options = Firebase.app().options;
  AppLogger.info('Firebase projectId=${options.projectId ?? 'n/d'}');
  AppLogger.info('Firebase storageBucket=${options.storageBucket ?? 'n/d'}');

  // Localizzazione date/ore in italiano
  await initializeDateFormatting('it_IT', null);

  // Su Web mantieni la sessione tra refresh
  if (kIsWeb) {
    await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
  }

  runApp(const PanApp());
}
