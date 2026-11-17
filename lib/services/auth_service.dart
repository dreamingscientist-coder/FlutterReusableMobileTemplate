import 'dart:io' show Platform;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../config/app_config.dart';

class AuthService extends ChangeNotifier {
  AuthService._();
  static final AuthService instance = AuthService._();

  FirebaseAuth? _auth;
  bool _initialized = false;
  bool _busy = false;
  String? _message;

  bool get busy => _busy;
  String? get message => _message;
  User? get user => _auth?.currentUser;
  bool get isSignedIn => user != null;

  Future<void> init() async {
    if (_initialized || !AppConfig.signInEnabled) return;
    _initialized = true;
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
      _auth = FirebaseAuth.instance;
      _auth!.authStateChanges().listen((_) => notifyListeners());
    } catch (e) {
      debugPrint('Firebase init failed: $e');
      _message = 'Sign in is not configured yet.';
      notifyListeners();
    }
  }

  Future<void> signInWithGoogle() async {
    if (!AppConfig.googleSignInEnabled || _auth == null || _busy) return;
    _setBusy(true);
    try {
      final account = await GoogleSignIn().signIn();
      if (account == null) return _setBusy(false);
      final googleAuth = await account.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await _auth!.signInWithCredential(credential);
      _setBusy(false, message: 'Account linked.');
    } catch (e) {
      debugPrint('Google sign in failed: $e');
      _setBusy(false, message: 'Could not sign in with Google.');
    }
  }

  Future<void> signInWithApple() async {
    if (!AppConfig.appleSignInEnabled ||
        _auth == null ||
        _busy ||
        !Platform.isIOS) {
      return;
    }
    _setBusy(true);
    try {
      final apple = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      final credential = OAuthProvider('apple.com').credential(
        idToken: apple.identityToken,
        accessToken: apple.authorizationCode,
      );
      await _auth!.signInWithCredential(credential);
      _setBusy(false, message: 'Account linked.');
    } catch (e) {
      debugPrint('Apple sign in failed: $e');
      _setBusy(false, message: 'Could not sign in with Apple.');
    }
  }

  Future<void> signOut() async {
    await _auth?.signOut();
    await GoogleSignIn().signOut();
  }

  void _setBusy(bool value, {String? message}) {
    _busy = value;
    _message = message;
    notifyListeners();
  }
}
