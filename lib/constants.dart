import 'dart:math';
import 'package:flutter/material.dart';

class AppConstants {
  // ============================================
  // EVENT CATEGORIES
  // ============================================
  static const List<String> eventCategories = [
    'තොරණ',
    'දන්සල',
    'ධර්ම දේශනාව',
    'බැති ගී',
    'කලාප',
    'කූඩු ප්‍රදර්ශන',
    'පෙරහැර'
  ];

  // ============================================
  // CATEGORY COLORS (Buddhist Theme)
  // ============================================
  static const Map<String, Color> categoryColors = {
    'තොරණ': Color(0xFFFF6B35), // Fiery Orange - Fireworks
    'දන්සල': Color(0xFFF59E0B), // Warm Amber - Food
    'ධර්ම දේශනාව': Color(0xFF4F46E5), // Indigo - Wisdom
    'බැති ගී': Color(0xFF10B981), // Emerald Green - Devotional
    'කලාප': Color(0xFF8B5CF6), // Purple - Art
    'කූඩු ප්‍රදර්ශන': Color(0xFFEF4444), // Red - Lanterns
    'පෙරහැර': Color(0xFFF59E0B), // Amber - Procession
  };

  // ============================================
  // CATEGORY ICONS (Emojis)
  // ============================================
  static const Map<String, String> categoryIcons = {
    'තොරණ': '🎆',
    'දන්සල': '🍛',
    'ධර්ම දේශනාව': '📿',
    'බැති ගී': '🎶',
    'කලාප': '🎨',
    'කූඩු ප්‍රදර්ශන': '🏮',
    'පෙරහැර': '🐘',
  };

  // ============================================
  // CATEGORY NAMES (English Translations)
  // ============================================
  static const Map<String, String> categoryNames = {
    'තොරණ': 'Thorana (Fireworks)',
    'දන්සල': 'Dansala (Food Stall)',
    'ධර්ම දේශනාව': 'Dhamma Discourse',
    'බැති ගී': 'Bhakthi Gee (Devotional Songs)',
    'කලාප': 'Kalapa (Art Exhibition)',
    'කූඩු ප්‍රදර්ශන': 'Kudu Pradarshana (Lantern Exhibition)',
    'පෙරහැර': 'Perahera (Procession)',
  };

  // ============================================
  // FOOD TYPES FOR DANSALA CATEGORY
  // ============================================
  static const List<Map<String, String>> foodTypes = [
    {'sinhala': 'පාන්', 'emoji': '🍞', 'english': 'Bread'},
    {'sinhala': 'මාලු පාන්', 'emoji': '🥐', 'english': 'Fish Bread'},
    {'sinhala': 'බඩ ඉරිගු', 'emoji': '🌽', 'english': 'Corn'},
    {'sinhala': 'නූඩ්ලස්', 'emoji': '🍝', 'english': 'Noodles'},
    {'sinhala': 'අයිස්ක්‍රීම්', 'emoji': '🍦', 'english': 'Ice Cream'},
    {'sinhala': 'බෙලිමල්', 'emoji': '☕', 'english': 'Plain Tea'},
    {'sinhala': 'කිරිකෝපි', 'emoji': '☕', 'english': 'Milk Coffee'},
    {'sinhala': 'බත්', 'emoji': '🍛', 'english': 'Rice'},
    {'sinhala': 'කොත්තු', 'emoji': '🍛', 'english': 'Kottu'},
    {'sinhala': 'කොස්', 'emoji': '🍛', 'english': 'Jackfruit'},
    {'sinhala': 'සුප්', 'emoji': '🍲', 'english': 'Soup'},
    {'sinhala': 'කැඳ', 'emoji': '🍲', 'english': 'Porridge'},
    {'sinhala': 'කඩල', 'emoji': '🫘', 'english': 'Chickpeas'},
    {'sinhala': 'මුං ඇට', 'emoji': '🫘', 'english': 'Mung Beans'},
    {'sinhala': 'කව්පි', 'emoji': '🫘', 'english': 'Cowpeas'},
    {'sinhala': 'බීම', 'emoji': '🥤', 'english': 'Drinks'},
  ];

