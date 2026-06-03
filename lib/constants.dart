import 'dart:math';
import 'package:flutter/material.dart';

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

  static const Map<String, Color> categoryColors = {
    'තොරණ': Color(0xFFFFD700),
    'දන්සල': Color(0xFFFF9800),
    'ධර්ම දේශනාව': Color(0xFF2196F3),
    'බැති ගී': Color(0xFF4CAF50),
    'කලාප': Color(0xFF9C27B0),
    'කූඩු ප්‍රදර්ශන': Color(0xFFF44336),
    'පෙරහැර': Color(0xFF9E9E9E),
  };

  static const Map<String, String> categoryIcons = {
    'තොරණ': '🎆',
    'දන්සල': '🍛',
    'ධර්ම දේශනාව': '📿',
    'බැති ගී': '🎶',
    'කලාප': '🎭',
    'කූඩු ප්‍රදර්ශන': '🏮',
    'පෙරහැර': '🐘',
  };

  static const Map<String, String> categoryNames = {
    'තොරණ': 'Thorana (Fireworks)',
    'දන්සල': 'Dansala (Food Stall)',
    'ධර්ම දේශනාව': 'Dhamma Discourse',
    'බැති ගී': 'Bhakthi Gee (Devotional Songs)',
    'කලාප': 'Kalapa (Art Exhibition)',
    'කූඩු ප්‍රදර්ශන': 'Kudu Pradarshana (Lantern Exhibition)',
    'පෙරහැර': 'Perahera (Procession)',
  };

  static const List<Map<String, dynamic>> leagues = [
    {'name': 'Unranked', 'minLevel': 0, 'maxLevel': 0, 'icon': '🌱'},
    {'name': 'Lantern III', 'minLevel': 1, 'maxLevel': 1, 'icon': '🏮'},
    {'name': 'Lantern II', 'minLevel': 2, 'maxLevel': 2, 'icon': '🏮🏮'},
    {'name': 'Lantern I', 'minLevel': 3, 'maxLevel': 999, 'icon': '🏮🏮🏮'},
  ];

  static const double mapInitialZoom = 13.0;
  static const double mapMaxZoom = 18.0;
  static const double mapFocusZoom = 15.0;
  static const double mapMinZoom = 10.0;
  static const double mapZoomStep = 0.5;
  static const String mapTileUrl =
      'https://cartodb-basemaps-a.global.ssl.fastly.net/light_all/{z}/{x}/{y}.png';

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

  static Color getCategoryColor(String category) {
    return categoryColors[category] ?? Colors.grey;
  }

  static String getCategoryIcon(String category) {
    return categoryIcons[category] ?? '📍';
  }

  static String getCategoryName(String category) {
    return categoryNames[category] ?? category;
  }
}
