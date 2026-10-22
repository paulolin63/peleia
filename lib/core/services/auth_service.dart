import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Login anônimo do Firebase. O uid é o mesmo que o Worker consulta no RevenueCat.
class AuthService {
  static Future<String?> idToken() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      var user = FirebaseAuth.instance.currentUser;
      user ??= (await FirebaseAuth.instance.signInAnonymously()).user;
      if (user == null) return null;

      if (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS)) {
        try {
          await Purchases.logIn(user.uid);
        } catch (e) {
          debugPrint('RevenueCat logIn ignorado: $e');
        }
      }
      return await user.getIdToken();
    } catch (e) {
      debugPrint('Firebase indisponível: $e');
      return null;
    }
  }
}
