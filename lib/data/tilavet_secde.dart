// Kuran-i Kerim 14 tilavet secdesi sayfa numaralari
class TilavetSecdeData {
  static const Map<int, String> secdePages = {
    176: "A'raf 206",
    251: "Ra'd 15",
    272: "Nahl 49-50",
    293: "Isra 107-109",
    308: "Meryem 58",
    332: "Hac 18",
    365: "Furkan 60",
    379: "Neml 25-26",
    415: "Secde 15",
    454: "Sad 24",
    480: "Fussilet 37-38",
    527: "Necm 62",
    589: "Insikak 21",
    598: "Alak 19",
  };

  static bool hasSecde(int page) => secdePages.containsKey(page);
  static String? secdeLabel(int page) => secdePages[page];

  static List<int> secdesInRange(int startPage, int endPage) {
    return secdePages.keys
        .where((p) => p >= startPage && p <= endPage)
        .toList()
      ..sort();
  }
}
