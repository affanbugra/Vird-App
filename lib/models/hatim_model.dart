import 'package:cloud_firestore/cloud_firestore.dart';

enum HatimType { arapca, meal }

class Hatim {
  final String id;
  final HatimType type;
  final String? name;
  final int currentPage;
  final int totalPages;
  final DateTime createdAt;
  final DateTime updatedAt;

  Hatim({
    required this.id,
    required this.type,
    this.name,
    this.currentPage = 0,
    this.totalPages = 604,
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
      totalPages: data['totalPages'] ?? 604,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type == HatimType.arapca ? 'arapca' : 'meal',
      if (name != null && name!.isNotEmpty) 'name': name,
      'currentPage': currentPage,
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
