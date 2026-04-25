import 'package:cloud_firestore/cloud_firestore.dart';

enum HatimType { arapca, meal }

class Hatim {
  final String id;
  final HatimType type;
  final int currentPage;
  final int totalPages;
  final DateTime createdAt;
  final DateTime updatedAt;

  Hatim({
    required this.id,
    required this.type,
    this.currentPage = 0,
    this.totalPages = 604,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Hatim.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Hatim(
      id: doc.id,
      type: data['type'] == 'arapca' ? HatimType.arapca : HatimType.meal,
      currentPage: data['currentPage'] ?? 0,
      totalPages: data['totalPages'] ?? 604,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type == HatimType.arapca ? 'arapca' : 'meal',
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
