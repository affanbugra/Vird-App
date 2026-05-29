import 'package:flutter/material.dart';

// Türkiye Diyanet mushafı sayfa sistemi:
// Fatiha → özel blok (page 0), Bakara 1. ayeti → sayfa 1.
// Sayfalı toplam: 604 (1–604). Fatiha dahil 605 eleman.
// Cüz 1–29: 20'şer sayfa. Cüz 30: 24 sayfa (581–604).

class SurahInfo {
  final int id;
  final String name;
  final String arabicName;
  final int startPage; // Türkiye sayfa numarası (Fatiha = 0)
  final int endPage;

  const SurahInfo({
    required this.id,
    required this.name,
    required this.arabicName,
    required this.startPage,
    required this.endPage,
  });
}

class CuzInfo {
  final int cuzNo;
  final int startPage;
  final int endPage;

  const CuzInfo({
    required this.cuzNo,
    required this.startPage,
    required this.endPage,
  });

  int get pageCount => endPage - startPage + 1;
}

class QuranData {
  static const int totalNumberedPages = 604; // sayfa 1–604

  // ── Sure verisi ───────────────────────────────────────────────────────────
  static const List<SurahInfo> surahlar = [
    SurahInfo(id: 1,   name: 'Fâtiha',       arabicName: 'الفاتحة',    startPage: 0,   endPage: 0),
    SurahInfo(id: 2,   name: 'Bakara',        arabicName: 'البقرة',     startPage: 1,   endPage: 48),
    SurahInfo(id: 3,   name: 'Âl-i İmrân',   arabicName: 'آل عمران',   startPage: 49,  endPage: 75),
    SurahInfo(id: 4,   name: 'Nisâ',          arabicName: 'النساء',     startPage: 76,  endPage: 105),
    SurahInfo(id: 5,   name: 'Mâide',         arabicName: 'المائدة',    startPage: 105, endPage: 126),
    SurahInfo(id: 6,   name: "En'âm",         arabicName: 'الأنعام',    startPage: 127, endPage: 149),
    SurahInfo(id: 7,   name: "A'râf",         arabicName: 'الأعراف',    startPage: 150, endPage: 175),
    SurahInfo(id: 8,   name: 'Enfâl',         arabicName: 'الأنفال',    startPage: 176, endPage: 185),
    SurahInfo(id: 9,   name: 'Tevbe',         arabicName: 'التوبة',     startPage: 186, endPage: 206),
    SurahInfo(id: 10,  name: 'Yûnus',         arabicName: 'يونس',       startPage: 207, endPage: 220),
    SurahInfo(id: 11,  name: 'Hûd',           arabicName: 'هود',        startPage: 220, endPage: 234),
    SurahInfo(id: 12,  name: 'Yûsuf',         arabicName: 'يوسف',       startPage: 234, endPage: 247),
    SurahInfo(id: 13,  name: "Ra'd",          arabicName: 'الرعد',      startPage: 248, endPage: 254),
    SurahInfo(id: 14,  name: 'İbrâhîm',       arabicName: 'إبراهيم',    startPage: 254, endPage: 260),
    SurahInfo(id: 15,  name: 'Hicr',          arabicName: 'الحجر',      startPage: 261, endPage: 266),
    SurahInfo(id: 16,  name: 'Nahl',          arabicName: 'النحل',      startPage: 266, endPage: 280),
    SurahInfo(id: 17,  name: 'İsrâ',          arabicName: 'الإسراء',    startPage: 281, endPage: 292),
    SurahInfo(id: 18,  name: 'Kehf',          arabicName: 'الكهف',      startPage: 292, endPage: 303),
    SurahInfo(id: 19,  name: 'Meryem',        arabicName: 'مريم',       startPage: 304, endPage: 311),
    SurahInfo(id: 20,  name: 'Tâhâ',          arabicName: 'طه',         startPage: 311, endPage: 320),
    SurahInfo(id: 21,  name: 'Enbiyâ',        arabicName: 'الأنبياء',   startPage: 321, endPage: 330),
    SurahInfo(id: 22,  name: 'Hac',           arabicName: 'الحج',       startPage: 331, endPage: 340),
    SurahInfo(id: 23,  name: "Mü'minûn",      arabicName: 'المؤمنون',   startPage: 341, endPage: 348),
    SurahInfo(id: 24,  name: 'Nûr',           arabicName: 'النور',      startPage: 349, endPage: 358),
    SurahInfo(id: 25,  name: 'Furkân',        arabicName: 'الفرقان',    startPage: 358, endPage: 365),
    SurahInfo(id: 26,  name: "Şu'arâ",        arabicName: 'الشعراء',    startPage: 366, endPage: 375),
    SurahInfo(id: 27,  name: 'Neml',          arabicName: 'النمل',      startPage: 376, endPage: 384),
    SurahInfo(id: 28,  name: 'Kasas',         arabicName: 'القصص',      startPage: 384, endPage: 395),
    SurahInfo(id: 29,  name: 'Ankebût',       arabicName: 'العنكبوت',   startPage: 395, endPage: 403),
    SurahInfo(id: 30,  name: 'Rûm',           arabicName: 'الروم',      startPage: 403, endPage: 409),
    SurahInfo(id: 31,  name: 'Lokmân',        arabicName: 'لقمان',      startPage: 410, endPage: 413),
    SurahInfo(id: 32,  name: 'Secde',         arabicName: 'السجدة',     startPage: 414, endPage: 416),
    SurahInfo(id: 33,  name: 'Ahzâb',         arabicName: 'الأحزاب',    startPage: 417, endPage: 426),
    SurahInfo(id: 34,  name: "Sebe'",         arabicName: 'سبأ',        startPage: 427, endPage: 433),
    SurahInfo(id: 35,  name: 'Fâtır',         arabicName: 'فاطر',       startPage: 433, endPage: 439),
    SurahInfo(id: 36,  name: 'Yâsîn',         arabicName: 'يس',         startPage: 439, endPage: 444),
    SurahInfo(id: 37,  name: 'Sâffât',        arabicName: 'الصافات',    startPage: 445, endPage: 451),
    SurahInfo(id: 38,  name: 'Sâd',           arabicName: 'ص',          startPage: 452, endPage: 457),
    SurahInfo(id: 39,  name: 'Zümer',         arabicName: 'الزمر',      startPage: 457, endPage: 466),
    SurahInfo(id: 40,  name: "Mü'min",        arabicName: 'غافر',       startPage: 466, endPage: 475),
    SurahInfo(id: 41,  name: 'Fussilet',      arabicName: 'فصلت',       startPage: 476, endPage: 481),
    SurahInfo(id: 42,  name: 'Şûrâ',          arabicName: 'الشورى',     startPage: 482, endPage: 488),
    SurahInfo(id: 43,  name: 'Zuhruf',        arabicName: 'الزخرف',     startPage: 488, endPage: 494),
    SurahInfo(id: 44,  name: 'Duhân',         arabicName: 'الدخان',     startPage: 495, endPage: 497),
    SurahInfo(id: 45,  name: 'Câsiye',        arabicName: 'الجاثية',    startPage: 498, endPage: 501),
    SurahInfo(id: 46,  name: 'Ahkâf',         arabicName: 'الأحقاف',    startPage: 501, endPage: 505),
    SurahInfo(id: 47,  name: 'Muhammed',      arabicName: 'محمد',       startPage: 506, endPage: 509),
    SurahInfo(id: 48,  name: 'Fetih',         arabicName: 'الفتح',      startPage: 510, endPage: 514),
    SurahInfo(id: 49,  name: 'Hucurât',       arabicName: 'الحجرات',    startPage: 514, endPage: 516),
    SurahInfo(id: 50,  name: 'Kâf',           arabicName: 'ق',          startPage: 517, endPage: 519),
    SurahInfo(id: 51,  name: 'Zâriyât',       arabicName: 'الذاريات',   startPage: 519, endPage: 522),
    SurahInfo(id: 52,  name: 'Tûr',           arabicName: 'الطور',      startPage: 522, endPage: 524),
    SurahInfo(id: 53,  name: 'Necm',          arabicName: 'النجم',      startPage: 525, endPage: 527),
    SurahInfo(id: 54,  name: 'Kamer',         arabicName: 'القمر',      startPage: 527, endPage: 530),
    SurahInfo(id: 55,  name: 'Rahmân',        arabicName: 'الرحمن',     startPage: 530, endPage: 533),
    SurahInfo(id: 56,  name: 'Vâkıa',         arabicName: 'الواقعة',    startPage: 533, endPage: 536),
    SurahInfo(id: 57,  name: 'Hadîd',         arabicName: 'الحديد',     startPage: 536, endPage: 540),
    SurahInfo(id: 58,  name: 'Mücâdele',      arabicName: 'المجادلة',   startPage: 541, endPage: 544),
    SurahInfo(id: 59,  name: 'Haşr',          arabicName: 'الحشر',      startPage: 544, endPage: 547),
    SurahInfo(id: 60,  name: 'Mümtehine',     arabicName: 'الممتحنة',   startPage: 548, endPage: 550),
    SurahInfo(id: 61,  name: 'Saff',          arabicName: 'الصف',       startPage: 550, endPage: 551),
    SurahInfo(id: 62,  name: 'Cuma',          arabicName: 'الجمعة',     startPage: 552, endPage: 553),
    SurahInfo(id: 63,  name: 'Münâfikûn',     arabicName: 'المنافقون',  startPage: 553, endPage: 554),
    SurahInfo(id: 64,  name: 'Tegâbün',       arabicName: 'التغابن',    startPage: 555, endPage: 556),
    SurahInfo(id: 65,  name: 'Talâk',         arabicName: 'الطلاق',     startPage: 557, endPage: 558),
    SurahInfo(id: 66,  name: 'Tahrîm',        arabicName: 'التحريم',    startPage: 559, endPage: 560),
    SurahInfo(id: 67,  name: 'Mülk',          arabicName: 'الملك',      startPage: 561, endPage: 563),
    SurahInfo(id: 68,  name: 'Kalem',         arabicName: 'القلم',      startPage: 563, endPage: 565),
    SurahInfo(id: 69,  name: 'Hâkka',         arabicName: 'الحاقة',     startPage: 565, endPage: 567),
    SurahInfo(id: 70,  name: 'Meâric',        arabicName: 'المعارج',    startPage: 567, endPage: 569),
    SurahInfo(id: 71,  name: 'Nûh',           arabicName: 'نوح',        startPage: 569, endPage: 570),
    SurahInfo(id: 72,  name: 'Cin',           arabicName: 'الجن',       startPage: 571, endPage: 572),
    SurahInfo(id: 73,  name: 'Müzzemmil',     arabicName: 'المزمل',     startPage: 573, endPage: 574),
    SurahInfo(id: 74,  name: 'Müddessir',     arabicName: 'المدثر',     startPage: 574, endPage: 576),
    SurahInfo(id: 75,  name: 'Kıyâme',        arabicName: 'القيامة',    startPage: 576, endPage: 577),
    SurahInfo(id: 76,  name: 'İnsân',         arabicName: 'الإنسان',    startPage: 577, endPage: 579),
    SurahInfo(id: 77,  name: 'Mürselât',      arabicName: 'المرسلات',   startPage: 579, endPage: 580),
    SurahInfo(id: 78,  name: "Nebe'",         arabicName: 'النبأ',      startPage: 581, endPage: 582),
    SurahInfo(id: 79,  name: 'Nâziât',        arabicName: 'النازعات',   startPage: 582, endPage: 583),
    SurahInfo(id: 80,  name: 'Abese',         arabicName: 'عبس',        startPage: 584, endPage: 585),
    SurahInfo(id: 81,  name: 'Tekvîr',        arabicName: 'التكوير',    startPage: 585, endPage: 586),
    SurahInfo(id: 82,  name: 'İnfitâr',       arabicName: 'الانفطار',   startPage: 586, endPage: 586),
    SurahInfo(id: 83,  name: 'Mutaffifîn',    arabicName: 'المطففين',   startPage: 587, endPage: 588),
    SurahInfo(id: 84,  name: 'İnşikâk',       arabicName: 'الانشقاق',   startPage: 588, endPage: 589),
    SurahInfo(id: 85,  name: 'Bürûc',         arabicName: 'البروج',     startPage: 589, endPage: 590),
    SurahInfo(id: 86,  name: 'Târık',         arabicName: 'الطارق',     startPage: 590, endPage: 590),
    SurahInfo(id: 87,  name: "A'lâ",          arabicName: 'الأعلى',     startPage: 590, endPage: 591),
    SurahInfo(id: 88,  name: 'Gâşiye',        arabicName: 'الغاشية',    startPage: 591, endPage: 592),
    SurahInfo(id: 89,  name: 'Fecr',          arabicName: 'الفجر',      startPage: 592, endPage: 593),
    SurahInfo(id: 90,  name: 'Beled',         arabicName: 'البلد',      startPage: 593, endPage: 594),
    SurahInfo(id: 91,  name: 'Şems',          arabicName: 'الشمس',      startPage: 594, endPage: 594),
    SurahInfo(id: 92,  name: 'Leyl',          arabicName: 'الليل',      startPage: 595, endPage: 595),
    SurahInfo(id: 93,  name: 'Duhâ',          arabicName: 'الضحى',      startPage: 595, endPage: 596),
    SurahInfo(id: 94,  name: 'İnşirâh',       arabicName: 'الشرح',      startPage: 596, endPage: 596),
    SurahInfo(id: 95,  name: 'Tîn',           arabicName: 'التين',      startPage: 596, endPage: 597),
    SurahInfo(id: 96,  name: 'Alak',          arabicName: 'العلق',      startPage: 597, endPage: 597),
    SurahInfo(id: 97,  name: 'Kadr',          arabicName: 'القدر',      startPage: 598, endPage: 598),
    SurahInfo(id: 98,  name: 'Beyyine',       arabicName: 'البينة',     startPage: 598, endPage: 598),
    SurahInfo(id: 99,  name: 'Zilzâl',        arabicName: 'الزلزلة',    startPage: 599, endPage: 599),
    SurahInfo(id: 100, name: 'Âdiyât',        arabicName: 'العاديات',   startPage: 599, endPage: 599),
    SurahInfo(id: 101, name: 'Kâria',         arabicName: 'القارعة',    startPage: 600, endPage: 600),
    SurahInfo(id: 102, name: 'Tekâsür',       arabicName: 'التكاثر',    startPage: 600, endPage: 600),
    SurahInfo(id: 103, name: 'Asr',           arabicName: 'العصر',      startPage: 601, endPage: 601),
    SurahInfo(id: 104, name: 'Hümeze',        arabicName: 'الهمزة',     startPage: 601, endPage: 601),
    SurahInfo(id: 105, name: 'Fîl',           arabicName: 'الفيل',      startPage: 601, endPage: 601),
    SurahInfo(id: 106, name: 'Kureyş',        arabicName: 'قريش',       startPage: 602, endPage: 602),
    SurahInfo(id: 107, name: 'Mâûn',          arabicName: 'الماعون',    startPage: 602, endPage: 602),
    SurahInfo(id: 108, name: 'Kevser',        arabicName: 'الكوثر',     startPage: 602, endPage: 602),
    SurahInfo(id: 109, name: 'Kâfirûn',       arabicName: 'الكافرون',   startPage: 603, endPage: 603),
    SurahInfo(id: 110, name: 'Nasr',          arabicName: 'النصر',      startPage: 603, endPage: 603),
    SurahInfo(id: 111, name: 'Tebbet',        arabicName: 'المسد',      startPage: 603, endPage: 603),
    SurahInfo(id: 112, name: 'İhlâs',         arabicName: 'الإخلاص',    startPage: 604, endPage: 604),
    SurahInfo(id: 113, name: 'Felak',         arabicName: 'الفلق',      startPage: 604, endPage: 604),
    SurahInfo(id: 114, name: 'Nâs',           arabicName: 'الناس',      startPage: 604, endPage: 604),
  ];

