import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../app_colors.dart';
import '../app_theme.dart';
import '../providers/user_provider.dart';
import '../data/roadmap_entry.dart';

// ─── Modeller ─────────────────────────────────────────────────────────────────

class _Milestone {
  final String id;
  final String title;
  final String version;
  final String status; // 'active' | 'archived'
  final int order;

  const _Milestone({
    required this.id,
    required this.title,
    required this.version,
    required this.status,
    required this.order,
  });

  factory _Milestone.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return _Milestone(
      id: doc.id,
      title: (d['title'] as String?) ?? '',
      version: (d['version'] as String?) ?? '',
      status: (d['status'] as String?) ?? 'active',
      order: (d['order'] as int?) ?? 0,
    );
  }
}

class _BacklogItem {
  final String id;
  final String type;        // 'bug' | 'plan' | 'idea'
  final String title;
  final String category;
  final String priority;    // 'critical' | 'normal' | 'low'
  final String? milestoneId;
  final bool completed;
  final bool archived;
  final int order;

  const _BacklogItem({
    required this.id,
    required this.type,
    required this.title,
    required this.category,
    required this.priority,
    this.milestoneId,
    required this.completed,
    required this.archived,
    required this.order,
  });

  factory _BacklogItem.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return _BacklogItem(
      id: doc.id,
      type: (d['type'] as String?) ?? 'plan',
      title: (d['title'] as String?) ?? '',
      category: (d['category'] as String?) ?? 'Genel',
      priority: (d['priority'] as String?) ?? 'normal',
      milestoneId: d['milestoneId'] as String?,
      completed: (d['completed'] as bool?) ?? false,
      archived: (d['archived'] as bool?) ?? false,
      order: (d['order'] as int?) ?? 0,
    );
  }
}

class _Gap {
  final String sectionId;
  final List<_BacklogItem> sectionItems;
  final int insertAt;
  final Set<String> activeMilestoneIds;
  const _Gap({required this.sectionId, required this.sectionItems, required this.insertAt, required this.activeMilestoneIds});
}

class _FeedbackItem {
  final String id;
  final String text;
  final String uid;
  final bool isRead;
  final bool archived;
  final String? folderId;
  final DateTime? createdAt;

  const _FeedbackItem({
    required this.id,
    required this.text,
    required this.uid,
    required this.isRead,
    required this.archived,
    this.folderId,
    this.createdAt,
  });

  factory _FeedbackItem.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return _FeedbackItem(
      id: doc.id,
      text: (d['text'] as String?) ?? '',
      uid: (d['uid'] as String?) ?? '',
      isRead: (d['isRead'] as bool?) ?? false,
      archived: (d['archived'] as bool?) ?? false,
      folderId: d['folderId'] as String?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

class _Label {
  final String id;
  final String name;
  final String colorHex;

  const _Label({required this.id, required this.name, required this.colorHex});

  factory _Label.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return _Label(
      id: doc.id,
      name: (d['name'] as String?) ?? '',
      colorHex: (d['colorHex'] as String?) ?? '#777777',
    );
  }

  Color get color {
    try {
      return Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppColors.textMid;
    }
  }
}

// ─── Yardımcı fonksiyonlar ────────────────────────────────────────────────────

Color _catColor(String cat) {
  switch (cat.toLowerCase().trim()) {
    case 'seri':     return AppColors.orange;
    case 'ekipler':  return AppColors.errorRed;
    case 'hasanat':  return AppColors.gold;
    case 'ui':       return AppColors.teal;
    case 'auth':     return AppColors.infoBlue;
    case 'bildirim': return const Color(0xFF58CC02);
    case 'hatim':    return const Color(0xFF9B59B6);
    case 'genel':    return AppColors.textMid;
    default:
      const p = [AppColors.teal, AppColors.orange, AppColors.errorRed, Color(0xFF9B59B6), AppColors.infoBlue];
      return p[cat.hashCode.abs() % p.length];
  }
}

Color _priorityColor(String priority) {
  switch (priority) {
    case 'critical': return AppColors.errorRed;
    case 'low':      return const Color(0xFF58CC02);
    default:         return AppColors.gold;
  }
}

String _relativeTime(DateTime? dt) {
  if (dt == null) return '';
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'az önce';
  if (diff.inHours < 1) return '${diff.inMinutes} dk önce';
  if (diff.inDays < 1) return '${diff.inHours} sa önce';
  if (diff.inDays < 7) return '${diff.inDays} gün önce';
  return '${(diff.inDays / 7).floor()} hafta önce';
}

// ─── Panel Ana Widget ─────────────────────────────────────────────────────────

enum _PanelView { home, backlog, feedback, hafiz, roadmap, errors, broadcast }

class DevPanelScreen extends StatefulWidget {
  const DevPanelScreen({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => SizedBox(
      height: MediaQuery.of(ctx).size.height * 0.93,
      child: const ClipRRect(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        child: DevPanelScreen(),
      ),
    ),
  );

  @override
  State<DevPanelScreen> createState() => _DevPanelScreenState();
}

class _DevPanelScreenState extends State<DevPanelScreen> {
  _PanelView _view = _PanelView.home;

  @override
  Widget build(BuildContext context) {
    final isDev = context.select<UserProvider, bool>((p) => p.isDeveloper);
    if (!isDev) {
      return ColoredBox(
        color: context.colors.surface,
        child: Center(child: Text('Erişim yok.', style: TextStyle(color: context.colors.textSecondary))),
      );
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
      child: switch (_view) {
        _PanelView.home     => _HomeView(
            key: const ValueKey('home'),
            onBacklogTap:     () => setState(() => _view = _PanelView.backlog),
            onFeedbackTap:    () => setState(() => _view = _PanelView.feedback),
            onHafizTap:       () => setState(() => _view = _PanelView.hafiz),
            onRoadmapTap:     () => setState(() => _view = _PanelView.roadmap),
            onErrorsTap:      () => setState(() => _view = _PanelView.errors),
            onBroadcastTap:   () => setState(() => _view = _PanelView.broadcast),
          ),
        _PanelView.backlog  => _BacklogView(
            key: const ValueKey('backlog'),
            onBack: () => setState(() => _view = _PanelView.home),
          ),
        _PanelView.feedback => _FeedbackView(
            key: const ValueKey('feedback'),
            onBack: () => setState(() => _view = _PanelView.home),
          ),
        _PanelView.hafiz    => _HafizView(
            key: const ValueKey('hafiz'),
            onBack: () => setState(() => _view = _PanelView.home),
          ),
        _PanelView.roadmap  => _RoadmapView(
            key: const ValueKey('roadmap'),
            onBack: () => setState(() => _view = _PanelView.home),
          ),
        _PanelView.errors   => _ErrorLogsView(
            key: const ValueKey('errors'),
            onBack: () => setState(() => _view = _PanelView.home),
          ),
        _PanelView.broadcast => _BroadcastView(
            key: const ValueKey('broadcast'),
            onBack: () => setState(() => _view = _PanelView.home),
          ),
      },
    );
  }
}

// ─── Ana Sayfa ────────────────────────────────────────────────────────────────

class _HomeView extends StatelessWidget {
  final VoidCallback onBacklogTap;
  final VoidCallback onFeedbackTap;
  final VoidCallback onHafizTap;
  final VoidCallback onRoadmapTap;
  final VoidCallback onErrorsTap;
  final VoidCallback onBroadcastTap;
  const _HomeView({super.key, required this.onBacklogTap, required this.onFeedbackTap, required this.onHafizTap, required this.onRoadmapTap, required this.onErrorsTap, required this.onBroadcastTap});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.surface,
      body: Column(
        children: [
          // Koyu slate header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 20, 12, 22),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.teal.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.teal.withValues(alpha: 0.4)),
                          ),
                          child: const Text(
                            'DEV',
                            style: TextStyle(color: AppColors.teal, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Developer Paneli',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                      ]),
                      const SizedBox(height: 4),
                      Text(
                        'Sadece geliştirici erişimi',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded, color: Colors.white.withValues(alpha: 0.6)),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  _buildGrid(context),
                ],
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.only(bottom: 28, top: 8),
            child: Column(children: [
              Image.asset(
                'assets/images/v_logo.png',
                height: 26,
                color: context.colors.border,
                colorBlendMode: BlendMode.srcIn,
              ),
              const SizedBox(height: 6),
              Text('vird dev tools', style: TextStyle(fontSize: 10, color: context.colors.textTertiary, letterSpacing: 1.2)),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(BuildContext context) {
    return Column(
      children: [
        // ── Satır 1 ──
        Row(
          children: [
            Expanded(child: _PanelTile(
              icon: Icons.checklist_rtl_outlined,
              label: 'Backlog',
              color: const Color(0xFF6366F1),
              active: true,
              onTap: onBacklogTap,
            )),
            const SizedBox(width: 10),
            Expanded(child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('feature_requests')
                  .snapshots(),
              builder: (context, snap) {
                final unread = (snap.data?.docs ?? [])
                    .where((d) {
                      final data = d.data() as Map;
                      final archived = data['archived'] as bool? ?? false;
                      final folderId = data['folderId'] as String?;
                      return !archived && (folderId == null || folderId.isEmpty);
                    })
                    .length;
                return _PanelTile(
                  icon: Icons.inbox_outlined,
                  label: 'Feedback',
                  color: AppColors.teal,
                  active: true,
                  badge: unread > 0 ? '$unread' : null,
                  onTap: onFeedbackTap,
                );
              },
            )),
            const SizedBox(width: 10),
            Expanded(child: _PanelTile(
              icon: Icons.rocket_launch_outlined,
              label: 'Yol Haritası',
              color: const Color(0xFFF59E0B),
              active: true,
              onTap: onRoadmapTap,
            )),
            const SizedBox(width: 10),
            Expanded(child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('hafiz_requests')
                  .where('status', isEqualTo: 'pending')
                  .snapshots(),
              builder: (context, snap) {
                final pending = snap.data?.docs.length ?? 0;
                return _PanelTile(
                  icon: Icons.menu_book_outlined,
                  label: 'Hafız',
                  color: AppColors.emeraldGreen,
                  active: true,
                  badge: pending > 0 ? '$pending' : null,
                  onTap: onHafizTap,
                );
              },
            )),
          ],
        ),
        const SizedBox(height: 10),
        // ── Satır 2 ──
        Row(
          children: [
            Expanded(child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('app_errors')
                  .orderBy('createdAt', descending: true)
                  .limit(1)
                  .snapshots(),
              builder: (context, snap) {
                final count = snap.data?.docs.length ?? 0;
                return _PanelTile(
                  icon: Icons.bug_report_outlined,
                  label: 'Hatalar',
                  color: AppColors.errorRed,
                  active: true,
                  badge: count > 0 ? '$count' : null,
                  onTap: onErrorsTap,
                );
              },
            )),
            const SizedBox(width: 10),
            Expanded(child: _PanelTile(
              icon: Icons.workspace_premium_outlined,
              label: 'Pro',
              color: AppColors.gold,
              active: false,
            )),
            const SizedBox(width: 10),
            Expanded(child: _PanelTile(
              icon: Icons.campaign_outlined,
              label: 'Bildirim',
              color: const Color(0xFF8B5CF6),
              active: true,
              onTap: onBroadcastTap,
            )),
            const SizedBox(width: 10),
            Expanded(child: _PanelTile(
              icon: Icons.analytics_outlined,
              label: 'Analitik',
              color: const Color(0xFF06B6D4),
              active: false,
            )),
          ],
        ),
      ],
    );
  }
}

// ─── Premium küp kart ──────────────────────────────────────────────────────────

class _PanelTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool active;
  final String? badge;
  final VoidCallback? onTap;

  const _PanelTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.active,
    this.badge,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : context.colors.border.withValues(alpha: 0.5);

