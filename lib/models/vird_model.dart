import 'package:cloud_firestore/cloud_firestore.dart';

class VirdItem {
  final String id;
  final String title;
  final String? arabicTitle;
  final String description;
  final String category; // 'sure' | 'zikir' | 'dua' | 'custom'
  final int targetCount;
  final String recommendedTime;
  final String? hadith;
  final bool active;
  final bool isCustom;

  VirdItem({
    required this.id,
    required this.title,
    this.arabicTitle,
    required this.description,
    required this.category,
    required this.targetCount,
    required this.recommendedTime,
    this.hadith,
    required this.active,
    this.isCustom = false,
  });

  VirdItem copyWith({
    String? title,
    String? arabicTitle,
    String? description,
    String? category,
    int? targetCount,
    String? recommendedTime,
    String? hadith,
    bool? active,
    bool? isCustom,
  }) {
    return VirdItem(
      id: id,
      title: title ?? this.title,
      arabicTitle: arabicTitle ?? this.arabicTitle,
      description: description ?? this.description,
      category: category ?? this.category,
      targetCount: targetCount ?? this.targetCount,
      recommendedTime: recommendedTime ?? this.recommendedTime,
      hadith: hadith ?? this.hadith,
      active: active ?? this.active,
      isCustom: isCustom ?? this.isCustom,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'arabicTitle': arabicTitle,
      'description': description,
      'category': category,
      'targetCount': targetCount,
      'recommendedTime': recommendedTime,
      'hadith': hadith,
      'active': active,
      'isCustom': isCustom,
    };
  }

  factory VirdItem.fromMap(Map<String, dynamic> map) {
    return VirdItem(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      arabicTitle: map['arabicTitle'],
      description: map['description'] ?? '',
      category: map['category'] ?? 'custom',
      targetCount: map['targetCount'] ?? 1,
      recommendedTime: map['recommendedTime'] ?? 'Günlük',
      hadith: map['hadith'],
      active: map['active'] ?? false,
      isCustom: map['isCustom'] ?? false,
    );
  }

