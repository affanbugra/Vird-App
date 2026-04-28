import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import '../app_colors.dart';
import '../models/reading_log_model.dart';
import '../models/hatim_model.dart';
import '../data/quran_cuz.dart';
import 'log_edit_sheet.dart';
import '../utils/hatim_calculator.dart';

class LogHistorySheet {
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _LogHistoryContent(),
    );
  }
}

// ── Ana içerik ────────────────────────────────────────────────────────────────

class _LogHistoryContent extends StatefulWidget {
  const _LogHistoryContent();

  @override
  State<_LogHistoryContent> createState() => _LogHistoryContentState();
}

class _LogHistoryContentState extends State<_LogHistoryContent> {
  bool _deleting = false;

  Future<void> _deleteAllLogs(String uid) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Tüm kayıtları sil',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
          'Tüm okuma kayıtları silinecek.\nHasanat puanı, okunan sayfalar ve hatim ilerlemeleri sıfırlanır.\n\nBu işlem geri alınamaz.',
          style: TextStyle(color: AppColors.textMid),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal',
                style: TextStyle(color: AppColors.textMid)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorRed,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Tümünü Sil',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ) ?? false;
    if (!confirmed || !mounted) return;

    setState(() => _deleting = true);

    try {
      final db = FirebaseFirestore.instance;
      final logsSnap = await db
          .collection('users')
          .doc(uid)
          .collection('logs')
          .get();

      // Toplam sayfa sayısını hesapla
      int totalPages = 0;
      final Set<String> affectedHatimIds = {};
      for (var doc in logsSnap.docs) {
        final data = doc.data();
        totalPages += (data['pagesRead'] as int?) ?? 0;
        final hatimId = data['hatimId'] as String?;
        if (hatimId != null) affectedHatimIds.add(hatimId);
      }

      // Logları 400'lük batch'ler halinde sil
      final docs = logsSnap.docs;
      for (int i = 0; i < docs.length; i += 400) {
        final chunk = docs.sublist(i, (i + 400).clamp(0, docs.length));
        final batch = db.batch();
        for (var doc in chunk) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }

      // Kullanıcı istatistiklerini sıfırla
      if (totalPages > 0) {
        await db.collection('users').doc(uid).update({
          'hasanat': FieldValue.increment(-(totalPages * 10)),
          'totalPages': FieldValue.increment(-totalPages),
        });
      }

      // Etkilenen hatimleri yeniden hesapla
      for (final hatimId in affectedHatimIds) {
        await HatimCalculator.recalculate(uid, hatimId);
      }

      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.68,
        child: Scaffold(
          backgroundColor: AppColors.white,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 8, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Son Kayıtlar',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Liste
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(uid)
                      .collection('logs')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator(color: AppColors.teal));
                    }
                    final docs = snap.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history, size: 52, color: AppColors.borderGrey),
                            SizedBox(height: 12),
                            Text('Henüz kayıt yok.',
                                style: TextStyle(color: AppColors.textMid)),
                          ],
                        ),
                      );
                    }
                    final logs = docs
                        .map((d) => ReadingLog.fromFirestore(d))
                        .toList();
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: logs.length,
                      separatorBuilder: (ctx, i) =>
                          const Divider(height: 1, color: AppColors.borderGrey),
                      itemBuilder: (context, i) => _LogTile(
                        log: logs[i],
                        uid: uid,
                      ),
                    );
                  },
                ),
              ),
              // Tüm kayıtları sil butonu
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: TextButton.icon(
                  onPressed: _deleting ? null : () => _deleteAllLogs(uid),
                  icon: _deleting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.errorRed))
                      : const Icon(Icons.delete_sweep_outlined,
                          color: AppColors.errorRed, size: 20),
                  label: Text(
                    _deleting ? 'Siliniyor...' : 'Tüm Kayıtları Sil',
                    style: const TextStyle(
                      color: AppColors.errorRed,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                          color: AppColors.errorRed.withValues(alpha: 0.3)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Log satırı ────────────────────────────────────────────────────────────────

class _LogTile extends StatelessWidget {
  final ReadingLog log;
  final String uid;

  const _LogTile({required this.log, required this.uid});

  String get _title {
    switch (log.method) {
      case LogMethod.hatim:
        return '+${log.pagesRead} sayfa devam';
      case LogMethod.pages:
        return '${log.startPage}–${log.endPage}. sayfalar';
      case LogMethod.cuz:
        final cuz = QuranData.cuzler
            .where((c) => c.startPage == log.startPage)
            .firstOrNull;
        return cuz != null ? '${cuz.cuzNo}. Cüz' : '${log.pagesRead} sayfa';
      case LogMethod.surah:
        final surah = log.surahId != null
            ? QuranData.surahlar
                .where((s) => s.id == log.surahId)
                .firstOrNull
            : null;
        return surah?.name ?? '${log.pagesRead} sayfa';
    }
  }

  String get _typeLabel =>
      log.type == HatimType.arapca ? 'Arapça' : 'Meal';

  IconData get _icon {
    switch (log.method) {
      case LogMethod.hatim:
        return Icons.bookmark_border;
      case LogMethod.pages:
        return Icons.article_outlined;
      case LogMethod.cuz:
        return Icons.pie_chart_outline;
      case LogMethod.surah:
        return Icons.menu_book_outlined;
    }
  }

  Color get _iconColor =>
      log.method == LogMethod.hatim ? AppColors.orange : AppColors.teal;

  String _timeText(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Az önce';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
    if (diff.inHours < 24) return '${diff.inHours} sa önce';
    final today = DateTime(now.year, now.month, now.day);
    final logDay = DateTime(dt.year, dt.month, dt.day);
    final dayDiff = today.difference(logDay).inDays;
    if (dayDiff == 1) return 'Dün';
    if (dayDiff < 7) return '$dayDiff gün önce';
    return '${dt.day}.${dt.month}.${dt.year}';
  }

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Kaydı sil',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          '"$_title" silinsin mi?\nHasanat ${log.pagesRead * 10} geri alınacak.',
          style: const TextStyle(color: AppColors.textMid),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal',
                style: TextStyle(color: AppColors.textMid)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorRed,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final batch = FirebaseFirestore.instance.batch();
    batch.delete(FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('logs')
        .doc(log.id));
    batch.update(
      FirebaseFirestore.instance.collection('users').doc(uid),
      {
        'hasanat': FieldValue.increment(-(log.pagesRead * 10)),
        'totalPages': FieldValue.increment(-log.pagesRead),
      },
    );
    await batch.commit();

    if (log.hatimId != null) {
      await HatimCalculator.recalculate(uid, log.hatimId!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          // İkon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_icon, color: _iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          // Metin
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        _title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppColors.textDark),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    _TypeBadge(label: _typeLabel),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${_timeText(log.createdAt)} · +${log.pagesRead * 10} ✨',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textLight),
                ),
              ],
            ),
          ),
          // Aksiyonlar
          IconButton(
            icon: const Icon(Icons.edit_outlined,
                color: AppColors.teal, size: 20),
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => Padding(
                padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom),
                child: LogEditSheet(log: log, uid: uid),
              ),
            ),
            tooltip: 'Düzenle',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline,
                color: AppColors.errorRed, size: 20),
            onPressed: () => _delete(context),
            tooltip: 'Sil',
          ),
        ],
      ),
    );
  }
}

// ── Tip badge ─────────────────────────────────────────────────────────────────

class _TypeBadge extends StatelessWidget {
  final String label;
  const _TypeBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.tealLight,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: AppColors.teal),
      ),
    );
  }
}