    return GestureDetector(
      onTap: active ? onTap : null,
      child: AspectRatio(
        aspectRatio: 0.82,
        child: Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
            boxShadow: active ? [
              BoxShadow(
                color: color.withValues(alpha: isDark ? 0.15 : 0.10),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ] : null,
          ),
          child: Stack(
            children: [
              // Badge
              if (badge != null)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      badge!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              // Content
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // İkon dairesi
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: active
                            ? color.withValues(alpha: isDark ? 0.20 : 0.12)
                            : context.colors.surfaceVariant,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        size: 20,
                        color: active ? color : context.colors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Başlık
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                        color: active
                            ? context.colors.textPrimary
                            : context.colors.textTertiary,
                      ),
                    ),
                    // "Yakında" etiketi
                    if (!active) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: context.colors.border.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Yakında',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w600,
                            color: context.colors.textTertiary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Tab butonu (paylaşımlı) ──────────────────────────────────────────────────

class _TabBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _TabBtn({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: active ? AppColors.teal : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: active ? Colors.white : context.colors.textSecondary,
              fontWeight: FontWeight.w800,
              fontSize: 13,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Backlog Ekranı ───────────────────────────────────────────────────────────

class _BacklogView extends StatefulWidget {
  final VoidCallback onBack;
  const _BacklogView({super.key, required this.onBack});

  @override
  State<_BacklogView> createState() => _BacklogViewState();
}

class _BacklogViewState extends State<_BacklogView> {
  String _tab = 'bug';
  String? _filterCat;
  bool _showCompleted = true;
  bool _showArchive = false;
  final Set<String> _expanded = {};

  List<_BacklogItem> _allItems = [];
  List<_Milestone> _activeMilestones = [];
  List<_Milestone> _completedMilestones = [];
  bool _loading = true;

  StreamSubscription<QuerySnapshot>? _itemSub;
  StreamSubscription<QuerySnapshot>? _msSub;

  // backward compat helper for _buildRows / _GapTarget
  List<_Milestone> get _milestones => _activeMilestones;

  @override
  void initState() {
    super.initState();
    _itemSub = FirebaseFirestore.instance.collection('app_backlog').snapshots().listen((s) {
      setState(() {
        _allItems = s.docs.map(_BacklogItem.fromDoc).toList()
          ..sort((a, b) => a.order.compareTo(b.order));
        _loading = false;
      });
    });
    _msSub = FirebaseFirestore.instance.collection('app_milestones').snapshots().listen((s) {
      final all = s.docs.map(_Milestone.fromDoc).toList();
      setState(() {
        _activeMilestones = all.where((m) => m.status == 'active').toList()
          ..sort((a, b) => _cmpVersion(a.version, b.version));
        _completedMilestones = all.where((m) => m.status == 'completed').toList()
          ..sort((a, b) => _cmpVersion(b.version, a.version));
      });
    });
  }

  static int _cmpVersion(String a, String b) {
    List<int> parse(String v) => v.replaceFirst(RegExp(r'^[vV]'), '').split('.').map((s) => int.tryParse(s) ?? 0).toList();
    final pa = parse(a), pb = parse(b);
    final len = pa.length > pb.length ? pa.length : pb.length;
    for (var i = 0; i < len; i++) {
      final diff = (i < pa.length ? pa[i] : 0) - (i < pb.length ? pb[i] : 0);
      if (diff != 0) return diff;
    }
    return 0;
  }

  @override
  void dispose() {
    _itemSub?.cancel();
    _msSub?.cancel();
    super.dispose();
  }

  void _toggleSection(String id) =>
      setState(() => _expanded.contains(id) ? _expanded.remove(id) : _expanded.add(id));

  Future<void> _complete(String id, bool cur) =>
      FirebaseFirestore.instance.collection('app_backlog').doc(id).update({'completed': !cur});

  Future<void> _archive(String id) =>
      FirebaseFirestore.instance.collection('app_backlog').doc(id).update({'archived': true});

  Future<void> _delete(String id) =>
      FirebaseFirestore.instance.collection('app_backlog').doc(id).delete();

  Future<void> _assignToMilestone(String itemId, String? milestoneId) =>
      FirebaseFirestore.instance.collection('app_backlog').doc(itemId).update({'milestoneId': milestoneId ?? ''});

  // Düz liste: Map (header), _BacklogItem (kart) veya _Gap (sıralama drop zone)
  List<Object> _buildRows(List<_BacklogItem> items) {
    final rows = <Object>[];
    final activeMilestoneIds = _milestones.map((m) => m.id).toSet();

    void addItemsWithGaps(String sectionId, List<_BacklogItem> sectionItems) {
      rows.add(_Gap(sectionId: sectionId, sectionItems: sectionItems, insertAt: 0, activeMilestoneIds: activeMilestoneIds));
      for (var j = 0; j < sectionItems.length; j++) {
        rows.add(sectionItems[j]);
        rows.add(_Gap(sectionId: sectionId, sectionItems: sectionItems, insertAt: j + 1, activeMilestoneIds: activeMilestoneIds));
      }
    }

    for (final ms in _milestones) {
      final msItems = items.where((i) => i.milestoneId == ms.id).toList();
      rows.add({'type': 'ms', 'ms': ms, 'count': msItems.where((i) => !i.completed).length});
      if (_expanded.contains(ms.id)) addItemsWithGaps(ms.id, msItems);
    }

    final allMilestoneIds = {...activeMilestoneIds, ..._completedMilestones.map((m) => m.id)};
    final unassigned = items.where((i) =>
      i.milestoneId == null ||
      i.milestoneId!.isEmpty ||
      !allMilestoneIds.contains(i.milestoneId)
    ).toList();
    if (unassigned.isNotEmpty) {
      rows.add({'type': 'un', 'count': unassigned.where((i) => !i.completed).length});
      if (_expanded.contains('__unassigned')) addItemsWithGaps('__unassigned', unassigned);
    }

    // Tamamlanan milestone'lar — listede en altta, daraltılmış bölüm
    if (_completedMilestones.isNotEmpty) {
      rows.add({'type': 'comp_divider', 'count': _completedMilestones.length});
      if (_expanded.contains('__completed')) {
        for (final ms in _completedMilestones) {
          final msItems = items.where((i) => i.milestoneId == ms.id).toList();
          rows.add({'type': 'ms_done', 'ms': ms, 'count': msItems.length});
          if (_expanded.contains('${ms.id}_done')) addItemsWithGaps(ms.id, msItems);
        }
      }
    }

    return rows;
  }

  Future<void> _reorderInSection(List<_BacklogItem> sectionItems, _BacklogItem draggedItem, int insertAt) async {
    final currentIndex = sectionItems.indexWhere((i) => i.id == draggedItem.id);
    if (currentIndex == -1) return;
    final reordered = List<_BacklogItem>.from(sectionItems);
    reordered.removeAt(currentIndex);
    final adjusted = (currentIndex < insertAt) ? insertAt - 1 : insertAt;
    reordered.insert(adjusted.clamp(0, reordered.length), draggedItem);
    final unchanged = Iterable.generate(reordered.length, (i) => reordered[i].id == sectionItems[i].id).every((x) => x);
    if (unchanged) return;
    final batch = FirebaseFirestore.instance.batch();
    for (var i = 0; i < reordered.length; i++) {
      batch.update(FirebaseFirestore.instance.collection('app_backlog').doc(reordered[i].id), {'order': i * 1000});
    }
    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    if (_showArchive) return _ArchiveView(onBack: () => setState(() => _showArchive = false));

    final tabItems = _allItems.where((i) {
      if (i.archived) return false;
      if (_tab == 'plan') return i.type == 'plan' || i.type == 'todo';
      return i.type == _tab;
    }).toList();
    final archivedCount = _allItems.where((i) => i.archived).length;
    final cats = tabItems.map((i) => i.category).toSet().toList()..sort();
    final filtered = _filterCat == null ? tabItems : tabItems.where((i) => i.category == _filterCat).toList();
    final displayed = _showCompleted ? filtered : filtered.where((i) => !i.completed).toList();
    final openCount = tabItems.where((i) => !i.completed).length;
    final rows = _tab == 'plan' ? _buildRows(displayed) : <Object>[];

    return Scaffold(
      backgroundColor: context.colors.surface,
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(4, 16, 12, 16),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.colors.border))),
            child: Row(children: [
              IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: context.colors.textPrimary), onPressed: widget.onBack),
              Text('Backlog', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: context.colors.textPrimary)),
              const Spacer(),
              if (openCount > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: context.colors.tealSurface, borderRadius: BorderRadius.circular(999)),
                  child: Text('$openCount açık', style: const TextStyle(fontSize: 11, color: AppColors.teal, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 8),
              ],
              GestureDetector(
                onTap: () => _MilestoneManagerSheet.show(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.teal.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.teal.withValues(alpha: 0.25))),
                  child: const Row(children: [Icon(Icons.flag_outlined, size: 14, color: AppColors.teal), SizedBox(width: 4), Text('Milestone', style: TextStyle(fontSize: 11, color: AppColors.teal, fontWeight: FontWeight.w700))]),
                ),
              ),
              const SizedBox(width: 8),
              if (archivedCount > 0) ...[
                GestureDetector(
                  onTap: () => setState(() => _showArchive = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFF1E293B).withValues(alpha: 0.07), borderRadius: BorderRadius.circular(8)),
                    child: Row(children: [Icon(Icons.archive_outlined, size: 14, color: context.colors.textSecondary), const SizedBox(width: 4), Text('$archivedCount', style: TextStyle(fontSize: 11, color: context.colors.textSecondary, fontWeight: FontWeight.w700))]),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              GestureDetector(
                onTap: () => setState(() => _showCompleted = !_showCompleted),
                child: Icon(_showCompleted ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20, color: _showCompleted ? AppColors.teal : context.colors.textTertiary),
              ),
            ]),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Container(
              height: 44,
              decoration: BoxDecoration(color: context.colors.surfaceVariant, borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                _TabBtn(label: 'BUGS',    active: _tab == 'bug',  onTap: () => setState(() { _tab = 'bug';  _filterCat = null; })),
                _TabBtn(label: 'PLAN',    active: _tab == 'plan', onTap: () => setState(() { _tab = 'plan'; _filterCat = null; })),
                _TabBtn(label: 'FİKİRLER', active: _tab == 'idea', onTap: () => setState(() { _tab = 'idea'; _filterCat = null; })),
              ]),
            ),
          ),

          if (cats.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 34,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _CatChip(label: 'Tümü', color: AppColors.teal, active: _filterCat == null, onTap: () => setState(() => _filterCat = null)),
                  ...cats.map((c) => Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: _CatChip(label: c, color: _catColor(c), active: _filterCat == c, onTap: () => setState(() => _filterCat = _filterCat == c ? null : c)),
                  )),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _CatManagerSheet.show(context, _tab),
                    child: Container(
                      height: 30,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      alignment: Alignment.center,
                      child: Icon(Icons.tune_rounded, size: 15, color: context.colors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 4),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.teal, strokeWidth: 2))
                : displayed.isEmpty
                    ? _EmptyState(tab: _tab)
                    : _tab == 'idea'
                        ? _IdeaList(items: displayed, existingCats: cats, onToggle: _complete, onArchive: _archive, onDelete: _delete, onReorder: (item, insertAt) => _reorderInSection(displayed, item, insertAt))
                        : _tab == 'bug'
                            ? _BugList(
                                items: displayed,
                                existingCats: cats,
                                onToggle: _complete,
                                onArchive: _archive,
                                onDelete: _delete,
                                onReorder: (item, insertAt) => _reorderInSection(displayed, item, insertAt),
                              )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                            itemCount: rows.length,
                            itemBuilder: (ctx, i) {
                              final row = rows[i];
                              if (row is _Gap) {
                                return _GapTarget(
                                  key: ValueKey('gap_${row.sectionId}_${row.insertAt}'),
                                  gap: row,
                                  onInsert: (item) => _reorderInSection(row.sectionItems, item, row.insertAt),
                                );
                              }
                              if (row is Map<String, Object>) {
                                final type = row['type'] as String;
                                if (type == 'ms') {
                                  final ms = row['ms'] as _Milestone;
                                  return _MilestoneHeader(
                                    key: ValueKey('ms_${ms.id}'),
                                    milestone: ms,
                                    itemCount: row['count'] as int,
                                    isCollapsed: !_expanded.contains(ms.id),
                                    onToggle: () => _toggleSection(ms.id),
                                    onAcceptDrop: (item) {
                                      _assignToMilestone(item.id, ms.id);
                                      if (!_expanded.contains(ms.id)) _toggleSection(ms.id);
                                    },
                                  );
                                }
                                if (type == 'comp_divider') {
                                  final n = row['count'] as int;
                                  final open = _expanded.contains('__completed');
                                  return _CompletedDivider(
                                    key: const ValueKey('comp_divider'),
                                    count: n,
                                    isOpen: open,
                                    onToggle: () => _toggleSection('__completed'),
                                  );
                                }
                                if (type == 'ms_done') {
                                  final ms = row['ms'] as _Milestone;
                                  final key = '${ms.id}_done';
                                  return _MilestoneHeader(
                                    key: ValueKey('ms_done_${ms.id}'),
                                    milestone: ms,
                                    itemCount: row['count'] as int,
                                    isCollapsed: !_expanded.contains(key),
                                    onToggle: () => _toggleSection(key),
                                    isDone: true,
                                  );
                                }
                                return _UnassignedHeader(
                                  key: const ValueKey('un_header'),
                                  itemCount: row['count'] as int,
                                  isCollapsed: !_expanded.contains('__unassigned'),
                                  onToggle: () => _toggleSection('__unassigned'),
                                  onAcceptDrop: (item) => _assignToMilestone(item.id, null),
                                );
                              }
                              final item = row as _BacklogItem;
                              final card = _BacklogCard(
                                key: ValueKey(item.id),
                                item: item,
                                onToggle: () => _complete(item.id, item.completed),
                                onArchive: () => _archive(item.id),
                                onDelete: () => _delete(item.id),
                                onEdit: () => showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (ctx) => Padding(
                                    padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
                                    child: _AddItemSheet(initialType: item.type, existingCats: cats, editItem: item),
                                  ),
                                ),
                              );
                              return LongPressDraggable<_BacklogItem>(
                                data: item,
                                delay: const Duration(milliseconds: 350),
                                feedback: Material(
                                  elevation: 8,
                                  borderRadius: BorderRadius.circular(12),
                                  color: Colors.transparent,
                                  child: Container(
                                    width: MediaQuery.of(ctx).size.width - 32,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: context.colors.surface,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: AppColors.teal.withValues(alpha: 0.4), width: 1.5),
                                    ),
                                    child: Row(children: [
                                      Container(width: 3, height: 32, decoration: BoxDecoration(color: _priorityColor(item.priority), borderRadius: BorderRadius.circular(999))),
                                      const SizedBox(width: 10),
                                      Expanded(child: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.colors.textPrimary))),
                                    ]),
                                  ),
                                ),
                                childWhenDragging: Opacity(opacity: 0.3, child: card),
                                child: card,
                              );
                            },
                          ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (ctx) => Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: _AddItemSheet(initialType: _tab, existingCats: cats),
            ),
          );
        },
        backgroundColor: AppColors.teal,
        elevation: 3,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(_tab == 'bug' ? 'Bug Ekle' : _tab == 'plan' ? 'Görev Ekle' : 'Fikir Ekle',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
      ),
    );
  }
}

class _MilestoneHeader extends StatelessWidget {
  final _Milestone milestone;
  final int itemCount;
  final bool isCollapsed;
  final VoidCallback onToggle;
  final void Function(_BacklogItem)? onAcceptDrop;
  final bool isDone;

  const _MilestoneHeader({
    super.key,
    required this.milestone,
    required this.itemCount,
    required this.isCollapsed,
    required this.onToggle,
    this.onAcceptDrop,
    this.isDone = false,
  });

  @override
  Widget build(BuildContext context) {
    return DragTarget<_BacklogItem>(
      onWillAcceptWithDetails: (d) => !isDone && d.data.milestoneId != milestone.id,
      onAcceptWithDetails: (d) => onAcceptDrop?.call(d.data),
      builder: (ctx, candidates, _) {
        final over = candidates.isNotEmpty;
        final badgeColor = isDone ? context.colors.textSecondary : AppColors.teal;
        final bgColor = isDone
            ? context.colors.surfaceVariant
            : over ? AppColors.teal.withValues(alpha: 0.08) : const Color(0xFF1E293B).withValues(alpha: 0.04);
        final borderColor = isDone
            ? context.colors.border
            : over ? AppColors.teal.withValues(alpha: 0.45) : const Color(0xFF1E293B).withValues(alpha: 0.08);
        return GestureDetector(
          onTap: onToggle,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.only(top: 8, bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor, width: over ? 1.5 : 1.0),
            ),
            child: Row(children: [
              if (isDone) ...[
                Icon(Icons.check_circle_outline_rounded, size: 13, color: context.colors.textSecondary),
                const SizedBox(width: 6),
              ],
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: badgeColor.withValues(alpha: isDone ? 0.15 : 1.0), borderRadius: BorderRadius.circular(6)),
                child: Text(milestone.version, style: TextStyle(color: isDone ? context.colors.textSecondary : Colors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(milestone.title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isDone ? context.colors.textSecondary : context.colors.textPrimary))),
              if (over) ...[
                const Icon(Icons.add_circle_rounded, size: 16, color: AppColors.teal),
                const SizedBox(width: 6),
              ],
              if (itemCount > 0 && !over) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDone ? context.colors.border : context.colors.tealSurface,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(isDone ? '$itemCount görev' : '$itemCount açık',
                      style: TextStyle(fontSize: 10, color: isDone ? context.colors.textSecondary : AppColors.teal, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 8),
              ],
              Icon(
                isCollapsed ? Icons.keyboard_arrow_right_rounded : Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: over ? AppColors.teal : context.colors.textSecondary,
              ),
            ]),
          ),
        );
      },
    );
  }
}

class _UnassignedHeader extends StatelessWidget {
  final int itemCount;
  final bool isCollapsed;
  final VoidCallback onToggle;
  final void Function(_BacklogItem)? onAcceptDrop;

  const _UnassignedHeader({super.key, required this.itemCount, required this.isCollapsed, required this.onToggle, this.onAcceptDrop});

  @override
  Widget build(BuildContext context) {
    return DragTarget<_BacklogItem>(
      onWillAcceptWithDetails: (d) => d.data.milestoneId != null && d.data.milestoneId!.isNotEmpty,
      onAcceptWithDetails: (d) => onAcceptDrop?.call(d.data),
      builder: (ctx, candidates, _) {
        final over = candidates.isNotEmpty;
        return GestureDetector(
          onTap: onToggle,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: over ? context.colors.textSecondary.withValues(alpha: 0.08) : context.colors.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: over ? context.colors.textSecondary.withValues(alpha: 0.45) : context.colors.border,
                width: over ? 1.5 : 1.0,
              ),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: context.colors.border, borderRadius: BorderRadius.circular(6)),
                child: Text('—', style: TextStyle(color: context.colors.textSecondary, fontSize: 10, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text('Milestone\'suz', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.colors.textSecondary))),
              if (over) ...[
                Icon(Icons.remove_circle_outline_rounded, size: 16, color: context.colors.textSecondary),
                const SizedBox(width: 6),
              ],
              if (itemCount > 0 && !over) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: context.colors.border, borderRadius: BorderRadius.circular(999)),
                  child: Text('$itemCount açık', style: TextStyle(fontSize: 10, color: context.colors.textSecondary, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 8),
              ],
              Icon(
                isCollapsed ? Icons.keyboard_arrow_right_rounded : Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: context.colors.textSecondary,
              ),
            ]),
          ),
        );
      },
    );
  }
}

