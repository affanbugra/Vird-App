import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../app_colors.dart';
import '../providers/user_provider.dart';

// ─── Model ────────────────────────────────────────────────────────────────────

class _BacklogItem {
  final String id;
  final String type;     // 'bug' | 'todo'
  final String title;
  final String category;
  final bool completed;
  final bool archived;
  final int order;

  const _BacklogItem({
    required this.id,
    required this.type,
    required this.title,
    required this.category,
    required this.completed,
    required this.archived,
    required this.order,
  });

  factory _BacklogItem.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return _BacklogItem(
      id: doc.id,
      type: (d['type'] as String?) ?? 'todo',
      title: (d['title'] as String?) ?? '',
      category: (d['category'] as String?) ?? 'Genel',
      completed: (d['completed'] as bool?) ?? false,
      archived: (d['archived'] as bool?) ?? false,
      order: (d['order'] as int?) ?? 0,
    );
  }
}

// ─── Category color ───────────────────────────────────────────────────────────

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

// ─── Panel Ana Widget ─────────────────────────────────────────────────────────

enum _PanelView { home, backlog }

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
      return const ColoredBox(
        color: AppColors.white,
        child: Center(child: Text('Erişim yok.', style: TextStyle(color: AppColors.textMid))),
      );
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
      child: _view == _PanelView.home
          ? _HomeView(
              key: const ValueKey('home'),
              onBacklogTap: () => setState(() => _view = _PanelView.backlog),
            )
          : _BacklogView(
              key: const ValueKey('backlog'),
              onBack: () => setState(() => _view = _PanelView.home),
            ),
    );
  }
}

// ─── Ana Sayfa ────────────────────────────────────────────────────────────────

class _HomeView extends StatelessWidget {
  final VoidCallback onBacklogTap;
  const _HomeView({super.key, required this.onBacklogTap});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
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
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 4,
                          child: _PanelCard(
                            icon: Icons.checklist_rtl_outlined,
                            title: 'Backlog',
                            subtitle: 'Bug & görev yönetimi',
                            active: true,
                            onTap: onBacklogTap,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 5,
                          child: _PanelCard(
                            icon: Icons.rocket_launch_outlined,
                            title: 'Neler Geldi\nNeler Gelecek',
                            subtitle: 'Yol haritası yönetimi',
                            active: false,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 5,
                          child: _PanelCard(
                            icon: Icons.analytics_outlined,
                            title: 'Kullanıcı\nİstatistikleri',
                            subtitle: 'Uygulama metrikleri',
                            active: false,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 4,
                          child: _PanelCard(
                            icon: Icons.workspace_premium_outlined,
                            title: 'Pro\nAyarları',
                            subtitle: 'Yetki yönetimi',
                            active: false,
                          ),
                        ),
                      ],
                    ),
                  ),
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
                color: AppColors.borderGrey,
                colorBlendMode: BlendMode.srcIn,
              ),
              const SizedBox(height: 6),
              const Text('vird dev tools', style: TextStyle(fontSize: 10, color: AppColors.textLight, letterSpacing: 1.2)),
            ]),
          ),
        ],
      ),
    );
  }
}

