import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../app_colors.dart';
import '../config/team_limits.dart';
import '../models/team_model.dart';
import '../widgets/duolingo_button.dart';
import 'kullanici_profil_screen.dart';
import 'ekip_gecmis_screen.dart';
import '../utils/name_utils.dart';
import '../utils/seri_calculator.dart';

// ─── Veri modeli ───────────────────────────────────────────────────────────────

class _MemberEntry {
  final String uid;
  final String name;
  final String username;
  final String? avatarSeed;
  final int periodHasanat;
  final int rawSeri;
  final Timestamp? lastLogTs;
  final bool isHafiz;

  const _MemberEntry({
    required this.uid,
    required this.name,
    required this.username,
    required this.avatarSeed,
    required this.periodHasanat,
    required this.rawSeri,
    this.lastLogTs,
    this.isHafiz = false,
  });
}

// ─── Ana ekran ─────────────────────────────────────────────────────────────────

enum _LeaderboardPeriod { daily, weekly }

class EkipProfilScreen extends StatefulWidget {
  final String teamId;
  final String currentUid;

  const EkipProfilScreen({
    super.key,
    required this.teamId,
    required this.currentUid,
  });

  @override
  State<EkipProfilScreen> createState() => _EkipProfilScreenState();
}

class _EkipProfilScreenState extends State<EkipProfilScreen> {
  final _periodMode = _LeaderboardPeriod.weekly;

  List<_MemberEntry> _leaderboard = [];
  bool _leaderboardLoading = true;
  bool _isPending = false;
  bool _isJoinLoading = false;
  Timer? _countdownTimer;
  Duration _untilEnd = Duration.zero;
  StreamSubscription<DocumentSnapshot>? _pendingSub;

