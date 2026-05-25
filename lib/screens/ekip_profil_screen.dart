import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../app_colors.dart';
import '../app_theme.dart';
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
  final String cinsiyet; // 'bey' | 'hanim' | ''

  const _MemberEntry({
    required this.uid,
    required this.name,
    required this.username,
    required this.avatarSeed,
    required this.periodHasanat,
    required this.rawSeri,
    this.lastLogTs,
    this.isHafiz = false,
    this.cinsiyet = '',
  });
}

// ─── Ana ekran ─────────────────────────────────────────────────────────────────

enum _LeaderboardPeriod { daily, weekly }

class EkipProfilScreen extends StatefulWidget {
  final String teamId;
  final String currentUid;
  final bool isAdmin;

  const EkipProfilScreen({
    super.key,
    required this.teamId,
    required this.currentUid,
    this.isAdmin = false,
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
  String _currentUserCinsiyet = '';

  static final _archivedThisSession = <String>{};

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
    _startCountdown();
    FirebaseFirestore.instance.collection('users').doc(widget.currentUid).get().then((doc) {
      if (mounted) setState(() => _currentUserCinsiyet = (doc.data()?['cinsiyet'] as String?) ?? '');
    });
    // Arşivleme sadece admin için — her ziyaretçinin tetiklemesi gereksiz yük oluşturur
    if (widget.isAdmin) _archivePastPeriodsIfNeeded();
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
          cinsiyet: data['cinsiyet'] as String? ?? '',
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

      // Cinsiyet politikası kontrolü — developer dahil herkes uymak zorunda
      if (genderPolicy != 'all') {
        final cinsiyet = userData['cinsiyet'] as String? ?? '';
        if (genderPolicy == 'men' && cinsiyet != 'bey') {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Bu ekip yalnızca erkek üyelere açık.', style: GoogleFonts.nunito()),
            backgroundColor: AppColors.errorRed,
          ));
          return;
        }
        if (genderPolicy == 'women' && cinsiyet != 'hanim') {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Bu ekip yalnızca hanım üyelere açık.', style: GoogleFonts.nunito()),
            backgroundColor: AppColors.errorRed,
          ));
          return;
        }
      }

      // Join limiti kontrolü (developer hariç)
      if (!isDeveloper) {
        final joinedCount = teamIds.length - adminTeamIds.length;
        if (!TeamLimits.canJoin(isPro: isPro, isDev: false, joinedCount: joinedCount)) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(TeamLimits.joinLimitMessage(isPro: isPro, isDev: false), style: GoogleFonts.nunito()),
            backgroundColor: AppColors.errorRed,
          ));
          return;
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
                style: GoogleFonts.nunito(color: ctx.colors.textSecondary)),
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
                style: GoogleFonts.nunito(color: ctx.colors.textSecondary)),
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
        });
      }
      // Admin dokümanını sorgudan bağımsız olarak kesin temizle
      batch.update(db.collection('users').doc(widget.currentUid), {
        'teamIds': FieldValue.arrayRemove([widget.teamId]),
        'adminTeamIds': FieldValue.arrayRemove([widget.teamId]),
        'teamJoinedAt.${widget.teamId}': FieldValue.delete(),
      });

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

  void _showTeamSettingsSheet(BuildContext context, TeamModel team, bool isAdmin) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('teams')
            .doc(widget.teamId)
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData || !snap.data!.exists) {
            return const SizedBox.shrink();
          }
          final latestTeam = TeamModel.fromFirestore(snap.data!);
          return _TeamSettingsSheet(
            team: latestTeam,
            isAdmin: isAdmin,
            onEditField: isAdmin ? (field) => _showEditSheet(context, latestTeam, field) : null,
          );
        },
      ),
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
          color: context.colors.tealSurface,
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
      return const SizedBox.shrink();
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
      backgroundColor: context.colors.surface,
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
              final isDev = (userData?['isDeveloper'] as bool?) ?? false;
              final userCinsiyet = (userData?['cinsiyet'] as String?) ?? '';

              // Cinsiyet uyumsuzluğu: bu ekip kullanıcının cinsiyetine kapalı
              final genderBlocked = !isAdmin && !isMember &&
                  userCinsiyet.isNotEmpty &&
                  ((team.genderPolicy == 'men' && userCinsiyet == 'hanim') ||
                   (team.genderPolicy == 'women' && userCinsiyet == 'bey'));
              if (genderBlocked) {
                return _GenderBlockedTeamView(
                  teamName: team.name,
                  genderPolicy: team.genderPolicy,
                  onBack: () => Navigator.pop(context),
                );
              }

              // Gizli ekip: sadece üyeler ve admin görebilir
              if (team.isPrivate && !isMember && !isAdmin) {
                return _LockedTeamView(teamName: team.name);
              }

              // Açık ekip: üye olmayan kullanıcıya katılım önizleme ekranı göster
              if (!team.isPrivate && !isMember && !isAdmin) {
                return _PublicTeamJoinView(
                  team: team,
                  isJoinLoading: _isJoinLoading,
                  onJoin: () => _sendJoinRequest(
                    isPrivate: false,
                    genderPolicy: team.genderPolicy,
                    teamName: team.name,
                    adminUid: team.adminUid,
                  ),
                  onBack: () => Navigator.pop(context),
                );
              }

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
                              _showTeamSettingsSheet(context, team, isAdmin);
                            } else if (v == 'manageMembers') {
                              _showManageMembersSheet(context, team.adminUid);
                            } else if (v == 'leaveTeam') {
                              _leaveTeam();
                            }
                          },
                          itemBuilder: (_) => [
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
                            const PopupMenuDivider(),
                            PopupMenuItem(
                              value: 'teamSettings',
                              child: Row(
                                children: [
                                  Icon(Icons.tune_outlined, color: context.colors.textPrimary, size: 20),
                                  const SizedBox(width: 8),
                                  Text('Takım Ayarları', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
                                ],
                              ),
                            ),
                            if (isMember && !isAdmin) ...[
                              const PopupMenuDivider(),
                              PopupMenuItem(
                                value: 'leaveTeam',
                                child: Row(
                                  children: [
                                    const Icon(Icons.logout, color: AppColors.errorRed, size: 20),
                                    const SizedBox(width: 8),
                                    Text('Ekipten Ayrıl', style: GoogleFonts.nunito(color: AppColors.errorRed, fontWeight: FontWeight.w700)),
                                  ],
                                ),
                              ),
                            ],
                            if (isAdmin) ...[
                              const PopupMenuDivider(),
                              PopupMenuItem(
                                value: 'manageMembers',
                                child: Row(
                                  children: [
                                    Icon(Icons.manage_accounts_outlined, color: context.colors.textPrimary, size: 20),
                                    const SizedBox(width: 8),
                                    Text('Üyeleri Yönet', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
                                  ],
                                ),
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
                            Icon(Icons.people_outline,
                                size: 15, color: context.colors.textSecondary),
                            const SizedBox(width: 4),
                            Text(
                              '${team.memberCount} üye',
                              style: GoogleFonts.nunito(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: context.colors.textSecondary,
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

                        if (team.description.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _InfoCard(icon: Icons.info_outline, text: team.description),
                        ],
                        if (team.penaltyNote.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _PenaltyCard(note: team.penaltyNote),
                        ],

                        // ── Admin: davet kodu kartı ──────────────────────
                        if (isAdmin && team.inviteCode.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _InviteCodeCard(inviteCode: team.inviteCode),
                        ],

                        // ── Admin: bekleyen istekler (tıklanabilir kart) ──
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
                                children: [
                                  const SizedBox(height: 16),
                                  GestureDetector(
                                    onTap: () => showModalBottomSheet(
                                      context: context,
                                      isScrollControlled: true,
                                      backgroundColor: Colors.transparent,
                                      builder: (_) => _PendingRequestsSheet(
                                        teamId: widget.teamId,
                                        onMemberApproved: _loadLeaderboard,
                                      ),
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFF8E1),
                                        border: Border.all(color: const Color(0xFFFFE082), width: 1.2),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 36, height: 36,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFFECB3),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(Icons.person_add_outlined, size: 18, color: Color(0xFFE65100)),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Bekleyen İstekler',
                                                  style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w800, color: context.colors.textPrimary),
                                                ),
                                                Text(
                                                  '${docs.length} kişi ekibe katılmak istiyor',
                                                  style: GoogleFonts.nunito(fontSize: 12, color: const Color(0xFFE65100)),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFF9800),
                                              borderRadius: BorderRadius.circular(99),
                                            ),
                                            child: Text(
                                              '${docs.length}',
                                              style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          const Icon(Icons.chevron_right, color: Color(0xFFE65100), size: 18),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),

                        const SizedBox(height: 20),

                        // Liderboard
                        _LeaderboardSection(
                          leaderboard: _leaderboard,
                          loading: _leaderboardLoading,
                          untilMidnight: _untilEnd,
                          currentUid: widget.currentUid,
                          currentUserCinsiyet: _currentUserCinsiyet,
                          leaderUid: team.adminUid,
                          showCrossGenderNames: team.showCrossGenderNames,
                          onRefresh: _loadLeaderboard,
                          onMemberTap: team.genderPolicy == 'all'
                              ? null
                              : (uid) => Navigator.push(
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
        color: context.colors.tealSurface,
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

// ─── Bekleyen İstekler Yönetim Sheet ─────────────────────────────────────────

class _PendingRequestsSheet extends StatefulWidget {
  final String teamId;
  final VoidCallback onMemberApproved;

  const _PendingRequestsSheet({
    required this.teamId,
    required this.onMemberApproved,
  });

  @override
  State<_PendingRequestsSheet> createState() => _PendingRequestsSheetState();
}

class _PendingRequestsSheetState extends State<_PendingRequestsSheet> {
  final _loadingUids = <String>{};
  String? _teamName;
  String _genderPolicy = 'all';

  @override
  void initState() {
    super.initState();
    FirebaseFirestore.instance.collection('teams').doc(widget.teamId).get().then((doc) {
      if (mounted) setState(() {
        _teamName = (doc.data()?['name'] as String?) ?? 'Ekip';
        _genderPolicy = (doc.data()?['genderPolicy'] as String?) ?? 'all';
      });
    });
  }

  Future<void> _approve(String requesterUid) async {
    if (_loadingUids.contains(requesterUid)) return;
    if (mounted) setState(() => _loadingUids.add(requesterUid));
    try {
      final db = FirebaseFirestore.instance;
      final userDoc = await db.collection('users').doc(requesterUid).get();
      final data = userDoc.data() ?? {};
      final teamIds = ((data['teamIds']) as List?)?.map((e) => e.toString()).toList() ?? [];
      final adminIds = ((data['adminTeamIds']) as List?)?.map((e) => e.toString()).toList() ?? [];
      final isPro = (data['isPro'] as bool?) ?? false;
      final isDev = (data['isDeveloper'] as bool?) ?? false;

      final reqRef = db.collection('teams').doc(widget.teamId).collection('requests').doc(requesterUid);

      if (teamIds.contains(widget.teamId)) { await reqRef.delete(); return; }

      final joinedCount = teamIds.length - adminIds.length;
      if (!isDev && !TeamLimits.canJoin(isPro: isPro, isDev: false, joinedCount: joinedCount)) {
        await reqRef.delete();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Kullanıcının ekip limiti doldu.', style: GoogleFonts.nunito()),
          backgroundColor: AppColors.errorRed,
        ));
        return;
      }

      // Cinsiyet politikası kontrolü — istek doc'undaki cinsiyet alanından oku
      if (_genderPolicy != 'all') {
        final reqDoc = await reqRef.get();
        final requesterCinsiyet = (reqDoc.data()?['cinsiyet'] as String?) ?? '';
        final blocked = (_genderPolicy == 'men' && requesterCinsiyet != 'bey') ||
                        (_genderPolicy == 'women' && requesterCinsiyet != 'hanim');
        if (blocked) {
          await reqRef.delete();
          await db.collection('users').doc(requesterUid).update({
            'pendingTeamIds': FieldValue.arrayRemove([widget.teamId]),
          });
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Bu kullanıcı ekibin cinsiyet politikasına uymuyor, istek silindi.', style: GoogleFonts.nunito()),
            backgroundColor: AppColors.errorRed,
          ));
          return;
        }
      }

      final batch = db.batch();
      batch.delete(reqRef);
      batch.update(db.collection('users').doc(requesterUid), {
        'teamIds': FieldValue.arrayUnion([widget.teamId]),
        'pendingTeamIds': FieldValue.arrayRemove([widget.teamId]),
        'teamJoinedAt.${widget.teamId}': FieldValue.serverTimestamp(),
      });
      batch.update(db.collection('teams').doc(widget.teamId), {
        'memberCount': FieldValue.increment(1),
      });
      await batch.commit();

      final name = _teamName ?? 'Ekip';
      await db.collection('users').doc(requesterUid).collection('notifications').add({
        'type': 'join_approved',
        'title': 'İsteğin kabul edildi!',
        'body': '$name ekibine katıldın.',
        'teamId': widget.teamId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      widget.onMemberApproved();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Hata: $e', style: GoogleFonts.nunito()),
        backgroundColor: AppColors.errorRed,
      ));
    } finally {
      if (mounted) setState(() => _loadingUids.remove(requesterUid));
    }
  }

  Future<void> _reject(String requesterUid) async {
    if (_loadingUids.contains(requesterUid)) return;
    if (mounted) setState(() => _loadingUids.add(requesterUid));
    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();
      batch.delete(db.collection('teams').doc(widget.teamId).collection('requests').doc(requesterUid));
      batch.update(db.collection('users').doc(requesterUid), {
        'pendingTeamIds': FieldValue.arrayRemove([widget.teamId]),
      });
      await batch.commit();

      final name = _teamName ?? 'Ekip';
      await db.collection('users').doc(requesterUid).collection('notifications').add({
        'type': 'join_rejected',
        'title': 'İsteğin reddedildi',
        'body': '$name ekibine katılma isteğin onaylanmadı.',
        'teamId': widget.teamId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Hata: $e', style: GoogleFonts.nunito()),
        backgroundColor: AppColors.errorRed,
      ));
    } finally {
      if (mounted) setState(() => _loadingUids.remove(requesterUid));
    }
  }

  String _timeAgo(Timestamp? ts) {
    if (ts == null) return '';
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inMinutes < 1) return 'Az önce';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
    if (diff.inHours < 24) return '${diff.inHours} sa önce';
    return '${diff.inDays} gün önce';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('teams')
              .doc(widget.teamId)
              .collection('requests')
              .orderBy('requestedAt', descending: false)
              .snapshots(),
          builder: (ctx, snap) {
            final docs = snap.data?.docs ?? [];
            final isLoading = snap.connectionState == ConnectionState.waiting && !snap.hasData;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Handle ──────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 4),
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: context.colors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // ── Başlık ──────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Katılım İstekleri',
                              style: GoogleFonts.nunito(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: context.colors.textPrimary,
                              ),
                            ),
                            if (!isLoading)
                              Text(
                                docs.isEmpty
                                    ? 'Bekleyen istek yok'
                                    : '${docs.length} kişi bekliyor · Onaylarsan ekibe katılır',
                                style: GoogleFonts.nunito(fontSize: 12, color: context.colors.textSecondary),
                              ),
                          ],
                        ),
                      ),
                      if (docs.isNotEmpty)
                        Container(
                          width: 32, height: 32,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFF9800),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${docs.length}',
                              style: GoogleFonts.nunito(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                Divider(height: 1, color: context.colors.border),

                // ── İstek listesi ────────────────────────────────────────────
                if (isLoading)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(color: AppColors.teal),
                  )
                else if (docs.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Column(
                      children: [
                        Container(
                          width: 56, height: 56,
                          decoration: const BoxDecoration(
                            color: Color(0xFFE8F5E9),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check_rounded, color: Color(0xFF43A047), size: 30),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Tüm istekler işlendi',
                          style: GoogleFonts.nunito(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: context.colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.52,
                    ),
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shrinkWrap: true,
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => Divider(height: 1, indent: 72, endIndent: 20, color: context.colors.border),
                      itemBuilder: (ctx, i) {
                        final doc = docs[i];
                        final data = doc.data() as Map<String, dynamic>;
                        final uid = doc.id;
                        final name = data['name'] as String? ?? 'İsimsiz';
                        final username = data['username'] as String? ?? '';
                        final avatarSeed = data['avatarSeed'] as String?;
                        final cinsiyet = data['cinsiyet'] as String? ?? '';
                        final city = data['city'] as String? ?? '';
                        final university = data['university'] as String? ?? '';
                        final requestedAt = data['requestedAt'] as Timestamp?;
                        final processing = _loadingUids.contains(uid);

                        return Padding(
                          key: ValueKey(uid),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Avatar
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: context.colors.tealSurface,
                                backgroundImage: avatarSeed != null
                                    ? NetworkImage('https://api.dicebear.com/7.x/micah/png?seed=$avatarSeed&backgroundColor=transparent')
                                    : null,
                                child: avatarSeed == null
                                    ? Text(
                                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                                        style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.teal),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              // Bilgi
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            name,
                                            style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w800, color: context.colors.textPrimary),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (cinsiyet.isNotEmpty) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: cinsiyet == 'hanim' ? const Color(0xFFFCE4EC) : const Color(0xFFE3F2FD),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              cinsiyet == 'hanim' ? 'Hanım' : 'Bey',
                                              style: GoogleFonts.nunito(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: cinsiyet == 'hanim' ? const Color(0xFFE91E63) : const Color(0xFF1976D2),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        if (username.isNotEmpty)
                                          Text('@$username', style: GoogleFonts.nunito(fontSize: 11, color: context.colors.textTertiary)),
                                        if (username.isNotEmpty && (city.isNotEmpty || university.isNotEmpty))
                                          Text(' · ', style: GoogleFonts.nunito(fontSize: 11, color: context.colors.textTertiary)),
                                        if (city.isNotEmpty || university.isNotEmpty)
                                          Flexible(child: Text([city, university].where((s) => s.isNotEmpty).join(' · '), style: GoogleFonts.nunito(fontSize: 11, color: context.colors.textTertiary), overflow: TextOverflow.ellipsis)),
                                        if (requestedAt != null) ...[
                                          Text(' · ', style: GoogleFonts.nunito(fontSize: 11, color: context.colors.textTertiary)),
                                          Text(_timeAgo(requestedAt), style: GoogleFonts.nunito(fontSize: 11, color: context.colors.textTertiary)),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Aksiyonlar
                              if (processing)
                                const SizedBox(
                                  width: 24, height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.teal),
                                )
                              else
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Reddet
                                    GestureDetector(
                                      onTap: () => _reject(uid),
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: AppColors.errorRed.withValues(alpha: 0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.close_rounded, size: 18, color: AppColors.errorRed),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Onayla
                                    GestureDetector(
                                      onTap: () => _approve(uid),
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: const BoxDecoration(
                                          color: AppColors.teal,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.check_rounded, size: 18, color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                const SizedBox(height: 8),
              ],
            );
          },
        ),
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
  final bool isLoading;
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
    this.isLoading = false,
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
        color: context.colors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: context.colors.tealSurface,
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
                              style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
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
                      Text('@$username', style: GoogleFonts.nunito(fontSize: 11, color: context.colors.textTertiary)),
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
                        style: GoogleFonts.nunito(fontSize: 11, color: context.colors.textSecondary),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                Text(_timeAgo(), style: GoogleFonts.nunito(fontSize: 11, color: context.colors.textTertiary)),
              ],
            ),
          ],
          const SizedBox(height: 8),
          if (isLoading)
            const Center(child: Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            ))
          else
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
        color: context.colors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: context.colors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.nunito(
                fontSize: 13,
                color: context.colors.textSecondary,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: isDark ? 0.1 : 0.15),
        border: Border.all(color: AppColors.gold.withValues(alpha: isDark ? 0.3 : 0.4)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded,
              size: 16, color: AppColors.gold),
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
                    color: AppColors.gold,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  note,
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    color: context.colors.textPrimary,
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
  final String currentUserCinsiyet;
  final String leaderUid;
  final VoidCallback onRefresh;
  final void Function(String uid)? onMemberTap;
  final bool showCrossGenderNames;

  const _LeaderboardSection({
    required this.leaderboard,
    required this.loading,
    required this.untilMidnight,
    required this.currentUid,
    required this.currentUserCinsiyet,
    required this.leaderUid,
    required this.onRefresh,
    required this.onMemberTap,
    this.showCrossGenderNames = true,
  });

  @override
  State<_LeaderboardSection> createState() => _LeaderboardSectionState();
}