class _PanelCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool active;
  final VoidCallback? onTap;

  const _PanelCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.active,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (active) {
      return Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.teal, AppColors.tealDark],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.teal.withValues(alpha: 0.30),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: Colors.white, size: 26),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800, height: 1.3),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.lightGrey,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderGrey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.textLight, size: 26),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(color: AppColors.textMid, fontSize: 14, fontWeight: FontWeight.w800, height: 1.3),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: AppColors.textLight, fontSize: 11)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: AppColors.borderGrey, borderRadius: BorderRadius.circular(999)),
            child: const Text('Yakında', style: TextStyle(fontSize: 10, color: AppColors.textLight, fontWeight: FontWeight.w600)),
          ),
        ],
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
              color: active ? Colors.white : AppColors.textMid,
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

  static const _col = 'app_backlog';

  Future<void> _toggle(String id, bool current) =>
      FirebaseFirestore.instance.collection(_col).doc(id).update({'completed': !current});

  Future<void> _delete(String id) =>
      FirebaseFirestore.instance.collection(_col).doc(id).delete();

  Future<void> _archive(String id) =>
      FirebaseFirestore.instance.collection(_col).doc(id).update({'archived': true});

  Future<void> _reorder(List<_BacklogItem> visible, int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    final list = List<_BacklogItem>.from(visible);
    list.insert(newIndex, list.removeAt(oldIndex));
    final batch = FirebaseFirestore.instance.batch();
    for (int i = 0; i < list.length; i++) {
      batch.update(
        FirebaseFirestore.instance.collection(_col).doc(list[i].id),
        {'order': i},
      );
    }
    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    if (_showArchive) {
      return _ArchiveView(onBack: () => setState(() => _showArchive = false));
    }

    return Scaffold(
      backgroundColor: AppColors.white,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection(_col)
            .orderBy('order')
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return const Center(
              child: Text('Yükleme hatası', style: TextStyle(color: AppColors.textMid)),
            );
          }

          final allItems = (snap.data?.docs ?? []).map((d) => _BacklogItem.fromDoc(d)).toList();
          // Arşivlenmiş öğeleri ana listeden çıkar
          final tabItems = allItems.where((i) => i.type == _tab && !i.archived).toList();
          final archivedCount = allItems.where((i) => i.archived).length;
          final cats = tabItems.map((i) => i.category).toSet().toList()..sort();
          final byCat = _filterCat == null
              ? tabItems
              : tabItems.where((i) => i.category == _filterCat).toList();
          final displayed = _showCompleted ? byCat : byCat.where((i) => !i.completed).toList();
          final openCount = tabItems.where((i) => !i.completed).length;
          final canDrag = _filterCat == null && _showCompleted;

          return Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(4, 16, 12, 16),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.borderGrey)),
                ),
                child: Row(children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppColors.textDark),
                    onPressed: widget.onBack,
                  ),
                  const Text(
                    'Backlog',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark),
                  ),
                  const Spacer(),
                  if (openCount > 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.tealLight,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$openCount açık',
                        style: const TextStyle(fontSize: 11, color: AppColors.teal, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  // Arşiv butonu
                  if (archivedCount > 0) ...[
                    GestureDetector(
                      onTap: () => setState(() => _showArchive = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B).withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(children: [
                          const Icon(Icons.archive_outlined, size: 14, color: AppColors.textMid),
                          const SizedBox(width: 4),
                          Text('$archivedCount', style: const TextStyle(fontSize: 11, color: AppColors.textMid, fontWeight: FontWeight.w700)),
                        ]),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  // Tamamlananları göster/gizle
                  GestureDetector(
                    onTap: () => setState(() => _showCompleted = !_showCompleted),
                    child: Icon(
                      _showCompleted ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      size: 20,
                      color: _showCompleted ? AppColors.teal : AppColors.textLight,
                    ),
                  ),
                ]),
              ),

              // Tab toggle
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.lightGrey,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(children: [
                    _TabBtn(
                      label: 'BUGS',
                      active: _tab == 'bug',
                      onTap: () => setState(() { _tab = 'bug'; _filterCat = null; }),
                    ),
                    _TabBtn(
                      label: 'TO-DO',
                      active: _tab == 'todo',
                      onTap: () => setState(() { _tab = 'todo'; _filterCat = null; }),
                    ),
                  ]),
                ),
              ),

              // Kategori filtre chips
              if (cats.isNotEmpty) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 30,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: cats.length + 1,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      if (i == 0) {
                        return _CatChip(
                          label: 'Tümü',
                          color: AppColors.teal,
                          active: _filterCat == null,
                          onTap: () => setState(() => _filterCat = null),
                        );
                      }
                      final c = cats[i - 1];
                      return _CatChip(
                        label: c,
                        color: _catColor(c),
                        active: _filterCat == c,
                        onTap: () => setState(() => _filterCat = _filterCat == c ? null : c),
                      );
                    },
                  ),
                ),
              ],

              const SizedBox(height: 4),

              // Liste
              Expanded(
                child: snap.connectionState == ConnectionState.waiting
                    ? const Center(child: CircularProgressIndicator(color: AppColors.teal, strokeWidth: 2))
                    : displayed.isEmpty
                        ? Center(
                            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Icon(
                                _tab == 'bug' ? Icons.bug_report_outlined : Icons.checklist_outlined,
                                size: 48,
                                color: AppColors.borderGrey,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _tab == 'bug' ? 'Bug yok! 🎉' : 'Yapılacak yok!',
                                style: const TextStyle(color: AppColors.textMid, fontSize: 15),
                              ),
                            ]),
                          )
                        : ReorderableListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                            buildDefaultDragHandles: false,
                            onReorder: canDrag
                                ? (o, n) => _reorder(displayed, o, n)
                                : (_, _) {},
                            itemCount: displayed.length,
                            itemBuilder: (context, i) {
                              final item = displayed[i];
                              return Dismissible(
                                key: ValueKey(item.id),
                                direction: DismissDirection.horizontal,
                                // Sağa kaydır → Arşivle (teal)
                                background: Container(
                                  alignment: Alignment.centerLeft,
                                  padding: const EdgeInsets.only(left: 20),
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.teal,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Row(children: [
                                    Icon(Icons.archive_outlined, color: Colors.white, size: 20),
                                    SizedBox(width: 8),
                                    Text('Arşivle', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                                  ]),
                                ),
                                // Sola kaydır → Sil (kırmızı)
                                secondaryBackground: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 20),
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.errorRed,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                                    Text('Sil', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                                    SizedBox(width: 8),
                                    Icon(Icons.delete_outline, color: Colors.white, size: 20),
                                  ]),
                                ),
                                confirmDismiss: (direction) async {
                                  if (direction == DismissDirection.startToEnd) {
                                    // Arşivle — stream item'ı kaldıracak, false dön
                                    await _archive(item.id);
                                    return false;
                                  }
                                  // Sil
                                  return true;
                                },
                                onDismissed: (_) => _delete(item.id),
                                child: Container(
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  decoration: BoxDecoration(
                                    color: item.completed ? const Color(0xFFF9FAFB) : AppColors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.borderGrey),
                                  ),
                                  child: Row(children: [
                                    canDrag
                                        ? ReorderableDragStartListener(
                                            index: i,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                                              child: Icon(
                                                Icons.drag_indicator_rounded,
                                                color: AppColors.textLight.withValues(alpha: 0.5),
                                                size: 18,
                                              ),
                                            ),
                                          )
                                        : const SizedBox(width: 14),
                                    GestureDetector(
                                      onTap: () => _toggle(item.id, item.completed),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        width: 20,
                                        height: 20,
                                        decoration: BoxDecoration(
                                          color: item.completed ? AppColors.teal : Colors.transparent,
                                          borderRadius: BorderRadius.circular(5),
                                          border: Border.all(
                                            color: item.completed ? AppColors.teal : AppColors.borderGrey,
                                            width: 1.5,
                                          ),
                                        ),
                                        child: item.completed
                                            ? const Icon(Icons.check_rounded, color: Colors.white, size: 13)
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 13),
                                        child: Text(
                                          item.title,
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            color: item.completed ? AppColors.textLight : AppColors.textDark,
                                            decoration: item.completed ? TextDecoration.lineThrough : null,
                                            decorationColor: AppColors.textLight,
                                            fontWeight: FontWeight.w600,
                                            height: 1.4,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Padding(
                                      padding: const EdgeInsets.only(right: 12),
                                      child: _CatBadge(cat: item.category),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (ctx) => Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: _AddItemSheet(initialType: _tab),
          ),
        ),
        backgroundColor: AppColors.teal,
        elevation: 3,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          _tab == 'bug' ? 'Bug Ekle' : 'Görev Ekle',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
        ),
      ),
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
      backgroundColor: AppColors.white,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection(_col).orderBy('order').snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return const Center(child: Text('Yükleme hatası', style: TextStyle(color: AppColors.textMid)));
          }

          final allItems = (snap.data?.docs ?? []).map((d) => _BacklogItem.fromDoc(d)).toList();
          final tabItems = allItems.where((i) => i.type == _tab && i.archived).toList();

          return Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(4, 16, 16, 16),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.borderGrey)),
                ),
                child: Row(children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppColors.textDark),
                    onPressed: widget.onBack,
                  ),
                  const Icon(Icons.archive_outlined, size: 18, color: AppColors.textDark),
                  const SizedBox(width: 8),
                  const Text(
                    'Arşiv',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark),
                  ),
                  const Spacer(),
                  Text(
                    '${tabItems.length} öğe',
                    style: const TextStyle(fontSize: 12, color: AppColors.textMid),
                  ),
                ]),
              ),

              // Tab toggle
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(color: AppColors.lightGrey, borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    _TabBtn(label: 'BUGS', active: _tab == 'bug', onTap: () => setState(() => _tab = 'bug')),
                    _TabBtn(label: 'TO-DO', active: _tab == 'todo', onTap: () => setState(() => _tab = 'todo')),
                  ]),
                ),
              ),

              const SizedBox(height: 4),

              Expanded(
                child: snap.connectionState == ConnectionState.waiting
                    ? const Center(child: CircularProgressIndicator(color: AppColors.teal, strokeWidth: 2))
                    : tabItems.isEmpty
                        ? const Center(
                            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Icon(Icons.archive_outlined, size: 48, color: AppColors.borderGrey),
                              SizedBox(height: 12),
                              Text('Arşiv boş', style: TextStyle(color: AppColors.textMid, fontSize: 15)),
                            ]),
                          )
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
                                  decoration: BoxDecoration(
                                    color: AppColors.errorRed,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
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
                                    color: AppColors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.borderGrey),
                                  ),
                                  child: Row(children: [
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 13),
                                        child: Text(
                                          item.title,
                                          style: const TextStyle(
                                            fontSize: 13.5,
                                            color: AppColors.textDark,
                                            fontWeight: FontWeight.w600,
                                            height: 1.4,
                                          ),
                                        ),
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
        child: Text(
          label,
          style: TextStyle(color: active ? Colors.white : color, fontSize: 11, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

// ─── Yeni Öğe Ekle Sheet ─────────────────────────────────────────────────────

class _AddItemSheet extends StatefulWidget {
  final String initialType;
  const _AddItemSheet({required this.initialType});

  @override
  State<_AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends State<_AddItemSheet> {
  late String _type;
  String? _selCat;
  final _titleCtrl = TextEditingController();
  final _customCatCtrl = TextEditingController();
  bool _saving = false;

  static const _col = 'app_backlog';
  static const _presets = ['Seri', 'Ekipler', 'Hasanat', 'UI', 'Auth', 'Bildirim', 'Hatim'];

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _customCatCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    final cat = _selCat ?? _customCatCtrl.text.trim();
    if (title.isEmpty || cat.isEmpty) return;

    setState(() => _saving = true);
    try {
      // Composite index gerektirmemek için timestamp'i order olarak kullan —
      // yeni öğeler listenin sonuna eklenir, kullanıcı sonra sürükleyerek sıralayabilir.
      final order = DateTime.now().millisecondsSinceEpoch;

      await FirebaseFirestore.instance.collection(_col).add({
        'type': _type,
        'title': title,
        'category': cat,
        'completed': false,
        'archived': false,
        'order': order,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) Navigator.pop(context);
    } catch (e) {
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
        backgroundColor: AppColors.white,
        resizeToAvoidBottomInset: false,
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 36, height: 4,
                    decoration: BoxDecoration(color: AppColors.borderGrey, borderRadius: BorderRadius.circular(999)),
                  ),
                ),
                const SizedBox(height: 16),

                const Text('Yeni Ekle', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                const SizedBox(height: 16),

                // Tip toggle
                SizedBox(
                  height: 42,
                  child: Container(
                    decoration: BoxDecoration(color: AppColors.lightGrey, borderRadius: BorderRadius.circular(11)),
                    child: Row(children: [
                      _TabBtn(label: 'BUG', active: _type == 'bug', onTap: () => setState(() => _type = 'bug')),
                      _TabBtn(label: 'TO-DO', active: _type == 'todo', onTap: () => setState(() => _type = 'todo')),
                    ]),
                  ),
                ),
                const SizedBox(height: 14),

                // Başlık alanı
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.lightGrey,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderGrey),
                  ),
                  child: TextField(
                    controller: _titleCtrl,
                    maxLines: 4,
                    minLines: 3,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(14),
                      hintText: 'Açıklama yaz...',
                      hintStyle: TextStyle(color: AppColors.textLight, fontSize: 14),
                    ),
                    style: const TextStyle(fontSize: 14, color: AppColors.textDark, height: 1.5),
                  ),
                ),
                const SizedBox(height: 16),

                // Kategori seçimi
                const Text('Kategori Seç', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ..._presets.map((c) {
                      final sel = _selCat == c;
                      final color = _catColor(c);
                      return GestureDetector(
                        onTap: () => setState(() {
                          _selCat = sel ? null : c;
                          if (!sel) _customCatCtrl.clear();
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: sel ? color : color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            c,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: sel ? Colors.white : color,
                            ),
                          ),
                        ),
                      );
                    }),
                    if (_selCat == null)
                      SizedBox(
                        height: 34,
                        width: 140,
                        child: TextField(
                          controller: _customCatCtrl,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            hintText: 'Yeni kategori...',
                            hintStyle: const TextStyle(fontSize: 11, color: AppColors.textLight),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(999),
                              borderSide: const BorderSide(color: AppColors.borderGrey),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(999),
                              borderSide: const BorderSide(color: AppColors.teal),
                            ),
                          ),
                          style: const TextStyle(fontSize: 12, color: AppColors.textDark),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),

                // Kaydet butonu
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
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text(
                              'KAYDET',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 0.8, color: Colors.white),
                            ),
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