  static final _archivedThisSession = <String>{};

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
    _startCountdown();
    _archivePastPeriodsIfNeeded();
    // Bekleyen istek durumunu stream ile takip et — ekran açıkken güncel kalsın
    _pendingSub = FirebaseFirestore.instance
        .collection('teams')
        .doc(widget.teamId)
        .collection('requests')
        .doc(widget.currentUid)
        .snapshots()
        .listen((snap) {
      if (mounted) setState(() => _isPending = snap.exists);
    });
  }

  @override
  void dispose() {
    _pendingSub?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  DateTime _getPeriodEnd() {
    final now = DateTime.now();
    if (_periodMode == _LeaderboardPeriod.daily) {
      return DateTime(now.year, now.month, now.day + 1);
    } else {
      // Haftalık (Pazar gecesi biten)
      final daysToSunday = DateTime.sunday - now.weekday;
      // Eğer Pazar ise daysToSunday = 0, bu yüzden bir sonraki pazartesiye geçmemiz için day + daysToSunday + 1 (yani +1 gün gece yarısı)
      return DateTime(now.year, now.month, now.day + daysToSunday + 1);
    }
  }

  DateTime _getPeriodStart() {
    final now = DateTime.now();
    if (_periodMode == _LeaderboardPeriod.daily) {
      return DateTime(now.year, now.month, now.day);
    } else {
      // Haftalık (Pazartesi başı)
      final daysSinceMonday = now.weekday - DateTime.monday;
      return DateTime(now.year, now.month, now.day - daysSinceMonday);
    }
  }

  void _startCountdown() {
    _tick();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final now = DateTime.now();
    final periodEnd = _getPeriodEnd();
    if (mounted) setState(() => _untilEnd = periodEnd.difference(now));
  }

  Future<void> _archivePastPeriodsIfNeeded() async {
    if (!mounted) return;
    if (_periodMode != _LeaderboardPeriod.weekly) return;
    // Bug 9: Bu oturumda bu ekip için zaten çalıştıysa atla
    if (_archivedThisSession.contains(widget.teamId)) return;
    _archivedThisSession.add(widget.teamId);

    try {
      final db = FirebaseFirestore.instance;
      
      // Takımın kurulma tarihini al
      final teamDoc = await db.collection('teams').doc(widget.teamId).get();
      final teamData = teamDoc.data();
      if (teamData == null) return;
      final createdAtTs = teamData['createdAt'] as Timestamp?;
      if (createdAtTs == null) return;
      final createdDate = createdAtTs.toDate();
      final teamCreatedAtDay = DateTime(createdDate.year, createdDate.month, createdDate.day);

      final historyRef = db.collection('teams').doc(widget.teamId).collection('history');
      
      // Önce hatalı oluşmuş eski arşivleri temizle (Kuruluş tarihinden önce biten haftaları VEYA eski günlük arşivleri)
      final oldDocs = await historyRef.get();
      for (final doc in oldDocs.docs) {
        final parts = doc.id.split('-');
        if (parts.length == 3) {
          final docDate = DateTime(int.tryParse(parts[0]) ?? 1970, int.tryParse(parts[1]) ?? 1, int.tryParse(parts[2]) ?? 1);
          final docEndDate = docDate.add(const Duration(days: 6));
          // Eğer arşiv Pazartesi gününe ait değilse, bu eski bir 'günlük' arşivdir, silinmelidir.
          // Veya haftanın bitiş tarihi takımın kurulduğu günden sonra değilse (Örn Pazar günü kurulduysa o hafta silinmelidir)
          if (docDate.weekday != DateTime.monday || !docEndDate.isAfter(teamCreatedAtDay)) {
            await doc.reference.delete();
          }
        }
      }

      final membersSnap = await db.collection('users').where('teamIds', arrayContains: widget.teamId).get();

      final now = DateTime.now();
      final currentDaysSinceMonday = now.weekday - DateTime.monday;
      final currentWeekStart = DateTime(now.year, now.month, now.day - currentDaysSinceMonday);

      // Son 3 haftayı geriye dönük kontrol et
      for (int i = 1; i <= 3; i++) {
        final targetWeekStart = currentWeekStart.subtract(Duration(days: 7 * i));
        final targetWeekEnd = targetWeekStart.add(const Duration(days: 6));
        
        // Eğer kontrol edilen haftanın bitiş günü, takımın kurulduğu günden sonra değilse arşive alma
        if (!targetWeekEnd.isAfter(teamCreatedAtDay)) continue;

        final targetDayStr = "${targetWeekStart.year}-${targetWeekStart.month.toString().padLeft(2, '0')}-${targetWeekStart.day.toString().padLeft(2, '0')}";

        // Geçen hafta (i==1): arşiv varsa sil ve loglardan yeniden hesapla
        // Daha eski haftalar: bir kez arşivlendi mi tekrar hesaplanmaz
        final docSnap = await historyRef.doc(targetDayStr).get();
        if (docSnap.exists && i > 1) continue;
        if (docSnap.exists && i == 1) await historyRef.doc(targetDayStr).delete();

        final periodStart = targetWeekStart.isBefore(teamCreatedAtDay) ? teamCreatedAtDay : targetWeekStart;
        final periodEnd = targetWeekStart.add(const Duration(days: 7));

        final eligibleDocs = membersSnap.docs.where((memberDoc) {
          final joinedAtRaw = memberDoc.data()['teamJoinedAt'];
          DateTime? joinedAt;
          if (joinedAtRaw is Timestamp) {
            joinedAt = joinedAtRaw.toDate();
          } else if (joinedAtRaw is Map) {
            final ts = joinedAtRaw[widget.teamId];
            if (ts is Timestamp) joinedAt = ts.toDate();
          }
          return joinedAt == null || !joinedAt.isAfter(targetWeekEnd);
        }).toList();

        final entries = await Future.wait(eligibleDocs.map((memberDoc) async {
          final uid = memberDoc.id;
          final data = memberDoc.data();

          // Her zaman log sorgusundan hesapla — denormalize weeklyHasanat geçiş döneminde hatalı olabilir
          final logsSnap = await db.collection('users').doc(uid).collection('logs')
              .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(periodStart))
              .where('createdAt', isLessThan: Timestamp.fromDate(periodEnd))
              .get();
          int periodHasanat = 0;
          for (final log in logsSnap.docs) {
            final logType = log.data()['type'] as String?;
            if (logType != 'arapca' && logType != 'meal') continue;
            periodHasanat += ((log.data()['pagesRead'] as int? ?? 0) * 10);
          }

          return _MemberEntry(
            uid: uid,
            name: data['name'] as String? ?? 'İsimsiz',
            username: data['username'] as String? ?? '',
            avatarSeed: data['avatarSeed'] as String?,
            periodHasanat: periodHasanat,
            rawSeri: (data['seri'] as int?) ?? 0,
            isHafiz: (data['isHafiz'] as bool?) ?? false,
          );
        }));

        entries.sort((a, b) => b.periodHasanat.compareTo(a.periodHasanat));

        await historyRef.doc(targetDayStr).set({
          'date': Timestamp.fromDate(targetWeekStart),
          'rankings': entries.map((e) => {
            'uid': e.uid,
            'name': e.name,
            'username': e.username,
            'avatarSeed': e.avatarSeed,
            'periodHasanat': e.periodHasanat,
            'isHafiz': e.isHafiz,
          }).toList(),
        });
      }
    } catch (e) {
      debugPrint('Arşivleme hatası: $e');
    }
  }

  Future<void> _loadLeaderboard() async {
    if (!mounted) return;
    setState(() => _leaderboardLoading = true);

    try {
      final weekStart = _getPeriodStart();
      final db = FirebaseFirestore.instance;

      final membersSnap = await db.collection('users').where('teamIds', arrayContains: widget.teamId).get();

      final entries = await Future.wait(membersSnap.docs.map((memberDoc) async {
        final uid = memberDoc.id;
        final data = memberDoc.data();
        final logsSnap = await db
            .collection('users')
            .doc(uid)
            .collection('logs')
            .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart))
            .get();
        int periodHasanat = 0;
        for (final log in logsSnap.docs) {
          final logType = log.data()['type'] as String?;
          if (logType != 'arapca' && logType != 'meal') continue;
          periodHasanat += ((log.data()['pagesRead'] as int? ?? 0) * 10);
        }
        return _MemberEntry(
          uid: uid,
          name: data['name'] as String? ?? 'İsimsiz',
          username: data['username'] as String? ?? '',
          avatarSeed: data['avatarSeed'] as String?,
          periodHasanat: periodHasanat,
          rawSeri: (data['seri'] as int?) ?? 0,
          lastLogTs: data['lastLogDate'] as Timestamp?,
          isHafiz: (data['isHafiz'] as bool?) ?? false,
        );
      }));
      entries.sort((a, b) => b.periodHasanat.compareTo(a.periodHasanat));

      if (mounted) {
        setState(() {
          _leaderboard = entries;
          _leaderboardLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _leaderboardLoading = false);
    }
  }

  // ── Üyelik aksiyonları ────────────────────────────────────────────────────────

  // isPrivate ve genderPolicy ekran build'inden geçirilir — fazla Firestore okuma önlenir
  Future<void> _sendJoinRequest({
    required bool isPrivate,
    required String genderPolicy,
    required String teamName,
    required String adminUid,
  }) async {
    if (_isJoinLoading) return;
    if (mounted) setState(() => _isJoinLoading = true);
    try {
      final db = FirebaseFirestore.instance;
      final userDoc = await db.collection('users').doc(widget.currentUid).get();
      final userData = userDoc.data() ?? {};
      final isDeveloper = (userData['isDeveloper'] as bool?) ?? false;
      final isPro = (userData['isPro'] as bool?) ?? false;
      final teamIds = ((userData['teamIds']) as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[];
      final adminTeamIds = ((userData['adminTeamIds']) as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[];

      // Zaten bu ekipte mi?
      if (teamIds.contains(widget.teamId)) return;

      // Join limiti kontrolü (developer hariç)
      if (!isDeveloper) {
        final joinedCount = teamIds.length - adminTeamIds.length;
        if (!TeamLimits.canJoin(
            isPro: isPro, isDev: false, joinedCount: joinedCount)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  TeamLimits.joinLimitMessage(isPro: isPro, isDev: false),
                  style: GoogleFonts.nunito()),
              backgroundColor: AppColors.errorRed,
            ));
          }
          return;
        }

        // Cinsiyet politikası kontrolü
        if (genderPolicy != 'all') {
          final cinsiyet = userData['cinsiyet'] as String? ?? '';
          if (genderPolicy == 'men' && cinsiyet == 'hanim') {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Bu ekip yalnızca erkek üyelere açık.',
                    style: GoogleFonts.nunito()),
                backgroundColor: AppColors.errorRed,
              ));
            }
            return;
          }
          if (genderPolicy == 'women' && cinsiyet == 'bey') {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Bu ekip yalnızca hanım üyelere açık.',
                    style: GoogleFonts.nunito()),
                backgroundColor: AppColors.errorRed,
              ));
            }
            return;
          }
        }
      }

      if (!isPrivate) {
        // Açık ekip → direkt katıl
        final batch = db.batch();
        batch.update(db.collection('users').doc(widget.currentUid), {
          'teamIds': FieldValue.arrayUnion([widget.teamId]),
          'teamJoinedAt.${widget.teamId}': FieldValue.serverTimestamp(),
        });
        batch.update(db.collection('teams').doc(widget.teamId), {
          'memberCount': FieldValue.increment(1),
        });
        await batch.commit();
        _loadLeaderboard();
      } else {
        // Gizli ekip (developer dahil herkes) → istek oluştur
        await db
            .collection('teams')
            .doc(widget.teamId)
            .collection('requests')
            .doc(widget.currentUid)
            .set({
          'name': userData['name'] as String? ?? 'İsimsiz',
          'username': userData['username'] as String? ?? '',
          'avatarSeed': userData['avatarSeed'] as String?,
          'city': userData['city'] as String? ?? '',
          'university': userData['university'] as String? ?? '',
          'cinsiyet': userData['cinsiyet'] as String? ?? '',
          'requestedAt': FieldValue.serverTimestamp(),
        });

        // pendingTeamIds'e ekle
        await db.collection('users').doc(widget.currentUid).update({
          'pendingTeamIds': FieldValue.arrayUnion([widget.teamId]),
        });

        // Lider'e bildirim gönder
        if (adminUid.isNotEmpty) {
          final requesterName = userData['name'] as String? ?? 'Biri';
          await db
              .collection('users')
              .doc(adminUid)
              .collection('notifications')
              .add({
            'type': 'join_request',
            'title': 'Yeni katılım isteği',
            'body': '$requesterName "$teamName" ekibine katılmak istiyor.',
            'teamId': widget.teamId,
            'requesterUid': widget.currentUid,
            'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
        // _isPending stream üzerinden otomatik güncellenir
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Hata: $e', style: GoogleFonts.nunito()),
          backgroundColor: AppColors.errorRed,
        ));
      }
    } finally {
      if (mounted) setState(() => _isJoinLoading = false);
    }
  }

  Future<void> _cancelRequest() async {
    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();
      batch.delete(
        db.collection('teams').doc(widget.teamId).collection('requests').doc(widget.currentUid),
      );
      batch.update(db.collection('users').doc(widget.currentUid), {
        'pendingTeamIds': FieldValue.arrayRemove([widget.teamId]),
      });
      await batch.commit();
      if (mounted) setState(() => _isPending = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Hata: $e', style: GoogleFonts.nunito()),
          backgroundColor: AppColors.errorRed,
        ));
      }
    }
  }

  Future<void> _leaveTeam() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Ekipten Ayrıl',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
        content: Text('Ekipten ayrılmak istediğine emin misin?',
            style: GoogleFonts.nunito()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('İptal',
                style: GoogleFonts.nunito(color: AppColors.textMid)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Ayrıl',
                style: GoogleFonts.nunito(
                    color: AppColors.errorRed, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final db = FirebaseFirestore.instance;
    final batch = db.batch();
    batch.update(db.collection('users').doc(widget.currentUid), {
      'teamIds': FieldValue.arrayRemove([widget.teamId]),
    });
    batch.update(db.collection('teams').doc(widget.teamId), {
      'memberCount': FieldValue.increment(-1),
    });
    await batch.commit();
    _loadLeaderboard();
  }

  Future<bool> _kickMember(String memberUid) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Üyeyi Çıkar',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
        content: Text('Bu üyeyi ekipten çıkarmak istediğine emin misin?',
            style: GoogleFonts.nunito()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('İptal',
                style: GoogleFonts.nunito(color: AppColors.textMid)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Çıkar',
                style: GoogleFonts.nunito(
                    color: AppColors.errorRed, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true) return false;

    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();
      batch.update(db.collection('users').doc(memberUid), {
        'teamIds': FieldValue.arrayRemove([widget.teamId]),
      });
      batch.update(db.collection('teams').doc(widget.teamId), {
        'memberCount': FieldValue.increment(-1),
      });
      await batch.commit();
      _loadLeaderboard();
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Hata: $e', style: GoogleFonts.nunito()),
          backgroundColor: AppColors.errorRed,
        ));
      }
      return false;
    }
  }

  // ── Lider aksiyonları ─────────────────────────────────────────────────────────

  Future<void> _approveRequest(String requesterUid) async {
    try {
      final db = FirebaseFirestore.instance;

      // Race condition koruması: kullanıcı zaten üye veya limiti dolmuş olabilir
      final requesterDoc = await db.collection('users').doc(requesterUid).get();
      final requesterData = requesterDoc.data() ?? {};
      final reqTeamIds = ((requesterData['teamIds']) as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[];
      final reqAdminTeamIds = ((requesterData['adminTeamIds']) as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[];
      final isPro = (requesterData['isPro'] as bool?) ?? false;
      final isDev = (requesterData['isDeveloper'] as bool?) ?? false;

      // Zaten üye mi?
      if (reqTeamIds.contains(widget.teamId)) {
        await db.collection('teams').doc(widget.teamId)
            .collection('requests').doc(requesterUid).delete();
        return;
      }

      // Limit aşıldı mı?
      final joinedCount = reqTeamIds.length - reqAdminTeamIds.length;
      if (!isDev && !TeamLimits.canJoin(isPro: isPro, isDev: false, joinedCount: joinedCount)) {
        await db.collection('teams').doc(widget.teamId)
            .collection('requests').doc(requesterUid).delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Kullanıcının ekip limiti doldu, istek silindi.', style: GoogleFonts.nunito()),
            backgroundColor: AppColors.errorRed,
          ));
        }
        return;
      }

      final batch = db.batch();
      batch.delete(db.collection('teams').doc(widget.teamId)
          .collection('requests').doc(requesterUid));
      batch.update(db.collection('users').doc(requesterUid), {
        'teamIds': FieldValue.arrayUnion([widget.teamId]),
        'pendingTeamIds': FieldValue.arrayRemove([widget.teamId]),
        'teamJoinedAt.${widget.teamId}': FieldValue.serverTimestamp(),
      });
      batch.update(db.collection('teams').doc(widget.teamId), {
        'memberCount': FieldValue.increment(1),
      });
      await batch.commit();

      // Kullanıcıya kabul bildirimi
      final teamDoc = await db.collection('teams').doc(widget.teamId).get();
      final teamName = (teamDoc.data()?['name'] as String?) ?? 'Ekip';
      await db.collection('users').doc(requesterUid).collection('notifications').add({
        'type': 'join_approved',
        'title': 'İsteğin kabul edildi!',
        'body': '$teamName ekibine katıldın.',
        'teamId': widget.teamId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _loadLeaderboard();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Hata: $e', style: GoogleFonts.nunito()),
          backgroundColor: AppColors.errorRed,
        ));
      }
    }
  }

  Future<void> _rejectRequest(String requesterUid) async {
    try {
      final db = FirebaseFirestore.instance;

      final batch = db.batch();
      // İsteği sil
      batch.delete(
        db.collection('teams').doc(widget.teamId).collection('requests').doc(requesterUid),
      );
      // Kullanıcının pendingTeamIds'inden çıkar
      batch.update(db.collection('users').doc(requesterUid), {
        'pendingTeamIds': FieldValue.arrayRemove([widget.teamId]),
      });
      await batch.commit();

      // Kullanıcıya ret bildirimi
      final teamDoc = await db.collection('teams').doc(widget.teamId).get();
      final teamName = (teamDoc.data()?['name'] as String?) ?? 'Ekip';
      await db.collection('users').doc(requesterUid).collection('notifications').add({
        'type': 'join_rejected',
        'title': 'İsteğin reddedildi',
        'body': '$teamName ekibine katılma isteğin onaylanmadı.',
        'teamId': widget.teamId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Hata: $e', style: GoogleFonts.nunito()),
          backgroundColor: AppColors.errorRed,
        ));
      }
    }
  }

  Future<void> _deleteTeam(BuildContext context) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Grubu Sil', style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
        content: Text(
          'Bu grubu kalıcı olarak silmek istediğine emin misin? Tüm üyeler gruptan çıkarılacak.',
          style: GoogleFonts.nunito(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('İptal', style: GoogleFonts.nunito()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Sil', style: GoogleFonts.nunito(color: AppColors.errorRed, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final db = FirebaseFirestore.instance;
      final membersSnap = await db.collection('users')
          .where('teamIds', arrayContains: widget.teamId)
          .get();

      final batch = db.batch();
      for (final doc in membersSnap.docs) {
        batch.update(doc.reference, {
          'teamIds': FieldValue.arrayRemove([widget.teamId]),
          if (doc.id == widget.currentUid)
            'adminTeamIds': FieldValue.arrayRemove([widget.teamId]),
        });
      }

      final requestsSnap = await db.collection('teams')
          .doc(widget.teamId)
          .collection('requests')
          .get();
      for (final doc in requestsSnap.docs) {
        batch.delete(doc.reference);
        batch.update(db.collection('users').doc(doc.id), {
          'pendingTeamIds': FieldValue.arrayRemove([widget.teamId]),
        });
      }

      final historySnap = await db.collection('teams')
          .doc(widget.teamId)
          .collection('history')
          .get();
      for (final doc in historySnap.docs) {
        batch.delete(doc.reference);
      }

      batch.delete(db.collection('teams').doc(widget.teamId));
      await batch.commit();

      navigator.pop();
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('Hata: $e', style: GoogleFonts.nunito()),
        backgroundColor: AppColors.errorRed,
      ));
    }
  }

  void _showTeamSettingsSheet(BuildContext context, TeamModel team) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TeamSettingsSheet(team: team),
    );
  }

  void _showManageMembersSheet(BuildContext context, String leaderUid) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ManageMembersSheet(
        members: _leaderboard,
        leaderUid: leaderUid,
        onKick: _kickMember,
      ),
    );
  }

  void _showEditSheet(BuildContext context, TeamModel team, String field) {
    final current =
        field == 'description' ? team.description : team.penaltyNote;
    final label = field == 'description' ? 'Açıklama' : 'Ceza Notu';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _EditFieldSheet(
        teamId: widget.teamId,
        field: field,
        label: label,
        current: current,
      ),
    );
  }

  // ── Üyelik widget'ı ──────────────────────────────────────────────────────────

  Widget _buildMembershipWidget({
    required bool isAdmin,
    required bool isMember,
    required bool isPrivate,
    required String genderPolicy,
    required String teamName,
    required String adminUid,
  }) {
    if (isAdmin) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.tealLight,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.teal.withValues(alpha: 0.4)),
        ),
        child: Text(
          'Lider',
          style: GoogleFonts.nunito(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.teal,
          ),
        ),
      );
    }

    if (isMember) {
      return OutlinedButton(
        onPressed: _leaveTeam,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.borderGrey),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(
          'Ayrıl',
          style: GoogleFonts.nunito(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textMid,
          ),
        ),
      );
    }

    if (_isPending) {
      return GestureDetector(
        onTap: _cancelRequest,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8E1),
            border: Border.all(color: const Color(0xFFFFE082)),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Beklemede',
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFF59E0B),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.close, size: 14, color: Color(0xFFF59E0B)),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 36,
      child: DuolingoButton(
        color: AppColors.teal,
        bottomColor: AppColors.tealDark,
        height: 36,
        isLoading: _isJoinLoading,
        onPressed: _isJoinLoading
            ? null
            : () => _sendJoinRequest(
                  isPrivate: isPrivate,
                  genderPolicy: genderPolicy,
                  teamName: teamName,
                  adminUid: adminUid,
                ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            isPrivate ? 'İstek Gönder' : 'Katıl',
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('teams')
            .doc(widget.teamId)
            .snapshots(),
        builder: (context, teamSnap) {
          if (!teamSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!teamSnap.data!.exists) {
            return const Center(child: Text('Ekip bulunamadı'));
          }

          final team = TeamModel.fromFirestore(teamSnap.data!);
          final isAdmin = team.adminUid == widget.currentUid;

          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(widget.currentUid)
                .snapshots(),
            builder: (context, userSnap) {
              if (userSnap.connectionState == ConnectionState.waiting &&
                  !userSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final userData =
                  userSnap.data?.data() as Map<String, dynamic>?;
              final userTeamIds =
                  ((userData?['teamIds']) as List?)
                      ?.map((e) => e.toString())
                      .toList() ??
                  const <String>[];
              final isMember = userTeamIds.contains(widget.teamId);

              return CustomScrollView(
                slivers: [
                  // ── Başlık ──────────────────────────────────────────────
                  SliverAppBar(
                    pinned: true,
                    expandedHeight: 140,
                    backgroundColor: AppColors.teal,
                    foregroundColor: Colors.white,
                    actions: [
                      if (isAdmin || isMember)
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, color: Colors.white),
                          onSelected: (v) {
                            if (v == 'deleteTeam') {
                              _deleteTeam(context);
                            } else if (v == 'history') {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => EkipGecmisScreen(teamId: widget.teamId, teamName: team.name, isAdmin: isAdmin)));
                            } else if (v == 'teamSettings') {
                              _showTeamSettingsSheet(context, team);
                            } else if (v == 'manageMembers') {
                              _showManageMembersSheet(context, team.adminUid);
                            } else {
                              _showEditSheet(context, team, v);
                            }
                          },
                          itemBuilder: (_) => [
                            if (isAdmin || !isAdmin) ...[
                              PopupMenuItem(
                                value: 'history',
                                child: Row(
                                  children: [
                                    const Icon(Icons.history, color: AppColors.teal, size: 20),
                                    const SizedBox(width: 8),
                                    Text('Geçmiş Sıralamalar', style: GoogleFonts.nunito(fontWeight: FontWeight.w700, color: AppColors.teal)),
                                  ],
                                ),
                              ),
                              if (isAdmin) const PopupMenuDivider(),
                            ],
                            if (isAdmin) ...[
                              PopupMenuItem(
                                value: 'teamSettings',
                                child: Row(
                                  children: [
                                    const Icon(Icons.tune_outlined, color: AppColors.textDark, size: 20),
                                    const SizedBox(width: 8),
                                    Text('Takım Ayarları', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'manageMembers',
                                child: Row(
                                  children: [
                                    const Icon(Icons.manage_accounts_outlined, color: AppColors.textDark, size: 20),
                                    const SizedBox(width: 8),
                                    Text('Üyeleri Yönet', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'description',
                                child: Text('Açıklamayı Düzenle',
                                    style: GoogleFonts.nunito()),
                              ),
                              PopupMenuItem(
                                value: 'penaltyNote',
                                child: Text('Ceza Notunu Düzenle',
                                    style: GoogleFonts.nunito()),
                              ),
                              const PopupMenuDivider(),
                              PopupMenuItem(
                                value: 'deleteTeam',
                                child: Text('Grubu Sil',
                                    style: GoogleFonts.nunito(
                                        color: AppColors.errorRed,
                                        fontWeight: FontWeight.w700)),
                              ),
                            ],
                          ],
                        ),
                    ],
                    flexibleSpace: FlexibleSpaceBar(
                      centerTitle: false,
                      titlePadding:
                          const EdgeInsets.fromLTRB(56, 0, 48, 16),
                      title: Text(
                        team.name,
                        style: GoogleFonts.nunito(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      background: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF2A7F8C), Color(0xFF1F6370)],
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.shield,
                            size: 56,
                            color: Colors.white.withValues(alpha: 0.15),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ── İçerik ──────────────────────────────────────────────
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        // Üye sayısı + üyelik widget'ı
                        Row(
                          children: [
                            const Icon(Icons.people_outline,
                                size: 15, color: AppColors.textMid),
                            const SizedBox(width: 4),
                            Text(
                              '${team.memberCount} üye',
                              style: GoogleFonts.nunito(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textMid,
                              ),
                            ),
                            const Spacer(),
                            _buildMembershipWidget(
                              isAdmin: isAdmin,
                              isMember: isMember,
                              isPrivate: team.isPrivate,
                              genderPolicy: team.genderPolicy,
                              teamName: team.name,
                              adminUid: team.adminUid,
                            ),
                          ],
                        ),

                        // ── Admin: davet kodu kartı ──────────────────────
                        if (isAdmin && team.inviteCode.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _InviteCodeCard(inviteCode: team.inviteCode),
                        ],

                        // ── Admin: bekleyen istekler ─────────────────────
                        if (isAdmin)
                          StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('teams')
                                .doc(widget.teamId)
                                .collection('requests')
                                .snapshots(),
                            builder: (ctx, reqSnap) {
                              if (reqSnap.hasError) return const SizedBox.shrink();
                              final docs = reqSnap.data?.docs ?? [];
                              if (docs.isEmpty) return const SizedBox.shrink();
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 16),
                                  Text(
                                    'Bekleyen İstekler (${docs.length})',
                                    style: GoogleFonts.nunito(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ...docs.map((doc) {
                                    final data = doc.data() as Map<String, dynamic>;
                                    final requesterUid = doc.id;
                                    return _RequestRow(
                                      name: data['name'] as String? ?? 'İsimsiz',
                                      username: data['username'] as String? ?? '',
                                      avatarSeed: data['avatarSeed'] as String?,
                                      city: data['city'] as String? ?? '',
                                      university: data['university'] as String? ?? '',
                                      cinsiyet: data['cinsiyet'] as String? ?? '',
                                      requestedAt: data['requestedAt'] as Timestamp?,
                                      onApprove: () => _approveRequest(requesterUid),
                                      onReject: () => _rejectRequest(requesterUid),
                                    );
                                  }),
                                ],
                              );
                            },
                          ),

                        // Açıklama
                        if (team.description.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _InfoCard(
                            icon: Icons.info_outline,
                            text: team.description,
                          ),
                        ],

                        // Ceza notu
                        if (team.penaltyNote.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _PenaltyCard(note: team.penaltyNote),
                        ],

                        const SizedBox(height: 20),

                        // Liderboard
                        _LeaderboardSection(
                          leaderboard: _leaderboard,
                          loading: _leaderboardLoading,
                          untilMidnight: _untilEnd,
                          currentUid: widget.currentUid,
                          leaderUid: team.adminUid,
                          onRefresh: _loadLeaderboard,
                          onMemberTap: (uid) => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => KullaniciProfilScreen(uid: uid),
                            ),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

// ─── Davet Kodu Kartı (admin-only) ────────────────────────────────────────────

class _InviteCodeCard extends StatelessWidget {
  final String inviteCode;
  const _InviteCodeCard({required this.inviteCode});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.tealLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.teal.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.key_outlined, size: 18, color: AppColors.teal),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Davet Kodu',
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.teal,
                    letterSpacing: 0.3,
                  ),
                ),
                Text(
                  inviteCode,
                  style: GoogleFonts.nunito(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.teal,
                    letterSpacing: 6,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: inviteCode));
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Kod kopyalandı: $inviteCode',
                    style: GoogleFonts.nunito()),
                backgroundColor: AppColors.teal,
                duration: const Duration(seconds: 2),
              ));
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.teal.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child:
                  const Icon(Icons.copy_outlined, size: 18, color: AppColors.teal),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Bekleyen İstek Satırı ────────────────────────────────────────────────────

class _RequestRow extends StatelessWidget {
  final String name;
  final String username;
  final String? avatarSeed;
  final String city;
  final String university;
  final String cinsiyet;
  final Timestamp? requestedAt;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _RequestRow({
    required this.name,
    required this.username,
    required this.avatarSeed,
    required this.city,
    required this.university,
    required this.cinsiyet,
    required this.requestedAt,
    required this.onApprove,
    required this.onReject,
  });

  String _timeAgo() {
    if (requestedAt == null) return '';
    final diff = DateTime.now().difference(requestedAt!.toDate());
    if (diff.inMinutes < 1) return 'Az önce';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
    if (diff.inHours < 24) return '${diff.inHours} sa önce';
    return '${diff.inDays} gün önce';
  }

  @override
  Widget build(BuildContext context) {
    final cinsiyetLabel = cinsiyet == 'hanim' ? 'Hanım' : cinsiyet == 'bey' ? 'Bey' : '';
    final detailParts = [
      if (city.isNotEmpty) city,
      if (university.isNotEmpty) university,
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.lightGrey,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.tealLight,
                backgroundImage: avatarSeed != null
                    ? NetworkImage(
                        'https://api.dicebear.com/7.x/micah/png?seed=$avatarSeed&backgroundColor=transparent',
                      )
                    : null,
                child: avatarSeed == null
                    ? Text(nameInitials(name),
                        style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.teal))
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(name,
                              style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                        ),
                        if (cinsiyetLabel.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: cinsiyet == 'hanim'
                                  ? const Color(0xFFFCE4EC)
                                  : const Color(0xFFE3F2FD),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(cinsiyetLabel,
                                style: GoogleFonts.nunito(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: cinsiyet == 'hanim' ? const Color(0xFFE91E63) : const Color(0xFF1976D2),
                                )),
                          ),
                      ],
                    ),
                    if (username.isNotEmpty)
                      Text('@$username', style: GoogleFonts.nunito(fontSize: 11, color: AppColors.textLight)),
                  ],
                ),
              ),
            ],
          ),
          if (detailParts.isNotEmpty || requestedAt != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                if (detailParts.isNotEmpty)
                  Expanded(
                    child: Text(detailParts.join(' · '),
                        style: GoogleFonts.nunito(fontSize: 11, color: AppColors.textMid),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                Text(_timeAgo(), style: GoogleFonts.nunito(fontSize: 11, color: AppColors.textLight)),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: onReject,
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text('Reddet',
                    style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.errorRed)),
              ),
              const SizedBox(width: 6),
              SizedBox(
                height: 32,
                child: DuolingoButton(
                  color: AppColors.teal,
                  bottomColor: AppColors.tealDark,
                  height: 32,
                  onPressed: onApprove,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('Onayla',
                        style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Bilgi Kartı ───────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoCard({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.lightGrey,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.textMid),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.nunito(
                fontSize: 13,
                color: AppColors.textMid,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Ceza Notu Kartı ───────────────────────────────────────────────────────────

class _PenaltyCard extends StatelessWidget {
  final String note;
  const _PenaltyCard({required this.note});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        border: Border.all(color: const Color(0xFFFFE082)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded,
              size: 16, color: Color(0xFFF59E0B)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ceza Notu',
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFF59E0B),
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  note,
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    color: const Color(0xFF92400E),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Liderboard Bölümü ─────────────────────────────────────────────────────────

enum _SortMode { puan, seri }
enum _HafizFilter { none, hafizOnly, nonHafiz }

class _LeaderboardSection extends StatefulWidget {
  final List<_MemberEntry> leaderboard;
  final bool loading;
  final Duration untilMidnight;
  final String currentUid;
  final String leaderUid;
  final VoidCallback onRefresh;
  final void Function(String uid) onMemberTap;

  const _LeaderboardSection({
    required this.leaderboard,
    required this.loading,
    required this.untilMidnight,
    required this.currentUid,
    required this.leaderUid,
    required this.onRefresh,
    required this.onMemberTap,
  });

  @override
  State<_LeaderboardSection> createState() => _LeaderboardSectionState();
}

class _LeaderboardSectionState extends State<_LeaderboardSection> {
  _SortMode _sortMode = _SortMode.puan;
  bool _showLow = false;
  _HafizFilter _hafizFilter = _HafizFilter.none;

  String _fmtDuration(Duration d) {
    if (d.inDays > 0) {
      final days = d.inDays;
      final h = (d.inHours % 24).toString().padLeft(2, '0');
      final m = (d.inMinutes % 60).toString().padLeft(2, '0');
      return '$days gün $h:$m';
    }
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  String _fmtHasanat(int n) {
    if (n == 0) return '0';
    final s = n.toString();
    if (s.length <= 3) return s;
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  List<_MemberEntry> get _sorted {
    final list = List<_MemberEntry>.from(widget.leaderboard);
    if (_sortMode == _SortMode.seri) {
      list.sort((a, b) {
        final aVal = seriDisplayState(a.rawSeri, a.lastLogTs).value;
        final bVal = seriDisplayState(b.rawSeri, b.lastLogTs).value;
        final cmp = bVal.compareTo(aVal);
        return cmp != 0 ? cmp : b.periodHasanat.compareTo(a.periodHasanat);
      });
    } else {
      list.sort((a, b) {
        final cmp = b.periodHasanat.compareTo(a.periodHasanat);
        final aVal = seriDisplayState(a.rawSeri, a.lastLogTs).value;
        final bVal = seriDisplayState(b.rawSeri, b.lastLogTs).value;
        return cmp != 0 ? cmp : bVal.compareTo(aVal);
      });
    }
    return list;
  }

  List<_MemberEntry> get _displayed {
    var s = _sorted;
    if (_hafizFilter == _HafizFilter.hafizOnly) {
      s = s.where((e) => e.isHafiz).toList();
    } else if (_hafizFilter == _HafizFilter.nonHafiz) {
      s = s.where((e) => !e.isHafiz).toList();
    }
    if (_showLow) return s.where((e) => e.periodHasanat < 100).toList();
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.leaderboard.length;
    final displayed = _displayed;
    final filtered = _hafizFilter != _HafizFilter.none || _showLow;
    final memberCount = widget.loading
        ? ''
        : filtered
            ? ' · ${displayed.length} / $total kişi'
            : ' · $total üye';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Haftalık Ekip Sıralaması$memberCount',
              style: GoogleFonts.nunito(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: widget.onRefresh,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.lightGrey,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.refresh,
                    size: 18, color: AppColors.textMid),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(Icons.access_time, size: 13, color: AppColors.textLight),
            const SizedBox(width: 4),
            Text(
              'Sıfırlanmaya ${_fmtDuration(widget.untilMidnight)} kaldı',
              style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textLight),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Sıralama filtresi
        Row(
          children: [
            _SortChip(
              label: 'Puan',
              selected: _sortMode == _SortMode.puan,
              onTap: () => setState(() => _sortMode = _SortMode.puan),
            ),
            const SizedBox(width: 8),
            _SortChip(
              label: '🔥 Seri',
              selected: _sortMode == _SortMode.seri,
              onTap: () => setState(() => _sortMode = _SortMode.seri),
            ),
            const SizedBox(width: 8),
            _SortChip(
              label: _hafizFilter == _HafizFilter.hafizOnly
                  ? '📖 Sadece Hafız'
                  : _hafizFilter == _HafizFilter.nonHafiz
                      ? '📖 Hafız Hariç'
                      : '📖 Hafız',
              selected: _hafizFilter != _HafizFilter.none,
              selectedColor: AppColors.emeraldGreen,
              onTap: () => setState(() {
                _hafizFilter = switch (_hafizFilter) {
                  _HafizFilter.none      => _HafizFilter.hafizOnly,
                  _HafizFilter.hafizOnly => _HafizFilter.nonHafiz,
                  _HafizFilter.nonHafiz  => _HafizFilter.none,
                };
              }),
            ),
            const Spacer(),
            _SortChip(
              label: '⚠️ <100 Puan',
              selected: _showLow,
              selectedColor: AppColors.errorRed,
              onTap: () => setState(() {
                _showLow = !_showLow;
                if (_showLow) _sortMode = _SortMode.puan;
              }),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (widget.loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          )
        else if (widget.leaderboard.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.lightGrey,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                'Henüz üye yok.',
                style: GoogleFonts.nunito(
                    fontSize: 13, color: AppColors.textLight),
              ),
            ),
          )
        else
          _buildList(),

        const SizedBox(height: 24),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              children: [
                Text(
                  '"Onlar, Allah\'a ve ahiret gününe inanırlar. İyiliği emrederler, kötülükten men ederler, hayır işlerinde birbirleriyle yarışırlar. İşte onlar salihlerdendir."',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(
                    fontSize: 12.5,
                    color: AppColors.textMid,
                    height: 1.6,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Âl-i İmrân, 114',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    color: AppColors.textLight,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildList() {
    final sorted = _displayed;
    final count = sorted.length;
    final showRedZone = !_showLow && count > 3;
    final redStartIdx = count - 3;

    return Column(
      children: List.generate(count, (i) {
        final entry = sorted[i];
        final isTop = !_showLow && i < 3;
        final isDeepRed = _showLow && entry.periodHasanat == 0;
        final isRed = isDeepRed ||
            entry.periodHasanat == 0 ||
            _showLow ||
            (!isTop && showRedZone && i >= redStartIdx);
        final isMe = entry.uid == widget.currentUid;

        return GestureDetector(
          onTap: () => widget.onMemberTap(entry.uid),
          child: _LeaderboardRow(
            rank: i + 1,
            entry: entry,
            isTop: isTop,
            isRed: isRed,
            isDeepRed: isDeepRed,
            isMe: isMe,
            isTeamLeader: entry.uid == widget.leaderUid,
            fmtHasanat: _fmtHasanat,
          ),
        );
      }),
    );
  }
}

class _SortChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? selectedColor;

  const _SortChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.selectedColor,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = selectedColor ?? AppColors.teal;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? activeColor : AppColors.lightGrey,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? activeColor : AppColors.borderGrey,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : AppColors.textMid,
          ),
        ),
      ),
    );
  }
}

// ─── Liderboard Satırı ─────────────────────────────────────────────────────────

class _LeaderboardRow extends StatelessWidget {
  final int rank;
  final _MemberEntry entry;
  final bool isTop;
  final bool isRed;
  final bool isDeepRed;
  final bool isMe;
  final bool isTeamLeader;
  final String Function(int) fmtHasanat;

  const _LeaderboardRow({
    required this.rank,
    required this.entry,
    required this.isTop,
    required this.isRed,
    this.isDeepRed = false,
    required this.isMe,
    this.isTeamLeader = false,
    required this.fmtHasanat,
  });

  String get _medal {
    switch (rank) {
      case 1:
        return '🥇';
      case 2:
        return '🥈';
      case 3:
        return '🥉';
      default:
        return '';
    }
  }

  Color get _bgColor {
    if (isDeepRed) return AppColors.errorRed.withValues(alpha: 0.48);
    if (isRed) return AppColors.errorBg;
    if (rank == 1) return AppColors.successBg;
    if (rank == 2) return AppColors.successBg.withValues(alpha: 0.6);
    if (rank == 3) return AppColors.successBg.withValues(alpha: 0.3);
    return AppColors.white;
  }

  Color get _borderColor {
    if (isMe) return AppColors.teal;
    if (isDeepRed) return AppColors.errorRed.withValues(alpha: 0.85);
    if (isRed) return AppColors.errorRed.withValues(alpha: 0.3);
    if (rank == 1) return AppColors.successGreen.withValues(alpha: 0.5);
    if (rank == 2) return AppColors.successGreen.withValues(alpha: 0.3);
    if (rank == 3) return AppColors.successGreen.withValues(alpha: 0.15);
    return AppColors.borderGrey;
  }

  double get _borderWidth => isMe ? 2.0 : 1.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _bgColor,
        border: Border.all(color: _borderColor, width: _borderWidth),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Sıra / madalya
          SizedBox(
            width: 32,
            child: isTop
                ? Text(
                    _medal,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 20),
                  )
                : Text(
                    '$rank',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isRed ? AppColors.errorRed : AppColors.textMid,
                    ),
                  ),
          ),
          const SizedBox(width: 8),
          // Avatar (hafız halkası)
          Container(
            padding: entry.isHafiz ? const EdgeInsets.all(2) : EdgeInsets.zero,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: entry.isHafiz
                  ? Border.all(color: AppColors.emeraldGreen, width: 2)
                  : null,
            ),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.tealLight,
              backgroundImage: entry.avatarSeed != null
                  ? NetworkImage(
                      'https://api.dicebear.com/7.x/micah/png?seed=${entry.avatarSeed}&backgroundColor=transparent',
                    )
                  : null,
              child: entry.avatarSeed == null
                  ? Text(
                      nameInitials(entry.name),
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.teal,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          // İsim
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.name,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 4),
                      Text(
                        '(sen)',
                        style: GoogleFonts.nunito(
                          fontSize: 11,
                          color: AppColors.teal,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (isTeamLeader) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.tealLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Ekip Lideri',
                          style: GoogleFonts.nunito(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.teal,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Row(
                  children: [
                    Builder(builder: (context) {
                      final ss = seriDisplayState(entry.rawSeri, entry.lastLogTs);
                      if (ss.value <= 0) return const SizedBox.shrink();
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(ss.atRisk ? '⚠️' : '🔥', style: const TextStyle(fontSize: 11)),
                          const SizedBox(width: 2),
                          Text(
                            '${ss.value} gün',
                            style: GoogleFonts.nunito(
                              fontSize: 11,
                              color: ss.atRisk ? AppColors.errorRed : AppColors.orange,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ],
            ),
          ),
          // Hasanat
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                fmtHasanat(entry.periodHasanat),
                style: GoogleFonts.nunito(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: entry.periodHasanat > 0
                      ? AppColors.gold
                      : AppColors.textLight,
                ),
              ),
              Text(
                'hasanat',
                style: GoogleFonts.nunito(
                  fontSize: 9,
                  color: AppColors.textLight,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Alan Düzenleme Sheet ──────────────────────────────────────────────────────

class _EditFieldSheet extends StatefulWidget {
  final String teamId;
  final String field;
  final String label;
  final String current;

  const _EditFieldSheet({
    required this.teamId,
    required this.field,
    required this.label,
    required this.current,
  });

  @override
  State<_EditFieldSheet> createState() => _EditFieldSheetState();
}

class _EditFieldSheetState extends State<_EditFieldSheet> {
  late TextEditingController _ctrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.current);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance
          .collection('teams')
          .doc(widget.teamId)
          .update({widget.field: _ctrl.text.trim()});
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.borderGrey,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            '${widget.label} Düzenle',
            style: GoogleFonts.nunito(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _ctrl,
            maxLines: 4,
            maxLength: 300,
            decoration: InputDecoration(
              labelText: widget.label,
              labelStyle: GoogleFonts.nunito(color: AppColors.textMid),
              counterText: '',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.teal, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: DuolingoButton(
              color: AppColors.teal,
              bottomColor: AppColors.tealDark,
              isLoading: _isLoading,
              onPressed: _isLoading ? null : _save,
              child: Text(
                'KAYDET',
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Üye Yönetimi Sheet ────────────────────────────────────────────────────────

class _ManageMembersSheet extends StatefulWidget {
  final List<_MemberEntry> members;
  final String leaderUid;
  final Future<bool> Function(String uid) onKick;

  const _ManageMembersSheet({
    required this.members,
    required this.leaderUid,
    required this.onKick,
  });

  @override
  State<_ManageMembersSheet> createState() => _ManageMembersSheetState();
}

class _ManageMembersSheetState extends State<_ManageMembersSheet> {
  String? _kickingUid;

  Future<void> _doKick(_MemberEntry member) async {
    if (_kickingUid != null) return;
    setState(() => _kickingUid = member.uid);
    final kicked = await widget.onKick(member.uid);
    if (!mounted) return;
    if (kicked) {
      Navigator.pop(context);
    } else {
      setState(() => _kickingUid = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final kickable =
        widget.members.where((m) => m.uid != widget.leaderUid).toList();

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, 32 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Üye Yönetimi',
                style: GoogleFonts.nunito(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          Text(
            'Ekipten çıkarmak istediğiniz üyeye dokunun.',
            style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textMid),
          ),
          const SizedBox(height: 16),
          if (kickable.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'Çıkarılabilecek başka üye yok.',
                  style: GoogleFonts.nunito(
                      fontSize: 13, color: AppColors.textLight),
                ),
              ),
            )
          else
            ...kickable.map((m) => _buildMemberRow(m)),
        ],
      ),
    );
  }

  Widget _buildMemberRow(_MemberEntry member) {
    final isKicking = _kickingUid == member.uid;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.lightGrey,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.tealLight,
            backgroundImage: member.avatarSeed != null
                ? NetworkImage(
                    'https://api.dicebear.com/7.x/micah/png?seed=${member.avatarSeed}&backgroundColor=transparent',
                  )
                : null,
            child: member.avatarSeed == null
                ? Text(
                    nameInitials(member.name),
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.teal,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.name,
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                if (member.username.isNotEmpty)
                  Text(
                    '@${member.username}',
                    style: GoogleFonts.nunito(
                        fontSize: 11, color: AppColors.textLight),
                  ),
              ],
            ),
          ),
          if (isKicking)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.errorRed),
            )
          else
            TextButton(
              onPressed: () => _doKick(member),
              style: TextButton.styleFrom(
                minimumSize: Size.zero,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Çıkar',
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.errorRed,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Takım Ayarları Sheet ─────────────────────────────────────────────────────

class _TeamSettingsSheet extends StatelessWidget {
  final TeamModel team;
  const _TeamSettingsSheet({required this.team});

  @override
  Widget build(BuildContext context) {
    final privacyLabel = team.isPrivate ? 'Sadece Davet' : 'Herkese Açık';
    final privacyIcon = team.isPrivate ? Icons.lock_outline : Icons.public_outlined;

    final genderLabel = switch (team.genderPolicy) {
      'men'   => 'Sadece Beyler',
      'women' => 'Sadece Hanımlar',
      _       => 'Herkese Açık',
    };
    final genderIcon = switch (team.genderPolicy) {
      'men'   => Icons.male_outlined,
      'women' => Icons.female_outlined,
      _       => Icons.groups_outlined,
    };

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(context).padding.bottom + 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(color: AppColors.borderGrey, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Takım Ayarları',
            style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark),
          ),
          const SizedBox(height: 4),
          Text(
            'Bu ayarlar ekip kurulurken belirlenir ve değiştirilemez.',
            style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textLight),
          ),
          const SizedBox(height: 20),
          _SettingRow(icon: privacyIcon, label: 'Görünürlük', value: privacyLabel),
          const SizedBox(height: 12),
          _SettingRow(icon: genderIcon, label: 'Katılım Politikası', value: genderLabel),
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _SettingRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.lightGrey,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(color: AppColors.tealLight, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 20, color: AppColors.teal),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(label, style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark)),
          ),
          Text(value, style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMid)),
        ],
      ),
    );
  }
}
