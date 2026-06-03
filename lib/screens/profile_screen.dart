import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../services/supabase_service.dart';
import '../services/session_service.dart';
import '../constants.dart';
import '../theme/app_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final SessionService _sessionService = SessionService();

  int _userEventsCount = 0;
  int _userTotalXp = 0;
  int _userCurrentLevel = 0;
  bool _isLoading = true;
  List<Map<String, dynamic>> _leaderboard = [];
  File? _avatarImage;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!_sessionService.isLoggedIn) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final userId = _sessionService.currentUser!.id;

    final freshUser = await _supabaseService.getUserById(userId);
    final events = await _supabaseService.getMyEvents(userId);
    final leaderboard = await _supabaseService.getLeaderboard();

    if (freshUser != null) {
      setState(() {
        _userTotalXp = freshUser.totalXp;
        _userCurrentLevel = freshUser.currentLevel;
        _userEventsCount = events.length;
        _leaderboard = leaderboard;
        _isLoading = false;
      });

      await _sessionService.login(freshUser);
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _pickAvatar() async {
    final pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      setState(() {
        _avatarImage = File(pickedFile.path);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avatar updated successfully!')),
      );
    }
  }

  String _getInitials() {
    if (!_sessionService.isLoggedIn) {
      return 'G';
    }
    final user = _sessionService.currentUser!;
    return '${user.firstName[0]}${user.lastName[0]}';
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout', style: TextStyle(color: AppTheme.charcoal)),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.charcoal)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child:
                const Text('Logout', style: TextStyle(color: AppTheme.maroon)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _sessionService.logout();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logged out successfully')),
        );
      }
    }
  }

  Future<void> _editProfile() async {
    final user = _sessionService.currentUser!;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfileScreen(
          firstName: user.firstName,
          lastName: user.lastName,
          email: user.email,
        ),
      ),
    );

    if (result == true) {
      _loadData();
    }
  }

  Future<void> _changePassword() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ChangePasswordScreen(),
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password changed successfully')),
      );
    }
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Settings',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.charcoal,
              ),
            ),
            const Divider(color: AppTheme.sand, height: 24),
            ListTile(
              leading: const Icon(Icons.notifications, color: AppTheme.saffron),
              title: const Text('Notifications'),
              subtitle: const Text('Event reminders and updates'),
              trailing: Switch(
                value: true,
                onChanged: (value) {},
                activeColor: AppTheme.saffron,
              ),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.language, color: AppTheme.saffron),
              title: const Text('Language'),
              subtitle: const Text('සිංහල / English'),
              trailing: const Icon(Icons.arrow_forward_ios,
                  size: 16, color: AppTheme.charcoal),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.privacy_tip, color: AppTheme.saffron),
              title: const Text('Privacy'),
              subtitle: const Text('Manage your data'),
              trailing: const Icon(Icons.arrow_forward_ios,
                  size: 16, color: AppTheme.charcoal),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.help_outline, color: AppTheme.saffron),
              title: const Text('Help & Support'),
              subtitle: const Text('FAQ and contact us'),
              trailing: const Icon(Icons.arrow_forward_ios,
                  size: 16, color: AppTheme.charcoal),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.info, color: AppTheme.saffron),
              title: const Text('About'),
              subtitle: const Text('Version 1.0.0'),
              trailing: const Icon(Icons.arrow_forward_ios,
                  size: 16, color: AppTheme.charcoal),
              onTap: () {},
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.sand,
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.navy,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: AppTheme.white),
            onPressed: _showSettings,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              color: AppTheme.gold,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    const SizedBox(height: 40),
                    _buildAvatar(),
                    const SizedBox(height: 24),
                    _buildUserInfo(),
                    const SizedBox(height: 24),
                    _buildLevelAndXp(),
                    const SizedBox(height: 24),
                    _buildActivityStats(),
                    const SizedBox(height: 24),
                    _buildBadges(),
                    const SizedBox(height: 24),
                    _buildLeaderboard(),
                    const SizedBox(height: 24),
                    _buildActionButtons(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildAvatar() {
    return Center(
      child: GestureDetector(
        onTap: _sessionService.isLoggedIn ? _pickAvatar : null,
        child: Stack(
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.gold, AppTheme.saffron],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppTheme.white,
                    shape: BoxShape.circle,
                  ),
                  child: ClipOval(
                    child: _avatarImage != null
                        ? Image.file(
                            _avatarImage!,
                            width: 94,
                            height: 94,
                            fit: BoxFit.cover,
                          )
                        : Center(
                            child: Text(
                              _getInitials(),
                              style: const TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.charcoal,
                              ),
                            ),
                          ),
                  ),
                ),
              ),
            ),
            if (_sessionService.isLoggedIn)
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: AppTheme.saffron,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    size: 16,
                    color: AppTheme.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserInfo() {
    if (!_sessionService.isLoggedIn) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppTheme.charcoal.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            const Text(
              'Guest User',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.charcoal,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You are browsing as a guest',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.charcoal.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Login / Register'),
            ),
          ],
        ),
      );
    }

    final user = _sessionService.currentUser!;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.charcoal.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person, color: AppTheme.saffron, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Personal Information',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.charcoal,
                ),
              ),
            ],
          ),
          const Divider(color: AppTheme.sand, height: 24),
          _buildInfoRow('Full Name', '${user.firstName} ${user.lastName}'),
          const SizedBox(height: 12),
          _buildInfoRow('Email', user.email),
          const SizedBox(height: 12),
          _buildInfoRow(
            'Member Since',
            DateFormat('dd/MM/yyyy').format(user.createdAt),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.charcoal.withOpacity(0.6),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.charcoal,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLevelAndXp() {
    if (!_sessionService.isLoggedIn) {
      return const SizedBox.shrink();
    }

    final currentLevel = _userCurrentLevel;
    final league = AppConstants.getLeagueByLevel(currentLevel);
    final leagueIcon = AppConstants.getLeagueIcon(currentLevel);
    final currentXp = _userTotalXp;
    final nextLevelXp = AppConstants.getRequiredXpForLevel(currentLevel + 1);
    final currentLevelXp = AppConstants.getRequiredXpForLevel(currentLevel);

    double progress = 0;
    if (nextLevelXp > currentLevelXp) {
      progress = (currentXp - currentLevelXp) / (nextLevelXp - currentLevelXp);
      if (progress < 0) progress = 0;
      if (progress > 1) progress = 1;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.charcoal.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events, color: AppTheme.saffron, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Level & Progress',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.charcoal,
                ),
              ),
            ],
          ),
          const Divider(color: AppTheme.sand, height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    league,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.charcoal,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        leagueIcon,
                        style: const TextStyle(fontSize: 20),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Level $currentLevel',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.charcoal.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$currentXp XP',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.charcoal,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Next: ${nextLevelXp - currentXp} XP',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.charcoal.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppTheme.sand,
              color: AppTheme.gold,
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(progress * 100).toInt()}% to next level',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.charcoal.withOpacity(0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildActivityStats() {
    if (!_sessionService.isLoggedIn) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.charcoal.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart, color: AppTheme.saffron, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Activity Stats',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.charcoal,
                ),
              ),
            ],
          ),
          const Divider(color: AppTheme.sand, height: 24),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Events Created',
                  _userEventsCount.toString(),
                  Icons.event,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Total XP',
                  _userTotalXp.toString(),
                  Icons.stars,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.saffron, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppTheme.charcoal,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.charcoal.withOpacity(0.6),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildBadges() {
    if (!_sessionService.isLoggedIn) {
      return const SizedBox.shrink();
    }

    final userEvents = _userEventsCount;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.charcoal.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events, color: AppTheme.saffron, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Achievements',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.charcoal,
                ),
              ),
            ],
          ),
          const Divider(color: AppTheme.sand, height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildBadgeItem(
                'First Event',
                userEvents >= 1,
                '🏅',
                'Create your first event',
              ),
              _buildBadgeItem(
                'Event Creator',
                userEvents >= 5,
                '🏆',
                'Create 5 events',
              ),
              _buildBadgeItem(
                'Event Master',
                userEvents >= 10,
                '⭐',
                'Create 10 events',
              ),
              _buildBadgeItem(
                'Lantern Lover',
                _userCurrentLevel >= 1,
                '🏮',
                'Reach Lantern level',
              ),
              _buildBadgeItem(
                'Early Bird',
                true,
                '⏰',
                'Joined VesakGO',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeItem(
      String name, bool earned, String icon, String description) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: earned ? AppTheme.gold.withOpacity(0.1) : AppTheme.sand,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: earned ? AppTheme.gold : AppTheme.sand,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: earned
                      ? AppTheme.charcoal
                      : AppTheme.charcoal.withOpacity(0.5),
                ),
              ),
              Text(
                description,
                style: TextStyle(
                  fontSize: 10,
                  color: earned
                      ? AppTheme.charcoal.withOpacity(0.6)
                      : AppTheme.charcoal.withOpacity(0.3),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboard() {
    if (!_sessionService.isLoggedIn) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.charcoal.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.leaderboard, color: AppTheme.saffron, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Leaderboard - Top 10',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.charcoal,
                ),
              ),
            ],
          ),
          const Divider(color: AppTheme.sand, height: 24),
          if (_leaderboard.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('No data available'),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _leaderboard.length,
              separatorBuilder: (context, index) =>
                  const Divider(color: AppTheme.sand),
              itemBuilder: (context, index) {
                final user = _leaderboard[index];
                final rank = index + 1;
                final league =
                    AppConstants.getLeagueByLevel(user['current_level']);
                final leagueIcon =
                    AppConstants.getLeagueIcon(user['current_level']);

                return Row(
                  children: [
                    SizedBox(
                      width: 40,
                      child: Text(
                        '#$rank',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              rank <= 3 ? FontWeight.bold : FontWeight.normal,
                          color: rank == 1
                              ? AppTheme.gold
                              : rank == 2
                                  ? Colors.grey
                                  : rank == 3
                                      ? Colors.brown
                                      : AppTheme.charcoal,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${user['first_name']} ${user['last_name']}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.charcoal,
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                leagueIcon,
                                style: const TextStyle(fontSize: 10),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                league,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppTheme.charcoal.withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${user['total_xp']} XP',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.charcoal,
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    if (!_sessionService.isLoggedIn) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          ElevatedButton(
            onPressed: _editProfile,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
            ),
            child: const Text('Edit Profile', style: TextStyle(fontSize: 16)),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _changePassword,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
            ),
            child:
                const Text('Change Password', style: TextStyle(fontSize: 16)),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _logout,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.maroon,
              side: const BorderSide(color: AppTheme.maroon),
              minimumSize: const Size(double.infinity, 50),
            ),
            child: const Text('Log Out',
                style: TextStyle(fontSize: 16, color: AppTheme.maroon)),
          ),
        ],
      ),
    );
  }
}

