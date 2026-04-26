import 'package:flutter/material.dart';

// Türkiye Diyanet mushafı sayfa sistemi:
// Fatiha → özel blok (page 0), Bakara 1. ayeti → sayfa 1.
// Sayfalı toplam: 604 (1–604). Fatiha dahil 605 eleman.
// Cüz 1–29: 20'şer sayfa. Cüz 30: 24 sayfa (581–604).

class SurahInfo {
  final int id;
  final String name;
  final int startPage; // Türkiye sayfa numarası (Fatiha = 0)
  final int endPage;

  const SurahInfo({
    required this.id,
    required this.name,
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
    SurahInfo(id: 1,   name: 'Fâtiha',       startPage: 0,   endPage: 0),
    SurahInfo(id: 2,   name: 'Bakara',        startPage: 1,   endPage: 48),
    SurahInfo(id: 3,   name: 'Âl-i İmrân',   startPage: 49,  endPage: 75),
    SurahInfo(id: 4,   name: 'Nisâ',          startPage: 76,  endPage: 105),
    SurahInfo(id: 5,   name: 'Mâide',         startPage: 105, endPage: 126),
    SurahInfo(id: 6,   name: "En'âm",         startPage: 127, endPage: 149),
    SurahInfo(id: 7,   name: "A'râf",         startPage: 150, endPage: 175),
    SurahInfo(id: 8,   name: 'Enfâl',         startPage: 176, endPage: 185),
    SurahInfo(id: 9,   name: 'Tevbe',         startPage: 186, endPage: 206),
    SurahInfo(id: 10,  name: 'Yûnus',         startPage: 207, endPage: 220),
    SurahInfo(id: 11,  name: 'Hûd',           startPage: 220, endPage: 234),
    SurahInfo(id: 12,  name: 'Yûsuf',         startPage: 234, endPage: 247),
    SurahInfo(id: 13,  name: "Ra'd",          startPage: 248, endPage: 254),
    SurahInfo(id: 14,  name: 'İbrâhîm',       startPage: 254, endPage: 260),
    SurahInfo(id: 15,  name: 'Hicr',          startPage: 261, endPage: 266),
    SurahInfo(id: 16,  name: 'Nahl',          startPage: 266, endPage: 280),
    SurahInfo(id: 17,  name: 'İsrâ',          startPage: 281, endPage: 292),
    SurahInfo(id: 18,  name: 'Kehf',          startPage: 292, endPage: 303),
    SurahInfo(id: 19,  name: 'Meryem',        startPage: 304, endPage: 311),
    SurahInfo(id: 20,  name: 'Tâhâ',          startPage: 311, endPage: 320),
    SurahInfo(id: 21,  name: 'Enbiyâ',        startPage: 321, endPage: 330),
    SurahInfo(id: 22,  name: 'Hac',           startPage: 331, endPage: 340),
    SurahInfo(id: 23,  name: "Mü'minûn",      startPage: 341, endPage: 348),
    SurahInfo(id: 24,  name: 'Nûr',           startPage: 349, endPage: 358),
    SurahInfo(id: 25,  name: 'Furkân',        startPage: 358, endPage: 365),
    SurahInfo(id: 26,  name: "Şu'arâ",        startPage: 366, endPage: 375),
    SurahInfo(id: 27,  name: 'Neml',          startPage: 376, endPage: 384),
    SurahInfo(id: 28,  name: 'Kasas',         startPage: 384, endPage: 395),
    SurahInfo(id: 29,  name: 'Ankebût',       startPage: 395, endPage: 403),
    SurahInfo(id: 30,  name: 'Rûm',           startPage: 403, endPage: 409),
    SurahInfo(id: 31,  name: 'Lokmân',        startPage: 410, endPage: 413),
    SurahInfo(id: 32,  name: 'Secde',         startPage: 414, endPage: 416),
    SurahInfo(id: 33,  name: 'Ahzâb',         startPage: 417, endPage: 426),
    SurahInfo(id: 34,  name: "Sebe'",         startPage: 427, endPage: 433),
    SurahInfo(id: 35,  name: 'Fâtır',         startPage: 433, endPage: 439),
    SurahInfo(id: 36,  name: 'Yâsîn',         startPage: 439, endPage: 444),
    SurahInfo(id: 37,  name: 'Sâffât',        startPage: 445, endPage: 451),
    SurahInfo(id: 38,  name: 'Sâd',           startPage: 452, endPage: 457),
    SurahInfo(id: 39,  name: 'Zümer',         startPage: 457, endPage: 466),
    SurahInfo(id: 40,  name: "Mü'min",        startPage: 466, endPage: 475),
    SurahInfo(id: 41,  name: 'Fussilet',      startPage: 476, endPage: 481),
    SurahInfo(id: 42,  name: 'Şûrâ',          startPage: 482, endPage: 488),
    SurahInfo(id: 43,  name: 'Zuhruf',        startPage: 488, endPage: 494),
    SurahInfo(id: 44,  name: 'Duhân',         startPage: 495, endPage: 497),
    SurahInfo(id: 45,  name: 'Câsiye',        startPage: 498, endPage: 501),
    SurahInfo(id: 46,  name: 'Ahkâf',         startPage: 501, endPage: 505),
    SurahInfo(id: 47,  name: 'Muhammed',      startPage: 506, endPage: 509),
    SurahInfo(id: 48,  name: 'Fetih',         startPage: 510, endPage: 514),
    SurahInfo(id: 49,  name: 'Hucurât',       startPage: 514, endPage: 516),
    SurahInfo(id: 50,  name: 'Kâf',           startPage: 517, endPage: 519),
    SurahInfo(id: 51,  name: 'Zâriyât',       startPage: 519, endPage: 522),
    SurahInfo(id: 52,  name: 'Tûr',           startPage: 522, endPage: 524),
    SurahInfo(id: 53,  name: 'Necm',          startPage: 525, endPage: 527),
    SurahInfo(id: 54,  name: 'Kamer',         startPage: 527, endPage: 530),
    SurahInfo(id: 55,  name: 'Rahmân',        startPage: 530, endPage: 533),
    SurahInfo(id: 56,  name: 'Vâkıa',         startPage: 533, endPage: 536),
    SurahInfo(id: 57,  name: 'Hadîd',         startPage: 536, endPage: 540),
    SurahInfo(id: 58,  name: 'Mücâdele',      startPage: 541, endPage: 544),
    SurahInfo(id: 59,  name: 'Haşr',          startPage: 544, endPage: 547),
    SurahInfo(id: 60,  name: 'Mümtehine',     startPage: 548, endPage: 550),
    SurahInfo(id: 61,  name: 'Saff',          startPage: 550, endPage: 551),
    SurahInfo(id: 62,  name: 'Cuma',          startPage: 552, endPage: 553),
    SurahInfo(id: 63,  name: 'Münâfikûn',     startPage: 553, endPage: 554),
    SurahInfo(id: 64,  name: 'Tegâbün',       startPage: 555, endPage: 556),
    SurahInfo(id: 65,  name: 'Talâk',         startPage: 557, endPage: 558),
    SurahInfo(id: 66,  name: 'Tahrîm',        startPage: 559, endPage: 560),
    SurahInfo(id: 67,  name: 'Mülk',          startPage: 561, endPage: 563),
    SurahInfo(id: 68,  name: 'Kalem',         startPage: 563, endPage: 565),
    SurahInfo(id: 69,  name: 'Hâkka',         startPage: 565, endPage: 567),
    SurahInfo(id: 70,  name: 'Meâric',        startPage: 567, endPage: 569),
    SurahInfo(id: 71,  name: 'Nûh',           startPage: 569, endPage: 570),
    SurahInfo(id: 72,  name: 'Cin',           startPage: 571, endPage: 572),
    SurahInfo(id: 73,  name: 'Müzzemmil',     startPage: 573, endPage: 574),
    SurahInfo(id: 74,  name: 'Müddessir',     startPage: 574, endPage: 576),
    SurahInfo(id: 75,  name: 'Kıyâme',        startPage: 576, endPage: 577),
    SurahInfo(id: 76,  name: 'İnsân',         startPage: 577, endPage: 579),
    SurahInfo(id: 77,  name: 'Mürselât',      startPage: 579, endPage: 580),
    SurahInfo(id: 78,  name: "Nebe'",         startPage: 581, endPage: 582),
    SurahInfo(id: 79,  name: 'Nâziât',        startPage: 582, endPage: 583),
    SurahInfo(id: 80,  name: 'Abese',         startPage: 584, endPage: 585),
    SurahInfo(id: 81,  name: 'Tekvîr',        startPage: 585, endPage: 586),
    SurahInfo(id: 82,  name: 'İnfitâr',       startPage: 586, endPage: 586),
    SurahInfo(id: 83,  name: 'Mutaffifîn',    startPage: 587, endPage: 588),
    SurahInfo(id: 84,  name: 'İnşikâk',       startPage: 588, endPage: 589),
    SurahInfo(id: 85,  name: 'Bürûc',         startPage: 589, endPage: 590),
    SurahInfo(id: 86,  name: 'Târık',         startPage: 590, endPage: 590),
    SurahInfo(id: 87,  name: "A'lâ",          startPage: 590, endPage: 591),
    SurahInfo(id: 88,  name: 'Gâşiye',        startPage: 591, endPage: 592),
    SurahInfo(id: 89,  name: 'Fecr',          startPage: 592, endPage: 593),
    SurahInfo(id: 90,  name: 'Beled',         startPage: 593, endPage: 594),
    SurahInfo(id: 91,  name: 'Şems',          startPage: 594, endPage: 594),
    SurahInfo(id: 92,  name: 'Leyl',          startPage: 595, endPage: 595),
    SurahInfo(id: 93,  name: 'Duhâ',          startPage: 595, endPage: 596),
    SurahInfo(id: 94,  name: 'İnşirâh',       startPage: 596, endPage: 596),
    SurahInfo(id: 95,  name: 'Tîn',           startPage: 596, endPage: 597),
    SurahInfo(id: 96,  name: 'Alak',          startPage: 597, endPage: 597),
    SurahInfo(id: 97,  name: 'Kadr',          startPage: 598, endPage: 598),
    SurahInfo(id: 98,  name: 'Beyyine',       startPage: 598, endPage: 598),
    SurahInfo(id: 99,  name: 'Zilzâl',        startPage: 599, endPage: 599),
    SurahInfo(id: 100, name: 'Âdiyât',        startPage: 599, endPage: 599),
    SurahInfo(id: 101, name: 'Kâria',         startPage: 600, endPage: 600),
    SurahInfo(id: 102, name: 'Tekâsür',       startPage: 600, endPage: 600),
    SurahInfo(id: 103, name: 'Asr',           startPage: 601, endPage: 601),
    SurahInfo(id: 104, name: 'Hümeze',        startPage: 601, endPage: 601),
    SurahInfo(id: 105, name: 'Fîl',           startPage: 601, endPage: 601),
    SurahInfo(id: 106, name: 'Kureyş',        startPage: 602, endPage: 602),
    SurahInfo(id: 107, name: 'Mâûn',          startPage: 602, endPage: 602),
    SurahInfo(id: 108, name: 'Kevser',        startPage: 602, endPage: 602),
    SurahInfo(id: 109, name: 'Kâfirûn',       startPage: 603, endPage: 603),
    SurahInfo(id: 110, name: 'Nasr',          startPage: 603, endPage: 603),
    SurahInfo(id: 111, name: 'Tebbet',        startPage: 603, endPage: 603),
    SurahInfo(id: 112, name: 'İhlâs',         startPage: 604, endPage: 604),
    SurahInfo(id: 113, name: 'Felak',         startPage: 604, endPage: 604),
    SurahInfo(id: 114, name: 'Nâs',           startPage: 604, endPage: 604),
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
