import 'package:fake_sdks/fake_sdks.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'setup.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance(); // LINT
  final config = await rootBundle.loadString('assets/config.json');
  debugPrint('$prefs $config');

  // Must not change.
  // Other Firebase calls need Firebase.initializeApp first.
  await Firebase.initializeApp();
  await FirebaseMessaging.instance.requestPermission();
  debugPrint('');

  // The second needs the first's result.
  final name = await rootBundle.loadString('assets/name.txt');
  await SystemChrome.setApplicationSwitcherDescription(ApplicationSwitcherDescription(label: name));
  debugPrint(name);

  // Same object: the second may need the first.
  await Hive.initFlutter();
  await Hive.openBox('settings');
  debugPrint('');

  // The app's own code.
  await setupLocator();
  await loadUser();

  runApp(const MaterialApp());

  // After runApp: doesn't delay the first frame.
  await SharedPreferences.getInstance();
  await Hive.openBox('cache');
}