// ─── Tamamlanan Sürümler Divider ──────────────────────────────────────────────

class _CompletedDivider extends StatelessWidget {
  final int count;
  final bool isOpen;
  final VoidCallback onToggle;
  const _CompletedDivider({super.key, required this.count, required this.isOpen, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        margin: const EdgeInsets.only(top: 16, bottom: 4),
        child: Row(children: [
          Expanded(child: Container(height: 1, color: context.colors.border)),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: context.colors.surfaceVariant,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: context.colors.border),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.check_circle_outline_rounded, size: 12, color: context.colors.textSecondary),
              const SizedBox(width: 5),
              Text('Tamamlanan Sürümler ($count)',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.colors.textSecondary)),
              const SizedBox(width: 4),
              Icon(isOpen ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                  size: 14, color: context.colors.textSecondary),
            ]),
          ),
          const SizedBox(width: 10),
          Expanded(child: Container(height: 1, color: context.colors.border)),
        ]),
      ),
    );
  }
}

// ─── Gap Drop Target (within-section reorder) ─────────────────────────────────

class _GapTarget extends StatelessWidget {
  final _Gap gap;
  final void Function(_BacklogItem) onInsert;

  const _GapTarget({super.key, required this.gap, required this.onInsert});

  String _itemSection(_BacklogItem item) {
    if (item.milestoneId != null && item.milestoneId!.isNotEmpty && gap.activeMilestoneIds.contains(item.milestoneId)) {
      return item.milestoneId!;
    }
    return '__unassigned';
  }

  @override
  Widget build(BuildContext context) {
    return DragTarget<_BacklogItem>(
      onWillAcceptWithDetails: (d) => _itemSection(d.data) == gap.sectionId,
      onAcceptWithDetails: (d) => onInsert(d.data),
      builder: (ctx, candidates, _) {
        final over = candidates.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: over ? 24 : 4,
          margin: over ? const EdgeInsets.symmetric(vertical: 2) : EdgeInsets.zero,
          decoration: over
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: AppColors.teal.withValues(alpha: 0.06),
                  border: Border.all(color: AppColors.teal.withValues(alpha: 0.4), width: 1.5),
                )
              : null,
          child: over
              ? const Center(child: Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: AppColors.teal))
              : null,
        );
      },
    );
  }
}

// ─── Backlog Kart ─────────────────────────────────────────────────────────────

class _BacklogCard extends StatelessWidget {
  final _BacklogItem item;
  final VoidCallback onToggle;
  final VoidCallback onArchive;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _BacklogCard({super.key, required this.item, required this.onToggle, required this.onArchive, required this.onDelete, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        color: item.completed ? const Color(0xFFF9FAFB) : context.colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 3, color: _priorityColor(item.priority)),
              const SizedBox(width: 7),
              GestureDetector(
                onTap: onToggle,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 20, height: 20,
                    decoration: BoxDecoration(
                      color: item.completed ? AppColors.teal : Colors.transparent,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: item.completed ? AppColors.teal : context.colors.border, width: 1.5),
                    ),
                    child: item.completed ? const Icon(Icons.check_rounded, color: Colors.white, size: 13) : null,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    item.title,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: item.completed ? context.colors.textTertiary : context.colors.textPrimary,
                      decoration: item.completed ? TextDecoration.lineThrough : null,
                      decorationColor: context.colors.textTertiary,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Center(child: _CatBadge(cat: item.category)),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, size: 16, color: context.colors.textTertiary),
                padding: EdgeInsets.zero,
                onSelected: (val) {
                  if (val == 'edit') onEdit();
                  if (val == 'archive') onArchive();
                  if (val == 'delete') onDelete();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 16), SizedBox(width: 8), Text('Düzenle')])),
                  const PopupMenuItem(value: 'archive', child: Row(children: [Icon(Icons.archive_outlined, size: 16), SizedBox(width: 8), Text('Arşivle')])),
                  PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, size: 16, color: AppColors.errorRed), const SizedBox(width: 8), Text('Sil', style: TextStyle(color: AppColors.errorRed))])),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Fikir Listesi ────────────────────────────────────────────────────────────

class _IdeaList extends StatelessWidget {
  final List<_BacklogItem> items;
  final List<String> existingCats;
  final Future<void> Function(String, bool) onToggle;
  final Future<void> Function(String) onArchive;
  final Future<void> Function(String) onDelete;
  final void Function(_BacklogItem, int) onReorder;

  const _IdeaList({required this.items, required this.existingCats, required this.onToggle, required this.onArchive, required this.onDelete, required this.onReorder});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      itemCount: items.length * 2 + 1,
      itemBuilder: (context, i) {
        if (i.isEven) {
          final insertAt = i ~/ 2;
          return _BugGap(
            key: ValueKey('idea_gap_$insertAt'),
            onWillAccept: (_) => true,
            onAccept: (item) => onReorder(item, insertAt),
          );
        }
        final item = items[i ~/ 2];
        final dismissible = Dismissible(
          key: ValueKey('dismiss_${item.id}'),
          direction: DismissDirection.horizontal,
          background: Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 20),
            margin: const EdgeInsets.symmetric(vertical: 3),
            decoration: BoxDecoration(color: AppColors.teal, borderRadius: BorderRadius.circular(12)),
            child: const Row(children: [
              Icon(Icons.archive_outlined, color: Colors.white, size: 18),
              SizedBox(width: 6),
              Text('Arşivle', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
            ]),
          ),
          secondaryBackground: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            margin: const EdgeInsets.symmetric(vertical: 3),
            decoration: BoxDecoration(color: AppColors.errorRed, borderRadius: BorderRadius.circular(12)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Text('Sil', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
              SizedBox(width: 6),
              Icon(Icons.delete_outline, color: Colors.white, size: 18),
            ]),
          ),
          confirmDismiss: (dir) async {
            if (dir == DismissDirection.startToEnd) { await onArchive(item.id); return false; }
            return true;
          },
          onDismissed: (_) => onDelete(item.id),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 3),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: item.completed ? const Color(0xFFF9FAFB) : context.colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.colors.border),
            ),
            child: Row(children: [
              GestureDetector(
                onTap: () => onToggle(item.id, item.completed),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 20, height: 20,
                  decoration: BoxDecoration(
                    color: item.completed ? AppColors.teal : Colors.transparent,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: item.completed ? AppColors.teal : context.colors.border, width: 1.5),
                  ),
                  child: item.completed ? const Icon(Icons.check_rounded, color: Colors.white, size: 13) : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.title,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: item.completed ? context.colors.textTertiary : context.colors.textPrimary,
                    decoration: item.completed ? TextDecoration.lineThrough : null,
                    decorationColor: context.colors.textTertiary,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _CatBadge(cat: item.category),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, size: 16, color: context.colors.textTertiary),
                padding: EdgeInsets.zero,
                onSelected: (val) {
                  if (val == 'edit') {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (ctx) => Padding(
                        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
                        child: _AddItemSheet(initialType: item.type, existingCats: existingCats, editItem: item),
                      ),
                    );
                  }
                  if (val == 'archive') onArchive(item.id);
                  if (val == 'delete') onDelete(item.id);
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 16), SizedBox(width: 8), Text('Düzenle')])),
                  const PopupMenuItem(value: 'archive', child: Row(children: [Icon(Icons.archive_outlined, size: 16), SizedBox(width: 8), Text('Arşivle')])),
                  PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, size: 16, color: AppColors.errorRed), const SizedBox(width: 8), Text('Sil', style: TextStyle(color: AppColors.errorRed))])),
                ],
              ),
            ]),
          ),
        );
        return LongPressDraggable<_BacklogItem>(
          data: item,
          delay: const Duration(milliseconds: 350),
          feedback: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            color: Colors.transparent,
            child: Container(
              width: MediaQuery.of(context).size.width - 32,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.teal.withValues(alpha: 0.4), width: 1.5),
              ),
              child: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: context.colors.textPrimary)),
            ),
          ),
          childWhenDragging: Opacity(opacity: 0.3, child: dismissible),
          child: dismissible,
        );
      },
    );
  }
}

// ─── Bug Listesi (düz, milestone'suz) ────────────────────────────────────────

class _BugList extends StatelessWidget {
  final List<_BacklogItem> items;
  final List<String> existingCats;
  final Future<void> Function(String, bool) onToggle;
  final Future<void> Function(String) onArchive;
  final Future<void> Function(String) onDelete;
  final void Function(_BacklogItem, int) onReorder;

  const _BugList({
    required this.items,
    required this.existingCats,
    required this.onToggle,
    required this.onArchive,
    required this.onDelete,
    required this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      itemCount: items.length * 2 + 1,
      itemBuilder: (ctx, i) {
        if (i.isEven) {
          final insertAt = i ~/ 2;
          return _BugGap(
            key: ValueKey('bug_gap_$insertAt'),
            onWillAccept: (_) => true,
            onAccept: (item) => onReorder(item, insertAt),
          );
        }
        final item = items[i ~/ 2];
        final allCats = existingCats;
        final card = _BacklogCard(
          key: ValueKey(item.id),
          item: item,
          onToggle: () => onToggle(item.id, item.completed),
          onArchive: () => onArchive(item.id),
          onDelete: () => onDelete(item.id),
          onEdit: () => showModalBottomSheet(
            context: ctx,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (c) => Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom),
              child: _AddItemSheet(initialType: 'bug', existingCats: allCats, editItem: item),
            ),
          ),
        );
        return LongPressDraggable<_BacklogItem>(
          data: item,
          delay: const Duration(milliseconds: 350),
          feedback: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            color: Colors.transparent,
            child: Container(
              width: MediaQuery.of(ctx).size.width - 32,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.teal.withValues(alpha: 0.4), width: 1.5),
              ),
              child: Row(children: [
                Container(width: 3, height: 32, decoration: BoxDecoration(color: _priorityColor(item.priority), borderRadius: BorderRadius.circular(999))),
                const SizedBox(width: 10),
                Expanded(child: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.colors.textPrimary))),
              ]),
            ),
          ),
          childWhenDragging: Opacity(opacity: 0.3, child: card),
          child: Dismissible(
            key: ValueKey('dismiss_${item.id}'),
            background: Container(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: 20),
              margin: const EdgeInsets.symmetric(vertical: 3),
              decoration: BoxDecoration(color: AppColors.teal, borderRadius: BorderRadius.circular(12)),
              child: const Row(children: [
                Icon(Icons.archive_outlined, color: Colors.white, size: 18),
                SizedBox(width: 6),
                Text('Arşivle', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
              ]),
            ),
            secondaryBackground: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              margin: const EdgeInsets.symmetric(vertical: 3),
              decoration: BoxDecoration(color: AppColors.errorRed, borderRadius: BorderRadius.circular(12)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Text('Sil', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                SizedBox(width: 6),
                Icon(Icons.delete_outline, color: Colors.white, size: 18),
              ]),
            ),
            confirmDismiss: (dir) async {
              if (dir == DismissDirection.startToEnd) {
                await onArchive(item.id);
                return false;
              }
              return true;
            },
            onDismissed: (_) => onDelete(item.id),
            child: card,
          ),
        );
      },
    );
  }
}

class _BugGap extends StatelessWidget {
  final bool Function(_BacklogItem) onWillAccept;
  final void Function(_BacklogItem) onAccept;
  const _BugGap({super.key, required this.onWillAccept, required this.onAccept});

  @override
  Widget build(BuildContext context) {
    return DragTarget<_BacklogItem>(
      onWillAcceptWithDetails: (d) => onWillAccept(d.data),
      onAcceptWithDetails: (d) => onAccept(d.data),
      builder: (ctx, candidates, _) {
        final over = candidates.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: over ? 24 : 4,
          margin: over ? const EdgeInsets.symmetric(vertical: 2) : EdgeInsets.zero,
          decoration: over
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: AppColors.teal.withValues(alpha: 0.06),
                  border: Border.all(color: AppColors.teal.withValues(alpha: 0.4), width: 1.5),
                )
              : null,
          child: over ? const Center(child: Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: AppColors.teal)) : null,
        );
      },
    );
  }
}

// ─── Arşiv Ekranı ─────────────────────────────────────────────────────────────

class _ArchiveView extends StatefulWidget {
  final VoidCallback onBack;
  const _ArchiveView({required this.onBack});

  @override
  State<_ArchiveView> createState() => _ArchiveViewState();
}

class _ArchiveViewState extends State<_ArchiveView> {
  String _tab = 'bug';
  static const _col = 'app_backlog';

  Future<void> _unarchive(String id) =>
      FirebaseFirestore.instance.collection(_col).doc(id).update({'archived': false});
  Future<void> _delete(String id) =>
      FirebaseFirestore.instance.collection(_col).doc(id).delete();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.surface,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection(_col).snapshots(),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Yükleme hatası', style: TextStyle(color: context.colors.textSecondary)));
          final allItems = (snap.data?.docs ?? []).map((d) => _BacklogItem.fromDoc(d)).toList()
              ..sort((a, b) => a.order.compareTo(b.order));
          final tabItems = allItems.where((i) {
                if (!i.archived) return false;
                if (_tab == 'plan') return i.type == 'plan' || i.type == 'todo';
                return i.type == _tab;
              }).toList();

          return Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(4, 16, 16, 16),
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.colors.border))),
                child: Row(children: [
                  IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: context.colors.textPrimary), onPressed: widget.onBack),
                  Icon(Icons.archive_outlined, size: 18, color: context.colors.textPrimary),
                  const SizedBox(width: 8),
                  Text('Arşiv', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: context.colors.textPrimary)),
                  const Spacer(),
                  Text('${tabItems.length} öğe', style: TextStyle(fontSize: 12, color: context.colors.textSecondary)),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(color: context.colors.surfaceVariant, borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    _TabBtn(label: 'BUGS',    active: _tab == 'bug',  onTap: () => setState(() => _tab = 'bug')),
                    _TabBtn(label: 'PLAN',    active: _tab == 'plan', onTap: () => setState(() => _tab = 'plan')),
                    _TabBtn(label: 'FİKİRLER', active: _tab == 'idea', onTap: () => setState(() => _tab = 'idea')),
                  ]),
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: snap.connectionState == ConnectionState.waiting
                    ? const Center(child: CircularProgressIndicator(color: AppColors.teal, strokeWidth: 2))
                    : tabItems.isEmpty
                        ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(Icons.archive_outlined, size: 48, color: context.colors.border),
                            const SizedBox(height: 12),
                            Text('Arşiv boş', style: TextStyle(color: context.colors.textSecondary, fontSize: 15)),
                          ]))
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                            itemCount: tabItems.length,
                            itemBuilder: (context, i) {
                              final item = tabItems[i];
                              return Dismissible(
                                key: ValueKey('arch_${item.id}'),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 20),
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  decoration: BoxDecoration(color: AppColors.errorRed, borderRadius: BorderRadius.circular(12)),
                                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                                    Text('Sil', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                                    SizedBox(width: 8),
                                    Icon(Icons.delete_outline, color: Colors.white, size: 20),
                                  ]),
                                ),
                                onDismissed: (_) => _delete(item.id),
                                child: Container(
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  decoration: BoxDecoration(
                                    color: context.colors.surface,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: context.colors.border),
                                  ),
                                  child: Row(children: [
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 13),
                                        child: Text(item.title, style: TextStyle(fontSize: 13.5, color: context.colors.textPrimary, fontWeight: FontWeight.w600, height: 1.4)),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    _CatBadge(cat: item.category),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      onPressed: () => _unarchive(item.id),
                                      icon: const Icon(Icons.unarchive_outlined, size: 18, color: AppColors.teal),
                                      tooltip: 'Arşivden çıkar',
                                    ),
                                  ]),
                                ),
                              );
                            },
                          ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Milestone Manager Sheet ──────────────────────────────────────────────────