  factory VirdItem.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return VirdItem.fromMap({
      ...data,
      'id': doc.id,
    });
  }

  static List<VirdItem> get defaultVirds => [
        // --- SURELER ---
        VirdItem(
          id: 'yasin',
          title: 'Yâsîn Suresi',
          arabicTitle: 'سورة يس',
          category: 'sure',
          targetCount: 1,
          recommendedTime: 'Sabah Vakti',
          description: 'Allah\'ı ve ahireti kastederek okuyanın bağışlanacağı rivayet edilmiştir.',
          hadith: 'Onu bir kimse ancak Allah\'ı ve ahiret gününü dileyerek okursa, Allah onu bağışlar. (Ebû Dâvûd, Cenâiz, 20)',
          active: false,
        ),
        VirdItem(
          id: 'fetih',
          title: 'Fetih Suresi',
          arabicTitle: 'سورة الفتح',
          category: 'sure',
          targetCount: 1,
          recommendedTime: 'Günlük',
          description: 'Resûlullah\'ın "dünyadan daha kıymetli" diye nitelendirdiği mübarek sûrelerden biri.',
          hadith: 'Resûlullah\'a (sav.) Fetih sûresi indirildiğinde "Bu gece bana öyle bir sûre indirildi ki, o benim için dünyadan ve dünyadaki her şeyden daha kıymetlidir" buyurdu. (Buhârî, Meğâzî, 35; Müslim, Müsâfirîn, 252)',
          active: false,
        ),
        VirdItem(
          id: 'nebe',
          title: 'Nebe Suresi (Amme)',
          arabicTitle: 'سورة النبأ',
          category: 'sure',
          targetCount: 1,
          recommendedTime: 'Günlük',
          description: 'Kıyameti ve hesap gününü güçlü sahnelerle anlatan mufassal surelerden biri.',
          hadith: 'Resûlullah (sav.) namazlarında bu sûreyi tilâvet eder; "Beni Amme sûresi ihtiyarlattı" buyururdu — kıyameti ve hesabı bu kadar derin işlediği için. (Buhârî, Fezâilü\'l-Kur\'ân, 28; Tirmizî, Tefsir, 56)',
          active: false,
        ),
        VirdItem(
          id: 'vakia',
          title: 'Vâkıa Suresi',
          arabicTitle: 'سورة الواقعة',
          category: 'sure',
          targetCount: 1,
          recommendedTime: 'Her Gece',
          description: 'Her gece okuyanın fakirlikten korunacağı rivayet edilmiştir.',
          hadith: 'Hz. Abdullah b. Mes\'ûd (r.a.) kızlarına her gece Vâkıa sûresini okumalarını emreder ve Resûlullah\'ın (sav.) "Her gece Vâkıa\'yı okuyana asla fakirlik dokunmaz" buyurduğunu aktarırdı. (İbn Hanbel, Fedâilü\'s-Sahâbe, II, 726)',
          active: false,
        ),
        VirdItem(
          id: 'mulk',
          title: 'Mülk Suresi (Tebâreke)',
          arabicTitle: 'سورة الملك',
          category: 'sure',
          targetCount: 1,
          recommendedTime: 'Her Gece (Uyumadan Önce)',
          description: 'Resûlullah her gece uyumadan önce Mülk sûresini okurdu. Kabir azabından koruyucu olduğu rivayet edilmektedir.',
          hadith: 'Kur\'an\'da otuz ayetlik bir sure vardır ki, okuyana şefaat eder ve günahları bağışlanır. O, Mülk suresidir. (Tirmizî, Fedâilü\'l-Kur\'ân, 9; Ebû Dâvûd, Salât, 322; İbn Mâce, Edep, 52)',
          active: false,
        ),
        VirdItem(
          id: 'kehf',
          title: 'Kehf Suresi',
          arabicTitle: 'سورة الكهف',
          category: 'sure',
          targetCount: 1,
          recommendedTime: 'Cuma Gününe Özel',
          description: 'Cuma günleri okunması çok faziletlidir.',
          hadith: 'Kim Cuma günü Kehf suresini okursa, iki Cuma arasını aydınlatan bir nur parlar. (Hâkim, Müstedrek, II, 399; Beyhakî, es-Sünenü\'l-Kübrâ, III, 353)',
          active: false,
        ),

        // --- ZİKİRLER ---
        VirdItem(
          id: 'subhanallah_bihamdihi',
          title: 'Sübhanallahi ve bi-hamdihî',
          arabicTitle: 'سبحان الله وبحمده',
          category: 'zikir',
          targetCount: 100,
          recommendedTime: 'Günlük',
          description: 'Günde 100 defa okunması günahların dökülmesine vesiledir.',
          hadith: 'Kim günde yüz defa \'Sübhanallahi ve bi-hamdihî\' derse, günahları deniz köpüğü kadar bile olsa bağışlanır. (Buhârî, Deavât, 65; Müslim, Zikir, 28)',
          active: false,
        ),
        VirdItem(
          id: 'salavat',
          title: 'Salavat-ı Şerife',
          arabicTitle: 'اللهم صل على محمد',
          category: 'zikir',
          targetCount: 100,
          recommendedTime: 'Günlük',
          description: 'Resûlullah Efendimiz\'e (sav) salat ve selam getirmek.',
          hadith: 'Kim bana bir defa salâtü selâm getirirse, Allah Teâlâ ona on defa rahmet eder, on günahını siler ve derecesini on kat yükseltir. (Nesâî, Sehv, 55)',
          active: false,
        ),
        VirdItem(
          id: 'istigfar',
          title: 'İstiğfar (Estağfirullah)',
          arabicTitle: 'أستغفر الله',
          category: 'zikir',
          targetCount: 100,
          recommendedTime: 'Günlük',
          description: 'Bağışlanma dilemek ve manevi ferahlık.',
          hadith: 'Kim istiğfara devam ederse, Allah ona her darlıktan bir çıkış, her kederden bir kurtuluş yolu açar ve onu ummadığı yerden rızıklandırır. (Ebû Dâvûd, Vitir, 26)',
          active: false,
        ),
        VirdItem(
          id: 'kelime_i_tevhid',
          title: 'Kelime-i Tevhid',
          arabicTitle: 'لا إله إلا الله',
          category: 'zikir',
          targetCount: 100,
          recommendedTime: 'Günlük',
          description: 'Tevhid inancını tazelemek.',
          hadith: 'Zikrin en faziletlisi \'Lâ ilâhe illallâh\'tır. (Tirmizî, Deavât, 9)',
          active: false,
        ),
        VirdItem(
          id: 'la_havle',
          title: 'Lâ Havle ve Lâ Kuvvete illâ Billâh',
          arabicTitle: 'لا حول ولا قوة إلا بالله',
          category: 'zikir',
          targetCount: 100,
          recommendedTime: 'Günlük',
          description: 'Cennet hazinelerinden bir hazine.',
          hadith: 'Sana cennet hazinelerinden bir hazineyi bildireyim mi? O, \'Lâ havle ve lâ kuvvete illâ billâh\'tır. (Buhârî, Megâzî, 38)',
          active: false,
        ),

        // --- DUALAR ---
        VirdItem(
          id: 'seyyidul_istigfar',
          title: 'Seyyidül İstiğfar Duası',
          arabicTitle: 'سيد الاستغفار',
          category: 'dua',
          targetCount: 1,
          recommendedTime: 'Sabah ve Akşam',
          description: 'Tövbe ve istiğfar dualarının en büyüğü.',
          hadith: 'Kim bu Seyyidül İstiğfar duasını inanarak sabahleyin okur da o gün akşama ermeden ölürse cennetliklerdendir. Akşamleyin okur da sabaha ermeden ölürse yine cennetliklerdendir. (Buhârî, Deavât, 2)',
          active: false,
        ),
        VirdItem(
          id: 'ayetel_kursi',
          title: 'Ayetel Kürsi',
          arabicTitle: 'آية الكرسي',
          category: 'dua',
          targetCount: 5,
          recommendedTime: 'Farz Namazların Ardından',
          description: 'Farz namazlardan sonra okunması faziletlidir.',
          hadith: 'Her kim her farz namazın arkasından Ayete\'l-Kürsî\'yi okursa, cennete girmesine ölümden başka hiçbir şey engel olamaz. (Nesâî, Amelü\'l-Yevm, 100)',
          active: false,
        ),
        VirdItem(
          id: 'amenerrasulu',
          title: 'Amenerrasulü',
          arabicTitle: 'آمن الرسول',
          category: 'dua',
          targetCount: 1,
          recommendedTime: 'Yatsı Namazı Sonrası',
          description: 'Bakara suresinin son iki ayetidir. Yatsıdan sonra okunması tavsiye edilir.',
          hadith: 'Bakara suresinin sonundaki iki ayeti geceleyin okuyan kimseye, bu iki ayet her şey için yeterlidir. (Buhârî, Fezâilü\'l-Kur\'ân, 10)',
          active: false,
        ),
      ];
}

class VirdLog {
  final String date; // Format: vird_YYYY-MM-DD
  final Map<String, int> completions; // vird_id -> completed_count or 1 for done

  VirdLog({
    required this.date,
    required this.completions,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': 'vird',
      'date': date,
      'completions': completions,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory VirdLog.fromMap(Map<String, dynamic> map, String docId) {
    final compsRaw = map['completions'] as Map<String, dynamic>? ?? {};
    final completions = compsRaw.map((k, v) => MapEntry(k, v is int ? v : (v == true ? 1 : 0)));
    return VirdLog(
      date: docId,
      completions: completions,
    );
  }

  factory VirdLog.fromDoc(DocumentSnapshot doc) {
    if (!doc.exists) {
      return VirdLog(date: doc.id, completions: {});
    }
    return VirdLog.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  }
}