  // ── Cüz verisi ────────────────────────────────────────────────────────────
  // Cüz 1–29: 20'şer sayfa. Cüz 30: 24 sayfa (581–604).
  // Fatiha (page 0) grid'de ayrıca gösterilir; cüz 1'e sayılmaz.
  static const List<CuzInfo> cuzler = [
    CuzInfo(cuzNo: 1,  startPage: 1,   endPage: 20),
    CuzInfo(cuzNo: 2,  startPage: 21,  endPage: 40),
    CuzInfo(cuzNo: 3,  startPage: 41,  endPage: 60),
    CuzInfo(cuzNo: 4,  startPage: 61,  endPage: 80),
    CuzInfo(cuzNo: 5,  startPage: 81,  endPage: 100),
    CuzInfo(cuzNo: 6,  startPage: 101, endPage: 120),
    CuzInfo(cuzNo: 7,  startPage: 121, endPage: 140),
    CuzInfo(cuzNo: 8,  startPage: 141, endPage: 160),
    CuzInfo(cuzNo: 9,  startPage: 161, endPage: 180),
    CuzInfo(cuzNo: 10, startPage: 181, endPage: 200),
    CuzInfo(cuzNo: 11, startPage: 201, endPage: 220),
    CuzInfo(cuzNo: 12, startPage: 221, endPage: 240),
    CuzInfo(cuzNo: 13, startPage: 241, endPage: 260),
    CuzInfo(cuzNo: 14, startPage: 261, endPage: 280),
    CuzInfo(cuzNo: 15, startPage: 281, endPage: 300),
    CuzInfo(cuzNo: 16, startPage: 301, endPage: 320),
    CuzInfo(cuzNo: 17, startPage: 321, endPage: 340),
    CuzInfo(cuzNo: 18, startPage: 341, endPage: 360),
    CuzInfo(cuzNo: 19, startPage: 361, endPage: 380),
    CuzInfo(cuzNo: 20, startPage: 381, endPage: 400),
    CuzInfo(cuzNo: 21, startPage: 401, endPage: 420),
    CuzInfo(cuzNo: 22, startPage: 421, endPage: 440),
    CuzInfo(cuzNo: 23, startPage: 441, endPage: 460),
    CuzInfo(cuzNo: 24, startPage: 461, endPage: 480),
    CuzInfo(cuzNo: 25, startPage: 481, endPage: 500),
    CuzInfo(cuzNo: 26, startPage: 501, endPage: 520),
    CuzInfo(cuzNo: 27, startPage: 521, endPage: 540),
    CuzInfo(cuzNo: 28, startPage: 541, endPage: 560),
    CuzInfo(cuzNo: 29, startPage: 561, endPage: 580),
    CuzInfo(cuzNo: 30, startPage: 581, endPage: 604),
  ];

