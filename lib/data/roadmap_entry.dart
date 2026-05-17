import 'package:cloud_firestore/cloud_firestore.dart';

class RoadmapEntry {
  final String id;
  final String type;       // 'released' | 'upcoming'
  final String title;
  final String? version;   // "v1.2"
  final String? date;      // "2026-05-17"
  final String? eta;       // "Yakında" | "Ramazan 2027"
  final int order;
  final List<String> bullets;
  final bool published;

  const RoadmapEntry({
    required this.id,
    required this.type,
    required this.title,
    this.version,
    this.date,
    this.eta,
    required this.order,
    required this.bullets,
    required this.published,
  });

  factory RoadmapEntry.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return RoadmapEntry(
      id:        doc.id,
      type:      (d['type']    as String?) ?? 'upcoming',
      title:     (d['title']   as String?) ?? '',
      version:   d['version']  as String?,
      date:      d['date']     as String?,
      eta:       d['eta']      as String?,
      order:     (d['order']   as int?)    ?? 0,
      bullets:   ((d['bullets'] as List?)  ?? []).map((e) => e.toString()).toList(),
      published: (d['published'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
    'type':      type,
    'title':     title,
    'version':   version,
    'date':      date,
    'eta':       eta,
    'order':     order,
    'bullets':   bullets,
    'published': published,
  };

  RoadmapEntry copyWith({
    String? type,
    String? title,
    String? version,
    String? date,
    String? eta,
    int? order,
    List<String>? bullets,
    bool? published,
  }) => RoadmapEntry(
    id:        id,
    type:      type      ?? this.type,
    title:     title     ?? this.title,
    version:   version   ?? this.version,
    date:      date      ?? this.date,
    eta:       eta       ?? this.eta,
    order:     order     ?? this.order,
    bullets:   bullets   ?? this.bullets,
    published: published ?? this.published,
  );
}