  // ============================================
  // LEAGUES & LEVELS
  // ============================================
  static const List<Map<String, dynamic>> leagues = [
    {
      'name': 'Unranked',
      'minLevel': 0,
      'maxLevel': 0,
      'icon': '🌱',
      'xpRequired': 0
    },
    {
      'name': 'Lantern III',
      'minLevel': 1,
      'maxLevel': 1,
      'icon': '🏮',
      'xpRequired': 100
    },
    {
      'name': 'Lantern II',
      'minLevel': 2,
      'maxLevel': 2,
      'icon': '🏮',
      'xpRequired': 250
    },
    {
      'name': 'Lantern I',
      'minLevel': 3,
      'maxLevel': 3,
      'icon': '🏮',
      'xpRequired': 500
    },
    {
      'name': 'Glow III',
      'minLevel': 4,
      'maxLevel': 4,
      'icon': '💡',
      'xpRequired': 1000
    },
    {
      'name': 'Glow II',
      'minLevel': 5,
      'maxLevel': 5,
      'icon': '💡',
      'xpRequired': 1750
    },
    {
      'name': 'Glow I',
      'minLevel': 6,
      'maxLevel': 6,
      'icon': '💡',
      'xpRequired': 2750
    },
    {
      'name': 'Radiance III',
      'minLevel': 7,
      'maxLevel': 7,
      'icon': '✨',
      'xpRequired': 4000
    },
    {
      'name': 'Radiance II',
      'minLevel': 8,
      'maxLevel': 8,
      'icon': '✨',
      'xpRequired': 5500
    },
    {
      'name': 'Radiance I',
      'minLevel': 9,
      'maxLevel': 9,
      'icon': '✨',
      'xpRequired': 7500
    },
    {
      'name': 'Beacon III',
      'minLevel': 10,
      'maxLevel': 10,
      'icon': '🔥',
      'xpRequired': 10000
    },
    {
      'name': 'Beacon II',
      'minLevel': 11,
      'maxLevel': 11,
      'icon': '🔥',
      'xpRequired': 13000
    },
    {
      'name': 'Beacon I',
      'minLevel': 12,
      'maxLevel': 12,
      'icon': '🔥',
      'xpRequired': 17000
    },
    {
      'name': 'Golden Beacon III',
      'minLevel': 13,
      'maxLevel': 13,
      'icon': '🌟',
      'xpRequired': 22000
    },
    {
      'name': 'Golden Beacon II',
      'minLevel': 14,
      'maxLevel': 14,
      'icon': '🌟',
      'xpRequired': 28000
    },
    {
      'name': 'Golden Beacon I',
      'minLevel': 15,
      'maxLevel': 15,
      'icon': '🌟',
      'xpRequired': 35000
    },
    {
      'name': 'Sacred Beacon III',
      'minLevel': 16,
      'maxLevel': 16,
      'icon': '🪷',
      'xpRequired': 45000
    },
    {
      'name': 'Sacred Beacon II',
      'minLevel': 17,
      'maxLevel': 17,
      'icon': '🪷',
      'xpRequired': 57000
    },
    {
      'name': 'Sacred Beacon I',
      'minLevel': 18,
      'maxLevel': 18,
      'icon': '🪷',
      'xpRequired': 72000
    },
    {
      'name': 'Guardian',
      'minLevel': 19,
      'maxLevel': 99,
      'icon': '🛡️',
      'xpRequired': 90000
    },
  ];

  // ============================================
  // MAP CONFIGURATIONS
  // ============================================
  static const double mapInitialZoom = 13.0;
  static const double mapMaxZoom = 18.0;
  static const double mapFocusZoom = 15.0;
  static const double mapMinZoom = 10.0;
  static const double mapZoomStep = 0.5;
  static const String mapTileUrl =
      'https://cartodb-basemaps-a.global.ssl.fastly.net/light_all/{z}/{x}/{y}.png';