  // page=0 → Cüz 1 (Fatiha), page=1–604 → normal arama
  static CuzInfo? cuzForPage(int page) {
    if (page == 0) return cuzler.first;
    for (final cuz in cuzler) {
      if (page >= cuz.startPage && page <= cuz.endPage) return cuz;
    }
    return null;
  }

  // O sayfadaki surelerin Türkçe adlarını döner (" · " ile birleştirir)
  static String surahsOnPage(int page) {
    if (page == 0) return 'Fâtiha';
    final names = surahlar
        .where((s) => s.startPage <= page && s.endPage >= page)
        .map((s) => s.name)
        .toList();
    return names.isEmpty ? '' : names.join(' · ');
  }

  static Color heatColor(int count) {
    if (count == 0) return const Color(0xFFEEEEEF);
    if (count <= 2) return const Color(0xFFB8DFE4);
    if (count <= 5) return const Color(0xFF7EC4CC);
    if (count <= 10) return const Color(0xFF2A7F8C);
    if (count <= 20) return const Color(0xFF1F6370);
    return const Color(0xFF0F3A40);
  }

  // Göreli ısı rengi — max=1 iken bile "en az okunan" seviyede kalır.
  // Taban 10: 10+ okumaya sahip sayfalar tam karanlık eşiğine ulaşabilir.
  static Color heatColorRelative(int count, int maxCount) {
    if (count == 0) return const Color(0xFFEEEEEF);
    final denom = maxCount < 10 ? 10.0 : maxCount.toDouble();
    final ratio = count / denom;
    if (ratio <= 0.1) return const Color(0xFFB8DFE4);
    if (ratio <= 0.3) return const Color(0xFF7EC4CC);
    if (ratio <= 0.55) return const Color(0xFF2A7F8C);
    if (ratio <= 0.8) return const Color(0xFF1F6370);
    return const Color(0xFF0F3A40);
  }
}