class _LeaderboardSectionState extends State<_LeaderboardSection> {
  _SortMode _sortMode = _SortMode.puan;
  bool _showLow = false;
  _HafizFilter _hafizFilter = _HafizFilter.none;

  // İsim sansürü: her kelime → ilk harf + *****
  String _censorName(String name) {
    return name.trim().split(RegExp(r'\s+')).map((w) {
      if (w.isEmpty) return w;
      return '${w[0]}*****';
    }).join(' ');
  }

  // Sansür gerekli mi? Karışık+gizli grupta, gösterme modunda, karşı cins ise
  String _displayName(_MemberEntry entry) {
    if (widget.showCrossGenderNames) return entry.name;
    final myCinsiyet = widget.currentUserCinsiyet;
    final theirCinsiyet = entry.cinsiyet;
    // Kendi kaydı — sansürsüz
    if (entry.uid == widget.currentUid) return entry.name;
    // Her ikisi de belirsiz veya aynı cinsiyet — sansürsüz
    if (myCinsiyet.isEmpty || theirCinsiyet.isEmpty) return entry.name;
    if (myCinsiyet == theirCinsiyet) return entry.name;
    // Karşı cins → sansürle
    return _censorName(entry.name);
  }

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
                color: context.colors.textPrimary,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: widget.onRefresh,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: context.colors.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.refresh,
                    size: 18, color: context.colors.textSecondary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(Icons.access_time, size: 13, color: context.colors.textTertiary),
            const SizedBox(width: 4),
            Text(
              'Sıfırlanmaya ${_fmtDuration(widget.untilMidnight)} kaldı',
              style: GoogleFonts.nunito(fontSize: 12, color: context.colors.textTertiary),
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
              color: context.colors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                'Henüz üye yok.',
                style: GoogleFonts.nunito(
                    fontSize: 13, color: context.colors.textTertiary),
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
                    color: context.colors.textSecondary,
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
                    color: context.colors.textTertiary,
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
          onTap: widget.onMemberTap != null ? () => widget.onMemberTap!(entry.uid) : null,
          child: _LeaderboardRow(
            rank: i + 1,
            entry: entry,
            displayName: _displayName(entry),
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
          color: selected ? activeColor : context.colors.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? activeColor : context.colors.border,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : context.colors.textSecondary,
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
  final String displayName;
  final bool isTop;
  final bool isRed;
  final bool isDeepRed;
  final bool isMe;
  final bool isTeamLeader;
  final String Function(int) fmtHasanat;

  const _LeaderboardRow({
    required this.rank,
    required this.entry,
    required this.displayName,
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

  Color _bgColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      // Dark modda: şeffaf/ton tabanlı renkler — arka planla uyumlu
      if (isDeepRed) return AppColors.errorRed.withValues(alpha: 0.22);
      if (isRed) return AppColors.errorRed.withValues(alpha: 0.10);
      if (rank == 1) return AppColors.successGreen.withValues(alpha: 0.18);
      if (rank == 2) return AppColors.successGreen.withValues(alpha: 0.12);
      if (rank == 3) return AppColors.successGreen.withValues(alpha: 0.07);
      return context.colors.surface;
    }
    // Light mode (orijinal)
    if (isDeepRed) return AppColors.errorRed.withValues(alpha: 0.48);
    if (isRed) return AppColors.errorBg;
    if (rank == 1) return AppColors.successBg;
    if (rank == 2) return AppColors.successBg.withValues(alpha: 0.6);
    if (rank == 3) return AppColors.successBg.withValues(alpha: 0.3);
    return context.colors.surface;
  }

  Color _borderColor(BuildContext context) {
    if (isMe) return AppColors.teal;
    if (isDeepRed) return AppColors.errorRed.withValues(alpha: 0.85);
    if (isRed) return AppColors.errorRed.withValues(alpha: 0.3);
    if (rank == 1) return AppColors.successGreen.withValues(alpha: 0.5);
    if (rank == 2) return AppColors.successGreen.withValues(alpha: 0.3);
    if (rank == 3) return AppColors.successGreen.withValues(alpha: 0.15);
    return context.colors.border;
  }

  double get _borderWidth => isMe ? 2.0 : 1.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _bgColor(context),
        border: Border.all(color: _borderColor(context), width: _borderWidth),
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
                      color: isRed ? AppColors.errorRed : context.colors.textSecondary,
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
              backgroundColor: context.colors.tealSurface,
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
                        displayName,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: context.colors.textPrimary,
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
                          color: context.colors.tealSurface,
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
                      : context.colors.textTertiary,
                ),
              ),
              Text(
                'hasanat',
                style: GoogleFonts.nunito(
                  fontSize: 9,
                  color: context.colors.textTertiary,
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
                color: context.colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            '${widget.label} Düzenle',
            style: GoogleFonts.nunito(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: context.colors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _ctrl,
            maxLines: 4,
            maxLength: 300,
            decoration: InputDecoration(
              labelText: widget.label,
              labelStyle: GoogleFonts.nunito(color: context.colors.textSecondary),
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
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                  color: context.colors.textPrimary,
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
            style: GoogleFonts.nunito(fontSize: 13, color: context.colors.textSecondary),
          ),
          const SizedBox(height: 16),
          if (kickable.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'Çıkarılabilecek başka üye yok.',
                  style: GoogleFonts.nunito(
                      fontSize: 13, color: context.colors.textTertiary),
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
        color: context.colors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: context.colors.tealSurface,
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
                    color: context.colors.textPrimary,
                  ),
                ),
                if (member.username.isNotEmpty)
                  Text(
                    '@${member.username}',
                    style: GoogleFonts.nunito(
                        fontSize: 11, color: context.colors.textTertiary),
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
  final bool isAdmin;
  final void Function(String field)? onEditField;

  const _TeamSettingsSheet({
    required this.team,
    this.isAdmin = false,
    this.onEditField,
  });

  @override
  Widget build(BuildContext context) {
    final privacyLabel = team.isPrivate ? 'Sadece Davet' : 'Herkese Açık';
    final privacyIcon = team.isPrivate ? Icons.lock_outline : Icons.public_outlined;

    final genderLabel = switch (team.genderPolicy) {
      'men'   => 'Sadece Beyler',
      'women' => 'Sadece Hanımlar',
      _       => 'Karışık (Herkese Açık)',
    };
    final genderIcon = switch (team.genderPolicy) {
      'men'   => Icons.male_outlined,
      'women' => Icons.female_outlined,
      _       => Icons.groups_outlined,
    };

    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(context).padding.bottom + 28),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(color: context.colors.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Takım Ayarları',
              style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w800, color: context.colors.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              isAdmin
                  ? 'Ekip bilgilerini buradan görüntüleyebilir ve düzenleyebilirsin.'
                  : 'Ekip hakkında bilgiler.',
              style: GoogleFonts.nunito(fontSize: 12, color: context.colors.textTertiary),
            ),
            const SizedBox(height: 20),
            _SettingRow(icon: privacyIcon, label: 'Görünürlük', value: privacyLabel),
            const SizedBox(height: 12),
            _SettingRow(icon: genderIcon, label: 'Katılım Politikası', value: genderLabel),

            // Karşı cins isim gizleme toggle — sadece admin + gizli + karışık
            if (isAdmin && team.isPrivate && team.genderPolicy == 'all') ...[
              const SizedBox(height: 12),
              _CrossGenderNamesToggle(teamId: team.id, value: team.showCrossGenderNames),
            ],

            // Grup Açıklaması
            if (team.description.isNotEmpty || isAdmin) ...[
              const SizedBox(height: 24),
              _SectionHeader(
                title: 'Grup Açıklaması',
                onEdit: isAdmin ? () => onEditField?.call('description') : null,
              ),
              const SizedBox(height: 8),
              if (team.description.isNotEmpty)
                _InfoCard(icon: Icons.info_outline, text: team.description)
              else
                Text(
                  'Henüz açıklama eklenmemiş.',
                  style: GoogleFonts.nunito(fontSize: 13, color: context.colors.textTertiary),
                ),
            ],

            // Ceza Notu
            if (team.penaltyNote.isNotEmpty || isAdmin) ...[
              const SizedBox(height: 20),
              _SectionHeader(
                title: 'Ceza Notu',
                onEdit: isAdmin ? () => onEditField?.call('penaltyNote') : null,
              ),
              const SizedBox(height: 8),
              if (team.penaltyNote.isNotEmpty)
                _PenaltyCard(note: team.penaltyNote)
              else
                Text(
                  'Henüz ceza notu eklenmemiş.',
                  style: GoogleFonts.nunito(fontSize: 13, color: context.colors.textTertiary),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Section Başlığı (düzenle butonu ile) ─────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onEdit;
  const _SectionHeader({required this.title, this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w800, color: context.colors.textPrimary),
        ),
        const Spacer(),
        if (onEdit != null)
          GestureDetector(
            onTap: onEdit,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: context.colors.tealSurface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.edit_outlined, size: 14, color: AppColors.teal),
                  const SizedBox(width: 4),
                  Text('Düzenle', style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.teal)),
                ],
              ),
            ),
          ),
      ],
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
        color: context.colors.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(color: context.colors.tealSurface, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 20, color: AppColors.teal),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(label, style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
          ),
          Text(value, style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600, color: context.colors.textSecondary)),
        ],
      ),
    );
  }
}

