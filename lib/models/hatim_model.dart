import 'package:cloud_firestore/cloud_firestore.dart';

enum HatimType { arapca, meal }

class Hatim {
  final String id;
  final HatimType type;
  final String? name;
  final int currentPage;   // Okunan benzersiz sayfa sayısı (0-604)
  final int lastReadPage;  // En son okunan sayfa numarası (Devam sekmesi için)
  final int totalPages;
  final bool isCompleted;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  Hatim({
    required this.id,
    required this.type,
    this.name,
    this.currentPage = 0,
    this.lastReadPage = 0,
    this.totalPages = 604,
    this.isCompleted = false,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  String get displayName {
    if (name != null && name!.isNotEmpty) return name!;
    return type == HatimType.arapca ? 'Arapça Hatim' : 'Meal Hatimi';
  }

  factory Hatim.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Hatim(
      id: doc.id,
      type: data['type'] == 'arapca' ? HatimType.arapca : HatimType.meal,
      name: data['name'] as String?,
      currentPage: data['currentPage'] ?? 0,
      lastReadPage: data['lastReadPage'] ?? data['currentPage'] ?? 0,
      totalPages: data['totalPages'] ?? 604,
      isCompleted: (data['isCompleted'] as bool?) ?? false,
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type == HatimType.arapca ? 'arapca' : 'meal',
      if (name != null && name!.isNotEmpty) 'name': name,
      'currentPage': currentPage,
      'lastReadPage': lastReadPage,
      'totalPages': totalPages,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  double get progressPercentage {
    if (totalPages == 0) return 0.0;
    return currentPage / totalPages;
  }
}
