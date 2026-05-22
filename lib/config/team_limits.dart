class TeamLimits {
  static const int _unlimited = -1;

  // Kaç farklı ekibe üye olabilir (kendi kurduğu hariç)
  static int maxJoin({required bool isPro, required bool isDev}) {
    if (isDev) return _unlimited;
    if (isPro) return 4;
    return 2;
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
      return 'Pro hesapla en fazla 4 ekibe katılabilirsin. Daha fazlası için bizimle iletişime geç.';
    }
    return '2 ekibe katılma limitine ulaştın. Şu an 1 ekip kurma + 2 farklı ekibe üye olma hakkın var. Daha fazlası için Pro üyelik gerekiyor — yakında geliyor, takipte kal!';
  }

  static String createLimitMessage({required bool isPro, required bool isDev}) {
    if (isDev) return '';
    if (isPro) {
      return 'Pro hesapla en fazla 3 ekip kurabilirsin. Daha fazlası için bizimle iletişime geç.';
    }
    return 'En fazla 1 ekip kurabilirsin. Daha fazlası için Pro üyelik gerekiyor — yakında geliyor, takipte kal!';
  }

  static String joinLimitLabel({required bool isPro, required bool isDev}) {
    final max = maxJoin(isPro: isPro, isDev: isDev);
    return max == _unlimited ? 'sınırsız' : '$max ekip';
  }
}
