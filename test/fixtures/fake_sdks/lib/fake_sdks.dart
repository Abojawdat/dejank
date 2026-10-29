class Firebase {
  static Future<void> initializeApp() async {}
}

class FirebaseMessaging {
  static final instance = FirebaseMessaging();
  Future<void> requestPermission() async {}
}

class SharedPreferences {
  static Future<SharedPreferences> getInstance() async => SharedPreferences();
}

class Hive {
  static Future<void> initFlutter() async {}
  static Future<void> openBox(String name) async {}
}
