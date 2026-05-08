import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserProvider extends ChangeNotifier {
  bool _isDeveloper = false;
  bool _isPro = false;
  String? _teamId;
  List<String> _developerTeamIds = const [];
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;

  bool get isDeveloper => _isDeveloper;
  bool get isPro => _isPro;
  String? get teamId => _teamId;
  List<String> get developerTeamIds => _developerTeamIds;

  void listenToUser(String? uid) {
    _sub?.cancel();
    if (uid == null) {
      _isDeveloper = false;
      _isPro = false;
      _teamId = null;
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
      _teamId = data?['teamId'] as String?;
      _developerTeamIds = ((data?['developerTeamIds']) as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [];
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