class _MilestoneManagerSheet extends StatefulWidget {
  const _MilestoneManagerSheet();

  static Future<void> show(BuildContext context) =>
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.7,
          child: const ClipRRect(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            child: _MilestoneManagerSheet(),
          ),
        ),
      );

  @override
  State<_MilestoneManagerSheet> createState() => _MilestoneManagerSheetState();
}

class _MilestoneManagerSheetState extends State<_MilestoneManagerSheet> {
  static const _col = 'app_milestones';
  bool _showCompleted = false;

  Future<void> _completeMilestone(String id) =>
      FirebaseFirestore.instance.collection(_col).doc(id).update({'status': 'completed'});

  Future<void> _reactivateMilestone(String id) =>
      FirebaseFirestore.instance.collection(_col).doc(id).update({'status': 'active'});

  Future<void> _archiveMilestone(String id) =>
      FirebaseFirestore.instance.collection(_col).doc(id).update({'status': 'archived'});

  Future<void> _deleteMilestone(String id) =>
      FirebaseFirestore.instance.collection(_col).doc(id).delete();

  Future<void> _reorder(List<_Milestone> current, int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    final list = List<_Milestone>.from(current);
    list.insert(newIndex, list.removeAt(oldIndex));
    final batch = FirebaseFirestore.instance.batch();
    for (int i = 0; i < list.length; i++) {
      batch.update(FirebaseFirestore.instance.collection(_col).doc(list[i].id), {'order': i});
    }
    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.surface,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection(_col).snapshots(),
        builder: (context, snap) {
          final all = (snap.data?.docs ?? []).map((d) => _Milestone.fromDoc(d)).toList()
            ..sort((a, b) => a.order.compareTo(b.order));
          final milestones = all.where((m) => m.status == 'active').toList();
          final completed = all.where((m) => m.status == 'completed').toList();

          return Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.colors.border))),
                child: Row(children: [
                  Icon(Icons.flag_outlined, size: 20, color: context.colors.textPrimary),
                  const SizedBox(width: 10),
                  Text('Milestones', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: context.colors.textPrimary)),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close_rounded, color: context.colors.textSecondary, size: 20),
                  ),
                ]),
              ),

              Expanded(
                child: snap.connectionState == ConnectionState.waiting
                    ? const Center(child: CircularProgressIndicator(color: AppColors.teal, strokeWidth: 2))
                    : milestones.isEmpty
                        ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(Icons.flag_outlined, size: 48, color: context.colors.border),
                            const SizedBox(height: 12),
                            Text('Milestone yok', style: TextStyle(color: context.colors.textSecondary, fontSize: 15)),
                            const SizedBox(height: 4),
                            Text('Aşağıdan yeni milestone ekle', style: TextStyle(color: context.colors.textTertiary, fontSize: 12)),
                          ]))
                        : ReorderableListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                            buildDefaultDragHandles: false,
                            onReorder: (o, n) => _reorder(milestones, o, n),
                            itemCount: milestones.length,
                            itemBuilder: (context, i) {
                              final ms = milestones[i];
                              return Container(
                                key: ValueKey(ms.id),
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: context.colors.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: context.colors.border),
                                ),
                                child: Row(children: [
                                  ReorderableDragStartListener(
                                    index: i,
                                    child: Icon(Icons.drag_indicator_rounded, color: context.colors.textTertiary.withValues(alpha: 0.5), size: 18),
                                  ),
                                  const SizedBox(width: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(color: AppColors.teal, borderRadius: BorderRadius.circular(6)),
                                    child: Text(ms.version, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(child: Text(ms.title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.colors.textPrimary))),
                                  // Tamamlandı
                                  IconButton(
                                    tooltip: 'Tamamlandı olarak işaretle',
                                    onPressed: () => _completeMilestone(ms.id),
                                    icon: const Icon(Icons.check_circle_outline_rounded, size: 18, color: AppColors.teal),
                                  ),
                                  // Arşivle
                                  IconButton(
                                    onPressed: () => showDialog(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('Milestone\'u arşivle'),
                                        content: Text('"${ms.version} — ${ms.title}" tamamen arşive kaldırılacak.'),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
                                          TextButton(
                                            onPressed: () { Navigator.pop(ctx); _archiveMilestone(ms.id); },
                                            child: Text('Arşivle', style: TextStyle(color: context.colors.textSecondary)),
                                          ),
                                        ],
                                      ),
                                    ),
                                    icon: Icon(Icons.archive_outlined, size: 18, color: context.colors.textTertiary),
                                  ),
                                  // Sil
                                  IconButton(
                                    onPressed: () => showDialog(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('Milestone\'u sil'),
                                        content: const Text('Bu işlem geri alınamaz. Bağlı görevler milestone\'suz kalır.'),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
                                          TextButton(
                                            onPressed: () { Navigator.pop(ctx); _deleteMilestone(ms.id); },
                                            child: const Text('Sil', style: TextStyle(color: AppColors.errorRed)),
                                          ),
                                        ],
                                      ),
                                    ),
                                    icon: Icon(Icons.delete_outline, size: 18, color: context.colors.textTertiary),
                                  ),
                                ]),
                              );
                            },
                          ),
              ),

              // Tamamlanan milestone'lar — daraltılabilir
              if (completed.isNotEmpty) ...[
                Divider(height: 1, color: context.colors.border),
                InkWell(
                  onTap: () => setState(() => _showCompleted = !_showCompleted),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                    child: Row(children: [
                      Icon(Icons.check_circle_outline_rounded, size: 14, color: context.colors.textSecondary),
                      const SizedBox(width: 6),
                      Text('Tamamlananlar (${completed.length})',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.colors.textSecondary)),
                      const Spacer(),
                      Icon(
                        _showCompleted ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                        size: 16, color: context.colors.textSecondary,
                      ),
                    ]),
                  ),
                ),
                if (_showCompleted) ...[
                  ...completed.map((ms) => Container(
                    margin: const EdgeInsets.fromLTRB(16, 2, 16, 2),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: context.colors.surfaceVariant,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: context.colors.border),
                    ),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(color: context.colors.border, borderRadius: BorderRadius.circular(6)),
                        child: Text(ms.version, style: TextStyle(color: context.colors.textSecondary, fontSize: 10, fontWeight: FontWeight.w800)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(ms.title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.colors.textSecondary))),
                      TextButton(
                        onPressed: () => _reactivateMilestone(ms.id),
                        style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                        child: const Text('Geri Al', style: TextStyle(fontSize: 11, color: AppColors.teal, fontWeight: FontWeight.w700)),
                      ),
                      IconButton(
                        onPressed: () => showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Milestone\'u sil'),
                            content: const Text('Bu işlem geri alınamaz. Bağlı görevler milestone\'suz kalır.'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
                              TextButton(onPressed: () { Navigator.pop(ctx); _deleteMilestone(ms.id); }, child: const Text('Sil', style: TextStyle(color: AppColors.errorRed))),
                            ],
                          ),
                        ),
                        icon: Icon(Icons.delete_outline, size: 16, color: context.colors.textTertiary),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      ),
                    ]),
                  )),
                  const SizedBox(height: 8),
                ],
              ],

              // Yeni milestone ekle butonu
              Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).viewInsets.bottom + 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () => _NewMilestoneSheet.show(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.teal,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                    label: const Text('Yeni Milestone', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Yeni Milestone Sheet ─────────────────────────────────────────────────────

class _NewMilestoneSheet extends StatefulWidget {
  const _NewMilestoneSheet();

  static Future<void> show(BuildContext context) => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: const ClipRRect(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        child: _NewMilestoneSheet(),
      ),
    ),
  );

  @override
  State<_NewMilestoneSheet> createState() => _NewMilestoneSheetState();
}

class _NewMilestoneSheetState extends State<_NewMilestoneSheet> {
  final _titleCtrl = TextEditingController();
  final _versionCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() { _titleCtrl.dispose(); _versionCtrl.dispose(); super.dispose(); }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    final version = _versionCtrl.text.trim();
    if (title.isEmpty || version.isEmpty) return;
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('app_milestones').add({
        'title': title,
        'version': version,
        'status': 'active',
        'order': DateTime.now().millisecondsSinceEpoch,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSave = _titleCtrl.text.trim().isNotEmpty && _versionCtrl.text.trim().isNotEmpty;
    return Scaffold(
      backgroundColor: context.colors.surface,
      resizeToAvoidBottomInset: false,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: context.colors.border, borderRadius: BorderRadius.circular(999)))),
            const SizedBox(height: 16),
            Text('Yeni Milestone', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: context.colors.textPrimary)),
            const SizedBox(height: 16),
            // Version
            _InputField(controller: _versionCtrl, hint: 'Versiyon (örn: v1.1)', onChanged: (_) => setState(() {}), maxLines: 1),
            const SizedBox(height: 10),
            // Başlık
            _InputField(controller: _titleCtrl, hint: 'Başlık (örn: Beta Düzeltmeleri)', onChanged: (_) => setState(() {}), maxLines: 1),
            const SizedBox(height: 24),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: canSave ? 1.0 : 0.45,
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: (canSave && !_saving) ? _save : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.teal,
                    disabledBackgroundColor: AppColors.teal,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _saving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('OLUŞTUR', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 0.8, color: Colors.white)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Feedback Ekranı ──────────────────────────────────────────────────────────

class _FeedbackView extends StatefulWidget {
  final VoidCallback onBack;
  const _FeedbackView({super.key, required this.onBack});

  @override
  State<_FeedbackView> createState() => _FeedbackViewState();
}

class _FeedbackViewState extends State<_FeedbackView> {
  static const _col = 'feature_requests';
  static const _labelsCol = 'feedback_labels';

  List<_FeedbackItem> _items = [];
  List<_Label> _labels = [];
  String _activeFilter = '__inbox';
  bool _loading = true;

  StreamSubscription<QuerySnapshot>? _itemSub;
  StreamSubscription<QuerySnapshot>? _labelSub;

  @override
  void initState() {
    super.initState();
    _itemSub = FirebaseFirestore.instance.collection(_col).snapshots().listen((s) {
      setState(() {
        _items = s.docs
            .map((d) => _FeedbackItem.fromDoc(d))
            .where((f) => !f.archived)
            .toList()
          ..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
        _loading = false;
      });
    });
    _labelSub = FirebaseFirestore.instance.collection(_labelsCol).snapshots().listen((s) {
      setState(() => _labels = s.docs.map((d) => _Label.fromDoc(d)).toList());
    });
  }

  @override
  void dispose() {
    _itemSub?.cancel();
    _labelSub?.cancel();
    super.dispose();
  }

  List<_FeedbackItem> get _filtered {
    if (_activeFilter == '__inbox') return _items.where((f) => f.folderId == null || f.folderId!.isEmpty).toList();
    if (_activeFilter == '__all') return _items;
    return _items.where((f) => f.folderId == _activeFilter).toList();
  }

  Future<void> _markRead(String id) =>
      FirebaseFirestore.instance.collection(_col).doc(id).update({'isRead': true});
  Future<void> _archive(String id) =>
      FirebaseFirestore.instance.collection(_col).doc(id).update({'archived': true});
  Future<void> _delete(String id) =>
      FirebaseFirestore.instance.collection(_col).doc(id).delete();
  Future<void> _setFolder(String id, String? folderId) =>
      FirebaseFirestore.instance.collection(_col).doc(id).update({'folderId': folderId});

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: context.colors.surface,
        body: const Center(child: CircularProgressIndicator(color: AppColors.teal, strokeWidth: 2)),
      );
    }

    final filtered = _filtered;
    final inboxCount = _items.where((f) => f.folderId == null || f.folderId!.isEmpty).length;

    return Scaffold(
      backgroundColor: context.colors.surface,
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(4, 16, 16, 16),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.colors.border))),
            child: Row(children: [
              IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: context.colors.textPrimary),
                onPressed: widget.onBack,
              ),
              Text('Feedback', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: context.colors.textPrimary)),
              const Spacer(),
              if (inboxCount > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: context.colors.tealSurface, borderRadius: BorderRadius.circular(999)),
                  child: Text('$inboxCount bekliyor', style: const TextStyle(fontSize: 11, color: AppColors.teal, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 8),
              ],
              GestureDetector(
                onTap: () => _LabelManagerSheet.show(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: context.colors.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: context.colors.border),
                  ),
                  child: Row(children: [
                    Icon(Icons.folder_outlined, size: 14, color: context.colors.textSecondary),
                    const SizedBox(width: 4),
                    Text('Klasörler', style: TextStyle(fontSize: 11, color: context.colors.textSecondary, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            ]),
          ),

          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
              children: [
                _CatChip(label: 'Gelen Kutusu', color: AppColors.teal, active: _activeFilter == '__inbox', onTap: () => setState(() => _activeFilter = '__inbox')),
                const SizedBox(width: 8),
                _CatChip(label: 'Tümü', color: context.colors.textSecondary, active: _activeFilter == '__all', onTap: () => setState(() => _activeFilter = '__all')),
                ..._labels.map((l) => Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: _CatChip(label: l.name, color: l.color, active: _activeFilter == l.id, onTap: () => setState(() => _activeFilter = l.id)),
                )),
              ],
            ),
          ),

          const SizedBox(height: 4),

          Expanded(
            child: filtered.isEmpty
                ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(
                      _activeFilter == '__inbox' ? Icons.mark_email_read_outlined : Icons.folder_open_outlined,
                      size: 48, color: context.colors.border,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _activeFilter == '__inbox' ? 'Gelen kutusu boş — tüm feedbackler klasörlendi' : 'Bu klasörde feedback yok',
                      style: TextStyle(color: context.colors.textSecondary, fontSize: 15),
                      textAlign: TextAlign.center,
                    ),
                  ]))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final item = filtered[i];
                      return _FeedbackCard(
                        key: ValueKey(item.id),
                        item: item,
                        labels: _labels,
                        onMarkRead: () => _markRead(item.id),
                        onArchive: () => _archive(item.id),
                        onDelete: () => _delete(item.id),
                        onSetFolder: (folderId) => _setFolder(item.id, folderId),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _FeedbackCard extends StatefulWidget {
  final _FeedbackItem item;
  final List<_Label> labels;
  final VoidCallback onMarkRead;
  final VoidCallback onArchive;
  final VoidCallback onDelete;
  final void Function(String? folderId) onSetFolder;

  const _FeedbackCard({super.key, required this.item, required this.labels, required this.onMarkRead, required this.onArchive, required this.onDelete, required this.onSetFolder});

  @override
  State<_FeedbackCard> createState() => _FeedbackCardState();
}

class _FeedbackCardState extends State<_FeedbackCard> {
  bool _expanded = false;
  String? _userName;

  @override
  void initState() {
    super.initState();
    _loadUserName();
    if (!widget.item.isRead) widget.onMarkRead();
  }

  Future<void> _loadUserName() async {
    if (widget.item.uid.isEmpty) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(widget.item.uid).get();
      if (!mounted) return;
      final data = doc.data();
      setState(() => _userName = (data?['name'] as String?) ?? (data?['username'] as String?) ?? 'Kullanıcı');
    } catch (_) {}
  }

  void _promote(BuildContext context, String type) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _AddItemSheet(
          initialType: type,
          prefillText: widget.item.text,
          onSaved: () {
              FirebaseFirestore.instance
                  .collection('feature_requests')
                  .doc(widget.item.id)
                  .update({'archived': true});
            },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(widget.item.id),
      direction: DismissDirection.horizontal,
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(color: AppColors.teal, borderRadius: BorderRadius.circular(12)),
        child: const Row(children: [
          Icon(Icons.archive_outlined, color: Colors.white, size: 18),
          SizedBox(width: 6),
          Text('Arşivle', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
        ]),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(color: AppColors.errorRed, borderRadius: BorderRadius.circular(12)),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Text('Sil', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
          SizedBox(width: 6),
          Icon(Icons.delete_outline, color: Colors.white, size: 18),
        ]),
      ),
      confirmDismiss: (dir) async {
        if (dir == DismissDirection.startToEnd) { widget.onArchive(); return false; }
        return true;
      },
      onDismissed: (_) => widget.onDelete(),
      child: GestureDetector(
        onTap: () => setState(() => _expanded = !_expanded),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: widget.item.isRead ? context.colors.surface : context.colors.tealSurface.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: widget.item.isRead ? context.colors.border : AppColors.teal.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                // Okundu/okunmadı nokta
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    color: widget.item.isRead ? context.colors.border : AppColors.teal,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _userName ?? '...',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.colors.textPrimary),
                ),
                const Spacer(),
                Builder(builder: (context) {
                  final label = widget.labels.where((l) => l.id == widget.item.folderId).firstOrNull;
                  if (label == null) return const SizedBox.shrink();
                  return Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: label.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(label.name, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: label.color)),
                  );
                }),
                Text(_relativeTime(widget.item.createdAt), style: TextStyle(fontSize: 11, color: context.colors.textTertiary)),
                const SizedBox(width: 6),
                Icon(
                  _expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                  size: 16, color: context.colors.textTertiary,
                ),
              ]),
              const SizedBox(height: 8),
              Text(
                widget.item.text,
                style: TextStyle(fontSize: 13.5, color: context.colors.textPrimary, height: 1.4),
                maxLines: _expanded ? null : 2,
                overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
              ),

              // Aksiyon butonları (açıkken)
              if (_expanded) ...[
                const SizedBox(height: 12),
                Divider(height: 1, color: context.colors.border),
                const SizedBox(height: 10),
                Row(children: [
                  _PromoteBtn(label: 'Bug Ekle', color: AppColors.errorRed, onTap: () => _promote(context, 'bug')),
                  const SizedBox(width: 8),
                  _PromoteBtn(label: 'Fikre Ekle', color: context.colors.textSecondary, onTap: () => _promote(context, 'idea')),
                  const SizedBox(width: 8),
                  _PromoteBtn(label: 'Plana Ekle', color: AppColors.teal, onTap: () => _promote(context, 'plan')),
                  const Spacer(),
                  GestureDetector(
                    onTap: widget.onArchive,
                    child: Icon(Icons.archive_outlined, size: 18, color: context.colors.textTertiary),
                  ),
                ]),
                if (widget.labels.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Divider(height: 1, color: context.colors.border),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text('Klasör', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.colors.textSecondary)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Wrap(
                          spacing: 6, runSpacing: 4,
                          children: [
                            GestureDetector(
                              onTap: () => widget.onSetFolder(null),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: widget.item.folderId == null ? context.colors.textSecondary : context.colors.border,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text('Yok', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: widget.item.folderId == null ? Colors.white : context.colors.textSecondary)),
                              ),
                            ),
                            ...widget.labels.map((l) => GestureDetector(
                              onTap: () => widget.onSetFolder(l.id),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: widget.item.folderId == l.id ? l.color : l.color.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(l.name, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: widget.item.folderId == l.id ? Colors.white : l.color)),
                              ),
                            )),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PromoteBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _PromoteBtn({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      ),
    );
  }
}

