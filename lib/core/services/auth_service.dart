import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Autenticação híbrida:
/// - Login anônimo automático (zero fricção na abertura)
/// - Login com Google (vínculo de conta permanente, sincronização e anti-fraude)
class AuthService {
  static User? get currentUser {
    if (Firebase.apps.isEmpty) return null;
    return FirebaseAuth.instance.currentUser;
  }

  static bool get isGoogleUser {
    final user = currentUser;
    if (user == null || user.isAnonymous) return false;
    return user.providerData.any((p) => p.providerId == 'google.com');
  }

  static String? get userEmail => currentUser?.email;
  static String? get userDisplayName => currentUser?.displayName;
  static String? get userPhotoUrl => currentUser?.photoURL;

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

  /// Realiza login com o Google e vincula os dados existentes à conta permanente
  static Future<UserCredential?> signInWithGoogle() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      final googleSignIn = GoogleSignIn();
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        // Usuário cancelou o seletor do Google
        return null;
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final current = FirebaseAuth.instance.currentUser;
      UserCredential userCredential;

      if (current != null && current.isAnonymous) {
        try {
          userCredential = await current.linkWithCredential(credential);
        } on FirebaseAuthException catch (e) {
          if (e.code == 'credential-already-in-use') {
            userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
          } else {
            rethrow;
          }
        }
      } else {
        userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      }

      final uid = userCredential.user?.uid;
      if (uid != null &&
          !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS)) {
        try {
          await Purchases.logIn(uid);
        } catch (e) {
          debugPrint('RevenueCat logIn Google ignorado: $e');
        }
      }

      return userCredential;
    } catch (e) {
      debugPrint('[AuthService] signInWithGoogle error: $e');
      rethrow;
    }
  }

  static Future<void> signOut() async {
    try {
      if (Firebase.apps.isEmpty) return;
      await GoogleSignIn().signOut().catchError((_) => null);
      await FirebaseAuth.instance.signOut();
      await idToken();
    } catch (e) {
      debugPrint('[AuthService] signOut error: $e');
    }
  }

  /// LGPD: remove a conta (anônima ou permanente).
  static Future<void> deleteAnonymousAccount() async {
    try {
      if (Firebase.apps.isEmpty) return;
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      try {
        await user.delete();
      } catch (e) {
        debugPrint('Firebase delete falhou, fazendo signOut: $e');
        await FirebaseAuth.instance.signOut();
      }
    } catch (e) {
      debugPrint('Firebase deleteAnonymousAccount: $e');
    }
  }
}
