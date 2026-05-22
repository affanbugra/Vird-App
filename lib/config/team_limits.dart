class TeamLimits {
  static const int _unlimited = -1;

  // Kaç farklı ekibe üye olabilir (kendi kurduğu hariç)
  static int maxJoin({required bool isPro, required bool isDev}) {
    if (isDev) return _unlimited;
    if (isPro) return 5;
    return 3;
  }

  // Kaç ekip kurabilir (lider olabileceği)
  static int maxCreate({required bool isPro, required bool isDev}) {
    if (isDev) return _unlimited;
    if (isPro) return 3;
    return 1;
  }

  static bool canJoin({
    required bool isPro,
    required bool isDev,
    required int joinedCount, // adminTeamIds HARİÇ, sadece üye olduğu ekip sayısı
  }) {
    final max = maxJoin(isPro: isPro, isDev: isDev);
    return max == _unlimited || joinedCount < max;
  }

  static bool canCreate({
    required bool isPro,
    required bool isDev,
    required int adminCount, // adminTeamIds.length
  }) {
    final max = maxCreate(isPro: isPro, isDev: isDev);
    return max == _unlimited || adminCount < max;
  }

  // Limit aşımında gösterilecek mesaj
  static String joinLimitMessage({required bool isPro, required bool isDev}) {
    if (isDev) return '';
    if (isPro) {
      return 'Pro hesap ekip limitine ulaştı (${maxJoin(isPro: true, isDev: false)} ekip). '
          'Daha fazlası için geliştirici ile iletişime geçebilirsiniz.';
    }
    return 'Ekip limitine ulaştın (${maxJoin(isPro: false, isDev: false)} ekip). '
        'Daha fazla ekibe katılmak için Pro hesap gereklidir — yakında geliyor!';
  }

  static String createLimitMessage({required bool isPro, required bool isDev}) {
    if (isDev) return '';
    if (isPro) {
      return 'Pro hesap ekip kurma limitine ulaştı (${maxCreate(isPro: true, isDev: false)} ekip). '
          'Daha fazlası için geliştirici ile iletişime geçebilirsiniz.';
    }
    return '1\'den fazla ekip kurmak Pro hesap gerektirir. '
        'Pro hesap yakında geliyor!';
  }

  static String joinLimitLabel({required bool isPro, required bool isDev}) {
    final max = maxJoin(isPro: isPro, isDev: isDev);
    return max == _unlimited ? 'sınırsız' : '$max ekip';
  }
}
