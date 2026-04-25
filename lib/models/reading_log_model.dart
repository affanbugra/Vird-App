import 'package:cloud_firestore/cloud_firestore.dart';
import 'hatim_model.dart';

enum LogMethod { hatim, surah, pages }

class ReadingLog {
  final String id;
  final HatimType type;
  final LogMethod method;
  final int pagesRead;
  final int? surahId;
  final int? startPage;
  final int? endPage;
  final String? hatimId;
  final DateTime createdAt;

  ReadingLog({
    required this.id,
    required this.type,
    required this.method,
    required this.pagesRead,
    this.surahId,
    this.startPage,
    this.endPage,
    this.hatimId,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type == HatimType.arapca ? 'arapca' : 'meal',
      'method': method.name,
      'pagesRead': pagesRead,
      'surahId': surahId,
      'startPage': startPage,
      'endPage': endPage,
      'hatimId': hatimId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory ReadingLog.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ReadingLog(
      id: doc.id,
      type: data['type'] == 'arapca' ? HatimType.arapca : HatimType.meal,
      method: LogMethod.values.firstWhere((e) => e.name == data['method'], orElse: () => LogMethod.pages),
      pagesRead: data['pagesRead'] ?? 0,
      surahId: data['surahId'],
      startPage: data['startPage'],
      endPage: data['endPage'],
      hatimId: data['hatimId'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }
}