// ─── Karşı Cins İsim Gizleme Toggle ──────────────────────────────────────────

class _CrossGenderNamesToggle extends StatefulWidget {
  final String teamId;
  final bool value;
  const _CrossGenderNamesToggle({required this.teamId, required this.value});

  @override
  State<_CrossGenderNamesToggle> createState() => _CrossGenderNamesToggleState();
}

class _CrossGenderNamesToggleState extends State<_CrossGenderNamesToggle> {
  late bool _localValue;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _localValue = widget.value;
  }

  Future<void> _toggle(bool newValue) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _localValue = newValue;
    });
    try {
      await FirebaseFirestore.instance
          .collection('teams')
          .doc(widget.teamId)
          .update({'showCrossGenderNames': newValue});
    } catch (_) {
      if (mounted) setState(() => _localValue = !newValue);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.colors.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: _localValue ? context.colors.tealSurface : const Color(0xFFFCE4EC),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _localValue ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              size: 18,
              color: _localValue ? AppColors.teal : const Color(0xFFE91E63),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Karşı cins isimleri',
                  style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w800, color: context.colors.textPrimary),
                ),
                Text(
                  _localValue
                      ? 'Herkes herkesi tam adıyla görüyor'
                      : 'Karşı cins adları sansürlü görünüyor',
                  style: GoogleFonts.nunito(fontSize: 11, color: context.colors.textSecondary),
                ),
              ],
            ),
          ),
          if (_loading)
            const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.teal))
          else
            Switch(
              value: _localValue,
              onChanged: _toggle,
              activeColor: AppColors.teal,
            ),
        ],
      ),
    );
  }
}

