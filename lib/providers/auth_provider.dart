import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  User? _user;
  bool _isLoading = true;
  bool _needsProfileSetup = false;
  bool _signingInWithGoogle = false;

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;
  bool get needsProfileSetup => _needsProfileSetup;

  AuthProvider() {
    _authService.authStateChanges.listen((User? user) {
      _user = user;
      // Google girişi sürerken UI'ı güncelleme — needsProfileSetup
      // belirlenmeden önce MainScreen render edilip widget hataları çıkmasın.
      if (!_signingInWithGoogle) {
        _isLoading = false;
        notifyListeners();
      }
    });
  }

  Future<void> signInWithEmail(String email, String password) async {
    await _authService.signInWithEmail(email, password);
  }

  Future<void> registerWithEmail(String email, String password) async {
    await _authService.registerWithEmail(email, password);
    _needsProfileSetup = true;
    notifyListeners();
  }

  Future<void> signInWithGoogle() async {
    _signingInWithGoogle = true;
    try {
      final cred = await _authService.signInWithGoogle();
      if (cred?.additionalUserInfo?.isNewUser == true) {
        _needsProfileSetup = true;
      }
    } finally {
      _signingInWithGoogle = false;
      _isLoading = false;
      notifyListeners();
    }
  }

  void completeProfileSetup() {
    if (_needsProfileSetup) {
      _needsProfileSetup = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    _needsProfileSetup = false;
    await _authService.signOut();
  }
}
