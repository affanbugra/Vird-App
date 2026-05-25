import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserProvider extends ChangeNotifier {
  bool _isDeveloper = false;
  bool _isPro = false;
  bool _isHafiz = false;
  List<String> _teamIds = const [];
  List<String> _adminTeamIds = const [];
  List<String> _pendingTeamIds = const [];
  // 'hanim' veya 'bey' — kayıt sırasında seçilir
  String? _cinsiyet;
  String? _username;
  bool _userDataLoaded = false;
  bool _suppressMandatorySetup = false;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;

  bool get isDeveloper => _isDeveloper;
  bool get isPro => _isPro;
  bool get isHafiz => _isHafiz;
  List<String> get teamIds => _teamIds;
  List<String> get adminTeamIds => _adminTeamIds;
  List<String> get pendingTeamIds => _pendingTeamIds;
  String? get cinsiyet => _cinsiyet;
  String? get username => _username;
  bool get userDataLoaded => _userDataLoaded;

  /// Hesap silme sırasında Firestore tetiklemesini engelle
  void suppressSetup() {
    _suppressMandatorySetup = true;
    notifyListeners();
  }

  /// Cinsiyet veya kullanıcı adı eksikse zorunlu kurulum sheet'i göster
  bool get needsMandatorySetup =>
      !_suppressMandatorySetup &&
      _userDataLoaded &&
      ((_cinsiyet == null || _cinsiyet!.isEmpty) ||
          (_username == null || _username!.isEmpty));

  // Sadece üye olduğu (kurmadığı) ekip sayısı — join limiti için
  int get joinedTeamCount => _teamIds.length - _adminTeamIds.length;

  bool isMemberOf(String teamId) => _teamIds.contains(teamId);
  bool isAdminOf(String teamId) => _adminTeamIds.contains(teamId);

  String get hitap => _cinsiyet == 'hanim' ? 'Hanımefendi' : 'Beyefendi';

  void listenToUser(String? uid) {
    _sub?.cancel();
    _userDataLoaded = false;
    if (uid == null) {
      _isDeveloper = false;
      _isPro = false;
      _isHafiz = false;
      _teamIds = const [];
      _adminTeamIds = const [];
      _pendingTeamIds = const [];
      _cinsiyet = null;
      _username = null;
      notifyListeners();
      return;
    }
    _sub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen((snap) {
      final data = snap.data();
      _isDeveloper = (data?['isDeveloper'] as bool?) ?? false;
      _isPro = (data?['isPro'] as bool?) ?? false;
      _isHafiz = (data?['isHafiz'] as bool?) ?? false;
      _cinsiyet = data?['cinsiyet'] as String?;
      _username = data?['username'] as String?;
      _teamIds = ((data?['teamIds']) as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [];
      _adminTeamIds = ((data?['adminTeamIds']) as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [];
      _pendingTeamIds = ((data?['pendingTeamIds']) as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [];
      _userDataLoaded = true;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

