import 'package:cloud_firestore/cloud_firestore.dart';

class TeamModel {
  final String id;
  final String name;
  final String description;
  final String penaltyNote;
  final String adminUid;
  final int memberCount;
  final DateTime createdAt;
  final String? logoAsset;
  final bool isPrivate;
  final String inviteCode;
  // 'all' | 'men' | 'women'
  final String genderPolicy;
  // Sadece private + all gruplarda geçerli: karşı cinsin adı tam görünsün mü?
  final bool showCrossGenderNames;

  const TeamModel({
    required this.id,
    required this.name,
    required this.description,
    required this.penaltyNote,
    required this.adminUid,
    required this.memberCount,
    required this.createdAt,
    this.logoAsset,
    required this.isPrivate,
    required this.inviteCode,
    this.genderPolicy = 'all',
    this.showCrossGenderNames = true,
  });

  factory TeamModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TeamModel(
      id: doc.id,
      name: data['name'] as String? ?? '',
      description: data['description'] as String? ?? '',
      penaltyNote: data['penaltyNote'] as String? ?? '',
      adminUid: data['adminUid'] as String? ?? '',
      memberCount: data['memberCount'] as int? ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      logoAsset: data['logoAsset'] as String?,
      isPrivate: data['isPrivate'] as bool? ?? true,
      inviteCode: data['inviteCode'] as String? ?? '',
      genderPolicy: data['genderPolicy'] as String? ?? 'all',
      showCrossGenderNames: data['showCrossGenderNames'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'description': description,
        'penaltyNote': penaltyNote,
        'adminUid': adminUid,
        'memberCount': memberCount,
        'createdAt': Timestamp.fromDate(createdAt),
        if (logoAsset != null) 'logoAsset': logoAsset,
        'isPrivate': isPrivate,
        'inviteCode': inviteCode,
        'genderPolicy': genderPolicy,
        'showCrossGenderNames': showCrossGenderNames,
      };
}