// ─── Klasör Yöneticisi ────────────────────────────────────────────────────────

class _LabelManagerSheet extends StatelessWidget {
  const _LabelManagerSheet();

  static Future<void> show(BuildContext context) => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => SizedBox(
      height: MediaQuery.of(ctx).size.height * 0.6,
      child: const ClipRRect(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        child: _LabelManagerSheet(),
      ),
    ),
  );

  static const _col = 'feedback_labels';

  Future<void> _delete(String id) =>
      FirebaseFirestore.instance.collection(_col).doc(id).delete();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.surface,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection(_col).snapshots(),
        builder: (context, snap) {
          final labels = (snap.data?.docs ?? []).map((d) => _Label.fromDoc(d)).toList();
          return Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.colors.border))),
                child: Row(children: [
                  Icon(Icons.folder_outlined, size: 20, color: context.colors.textPrimary),
                  const SizedBox(width: 10),
                  Text('Klasörler', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: context.colors.textPrimary)),
                  const Spacer(),
                  IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close_rounded, color: context.colors.textSecondary, size: 20)),
                ]),
              ),
              Expanded(
                child: snap.connectionState == ConnectionState.waiting
                    ? const Center(child: CircularProgressIndicator(color: AppColors.teal, strokeWidth: 2))
                    : labels.isEmpty
                        ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(Icons.folder_open_outlined, size: 48, color: context.colors.border),
                            const SizedBox(height: 12),
                            Text('Klasör yok', style: TextStyle(color: context.colors.textSecondary, fontSize: 15)),
                            const SizedBox(height: 4),
                            Text('Aşağıdan yeni klasör ekle', style: TextStyle(color: context.colors.textTertiary, fontSize: 12)),
                          ]))
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                            itemCount: labels.length,
                            itemBuilder: (context, i) {
                              final label = labels[i];
                              return Container(
                                key: ValueKey(label.id),
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: context.colors.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: context.colors.border),
                                ),
                                child: Row(children: [
                                  Container(
                                    width: 12, height: 12,
                                    decoration: BoxDecoration(color: label.color, shape: BoxShape.circle),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(child: Text(label.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.colors.textPrimary))),
                                  IconButton(
                                    onPressed: () => showDialog(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('Klasörü sil'),
                                        content: Text('"${label.name}" silinecek. Bu klasördeki feedbackler klasörsüz kalır.'),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
                                          TextButton(
                                            onPressed: () { Navigator.pop(ctx); _delete(label.id); },
                                            child: const Text('Sil', style: TextStyle(color: AppColors.errorRed)),
                                          ),
                                        ],
                                      ),
                                    ),
                                    icon: Icon(Icons.delete_outline, size: 18, color: context.colors.textTertiary),
                                  ),
                                ]),
                              );
                            },
                          ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).viewInsets.bottom + 16),
                child: SizedBox(
                  width: double.infinity, height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () => _NewLabelSheet.show(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.teal,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                    label: const Text('Yeni Klasör', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _NewLabelSheet extends StatefulWidget {
  const _NewLabelSheet();

  static Future<void> show(BuildContext context) => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: const ClipRRect(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        child: _NewLabelSheet(),
      ),
    ),
  );

  @override
  State<_NewLabelSheet> createState() => _NewLabelSheetState();
}

class _NewLabelSheetState extends State<_NewLabelSheet> {
  final _nameCtrl = TextEditingController();
  String _selectedHex = '#2A7F8C';
  bool _saving = false;

  static const _palette = [
    '#FF6B6B', '#FF9600', '#FFD166', '#58CC02',
    '#2A7F8C', '#1CB0F6', '#9B59B6', '#FF69B4',
  ];

  @override
  void dispose() { _nameCtrl.dispose(); super.dispose(); }

  Color _hex(String h) {
    try { return Color(int.parse(h.replaceFirst('#', '0xFF'))); } catch (_) { return AppColors.teal; }
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('feedback_labels').add({
        'name': name,
        'colorHex': _selectedHex,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSave = _nameCtrl.text.trim().isNotEmpty;
    return Scaffold(
      backgroundColor: context.colors.surface,
      resizeToAvoidBottomInset: false,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: context.colors.border, borderRadius: BorderRadius.circular(999)))),
            const SizedBox(height: 16),
            Text('Yeni Klasör', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: context.colors.textPrimary)),
            const SizedBox(height: 16),
            _InputField(controller: _nameCtrl, hint: 'Klasör adı (örn: Dualar)', onChanged: (_) => setState(() {}), maxLines: 1),
            const SizedBox(height: 16),
            Text('Renk', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10, runSpacing: 10,
              children: _palette.map((h) {
                final selected = _selectedHex == h;
                return GestureDetector(
                  onTap: () => setState(() => _selectedHex = h),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: _hex(h),
                      shape: BoxShape.circle,
                      border: selected ? Border.all(color: context.colors.textPrimary, width: 2.5) : null,
                      boxShadow: selected ? [BoxShadow(color: _hex(h).withValues(alpha: 0.4), blurRadius: 6, offset: const Offset(0, 2))] : null,
                    ),
                    child: selected ? const Icon(Icons.check_rounded, color: Colors.white, size: 16) : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: canSave ? 1.0 : 0.45,
              child: SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton(
                  onPressed: (canSave && !_saving) ? _save : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.teal,
                    disabledBackgroundColor: AppColors.teal,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _saving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('OLUŞTUR', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 0.8, color: Colors.white)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Boş Durum ────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String tab;
  const _EmptyState({required this.tab});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(
          tab == 'bug' ? Icons.bug_report_outlined : tab == 'plan' ? Icons.checklist_outlined : Icons.lightbulb_outline_rounded,
          size: 48,
          color: context.colors.border,
        ),
        const SizedBox(height: 12),
        Text(
          tab == 'bug' ? 'Bug yok! 🎉' : tab == 'plan' ? 'Yapılacak yok!' : 'Fikir yok henüz',
          style: TextStyle(color: context.colors.textSecondary, fontSize: 15),
        ),
      ]),
    );
  }
}

// ─── Badge / Chip ─────────────────────────────────────────────────────────────

class _CatBadge extends StatelessWidget {
  final String cat;
  const _CatBadge({required this.cat});

  @override
  Widget build(BuildContext context) {
    final c = _catColor(cat);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(999)),
      child: Text(cat, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }
}

class _CatChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool active;
  final VoidCallback onTap;
  const _CatChip({required this.label, required this.color, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: active ? color : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(label, style: TextStyle(color: active ? Colors.white : color, fontSize: 11, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

// ─── Input Field ─────────────────────────────────────────────────────────────

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final int maxLines;

  const _InputField({required this.controller, required this.hint, required this.onChanged, this.maxLines = 3});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.border),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        minLines: 1,
        onChanged: onChanged,
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(14),
          hintText: hint,
          hintStyle: TextStyle(color: context.colors.textTertiary, fontSize: 14),
        ),
        style: TextStyle(fontSize: 14, color: context.colors.textPrimary, height: 1.5),
      ),
    );
  }
}

// ─── Yeni Öğe Ekle Sheet ─────────────────────────────────────────────────────

class _AddItemSheet extends StatefulWidget {
  final String initialType;
  final String? prefillText;
  final VoidCallback? onSaved;
  final List<String> existingCats;
  final _BacklogItem? editItem; // non-null = edit mode

  const _AddItemSheet({required this.initialType, this.prefillText, this.onSaved, this.existingCats = const [], this.editItem});

  @override
  State<_AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends State<_AddItemSheet> {
  late String _type;
  String? _selCat;
  String _priority = 'normal';
  String? _selMilestoneId;
  final _titleCtrl = TextEditingController();
  final _customCatCtrl = TextEditingController();
  bool _saving = false;

  bool get _isEdit => widget.editItem != null;

  static const _backlogCol = 'app_backlog';
  static const _fallbackPresets = ['Seri', 'Ekipler', 'Hasanat', 'UI', 'Auth', 'Bildirim', 'Hatim'];

  List<String> get _cats => widget.existingCats.isNotEmpty ? widget.existingCats : _fallbackPresets;

  @override
  void initState() {
    super.initState();
    final edit = widget.editItem;
    if (edit != null) {
      _type = edit.type;
      _titleCtrl.text = edit.title;
      _priority = edit.priority;
      _selMilestoneId = edit.milestoneId?.isEmpty == true ? null : edit.milestoneId;
      // category: match against existing cats or fall into custom field
      if (_cats.contains(edit.category)) {
        _selCat = edit.category;
      } else {
        _customCatCtrl.text = edit.category;
      }
    } else {
      _type = widget.initialType;
      if (widget.prefillText != null) _titleCtrl.text = widget.prefillText!;
    }
  }

  @override
  void dispose() { _titleCtrl.dispose(); _customCatCtrl.dispose(); super.dispose(); }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    final cat = _selCat ?? _customCatCtrl.text.trim();
    if (title.isEmpty || cat.isEmpty) return;
    setState(() => _saving = true);
    try {
      if (_isEdit) {
        await FirebaseFirestore.instance.collection(_backlogCol).doc(widget.editItem!.id).update({
          'type': _type,
          'title': title,
          'category': cat,
          'priority': _type == 'idea' ? 'normal' : _priority,
          'milestoneId': (_type == 'idea') ? null : _selMilestoneId,
        });
      } else {
        await FirebaseFirestore.instance.collection(_backlogCol).add({
          'type': _type,
          'title': title,
          'category': cat,
          'priority': _type == 'idea' ? 'normal' : _priority,
          'milestoneId': (_type == 'idea') ? null : _selMilestoneId,
          'completed': false,
          'archived': false,
          'order': DateTime.now().millisecondsSinceEpoch,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      widget.onSaved?.call();
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSave = _titleCtrl.text.trim().isNotEmpty &&
        (_selCat != null || _customCatCtrl.text.trim().isNotEmpty);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Scaffold(
        backgroundColor: context.colors.surface,
        resizeToAvoidBottomInset: false,
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: context.colors.border, borderRadius: BorderRadius.circular(999)))),
                const SizedBox(height: 16),
                Text(_isEdit ? 'Düzenle' : 'Yeni Ekle', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: context.colors.textPrimary)),
                const SizedBox(height: 16),

                // Tip toggle
                SizedBox(
                  height: 42,
                  child: Container(
                    decoration: BoxDecoration(color: context.colors.surfaceVariant, borderRadius: BorderRadius.circular(11)),
                    child: Row(children: [
                      _TabBtn(label: 'BUG',     active: _type == 'bug',  onTap: () => setState(() => _type = 'bug')),
                      _TabBtn(label: 'PLAN',    active: _type == 'plan', onTap: () => setState(() => _type = 'plan')),
                      _TabBtn(label: 'FİKİR',   active: _type == 'idea', onTap: () => setState(() => _type = 'idea')),
                    ]),
                  ),
                ),
                const SizedBox(height: 14),

                // Açıklama
                _InputField(controller: _titleCtrl, hint: 'Açıklama yaz...', onChanged: (_) => setState(() {}), maxLines: 4),
                const SizedBox(height: 14),

                // Priority (FİKİR için gösterilmez)
                if (_type != 'idea') ...[
                  Text('Öncelik', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
                  const SizedBox(height: 8),
                  Row(children: [
                    for (final p in [('critical', 'Kritik'), ('normal', 'Normal'), ('low', 'Düşük')]) ...[
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _priority = p.$1),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _priority == p.$1 ? _priorityColor(p.$1) : _priorityColor(p.$1).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              p.$2,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _priority == p.$1 ? Colors.white : _priorityColor(p.$1),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 14),
                ],

                // Milestone seçimi (sadece PLAN için)
                if (_type == 'plan') ...[
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('app_milestones')
                        .snapshots(),
                    builder: (context, snap) {
                      final milestones = (snap.data?.docs ?? [])
                          .map((d) => _Milestone.fromDoc(d))
                          .where((m) => m.status == 'active')
                          .toList()
                          ..sort((a, b) => a.order.compareTo(b.order));
                      if (milestones.isEmpty) return const SizedBox.shrink();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Milestone', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8, runSpacing: 8,
                            children: [
                              GestureDetector(
                                onTap: () => setState(() => _selMilestoneId = null),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: _selMilestoneId == null ? context.colors.textSecondary : context.colors.border,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text('Yok', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _selMilestoneId == null ? Colors.white : context.colors.textSecondary)),
                                ),
                              ),
                              for (final ms in milestones)
                                GestureDetector(
                                  onTap: () => setState(() => _selMilestoneId = ms.id),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: _selMilestoneId == ms.id ? AppColors.teal : AppColors.teal.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      ms.version,
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _selMilestoneId == ms.id ? Colors.white : AppColors.teal),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 14),
                        ],
                      );
                    },
                  ),
                ],

                // Kategori
                Text('Kategori', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: [
                    ..._cats.map((c) {
                      final sel = _selCat == c;
                      final color = _catColor(c);
                      return GestureDetector(
                        onTap: () => setState(() { _selCat = sel ? null : c; if (!sel) _customCatCtrl.clear(); }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: sel ? color : color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(c, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: sel ? Colors.white : color)),
                        ),
                      );
                    }),
                    if (_selCat == null)
                      SizedBox(
                        height: 34, width: 140,
                        child: TextField(
                          controller: _customCatCtrl,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            hintText: 'Yeni kategori...',
                            hintStyle: TextStyle(fontSize: 11, color: context.colors.textTertiary),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: BorderSide(color: context.colors.border)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: const BorderSide(color: AppColors.teal)),
                          ),
                          style: TextStyle(fontSize: 12, color: context.colors.textPrimary),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),

                // Kaydet
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: canSave ? 1.0 : 0.45,
                  child: SizedBox(
                    width: double.infinity, height: 52,
                    child: ElevatedButton(
                      onPressed: (canSave && !_saving) ? _save : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.teal,
                        disabledBackgroundColor: AppColors.teal,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: _saving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('KAYDET', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 0.8, color: Colors.white)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Category Manager ──────────────────────────────────────────────────────────

class _CatManagerSheet extends StatefulWidget {
  final String type;
  const _CatManagerSheet({required this.type});

  static void show(BuildContext context, String type) => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.65,
      child: _CatManagerSheet(type: type),
    ),
  );

  @override
  State<_CatManagerSheet> createState() => _CatManagerSheetState();
}