  // ============================================
  // LEAGUE HELPER METHODS
  // ============================================
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
    if (level == 1) return 100;
    if (level == 2) return 283;
    if (level == 3) return 520;
    return (100 * pow(level, 1.5)).round();
  }

  static int calculateLevelFromXp(int xp) {
    int level = 0;
    while (xp >= getRequiredXpForLevel(level + 1)) {
      level++;
    }
    return level;
  }

  // ============================================
  // CATEGORY HELPER METHODS
  // ============================================
  static Color getCategoryColor(String category) {
    return categoryColors[category] ?? Colors.grey;
  }

  static String getCategoryIcon(String category) {
    return categoryIcons[category] ?? '📍';
  }

  static String getCategoryName(String category) {
    return categoryNames[category] ?? category;
  }

  static String getFoodTypeEmoji(String foodType) {
    for (var food in foodTypes) {
      if (food['sinhala'] == foodType) {
        return food['emoji']!;
      }
    }
    return '🍛';
  }

  static String getFoodTypeEnglish(String foodType) {
    for (var food in foodTypes) {
      if (food['sinhala'] == foodType) {
        return food['english']!;
      }
    }
    return 'Food Item';
  }

  // ============================================
  // XP & BADGE HELPERS
  // ============================================
  static int getXpForAction(String action) {
    switch (action) {
      case 'register':
        return 50;
      case 'create_event':
        return 50;
      case 'daily_login':
        return 5;
      case 'share_event':
        return 10;
      case 'bookmark_event':
        return 5;
      default:
        return 0;
    }
  }

  static String getBadgeIcon(String badgeName) {
    switch (badgeName) {
      case 'First Event':
        return '🏅';
      case 'Event Creator':
        return '🏆';
      case 'Event Master':
        return '⭐';
      case 'Lantern Lover':
        return '🏮';
      case 'Early Bird':
        return '⏰';
      case 'Foodie':
        return '🍛';
      case 'Social Butterfly':
        return '🦋';
      default:
        return '🎖️';
    }
  }

  // ============================================
  // QUOTES FOR HOME SCREEN
  // ============================================
  static const List<String> buddhistQuotes = [
    '“Happiness never decreases by being shared.” - Buddha',
    '“Peace comes from within. Do not seek it without.” - Buddha',
    '“The mind is everything. What you think you become.” - Buddha',
    '“Thousands of candles can be lit from a single candle.” - Buddha',
    '“Better than a thousand hollow words is one word that brings peace.” - Buddha',
    '“Health is the greatest gift, contentment the greatest wealth.” - Buddha',
    '“You yourself, as much as anybody in the entire universe, deserve your love and affection.” - Buddha',
    '“The only real failure in life is not to be true to the best one knows.” - Buddha',
  ];

  // ============================================
  // APP CONFIGURATIONS
  // ============================================
  static const int maxImageSizeKB = 500;
  static const int maxEventImages = 5;
  static const int maxEventTitleLength = 100;
  static const int maxEventDescriptionLength = 500;
  static const int homeCarouselAutoScrollSeconds = 5;
  static const int leaderboardLimit = 10;
  static const int upcomingEventsLimit = 5;

  // ============================================
  // DATE FORMATS
  // ============================================
  static const String dateFormatDisplay = 'EEEE, MMM d, yyyy';
  static const String dateFormatApi = 'yyyy-MM-dd';
  static const String dateFormatMonth = 'MMMM yyyy';
  static const String dateFormatDayMonth = 'MMM d';
  static const String timeFormatDisplay = 'h:mm a';
  static const String timeFormatApi = 'HH:mm:ss';

  // ============================================
  // SHARE MESSAGES
  // ============================================
  static String getShareMessage(String eventTitle, String eventDate,
      String eventTime, String eventLocation) {
    return '🎉 $eventTitle\n\n'
        '📅 Date: $eventDate\n'
        '⏰ Time: $eventTime\n'
        '📍 Location: $eventLocation\n\n'
        'Check out this event on VesakGO!';
  }

  // ============================================
  // VALIDATION HELPERS
  // ============================================
  static bool isValidEmail(String email) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email);
  }

  static bool isValidPassword(String password) {
    return password.length >= 6;
  }

  static bool isValidPhoneNumber(String phone) {
    final phoneRegex = RegExp(r'^[0-9]{10,12}$');
    return phoneRegex.hasMatch(phone);
  }

  // ============================================
  // UI CONSTANTS
  // ============================================
  static const double cardBorderRadius = 20.0;
  static const double buttonBorderRadius = 16.0;
  static const double inputBorderRadius = 16.0;
  static const double fabSize = 56.0;
  static const double fabMiniSize = 40.0;
  static const double iconSizeSmall = 16.0;
  static const double iconSizeMedium = 20.0;
  static const double iconSizeLarge = 24.0;
  static const double iconSizeExtraLarge = 28.0;

  // ============================================
  // ANIMATION DURATIONS
  // ============================================
  static const Duration animationFast = Duration(milliseconds: 200);
  static const Duration animationMedium = Duration(milliseconds: 400);
  static const Duration animationSlow = Duration(milliseconds: 600);
  static const Duration splashDelay = Duration(seconds: 2);
  static const Duration carouselDelay = Duration(seconds: 5);
  static const Duration snackBarDuration = Duration(seconds: 3);
}