// EditProfileScreen
class EditProfileScreen extends StatefulWidget {
  final String firstName;
  final String lastName;
  final String email;

  const EditProfileScreen({
    super.key,
    required this.firstName,
    required this.lastName,
    required this.email,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _emailController;
  final SupabaseService _supabaseService = SupabaseService();
  final SessionService _sessionService = SessionService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(text: widget.firstName);
    _lastNameController = TextEditingController(text: widget.lastName);
    _emailController = TextEditingController(text: widget.email);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (_firstNameController.text.isEmpty ||
        _lastNameController.text.isEmpty ||
        _emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final success = await _supabaseService.updateUserProfile(
      userId: _sessionService.currentUser!.id,
      firstName: _firstNameController.text,
      lastName: _lastNameController.text,
      email: _emailController.text,
    );

    setState(() {
      _isLoading = false;
    });

    if (success) {
      final updatedUser =
          await _supabaseService.getUserById(_sessionService.currentUser!.id);
      if (updatedUser != null) {
        await _sessionService.login(updatedUser);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email already exists or update failed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.sand,
      appBar: AppBar(
        title:
            const Text('Edit Profile', style: TextStyle(color: AppTheme.white)),
        backgroundColor: AppTheme.navy,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.gold.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_outline,
                size: 60,
                color: AppTheme.gold,
              ),
            ),
            const SizedBox(height: 40),
            TextField(
              controller: _firstNameController,
              decoration: InputDecoration(
                labelText: 'First Name',
                labelStyle: const TextStyle(color: AppTheme.charcoal),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppTheme.saffron, width: 2),
                ),
              ),
              style: const TextStyle(color: AppTheme.charcoal),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _lastNameController,
              decoration: InputDecoration(
                labelText: 'Last Name',
                labelStyle: const TextStyle(color: AppTheme.charcoal),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppTheme.saffron, width: 2),
                ),
              ),
              style: const TextStyle(color: AppTheme.charcoal),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Email',
                labelStyle: const TextStyle(color: AppTheme.charcoal),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppTheme.saffron, width: 2),
                ),
              ),
              style: const TextStyle(color: AppTheme.charcoal),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 30),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveChanges,
                    child: _isLoading
                        ? const CircularProgressIndicator(color: AppTheme.white)
                        : const Text('Save'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ChangePasswordScreen
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final SupabaseService _supabaseService = SupabaseService();
  final SessionService _sessionService = SessionService();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  Future<void> _changePassword() async {
    if (_currentPasswordController.text.isEmpty ||
        _newPasswordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    if (_newPasswordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 6 characters')),
      );
      return;
    }

    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New passwords do not match')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final success = await _supabaseService.changePassword(
      userId: _sessionService.currentUser!.id,
      currentPassword: _currentPasswordController.text,
      newPassword: _newPasswordController.text,
    );

    setState(() {
      _isLoading = false;
    });

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password changed successfully')),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Current password is incorrect')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.sand,
      appBar: AppBar(
        title: const Text('Change Password',
            style: TextStyle(color: AppTheme.white)),
        backgroundColor: AppTheme.navy,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.gold.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_outline,
                size: 60,
                color: AppTheme.gold,
              ),
            ),
            const SizedBox(height: 40),
            TextField(
              controller: _currentPasswordController,
              obscureText: _obscureCurrent,
              decoration: InputDecoration(
                labelText: 'Current Password',
                labelStyle: const TextStyle(color: AppTheme.charcoal),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppTheme.saffron, width: 2),
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureCurrent ? Icons.visibility_off : Icons.visibility,
                    color: AppTheme.charcoal,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureCurrent = !_obscureCurrent;
                    });
                  },
                ),
              ),
              style: const TextStyle(color: AppTheme.charcoal),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _newPasswordController,
              obscureText: _obscureNew,
              decoration: InputDecoration(
                labelText: 'New Password',
                labelStyle: const TextStyle(color: AppTheme.charcoal),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppTheme.saffron, width: 2),
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureNew ? Icons.visibility_off : Icons.visibility,
                    color: AppTheme.charcoal,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureNew = !_obscureNew;
                    });
                  },
                ),
              ),
              style: const TextStyle(color: AppTheme.charcoal),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirm,
              decoration: InputDecoration(
                labelText: 'Confirm New Password',
                labelStyle: const TextStyle(color: AppTheme.charcoal),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppTheme.saffron, width: 2),
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                    color: AppTheme.charcoal,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureConfirm = !_obscureConfirm;
                    });
                  },
                ),
              ),
              style: const TextStyle(color: AppTheme.charcoal),
            ),
            const SizedBox(height: 30),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _changePassword,
                    child: _isLoading
                        ? const CircularProgressIndicator(color: AppTheme.white)
                        : const Text('Update'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