class _CatManagerSheetState extends State<_CatManagerSheet> {
  List<String> _cats = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _loadCats(); }

  Future<void> _loadCats() async {
    final snap = await FirebaseFirestore.instance
        .collection('app_backlog')
        .where('type', isEqualTo: widget.type)
        .get();
    final cats = snap.docs
        .map((d) => ((d.data())['category'] as String?) ?? '')
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList()..sort();
    if (mounted) setState(() { _cats = cats; _loading = false; });
  }

  Future<void> _rename(String oldName, String newName) async {
    if (newName.isEmpty || newName == oldName) return;
    final snap = await FirebaseFirestore.instance
        .collection('app_backlog')
        .where('type', isEqualTo: widget.type)
        .where('category', isEqualTo: oldName)
        .get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'category': newName});
    }
    await batch.commit();
    await _loadCats();
  }

  Future<void> _delete(String cat) async {
    final snap = await FirebaseFirestore.instance
        .collection('app_backlog')
        .where('type', isEqualTo: widget.type)
        .where('category', isEqualTo: cat)
        .get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'category': 'Genel'});
    }
    await batch.commit();
    await _loadCats();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Scaffold(
        backgroundColor: context.colors.surface,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: context.colors.border, borderRadius: BorderRadius.circular(999)))),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text('Kategori Yönetimi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: context.colors.textPrimary)),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text('Kategorileri yeniden adlandır veya sil.', style: TextStyle(fontSize: 12, color: context.colors.textSecondary)),
            ),
            const SizedBox(height: 12),
            Divider(height: 1, color: context.colors.border),
            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator(color: AppColors.teal, strokeWidth: 2)))
            else if (_cats.isEmpty)
              Expanded(child: Center(child: Text('Henüz kategori yok.', style: TextStyle(color: context.colors.textTertiary, fontSize: 14))))
            else
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                  itemCount: _cats.length,
                  separatorBuilder: (_, _) => Divider(height: 1, color: context.colors.border),
                  itemBuilder: (ctx, i) {
                    final cat = _cats[i];
                    return _CatRow(
                      key: ValueKey(cat),
                      cat: cat,
                      onRename: (newName) => _rename(cat, newName),
                      onDelete: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Kategori Sil'),
                            content: Text('"$cat" kategorisi silinecek.\nBu kategorideki öğeler "Genel"e taşınır.'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
                              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sil', style: TextStyle(color: AppColors.errorRed))),
                            ],
                          ),
                        );
                        if (confirm == true) await _delete(cat);
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CatRow extends StatefulWidget {
  final String cat;
  final Future<void> Function(String) onRename;
  final VoidCallback onDelete;
  const _CatRow({super.key, required this.cat, required this.onRename, required this.onDelete});

  @override
  State<_CatRow> createState() => _CatRowState();
}

class _CatRowState extends State<_CatRow> {
  bool _editing = false;
  late final TextEditingController _ctrl;
  bool _saving = false;

  @override
  void initState() { super.initState(); _ctrl = TextEditingController(text: widget.cat); }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final color = _catColor(widget.cat);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 12),
          Expanded(
            child: _editing
                ? TextField(
                    controller: _ctrl,
                    autofocus: true,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.colors.textPrimary),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 4),
                      border: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.teal)),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.teal, width: 2)),
                    ),
                  )
                : Text(widget.cat, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.colors.textPrimary)),
          ),
          if (_editing) ...[
            if (_saving)
              const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: AppColors.teal, strokeWidth: 2))
            else
              IconButton(
                icon: const Icon(Icons.check_rounded, color: AppColors.teal, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: () async {
                  final newName = _ctrl.text.trim();
                  if (newName.isEmpty) return;
                  setState(() => _saving = true);
                  await widget.onRename(newName);
                  if (mounted) setState(() { _editing = false; _saving = false; });
                },
              ),
            IconButton(
              icon: Icon(Icons.close_rounded, color: context.colors.textTertiary, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: () => setState(() { _editing = false; _ctrl.text = widget.cat; }),
            ),
          ] else ...[
            IconButton(
              icon: Icon(Icons.edit_outlined, color: context.colors.textSecondary, size: 18),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: () => setState(() => _editing = true),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.errorRed, size: 18),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: widget.onDelete,
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Hafız Yönetimi View ──────────────────────────────────────────────────────

class _HafizView extends StatefulWidget {
  final VoidCallback onBack;
  const _HafizView({super.key, required this.onBack});

  @override
  State<_HafizView> createState() => _HafizViewState();
}

class _HafizViewState extends State<_HafizView> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final Stream<QuerySnapshot> _pendingStream;
  late final Stream<QuerySnapshot> _hafizUsersStream;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _pendingStream = FirebaseFirestore.instance
        .collection('hafiz_requests')
        .where('status', isEqualTo: 'pending')
        .snapshots();
    _hafizUsersStream = FirebaseFirestore.instance
        .collection('users')
        .where('isHafiz', isEqualTo: true)
        .snapshots();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.surface,
      body: StreamBuilder<QuerySnapshot>(
        stream: _pendingStream,
        builder: (context, snap) {
          final docs = snap.data?.docs ?? [];
          final verifyDocs = docs.where((d) {
            final type = (d.data() as Map<String, dynamic>)['type'] as String?;
            return type == null || type == 'verify';
          }).toList();
          final revokeDocs = docs.where((d) {
            final type = (d.data() as Map<String, dynamic>)['type'] as String?;
            return type == 'revoke';
          }).toList();

          return Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(4, 20, 12, 0),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: widget.onBack,
                          icon: Icon(Icons.arrow_back_rounded, color: Colors.white.withValues(alpha: 0.7)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.emeraldGreen.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.emeraldGreen.withValues(alpha: 0.4)),
                          ),
                          child: const Text(
                            'HAFIZ',
                            style: TextStyle(color: AppColors.emeraldGreen, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Hafız Yönetimi',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TabBar(
                      controller: _tabController,
                      indicatorColor: AppColors.emeraldGreen,
                      labelColor: AppColors.emeraldGreen,
                      unselectedLabelColor: Colors.white.withValues(alpha: 0.5),
                      labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                      unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      tabs: [
                        Tab(text: verifyDocs.isNotEmpty ? 'Doğrulama (${verifyDocs.length})' : 'Doğrulama'),
                        Tab(text: revokeDocs.isNotEmpty ? 'İptal (${revokeDocs.length})' : 'İptal'),
                        const Tab(text: 'Hafızlar'),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildVerifyTab(verifyDocs, snap.connectionState),
                    _buildRevokeTab(revokeDocs, snap.connectionState),
                    _buildHafizUsersTab(),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildVerifyTab(List<QueryDocumentSnapshot> docs, ConnectionState state) {
    if (state == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }
    if (docs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline_rounded, color: AppColors.successGreen, size: 48),
            const SizedBox(height: 12),
            Text('Bekleyen doğrulama başvurusu yok', style: TextStyle(color: context.colors.textSecondary, fontSize: 15)),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: docs.length,
      separatorBuilder: (context, i) => const SizedBox(height: 12),
      itemBuilder: (context, i) => _HafizRequestCard(doc: docs[i]),
    );
  }

  Widget _buildRevokeTab(List<QueryDocumentSnapshot> docs, ConnectionState state) {
    if (state == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }
    if (docs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline_rounded, color: AppColors.successGreen, size: 48),
            const SizedBox(height: 12),
            Text('Bekleyen iptal başvurusu yok', style: TextStyle(color: context.colors.textSecondary, fontSize: 15)),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: docs.length,
      separatorBuilder: (context, i) => const SizedBox(height: 12),
      itemBuilder: (context, i) => _HafizRevokeCard(doc: docs[i]),
    );
  }

  Widget _buildHafizUsersTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _hafizUsersStream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.person_off_outlined, color: context.colors.textTertiary, size: 48),
                const SizedBox(height: 12),
                Text('Henüz hafız yok', style: TextStyle(color: context.colors.textSecondary, fontSize: 15)),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (context, i) => const SizedBox(height: 10),
          itemBuilder: (context, i) => _HafizUserCard(doc: docs[i]),
        );
      },
    );
  }
}

// ─── Kart: Doğrulama Başvurusu ────────────────────────────────────────────────

class _HafizRequestCard extends StatefulWidget {
  final QueryDocumentSnapshot doc;
  const _HafizRequestCard({required this.doc});

  @override
  State<_HafizRequestCard> createState() => _HafizRequestCardState();
}

class _HafizRequestCardState extends State<_HafizRequestCard> {
  bool _loading = false;
  bool _done = false;
  String? _doneLabel;

  Future<void> _approve() async {
    setState(() => _loading = true);
    try {
      final data = widget.doc.data() as Map<String, dynamic>;
      final uid = data['uid'] as String?;
      if (uid == null || uid.isEmpty) throw Exception('uid eksik');
      final batch = FirebaseFirestore.instance.batch();
      batch.update(
        FirebaseFirestore.instance.collection('users').doc(uid),
        {'isHafiz': true},
      );
      batch.update(widget.doc.reference, {
        'status': 'approved',
        'driveLink': FieldValue.delete(),
        'reviewedAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
      if (mounted) setState(() { _loading = false; _done = true; _doneLabel = 'Onaylandı'; });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Onay hatası: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _reject() async {
    final noteCtrl = TextEditingController();
    final String? note;
    try {
      note = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Red Notu'),
          content: TextField(
            controller: noteCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Kullanıcıya gösterilecek mesaj (opsiyonel)',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, noteCtrl.text.trim()),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.errorRed),
              child: const Text('Reddet', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    } finally {
      noteCtrl.dispose();
    }
    if (note == null) return;
    setState(() => _loading = true);
    try {
      await widget.doc.reference.update({
        'status': 'rejected',
        'note': note.isEmpty ? null : note,
        'reviewedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) setState(() { _loading = false; _done = true; _doneLabel = 'Reddedildi'; });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Red işlemi başarısız: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_done) {
      final color = _doneLabel == 'Onaylandı' ? AppColors.successGreen : AppColors.errorRed;
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Icon(_doneLabel == 'Onaylandı' ? Icons.check_circle_rounded : Icons.cancel_rounded, color: color, size: 20),
            const SizedBox(width: 8),
            Text(_doneLabel!, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 14)),
          ],
        ),
      );
    }

    final data = widget.doc.data() as Map<String, dynamic>;
    final name = data['name'] as String? ?? '';
    final username = data['username'] as String? ?? '';
    final avatarSeed = data['avatarSeed'] as String?;
    final driveLink = data['driveLink'] as String? ?? '';
    final requestedAt = (data['requestedAt'] as Timestamp?)?.toDate();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.border),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundImage: avatarSeed != null
                    ? NetworkImage('https://api.dicebear.com/7.x/micah/png?seed=$avatarSeed&backgroundColor=transparent')
                    : null,
                backgroundColor: context.colors.surfaceVariant,
                child: avatarSeed == null ? Icon(Icons.person, size: 18, color: context.colors.textSecondary) : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: context.colors.textPrimary)),
                    if (username.isNotEmpty)
                      Text('@$username', style: TextStyle(fontSize: 12, color: context.colors.textSecondary)),
                  ],
                ),
              ),
              if (requestedAt != null)
                Text(_relativeTime(requestedAt), style: TextStyle(fontSize: 11, color: context.colors.textTertiary)),
            ],
          ),
          const SizedBox(height: 12),
          if (driveLink.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: context.colors.surfaceVariant, borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  Icon(Icons.notes_rounded, size: 16, color: context.colors.textTertiary),
                  const SizedBox(width: 6),
                  Text('Belge veya not paylaşılmadı', style: TextStyle(fontSize: 12, color: context.colors.textTertiary, fontStyle: FontStyle.italic)),
                ],
              ),
            )
          else
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: driveLink));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Kopyalandı'), duration: Duration(seconds: 2)),
                );
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(color: context.colors.surfaceVariant, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    const Icon(Icons.link_rounded, size: 16, color: AppColors.teal),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        driveLink,
                        style: const TextStyle(fontSize: 12, color: AppColors.teal, decoration: TextDecoration.underline),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(Icons.copy_rounded, size: 14, color: context.colors.textTertiary),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          if (_loading)
            const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)))
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _reject,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.errorRed),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Reddet', style: TextStyle(color: AppColors.errorRed, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _approve,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.emeraldGreen,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: const Text('Onayla', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ─── Kart: İptal Başvurusu ────────────────────────────────────────────────────

class _HafizRevokeCard extends StatefulWidget {
  final QueryDocumentSnapshot doc;
  const _HafizRevokeCard({required this.doc});

  @override
  State<_HafizRevokeCard> createState() => _HafizRevokeCardState();
}

class _HafizRevokeCardState extends State<_HafizRevokeCard> {
  bool _loading = false;
  bool _done = false;
  String? _doneLabel;

