import 'dart:math';

class AppConstants {
  static const List<String> eventCategories = [
    'තොරණ',
    'දන්සල',
    'ධර්ම දේශනාව',
    'බැති ගී',
    'කලාප',
    'කූඩු ප්‍රදර්ශන',
    'පෙරහැර'
  ];

  static const List<Map<String, dynamic>> leagues = [
    {'name': 'Unranked', 'minLevel': 0, 'maxLevel': 0, 'icon': '🌱'},
    {'name': 'Lantern III', 'minLevel': 1, 'maxLevel': 1, 'icon': '🏮'},
    {'name': 'Lantern II', 'minLevel': 2, 'maxLevel': 2, 'icon': '🏮🏮'},
    {'name': 'Lantern I', 'minLevel': 3, 'maxLevel': 999, 'icon': '🏮🏮🏮'},
  ];

  static String getLeagueByLevel(int level) {
    for (var league in leagues) {
      if (level >= league['minLevel'] && level <= league['maxLevel']) {
        return league['name'];
      }
    }
    return 'Unranked';
  }

  static String getLeagueIcon(int level) {
    for (var league in leagues) {
      if (level >= league['minLevel'] && level <= league['maxLevel']) {
        return league['icon'];
      }
    }
    return '🌱';
  }

  static int getRequiredXpForLevel(int level) {
    if (level == 0) return 0;
    return (100 * pow(level, 1.5)).round();
  }

  static int calculateLevelFromXp(int xp) {
    int level = 0;
    while (xp >= getRequiredXpForLevel(level + 1)) {
      level++;
    }
    return level;
  }
}