// ─── Açık Ekip Katılım Önizleme Ekranı ───────────────────────────────────────

class _PublicTeamJoinView extends StatelessWidget {
  final TeamModel team;
  final bool isJoinLoading;
  final VoidCallback onJoin;
  final VoidCallback onBack;

  const _PublicTeamJoinView({
    required this.team,
    required this.isJoinLoading,
    required this.onJoin,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
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
    final genderColor = switch (team.genderPolicy) {
      'men'   => const Color(0xFF1976D2),
      'women' => const Color(0xFFE91E63),
      _       => AppColors.teal,
    };
    final genderBg = switch (team.genderPolicy) {
      'men'   => const Color(0xFFE3F2FD),
      'women' => const Color(0xFFFCE4EC),
      _       => context.colors.tealSurface,
    };

    return Scaffold(
      backgroundColor: context.colors.surface,
      appBar: AppBar(
        backgroundColor: context.colors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.colors.textPrimary),
          onPressed: onBack,
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              // Ekip ikonu
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF2A7F8C), Color(0xFF1F6370)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.shield, size: 38, color: Colors.white),
              ),
              const SizedBox(height: 16),
              // Ekip adı
              Text(
                team.name,
                style: GoogleFonts.nunito(fontSize: 26, fontWeight: FontWeight.w800, color: context.colors.textPrimary),
              ),
              const SizedBox(height: 12),
              // Üye sayısı + cinsiyet politikası
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: context.colors.surfaceVariant, borderRadius: BorderRadius.circular(20)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.people_outline, size: 14, color: context.colors.textSecondary),
                        const SizedBox(width: 4),
                        Text('${team.memberCount} üye', style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700, color: context.colors.textSecondary)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: genderBg, borderRadius: BorderRadius.circular(20)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(genderIcon, size: 14, color: genderColor),
                        const SizedBox(width: 4),
                        Text(genderLabel, style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700, color: genderColor)),
                      ],
                    ),
                  ),
                ],
              ),
              // Açıklama
              if (team.description.isNotEmpty) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: context.colors.surfaceVariant, borderRadius: BorderRadius.circular(14)),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, size: 16, color: context.colors.textSecondary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(team.description, style: GoogleFonts.nunito(fontSize: 13, color: context.colors.textSecondary, height: 1.5)),
                      ),
                    ],
                  ),
                ),
              ],
              // Ceza notu
              if (team.penaltyNote.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1),
                    border: Border.all(color: const Color(0xFFFFE082)),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFF59E0B)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Ceza Notu', style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFF59E0B))),
                            const SizedBox(height: 2),
                            Text(team.penaltyNote, style: GoogleFonts.nunito(fontSize: 13, color: Color(0xFF92400E), height: 1.4)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const Spacer(),
              // Katılım sorusu
              Center(
                child: Text(
                  'Bu ekibe katılmak istiyor musun?',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w700, color: context.colors.textSecondary),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: DuolingoButton(
                  color: AppColors.teal,
                  bottomColor: AppColors.tealDark,
                  isLoading: isJoinLoading,
                  onPressed: isJoinLoading ? null : onJoin,
                  child: Text('Katıl', style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: onBack,
                  child: Text('Geri Dön', style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700, color: context.colors.textSecondary)),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Cinsiyet Engeli Görünümü ─────────────────────────────────────────────────

class _GenderBlockedTeamView extends StatelessWidget {
  final String teamName;
  final String genderPolicy;
  final VoidCallback onBack;
  const _GenderBlockedTeamView({required this.teamName, required this.genderPolicy, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final forMen = genderPolicy == 'men';
    return Scaffold(
      backgroundColor: context.colors.surface,
      appBar: AppBar(
        backgroundColor: context.colors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.colors.textPrimary),
          onPressed: onBack,
        ),
        title: Text(teamName, style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w800, color: context.colors.textPrimary)),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: forMen ? const Color(0xFFE3F2FD) : const Color(0xFFFCE4EC),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  forMen ? Icons.male_outlined : Icons.female_outlined,
                  size: 40,
                  color: forMen ? const Color(0xFF1976D2) : const Color(0xFFE91E63),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                forMen ? 'Sadece Beyler' : 'Sadece Hanımlar',
                style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w800, color: context.colors.textPrimary),
              ),
              const SizedBox(height: 10),
              Text(
                forMen
                    ? 'Bu ekip yalnızca erkek üyelere açıktır.'
                    : 'Bu ekip yalnızca hanım üyelere açıktır.',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(fontSize: 14, color: context.colors.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: onBack,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: context.colors.border),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Geri Dön', style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700, color: context.colors.textSecondary)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Kilitli Ekip Görünümü (gizli + üye değil) ────────────────────────────────

class _LockedTeamView extends StatelessWidget {
  final String teamName;
  const _LockedTeamView({required this.teamName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.surface,
      appBar: AppBar(
        backgroundColor: context.colors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.colors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(teamName, style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w800, color: context.colors.textPrimary)),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(color: context.colors.surfaceVariant, shape: BoxShape.circle),
                child: Icon(Icons.lock_outlined, size: 36, color: context.colors.textSecondary),
              ),
              const SizedBox(height: 20),
              Text(
                'Gizli Ekip',
                style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w800, color: context.colors.textPrimary),
              ),
              const SizedBox(height: 10),
              Text(
                'Bu ekip gizlidir. Sadece kabul edilmiş üyeler ekip içeriğini görebilir.',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(fontSize: 14, color: context.colors.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: context.colors.border),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Geri Dön', style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700, color: context.colors.textSecondary)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