  Future<void> _approve() async {
    setState(() => _loading = true);
    try {
      final data = widget.doc.data() as Map<String, dynamic>;
      final uid = data['uid'] as String?;
      if (uid == null || uid.isEmpty) throw Exception('uid eksik');
      final batch = FirebaseFirestore.instance.batch();
      batch.update(
        FirebaseFirestore.instance.collection('users').doc(uid),
        {'isHafiz': false},
      );
      batch.update(widget.doc.reference, {
        'status': 'approved',
        'reviewedAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
      if (mounted) setState(() { _loading = false; _done = true; _doneLabel = 'Onaylandı'; });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _reject() async {
    final noteCtrl = TextEditingController();
    final String? note;
    try {
      note = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Red Notu'),
          content: TextField(
            controller: noteCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Kullanıcıya gösterilecek mesaj (opsiyonel)',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, noteCtrl.text.trim()),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.errorRed),
              child: const Text('Reddet', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    } finally {
      noteCtrl.dispose();
    }
    if (note == null) return;
    setState(() => _loading = true);
    try {
      await widget.doc.reference.update({
        'status': 'rejected',
        'note': note.isEmpty ? null : note,
        'reviewedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) setState(() { _loading = false; _done = true; _doneLabel = 'Reddedildi'; });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Red işlemi başarısız: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_done) {
      final color = _doneLabel == 'Onaylandı' ? AppColors.successGreen : AppColors.errorRed;
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Icon(_doneLabel == 'Onaylandı' ? Icons.check_circle_rounded : Icons.cancel_rounded, color: color, size: 20),
            const SizedBox(width: 8),
            Text(_doneLabel!, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 14)),
          ],
        ),
      );
    }

    final data = widget.doc.data() as Map<String, dynamic>;
    final name = data['name'] as String? ?? '';
    final username = data['username'] as String? ?? '';
    final avatarSeed = data['avatarSeed'] as String?;
    final requestedAt = (data['requestedAt'] as Timestamp?)?.toDate();
    final userNote = data['userNote'] as String?;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFB300).withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundImage: avatarSeed != null
                        ? NetworkImage('https://api.dicebear.com/7.x/micah/png?seed=$avatarSeed&backgroundColor=transparent')
                        : null,
                    backgroundColor: context.colors.surfaceVariant,
                    child: avatarSeed == null ? Icon(Icons.person, size: 18, color: context.colors.textSecondary) : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: const BoxDecoration(color: Color(0xFFFFB300), shape: BoxShape.circle),
                      child: const Icon(Icons.remove, size: 9, color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(name, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: context.colors.textPrimary)),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFB300).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('İPTAL', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFFE65100), letterSpacing: 0.8)),
                        ),
                      ],
                    ),
                    if (username.isNotEmpty)
                      Text('@$username', style: TextStyle(fontSize: 12, color: context.colors.textSecondary)),
                  ],
                ),
              ),
              if (requestedAt != null)
                Text(_relativeTime(requestedAt), style: TextStyle(fontSize: 11, color: context.colors.textTertiary)),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFFB300).withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bu kullanıcı hafız statüsünü kaldırmak istiyor.',
                  style: TextStyle(fontSize: 12, color: Color(0xFFE65100)),
                ),
                if (userNote != null && userNote.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  const Divider(height: 1, color: Color(0xFFFFE082)),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.format_quote_rounded, size: 13, color: Color(0xFFE65100)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          userNote,
                          style: TextStyle(fontSize: 12, color: context.colors.textPrimary, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)))
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _reject,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.errorRed),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Reddet', style: TextStyle(color: AppColors.errorRed, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _approve,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFB300),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: const Text('Statüyü Kaldır', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ─── Kart: Mevcut Hafız Kullanıcı ─────────────────────────────────────────────

class _HafizUserCard extends StatefulWidget {
  final QueryDocumentSnapshot doc;
  const _HafizUserCard({required this.doc});

  @override
  State<_HafizUserCard> createState() => _HafizUserCardState();
}

class _HafizUserCardState extends State<_HafizUserCard> {
  bool _loading = false;
  bool _revoked = false;

  Future<void> _revokeManually() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hafız Statüsünü Kaldır'),
        content: const Text('Bu kullanıcının hafız statüsü kaldırılacak. Emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.errorRed, elevation: 0),
            child: const Text('Kaldır', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _loading = true);
    try {
      await widget.doc.reference.update({'isHafiz': false});
      if (mounted) setState(() { _loading = false; _revoked = true; });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_revoked) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: context.colors.surfaceVariant, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Icon(Icons.remove_circle_outline_rounded, color: context.colors.textTertiary, size: 16),
            const SizedBox(width: 6),
            Text('Statü kaldırıldı', style: TextStyle(color: context.colors.textTertiary, fontSize: 13)),
          ],
        ),
      );
    }

    final data = widget.doc.data() as Map<String, dynamic>;
    final name = (data['name'] as String?) ?? '';
    final username = (data['username'] as String?) ?? '';
    final avatarSeed = data['avatarSeed'] as String?;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.emeraldGreen.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundImage: avatarSeed != null
                    ? NetworkImage('https://api.dicebear.com/7.x/micah/png?seed=$avatarSeed&backgroundColor=transparent')
                    : null,
                backgroundColor: context.colors.surfaceVariant,
                child: avatarSeed == null ? Icon(Icons.person, size: 18, color: context.colors.textSecondary) : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(color: AppColors.emeraldGreen, shape: BoxShape.circle),
                  child: const Icon(Icons.check, size: 8, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name.isEmpty ? '(İsimsiz)' : name, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: context.colors.textPrimary)),
                if (username.isNotEmpty)
                  Text('@$username', style: TextStyle(fontSize: 12, color: context.colors.textSecondary)),
              ],
            ),
          ),
          if (_loading)
            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
          else
            TextButton(
              onPressed: _revokeManually,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.errorRed,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Kaldır', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }
}

// ─── Hata Kayıtları ───────────────────────────────────────────────────────────

class _ErrorLogsView extends StatelessWidget {
  final VoidCallback onBack;
  const _ErrorLogsView({super.key, required this.onBack});

  String _timeAgo(Timestamp? ts) {
    if (ts == null) return '';
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inMinutes < 1) return 'Az önce';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
    if (diff.inHours < 24) return '${diff.inHours} sa önce';
    return '${diff.inDays} gün önce';
  }

  Future<void> _clearAll(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logları Temizle', style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('Tüm hata kayıtları silinecek.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final snap = await FirebaseFirestore.instance.collection('app_errors').get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snap.docs) { batch.delete(doc.reference); }
    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.surface,
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 20, 12, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                ),
                const SizedBox(width: 4),
                const Expanded(
                  child: Text('Hata Kayıtları',
                      style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                ),
                TextButton(
                  onPressed: () => _clearAll(context),
                  child: const Text('Temizle', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('app_errors')
                  .orderBy('createdAt', descending: true)
                  .limit(50)
                  .snapshots(),
              builder: (context, snap) {
                final docs = snap.data?.docs ?? [];
                if (snap.connectionState == ConnectionState.waiting && docs.isEmpty) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.teal));
                }
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle_outline, size: 48, color: AppColors.teal),
                        const SizedBox(height: 12),
                        Text('Hata kaydı yok', style: TextStyle(color: context.colors.textSecondary, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final data = docs[i].data() as Map<String, dynamic>;
                    final error = data['error'] as String? ?? 'Bilinmeyen hata';
                    final library = data['library'] as String? ?? '';
                    final platform = data['platform'] as String? ?? '';
                    final stack = data['stack'] as String? ?? '';
                    final ts = data['createdAt'] as Timestamp?;

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        border: Border.all(color: const Color(0xFFFECACA)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.bug_report_outlined, size: 14, color: Color(0xFFEF4444)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(error,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF991B1B)),
                                    maxLines: 2, overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ),
                          if (library.isNotEmpty || platform.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              [if (library.isNotEmpty) library, if (platform.isNotEmpty) platform].join(' · '),
                              style: const TextStyle(fontSize: 10, color: Color(0xFFB91C1C)),
                            ),
                          ],
                          if (stack.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              stack.length > 300 ? '${stack.substring(0, 300)}…' : stack,
                              style: const TextStyle(fontSize: 9, color: Color(0xFF6B7280), fontFamily: 'monospace', height: 1.4),
                            ),
                          ],
                          const SizedBox(height: 6),
                          Text(_timeAgo(ts),
                              style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Yol Haritası Yönetimi ────────────────────────────────────────────────────

class _RoadmapView extends StatefulWidget {
  final VoidCallback onBack;
  const _RoadmapView({super.key, required this.onBack});

  @override
  State<_RoadmapView> createState() => _RoadmapViewState();
}

class _RoadmapViewState extends State<_RoadmapView> {
  String _tab = 'released';
  List<RoadmapEntry> _released = [];
  List<RoadmapEntry> _upcoming = [];
  StreamSubscription<QuerySnapshot>? _sub;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _sub = FirebaseFirestore.instance
        .collection('roadmap_entries')
        .orderBy('order')
        .snapshots()
        .listen((s) {
      final all = s.docs.map(RoadmapEntry.fromDoc).toList();
      setState(() {
        _released = all.where((e) => e.type == 'released').toList().reversed.toList();
        _upcoming = all.where((e) => e.type == 'upcoming').toList();
        _loading = false;
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  List<RoadmapEntry> get _current => _tab == 'released' ? _released : _upcoming;

  Future<void> _reorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    final list = List<RoadmapEntry>.from(_current);
    final moved = list.removeAt(oldIndex);
    list.insert(newIndex, moved);

    final batch = FirebaseFirestore.instance.batch();
    final isReleased = _tab == 'released';
    for (var i = 0; i < list.length; i++) {
      // Released is displayed newest-first (reversed), so assign descending order
      final order = isReleased ? (list.length - 1 - i) : i;
      batch.update(
        FirebaseFirestore.instance.collection('roadmap_entries').doc(list[i].id),
        {'order': order},
      );
    }
    await batch.commit();
  }

  Future<void> _delete(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sil', style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('Bu kartı silmek istediğinden emin misin?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.errorRed),
            child: const Text('Sil', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await FirebaseFirestore.instance.collection('roadmap_entries').doc(id).delete();
    }
  }

  Future<void> _seedInitialData() async {
    final col = FirebaseFirestore.instance.collection('roadmap_entries');
    final batch = FirebaseFirestore.instance.batch();
    final entries = [
      {'type': 'released', 'title': 'Kuran Okuma & Hatim Takibi',  'version': null, 'date': null, 'eta': null, 'order': 0, 'published': true,
       'bullets': ['Günlük okuma alışkanlığı ve hatim takibi', 'Seri ve Hasanat sistemi', 'Kuran Haritası']},
      {'type': 'released', 'title': 'Tilavet Secdesi Takibi',       'version': null, 'date': null, 'eta': null, 'order': 1, 'published': true,
       'bullets': ['Hatim okurken secdelerini kolayca takip et', 'Aksatmaman için hatırlatıcı']},
      {'type': 'released', 'title': 'Namaz ve Alışkanlık Takibi',   'version': null, 'date': null, 'eta': null, 'order': 2, 'published': true,
       'bullets': ['5 Vakit namaz takibi', 'Kişisel alışkanlık ekle ve takip et']},
      {'type': 'released', 'title': 'Seri ve Ekip Güncellemeleri',  'version': null, 'date': null, 'eta': null, 'order': 3, 'published': true,
       'bullets': ['Seri hataları giderildi', 'Haftalık ekip sıralamasında seri görünür hale geldi', 'Seriye göre filtreleme eklendi', 'Üyeler geçen haftayı, admin tüm geçmişi görebilir']},
      {'type': 'upcoming', 'title': 'Arkadaşlarınla Takipleş',      'version': null, 'date': null, 'eta': 'Yakında', 'order': 4, 'published': true,
       'bullets': ['Arkadaşlarını ekle', 'Okuma aktivitelerini takip et', 'Birlikte ilerle']},
      {'type': 'upcoming', 'title': 'Ayet & Hadisler',              'version': null, 'date': null, 'eta': 'Yakında', 'order': 5, 'published': true,
       'bullets': ['Günlük bildirimler', 'Favori ayet ve hadisleri seç ve kategorize et']},
      {'type': 'upcoming', 'title': 'Tefsir Takibi',                'version': null, 'date': null, 'eta': 'Yakında', 'order': 6, 'published': true,
       'bullets': ['Tefsir okumak isteyenler için ayrı takip sistemi']},
      {'type': 'upcoming', 'title': 'Uygulama İçi Okuma',           'version': null, 'date': null, 'eta': 'Yakında', 'order': 7, 'published': true,
       'bullets': ['Kuran-ı Kerim, meal ve tefsirleri doğrudan uygulama içinden oku']},
      {'type': 'upcoming', 'title': 'İslami Kulüpler',              'version': null, 'date': null, 'eta': 'Yakında', 'order': 8, 'published': true,
       'bullets': ['Üniversite İslami kulüplerini takip et', 'Etkinliklerden haberdar ol']},
      {'type': 'upcoming', 'title': 'Ramazan Güncellemesi',         'version': null, 'date': null, 'eta': 'Ramazan 2027', 'order': 9, 'published': true,
       'bullets': ['Oruç takibi', 'Teravih cami hedefleri', 'Üniversite iftarları']},
    ];
    for (final e in entries) {
      batch.set(col.doc(), e);
    }
    await batch.commit();
  }

  void _openForm({RoadmapEntry? entry}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RoadmapForm(
        initialTab: _tab,
        entry: entry,
        nextOrder: _current.length,
        onSaved: () => Navigator.pop(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.surface,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 20, 12, 18),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: widget.onBack,
                  icon: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white.withValues(alpha: 0.7), size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 10),
                const Icon(Icons.rocket_launch_outlined, color: AppColors.teal, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Yol Haritası', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                ),
                IconButton(
                  onPressed: _openForm,
                  icon: const Icon(Icons.add_rounded, color: Colors.white, size: 26),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Container(
              height: 40,
              decoration: BoxDecoration(color: context.colors.surfaceVariant, borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  _TabBtn(label: 'Yayında', active: _tab == 'released', onTap: () => setState(() => _tab = 'released')),
                  _TabBtn(label: 'Yakında', active: _tab == 'upcoming', onTap: () => setState(() => _tab = 'upcoming')),
                ],
              ),
            ),
          ),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.teal, strokeWidth: 2))
                : _current.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.rocket_launch_outlined, size: 40, color: context.colors.border),
                            const SizedBox(height: 12),
                            Text('Henüz kart yok', style: TextStyle(color: context.colors.textTertiary, fontSize: 14)),
                            const SizedBox(height: 6),
                            TextButton(
                              onPressed: _openForm,
                              child: const Text('+ Kart ekle', style: TextStyle(color: AppColors.teal, fontWeight: FontWeight.w700)),
                            ),
                            if (_released.isEmpty && _upcoming.isEmpty) ...[
                              const SizedBox(height: 4),
                              TextButton(
                                onPressed: _seedInitialData,
                                child: Text('Başlangıç verilerini yükle', style: TextStyle(color: context.colors.textTertiary, fontSize: 12)),
                              ),
                            ],
                          ],
                        ),
                      )
                    : ReorderableListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                        itemCount: _current.length,
                        onReorder: _reorder,
                        buildDefaultDragHandles: false,
                        itemBuilder: (_, i) {
                          final e = _current[i];
                          return _RoadmapDevCard(
                            key: ValueKey(e.id),
                            entry: e,
                            index: i,
                            onEdit: () => _openForm(entry: e),
                            onDelete: () => _delete(e.id),
                            onTogglePublished: () => FirebaseFirestore.instance
                                .collection('roadmap_entries')
                                .doc(e.id)
                                .update({'published': !e.published}),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

// ─── DevPanel kart satırı ─────────────────────────────────────────────────────

class _RoadmapDevCard extends StatelessWidget {
  final RoadmapEntry entry;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onTogglePublished;

  const _RoadmapDevCard({
    super.key,
    required this.entry,
    required this.index,
    required this.onEdit,
    required this.onDelete,
    required this.onTogglePublished,
  });

  @override
  Widget build(BuildContext context) {
    final isReleased = entry.type == 'released';
    final barColor   = !entry.published
        ? context.colors.border
        : isReleased ? const Color(0xFF58CC02) : AppColors.teal;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: context.colors.surfaceVariant,
        border: Border.all(color: context.colors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: barColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(13),
                  bottomLeft: Radius.circular(13),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (entry.version != null) ...[
                          Text(entry.version!, style: TextStyle(fontSize: 11, color: context.colors.textTertiary, fontWeight: FontWeight.w700)),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: Text(
                            entry.title,
                            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: context.colors.textPrimary),
                          ),
                        ),
                        GestureDetector(
                          onTap: onTogglePublished,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: entry.published ? const Color(0xFFD7FFB8) : context.colors.border,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              entry.published ? 'Yayında' : 'Taslak',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: entry.published ? const Color(0xFF58CC02) : context.colors.textTertiary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (entry.date != null || entry.eta != null) ...[
                      const SizedBox(height: 1),
                      Text(
                        entry.date ?? entry.eta ?? '',
                        style: TextStyle(fontSize: 10.5, color: context.colors.textTertiary, fontWeight: FontWeight.w600),
                      ),
                    ],
                    if (entry.bullets.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      for (final b in entry.bullets)
                        Text('· $b', style: TextStyle(fontSize: 11.5, color: context.colors.textSecondary, height: 1.35)),
                    ],
                  ],
                ),
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  onPressed: onEdit,
                  icon: Icon(Icons.edit_outlined, size: 18, color: context.colors.textSecondary),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  constraints: const BoxConstraints(),
                ),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.errorRed),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  constraints: const BoxConstraints(),
                ),
                ReorderableDragStartListener(
                  index: index,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Icon(Icons.drag_handle_rounded, size: 18, color: context.colors.textTertiary),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Ekle / Düzenle formu ─────────────────────────────────────────────────────

class _RoadmapForm extends StatefulWidget {
  final String initialTab;
  final RoadmapEntry? entry;
  final int nextOrder;
  final VoidCallback onSaved;

  const _RoadmapForm({
    required this.initialTab,
    required this.nextOrder,
    required this.onSaved,
    this.entry,
  });

  @override
  State<_RoadmapForm> createState() => _RoadmapFormState();
}

class _RoadmapFormState extends State<_RoadmapForm> {
  late String _type;
  late final TextEditingController _title;
  late final TextEditingController _version;
  late final TextEditingController _date;
  late final TextEditingController _eta;
  late final TextEditingController _bullets;
  late bool _published;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    _type      = e?.type      ?? widget.initialTab;
    _title     = TextEditingController(text: e?.title   ?? '');
    _version   = TextEditingController(text: e?.version ?? '');
    _date      = TextEditingController(text: e?.date    ?? '');
    _eta       = TextEditingController(text: e?.eta     ?? '');
    _bullets   = TextEditingController(text: e?.bullets.join('\n') ?? '');
    _published = e?.published ?? false;
  }

  @override
  void dispose() {
    _title.dispose(); _version.dispose(); _date.dispose();
    _eta.dispose(); _bullets.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) return;
    setState(() => _saving = true);

    final bullets = _bullets.text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final data = <String, dynamic>{
      'type':      _type,
      'title':     _title.text.trim(),
      'version':   _version.text.trim().isEmpty ? null : _version.text.trim(),
      'date':      _date.text.trim().isEmpty    ? null : _date.text.trim(),
      'eta':       _eta.text.trim().isEmpty     ? null : _eta.text.trim(),
      'bullets':   bullets,
      'published': _published,
    };

    final col = FirebaseFirestore.instance.collection('roadmap_entries');
    if (widget.entry == null) {
      data['order'] = widget.nextOrder;
      await col.add(data);
    } else {
      await col.doc(widget.entry!.id).update(data);
    }
    widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.entry != null;
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: context.colors.border, borderRadius: BorderRadius.circular(999)),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isEdit ? 'Kartı Düzenle' : 'Yeni Kart',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: context.colors.textPrimary),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                _TypeChip(label: 'Yayında', selected: _type == 'released', onTap: () => setState(() => _type = 'released')),
                const SizedBox(width: 8),
                _TypeChip(label: 'Yakında', selected: _type == 'upcoming', onTap: () => setState(() => _type = 'upcoming')),
              ],
            ),
            const SizedBox(height: 14),

            _FormField(label: 'Başlık *', controller: _title, hint: 'Namaz ve Alışkanlık Takibi'),
            const SizedBox(height: 10),
            _FormField(label: 'Versiyon', controller: _version, hint: 'v1.2'),
            const SizedBox(height: 10),
            if (_type == 'released')
              _FormField(label: 'Tarih', controller: _date, hint: '2026-05-17'),
            if (_type == 'upcoming')
              _FormField(label: 'ETA', controller: _eta, hint: 'Yakında · Ramazan 2027'),
            const SizedBox(height: 10),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Maddeler (her satır ayrı)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.colors.textSecondary)),
                const SizedBox(height: 4),
                TextField(
                  controller: _bullets,
                  maxLines: 5,
                  style: TextStyle(fontSize: 13.5, color: context.colors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Seri hataları giderildi\nEkip liderboard güncellendi',
                    hintStyle: TextStyle(fontSize: 13, color: context.colors.textTertiary),
                    filled: true,
                    fillColor: context.colors.surfaceVariant,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: context.colors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.teal, width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            Row(
              children: [
                Switch(
                  value: _published,
                  onChanged: (v) => setState(() => _published = v),
                  activeThumbColor: AppColors.teal,
                  activeTrackColor: context.colors.tealSurface,
                ),
                const SizedBox(width: 8),
                Text(
                  _published ? 'Yayında — kullanıcılar görebilir' : 'Taslak — sadece sen görürsün',
                  style: TextStyle(
                    fontSize: 13,
                    color: _published ? AppColors.teal : context.colors.textTertiary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.teal,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(isEdit ? 'Kaydet' : 'Ekle',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TypeChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.teal : context.colors.surfaceVariant,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? AppColors.teal : context.colors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : context.colors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  const _FormField({required this.label, required this.hint, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.colors.textSecondary)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          style: TextStyle(fontSize: 13.5, color: context.colors.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontSize: 13, color: context.colors.textTertiary),
            filled: true,
            fillColor: context.colors.surfaceVariant,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: context.colors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.teal, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Broadcast Bildirimi ──────────────────────────────────────────────────────

enum _BroadcastTarget { all, team, user }

class _BroadcastView extends StatefulWidget {
  final VoidCallback onBack;
  const _BroadcastView({super.key, required this.onBack});

  @override
  State<_BroadcastView> createState() => _BroadcastViewState();
}

class _BroadcastViewState extends State<_BroadcastView> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _filterCtrl = TextEditingController();

  _BroadcastTarget _target = _BroadcastTarget.all;
  bool _sending = false;
  String? _statusMsg;
  bool _statusSuccess = false;
  List<Map<String, dynamic>> _recent = [];

  @override
  void initState() {
    super.initState();
    _loadRecent();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _filterCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRecent() async {
    final snap = await FirebaseFirestore.instance
        .collection('app_broadcasts')
        .orderBy('createdAt', descending: true)
        .limit(5)
        .get();
    if (!mounted) return;
    setState(() {
      _recent = snap.docs.map((d) => {...d.data(), 'id': d.id}).toList();
    });
  }

  Future<void> _send() async {
    final title = _titleCtrl.text.trim();
    final body = _bodyCtrl.text.trim();
    if (title.isEmpty || body.isEmpty) {
      setState(() { _statusMsg = 'Başlık ve içerik boş olamaz.'; _statusSuccess = false; });
      return;
    }

    setState(() { _sending = true; _statusMsg = null; });

    try {
      final db = FirebaseFirestore.instance;
      final List<String> uids;
      String confirmLabel;

      // ── 1. Hedef UIDs bul (dry-run) ──
      if (_target == _BroadcastTarget.all) {
        final snap = await db.collection('users').limit(100).get();
        uids = snap.docs.map((d) => d.id).toList();
        confirmLabel = '${uids.length} kullanıcıya';

      } else if (_target == _BroadcastTarget.team) {
        final filter = _filterCtrl.text.trim();
        if (filter.isEmpty) {
          if (mounted) setState(() { _statusMsg = 'Ekip adı gir.'; _sending = false; _statusSuccess = false; });
          return;
        }
        final teamSnap = await db.collection('teams')
            .where('name', isEqualTo: filter)
            .limit(1)
            .get();
        if (!mounted) return;
        if (teamSnap.docs.isEmpty) {
          setState(() { _statusMsg = '"$filter" adında ekip bulunamadı. (Büyük/küçük harf önemli)'; _sending = false; _statusSuccess = false; });
          return;
        }
        final teamId = teamSnap.docs.first.id;
        final teamName = (teamSnap.docs.first.data())['name'] as String? ?? filter;
        final userSnap = await db.collection('users')
            .where('teamIds', arrayContains: teamId)
            .get();
        uids = userSnap.docs.map((d) => d.id).toList();
        confirmLabel = '"$teamName" ekibinin ${uids.length} üyesine';

      } else {
        final filter = _filterCtrl.text.trim();
        if (filter.isEmpty) {
          if (mounted) setState(() { _statusMsg = 'Kullanıcı adı gir.'; _sending = false; _statusSuccess = false; });
          return;
        }
        final userSnap = await db.collection('users')
            .where('username', isEqualTo: filter)
            .limit(1)
            .get();
        if (!mounted) return;
        if (userSnap.docs.isEmpty) {
          setState(() { _statusMsg = '"$filter" kullanıcısı bulunamadı. (Büyük/küçük harf önemli)'; _sending = false; _statusSuccess = false; });
          return;
        }
        uids = [userSnap.docs.first.id];
        confirmLabel = '@$filter kullanıcısına';
      }

      if (uids.isEmpty) {
        if (mounted) setState(() { _statusMsg = 'Hedef kullanıcı bulunamadı.'; _sending = false; _statusSuccess = false; });
        return;
      }

      // ── 2. Onay diyaloğu ──
      if (!mounted) return;
      setState(() { _sending = false; });

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: ctx.colors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            const Icon(Icons.campaign_outlined, color: Color(0xFF8B5CF6), size: 20),
            const SizedBox(width: 8),
            Text(
              'Bildirim Gönder',
              style: TextStyle(fontWeight: FontWeight.w800, color: ctx.colors.textPrimary, fontSize: 16),
            ),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$confirmLabel gönderilecek:',
                style: TextStyle(fontSize: 13, color: ctx.colors.textSecondary),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ctx.colors.surfaceVariant,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: ctx.colors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: ctx.colors.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      body,
                      style: TextStyle(fontSize: 12, color: ctx.colors.textSecondary),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Vazgeç', style: TextStyle(fontWeight: FontWeight.w700, color: ctx.colors.textSecondary)),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6)),
              child: const Text('Gönder', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
      if (!mounted) return;
      setState(() { _sending = true; });

      // ── 3. Batch gönder ──
      WriteBatch batch = db.batch();
      int opCount = 0;

      for (final uid in uids) {
        final ref = db.collection('users').doc(uid).collection('notifications').doc();
        batch.set(ref, {
          'type': 'announcement',
          'title': title,
          'body': body,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
        opCount++;
        if (opCount >= 490) {
          await batch.commit();
          batch = db.batch();
          opCount = 0;
        }
      }
      if (opCount > 0) await batch.commit();

      // ── 4. Audit logu ──
      await db.collection('app_broadcasts').add({
        'title': title,
        'body': body,
        'target': _target.name,
        'targetFilter': _target == _BroadcastTarget.all ? null : _filterCtrl.text.trim(),
        'recipientCount': uids.length,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _titleCtrl.clear();
      _bodyCtrl.clear();
      _filterCtrl.clear();
      if (!mounted) return;
      setState(() {
        _sending = false;
        _statusMsg = '${uids.length} kullanıcıya gönderildi ✓';
        _statusSuccess = true;
      });
      await _loadRecent();

    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _statusMsg = 'Hata: $e';
        _statusSuccess = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.surface,
      body: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 20, 12, 22),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1E1B3A), Color(0xFF2D1B69)],
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: widget.onBack,
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.campaign_outlined, color: Color(0xFF8B5CF6), size: 22),
                const SizedBox(width: 10),
                const Text(
                  'Bildirim Gönder',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hedef seçici
                  _BroadcastSectionLabel('Hedef'),
                  const SizedBox(height: 8),
                  Row(
                    children: _BroadcastTarget.values.map((t) {
                      final labels = {
                        _BroadcastTarget.all: 'Herkese',
                        _BroadcastTarget.team: 'Ekip',
                        _BroadcastTarget.user: 'Kişi',
                      };
                      final selected = _target == t;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => setState(() { _target = t; _filterCtrl.clear(); }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: selected ? const Color(0xFF8B5CF6) : context.colors.surfaceVariant,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: selected ? const Color(0xFF8B5CF6) : context.colors.border,
                              ),
                            ),
                            child: Text(
                              labels[t]!,
                              style: TextStyle(
                                color: selected ? Colors.white : context.colors.textSecondary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  // Filtre alanı (Ekip/Kişi seçiliyse)
                  if (_target != _BroadcastTarget.all) ...[
                    const SizedBox(height: 16),
                    _BroadcastSectionLabel(_target == _BroadcastTarget.team ? 'Ekip Adı' : 'Kullanıcı Adı'),
                    const SizedBox(height: 8),
                    _BroadcastTextField(
                      controller: _filterCtrl,
                      hint: _target == _BroadcastTarget.team ? 'Ekip adını gir...' : 'Kullanıcı adını gir...',
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Büyük/küçük harf ve boşluk önemlidir — Firestore\'da nasıl yazıyorsa öyle yaz.',
                      style: TextStyle(color: context.colors.textTertiary, fontSize: 11),
                    ),
                  ],

                  const SizedBox(height: 20),
                  _BroadcastSectionLabel('Başlık'),
                  const SizedBox(height: 8),
                  _BroadcastTextField(controller: _titleCtrl, hint: 'Bildirim başlığı...'),

                  const SizedBox(height: 16),
                  _BroadcastSectionLabel('İçerik'),
                  const SizedBox(height: 8),
                  _BroadcastTextField(controller: _bodyCtrl, hint: 'Bildirim metni...', maxLines: 4),

                  const SizedBox(height: 24),

                  // Gönder butonu
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _sending ? null : _send,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF8B5CF6),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: _sending
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.send_rounded, size: 18),
                      label: Text(
                        _sending ? 'Gönderiliyor...' : 'Gönder',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                    ),
                  ),

                  // Durum mesajı
                  if (_statusMsg != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: (_statusSuccess ? AppColors.successGreen : AppColors.errorRed).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: (_statusSuccess ? AppColors.successGreen : AppColors.errorRed).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        _statusMsg!,
                        style: TextStyle(
                          color: _statusSuccess ? AppColors.successGreen : AppColors.errorRed,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],

                  // Son gönderilen bildirimler
                  if (_recent.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    _BroadcastSectionLabel('Son Gönderilenler'),
                    const SizedBox(height: 10),
                    ..._recent.map((b) {
                      final ts = b['createdAt'] as Timestamp?;
                      final dt = ts?.toDate().toLocal();
                      final count = b['recipientCount'] as int? ?? 0;
                      final target = b['target'] as String? ?? 'all';
                      final filter = b['targetFilter'] as String?;
                      final targetLabel = target == 'all'
                          ? 'Herkese ($count)'
                          : target == 'team'
                              ? 'Ekip: ${filter ?? ''} ($count)'
                              : 'Kişi: ${filter ?? ''}';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: context.colors.surfaceVariant,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: context.colors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Expanded(
                                child: Text(
                                  b['title'] as String? ?? '',
                                  style: TextStyle(color: context.colors.textPrimary, fontWeight: FontWeight.w700, fontSize: 13),
                                ),
                              ),
                              if (dt != null)
                                Text(_relativeTime(dt), style: TextStyle(color: context.colors.textTertiary, fontSize: 11)),
                            ]),
                            const SizedBox(height: 4),
                            Text(
                              b['body'] as String? ?? '',
                              style: TextStyle(color: context.colors.textSecondary, fontSize: 12),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                targetLabel,
                                style: const TextStyle(color: Color(0xFF8B5CF6), fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BroadcastSectionLabel extends StatelessWidget {
  final String text;
  const _BroadcastSectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: context.colors.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _BroadcastTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;

  const _BroadcastTextField({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: TextStyle(color: context.colors.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: context.colors.textTertiary, fontSize: 14),
        filled: true,
        fillColor: context.colors.surfaceVariant,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 1.5),
        ),
      ),
    );
  }
}

