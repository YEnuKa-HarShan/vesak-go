import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';
import '../constants.dart';
import '../theme/app_theme.dart';

// Glass helper
class _Glass extends StatelessWidget {
  final Widget child;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final Color tint;
  final double blur;
  final double opacity;
  final Border? border;

  const _Glass({
    required this.child,
    this.borderRadius,
    this.padding,
    this.tint = Colors.white,
    this.blur = 18,
    this.opacity = 0.10,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final br = borderRadius ?? BorderRadius.circular(20);
    return ClipRRect(
      borderRadius: br,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: tint.withOpacity(opacity),
            borderRadius: br,
            border: border ??
                Border.all(color: Colors.white.withOpacity(0.18), width: 1),
          ),
          child: child,
        ),
      ),
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final SessionService _sessionService = SessionService();

  int _userEventsCount = 0;
  int _userTotalXp = 0;
  int _userCurrentLevel = 0;
  bool _isLoading = true;
  List<Map<String, dynamic>> _leaderboard = [];
  File? _avatarImage;
  final ImagePicker _picker = ImagePicker();

  late AnimationController _fadeCtrl;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadData();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!_sessionService.isLoggedIn) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() => _isLoading = true);

    final userId = _sessionService.currentUser!.id;
    final freshUser = await ApiService.getUserById(userId);
    final events = await ApiService.getMyEvents(userId);
    // Leaderboard will be implemented when backend adds this endpoint

    if (freshUser != null) {
      setState(() {
        _userTotalXp = freshUser.totalXp;
        _userCurrentLevel = freshUser.currentLevel;
        _userEventsCount = events.length;
        _leaderboard = [];
        _isLoading = false;
      });
      await _sessionService.login(freshUser);
    } else {
      setState(() => _isLoading = false);
    }

    _fadeCtrl.forward(from: 0);
  }

  Future<void> _pickAvatar() async {
    final pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (pickedFile != null) {
      setState(() => _avatarImage = File(pickedFile.path));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avatar updated successfully!')),
      );
    }
  }

  String _getInitials() {
    if (!_sessionService.isLoggedIn) return 'G';
    final user = _sessionService.currentUser!;
    return '${user.firstName[0]}${user.lastName[0]}';
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Logout',
            style: TextStyle(
                color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
        content: Text('Are you sure you want to logout?',
            style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Logout'),
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
        builder: (_) => EditProfileScreen(
          firstName: user.firstName,
          lastName: user.lastName,
          email: user.email,
        ),
      ),
    );
    if (result == true) _loadData();
  }

  Future<void> _changePassword() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
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
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.80),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border(
                top: BorderSide(color: Colors.white.withOpacity(0.50)),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.timelineInactive,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                Divider(
                    color: Colors.grey.withOpacity(0.18),
                    height: 28,
                    thickness: 1),
                _buildSettingsTile(
                  icon: Icons.notifications_rounded,
                  label: 'Notifications',
                  subtitle: 'Event reminders and updates',
                  trailing: Switch(
                    value: true,
                    onChanged: (_) {},
                    activeColor: AppTheme.primary,
                  ),
                ),
                _buildSettingsTile(
                  icon: Icons.language_rounded,
                  label: 'Language',
                  subtitle: 'සිංහල / English',
                  trailing: const Icon(Icons.chevron_right_rounded,
                      size: 20, color: AppTheme.textSecondary),
                ),
                _buildSettingsTile(
                  icon: Icons.privacy_tip_rounded,
                  label: 'Privacy',
                  subtitle: 'Manage your data',
                  trailing: const Icon(Icons.chevron_right_rounded,
                      size: 20, color: AppTheme.textSecondary),
                ),
                _buildSettingsTile(
                  icon: Icons.help_outline_rounded,
                  label: 'Help & Support',
                  subtitle: 'FAQ and contact us',
                  trailing: const Icon(Icons.chevron_right_rounded,
                      size: 20, color: AppTheme.textSecondary),
                ),
                _buildSettingsTile(
                  icon: Icons.info_outline_rounded,
                  label: 'About',
                  subtitle: 'Version 1.0.0',
                  trailing: const Icon(Icons.chevron_right_rounded,
                      size: 20, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String label,
    required String subtitle,
    required Widget trailing,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
      leading: _Glass(
        borderRadius: BorderRadius.circular(12),
        opacity: 0.55,
        tint: Colors.white,
        padding: const EdgeInsets.all(8),
        child: Icon(icon, size: 20, color: AppTheme.primary),
      ),
      title: Text(label,
          style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary)),
      subtitle: Text(subtitle,
          style: TextStyle(
              fontSize: 12, color: AppTheme.textSecondary.withOpacity(0.8))),
      trailing: trailing,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          _buildAmbientBlobs(),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: _isLoading
                      ? Center(
                          child: _Glass(
                            borderRadius: BorderRadius.circular(20),
                            opacity: 0.55,
                            tint: Colors.white,
                            padding: const EdgeInsets.all(20),
                            child: const CircularProgressIndicator(
                              color: AppTheme.primary,
                              strokeWidth: 2.5,
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadData,
                          color: AppTheme.accent,
                          child: FadeTransition(
                            opacity: _fadeCtrl,
                            child: SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(
                                parent: BouncingScrollPhysics(),
                              ),
                              padding: const EdgeInsets.only(bottom: 40),
                              child: Column(
                                children: [
                                  const SizedBox(height: 24),
                                  _buildAvatarHero(),
                                  const SizedBox(height: 20),
                                  _buildUserInfoCard(),
                                  if (_sessionService.isLoggedIn) ...[
                                    const SizedBox(height: 16),
                                    _buildLevelXpCard(),
                                    const SizedBox(height: 16),
                                    _buildActivityStatsRow(),
                                    const SizedBox(height: 16),
                                    _buildAchievementsCard(),
                                    const SizedBox(height: 16),
                                    _buildLeaderboardCard(),
                                    const SizedBox(height: 16),
                                    _buildActionButtons(),
                                  ],
                                  const SizedBox(height: 8),
                                ],
                              ),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmbientBlobs() {
    return Stack(
      children: [
        Positioned(
          top: -60,
          left: -60,
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primary.withOpacity(0.12),
            ),
          ),
        ),
        Positioned(
          top: 100,
          right: -80,
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.accent.withOpacity(0.10),
            ),
          ),
        ),
        Positioned(
          bottom: -80,
          left: 60,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.blobEmerald.withOpacity(0.08),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.55),
            border: Border(
              bottom:
                  BorderSide(color: Colors.white.withOpacity(0.35), width: 1),
            ),
          ),
          child: Row(
            children: [
              _buildGlassIconButton(
                icon: Icons.arrow_back_rounded,
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  'My Profile',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              _buildGlassIconButton(
                icon: Icons.settings_rounded,
                onPressed: _showSettings,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlassIconButton(
      {required IconData icon, required VoidCallback onPressed}) {
    return _Glass(
      borderRadius: BorderRadius.circular(14),
      opacity: 0.55,
      tint: Colors.white,
      padding: EdgeInsets.zero,
      child: SizedBox(
        width: 44,
        height: 44,
        child: IconButton(
          icon: Icon(icon, size: 20),
          color: AppTheme.primary,
          onPressed: onPressed,
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }

  Widget _buildAvatarHero() {
    return GestureDetector(
      onTap: _sessionService.isLoggedIn ? _pickAvatar : null,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 116,
            height: 116,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  AppTheme.accent.withOpacity(0.60),
                  AppTheme.primary.withOpacity(0.60),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(55),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                width: 108,
                height: 108,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.70),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.80), width: 2),
                ),
                child: ClipOval(
                  child: _avatarImage != null
                      ? Image.file(_avatarImage!,
                          width: 108, height: 108, fit: BoxFit.cover)
                      : Center(
                          child: Text(
                            _getInitials(),
                            style: const TextStyle(
                              fontSize: 38,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primary,
                            ),
                          ),
                        ),
                ),
              ),
            ),
          ),
          if (_sessionService.isLoggedIn)
            Positioned(
              bottom: 2,
              right: 2,
              child: _Glass(
                borderRadius: BorderRadius.circular(12),
                opacity: 0.85,
                tint: AppTheme.primary,
                blur: 10,
                border:
                    Border.all(color: Colors.white.withOpacity(0.60), width: 1),
                padding: const EdgeInsets.all(6),
                child: const Icon(Icons.camera_alt_rounded,
                    size: 14, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUserInfoCard() {
    if (!_sessionService.isLoggedIn) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: _buildGlassCard(
          child: Column(
            children: [
              const Text(
                'Guest User',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You are browsing as a guest',
                style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary.withOpacity(0.8)),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Login / Register',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      );
    }

    final user = _sessionService.currentUser!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: _buildGlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCardSectionHeader(
                Icons.person_rounded, 'Personal Information',
                color: AppTheme.primary),
            Divider(
                color: Colors.grey.withOpacity(0.18), height: 24, thickness: 1),
            _buildInfoRow('Name', '${user.firstName} ${user.lastName}'),
            const SizedBox(height: 10),
            _buildInfoRow('Email', user.email),
            const SizedBox(height: 10),
            _buildInfoRow(
                'Member Since', DateFormat('MMMM yyyy').format(user.createdAt)),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(label,
              style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary.withOpacity(0.85))),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildLevelXpCard() {
    final currentLevel = _userCurrentLevel;
    final league = AppConstants.getLeagueByLevel(currentLevel);
    final leagueIcon = AppConstants.getLeagueIcon(currentLevel);
    final currentXp = _userTotalXp;
    final nextLevelXp = AppConstants.getRequiredXpForLevel(currentLevel + 1);
    final currentLevelXp = AppConstants.getRequiredXpForLevel(currentLevel);

    double progress = 0;
    if (nextLevelXp > currentLevelXp) {
      progress = (currentXp - currentLevelXp) / (nextLevelXp - currentLevelXp);
      progress = progress.clamp(0.0, 1.0);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.62),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                  color: AppTheme.accent.withOpacity(0.30), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accent.withOpacity(0.10),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.emoji_events_rounded,
                          color: AppTheme.accent, size: 18),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Level & Progress',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary),
                    ),
                    const Spacer(),
                    _Glass(
                      borderRadius: BorderRadius.circular(20),
                      opacity: 0.55,
                      tint: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      child: Text(
                        '$currentXp / $nextLevelXp XP',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary.withOpacity(0.8),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(leagueIcon, style: const TextStyle(fontSize: 28)),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(league,
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textPrimary,
                                letterSpacing: -0.3)),
                        Text('Level $currentLevel',
                            style: TextStyle(
                                fontSize: 12,
                                color:
                                    AppTheme.textSecondary.withOpacity(0.8))),
                      ],
                    ),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${nextLevelXp - currentXp} XP',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primary),
                        ),
                        Text(
                          'to next level',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary.withOpacity(0.7)),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: AppTheme.timelineInactive,
                    color: AppTheme.accent,
                    minHeight: 7,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      '${(progress * 100).toInt()}% to Level ${currentLevel + 1}',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary.withOpacity(0.7)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActivityStatsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              icon: Icons.event_rounded,
              iconColor: AppTheme.primary,
              count: _userEventsCount.toString(),
              label: 'Events Created',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              icon: Icons.stars_rounded,
              iconColor: AppTheme.accent,
              count: _userTotalXp.toString(),
              label: 'Total XP',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String count,
    required String label,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.62),
            borderRadius: BorderRadius.circular(20),
            border:
                Border.all(color: Colors.white.withOpacity(0.70), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: iconColor.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(count,
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary)),
                    Text(label,
                        style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary.withOpacity(0.8))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAchievementsCard() {
    final userEvents = _userEventsCount;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: _buildGlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCardSectionHeader(Icons.emoji_events_rounded, 'Achievements',
                color: AppTheme.accent),
            Divider(
                color: Colors.grey.withOpacity(0.18), height: 24, thickness: 1),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildBadgeChip('First Event', userEvents >= 1, '🏅',
                    'Create your first event'),
                _buildBadgeChip(
                    'Event Creator', userEvents >= 5, '🏆', 'Create 5 events'),
                _buildBadgeChip(
                    'Event Master', userEvents >= 10, '⭐', 'Create 10 events'),
                _buildBadgeChip('Lantern Lover', _userCurrentLevel >= 1, '🏮',
                    'Reach Lantern level'),
                _buildBadgeChip('Early Bird', true, '⏰', 'Joined VesakGO'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgeChip(
      String name, bool earned, String icon, String description) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: earned
                ? AppTheme.accent.withOpacity(0.12)
                : Colors.white.withOpacity(0.50),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: earned
                  ? AppTheme.accent.withOpacity(0.40)
                  : AppTheme.timelineInactive.withOpacity(0.50),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(icon,
                  style: TextStyle(
                      fontSize: 18,
                      color: earned ? null : const Color(0x88000000))),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: earned
                              ? AppTheme.textPrimary
                              : AppTheme.textSecondary)),
                  Text(description,
                      style: TextStyle(
                          fontSize: 10,
                          color: earned
                              ? AppTheme.textSecondary.withOpacity(0.8)
                              : AppTheme.textSecondary.withOpacity(0.45))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeaderboardCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: _buildGlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCardSectionHeader(
                Icons.leaderboard_rounded, 'Leaderboard — Coming Soon',
                color: AppTheme.primary),
            Divider(
                color: Colors.grey.withOpacity(0.18), height: 24, thickness: 1),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.leaderboard_rounded,
                        size: 48, color: AppTheme.primary.withOpacity(0.3)),
                    const SizedBox(height: 12),
                    Text(
                      'Leaderboard feature coming soon!',
                      style: TextStyle(
                        color: AppTheme.textSecondary.withOpacity(0.7),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          ElevatedButton(
            onPressed: _editProfile,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 52),
              elevation: 0,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('Edit Profile',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: OutlinedButton(
                onPressed: _changePassword,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                  side: BorderSide(
                      color: AppTheme.primary.withOpacity(0.60), width: 1.2),
                  minimumSize: const Size(double.infinity, 52),
                  backgroundColor: Colors.white.withOpacity(0.40),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Change Password',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: OutlinedButton(
                onPressed: _logout,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.error,
                  side: BorderSide(
                      color: AppTheme.error.withOpacity(0.60), width: 1.2),
                  minimumSize: const Size(double.infinity, 52),
                  backgroundColor: AppTheme.error.withOpacity(0.05),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Log Out',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.62),
            borderRadius: BorderRadius.circular(22),
            border:
                Border.all(color: Colors.white.withOpacity(0.70), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withOpacity(0.06),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildCardSectionHeader(IconData icon, String title,
      {required Color color}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary),
        ),
      ],
    );
  }
}

// EditProfileScreen (same as before, using ApiService)
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

    setState(() => _isLoading = true);

    // Update profile will be implemented when backend adds this endpoint
    await Future.delayed(const Duration(seconds: 1));

    setState(() => _isLoading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile updated successfully')),
    );
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          Positioned(
            top: -60,
            left: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primary.withOpacity(0.10),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            right: -40,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.accent.withOpacity(0.09),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.55),
                        border: Border(
                          bottom:
                              BorderSide(color: Colors.white.withOpacity(0.35)),
                        ),
                      ),
                      child: Row(
                        children: [
                          _Glass(
                            borderRadius: BorderRadius.circular(14),
                            opacity: 0.55,
                            tint: Colors.white,
                            padding: EdgeInsets.zero,
                            child: SizedBox(
                              width: 44,
                              height: 44,
                              child: IconButton(
                                icon: const Icon(Icons.arrow_back_rounded,
                                    size: 20),
                                color: AppTheme.primary,
                                onPressed: () => Navigator.pop(context),
                                padding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Text(
                            'Edit Profile',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        const SizedBox(height: 24),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(40),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                            child: Container(
                              padding: const EdgeInsets.all(22),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.62),
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.70),
                                    width: 1.2),
                              ),
                              child: const Icon(
                                Icons.person_outline_rounded,
                                size: 52,
                                color: AppTheme.primary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.62),
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.70),
                                    width: 1.2),
                              ),
                              child: Column(
                                children: [
                                  _buildGlassInput(
                                    controller: _firstNameController,
                                    label: 'First Name',
                                    hint: 'Enter your first name',
                                    icon: Icons.person_outline_rounded,
                                  ),
                                  const SizedBox(height: 14),
                                  _buildGlassInput(
                                    controller: _lastNameController,
                                    label: 'Last Name',
                                    hint: 'Enter your last name',
                                    icon: Icons.person_outline_rounded,
                                  ),
                                  const SizedBox(height: 14),
                                  _buildGlassInput(
                                    controller: _emailController,
                                    label: 'Email',
                                    hint: 'Enter your email address',
                                    icon: Icons.email_outlined,
                                    keyboardType: TextInputType.emailAddress,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: BackdropFilter(
                                  filter:
                                      ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                  child: OutlinedButton(
                                    onPressed: _isLoading
                                        ? null
                                        : () => Navigator.pop(context),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppTheme.textSecondary,
                                      side: BorderSide(
                                          color: AppTheme.timelineInactive
                                              .withOpacity(0.6)),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14),
                                      backgroundColor:
                                          Colors.white.withOpacity(0.40),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(16)),
                                    ),
                                    child: const Text('Cancel'),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _saveChanges,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primary,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16)),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2))
                                    : const Text('Save Changes',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w600)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassInput({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.70),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.60), width: 1),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
            decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              labelStyle:
                  TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              hintStyle: TextStyle(
                  color: AppTheme.textSecondary.withOpacity(0.6), fontSize: 13),
              prefixIcon: Icon(icon, size: 20, color: AppTheme.textSecondary),
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide:
                    const BorderSide(color: AppTheme.primary, width: 1.5),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
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

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

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

    setState(() => _isLoading = true);

    // Change password will be implemented when backend adds this endpoint
    await Future.delayed(const Duration(seconds: 1));

    setState(() => _isLoading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Password changed successfully')),
    );
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          Positioned(
            top: -60,
            left: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primary.withOpacity(0.10),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            right: -40,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.accent.withOpacity(0.09),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.55),
                        border: Border(
                          bottom:
                              BorderSide(color: Colors.white.withOpacity(0.35)),
                        ),
                      ),
                      child: Row(
                        children: [
                          _Glass(
                            borderRadius: BorderRadius.circular(14),
                            opacity: 0.55,
                            tint: Colors.white,
                            padding: EdgeInsets.zero,
                            child: SizedBox(
                              width: 44,
                              height: 44,
                              child: IconButton(
                                icon: const Icon(Icons.arrow_back_rounded,
                                    size: 20),
                                color: AppTheme.primary,
                                onPressed: () => Navigator.pop(context),
                                padding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Text(
                            'Change Password',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        const SizedBox(height: 24),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(40),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                            child: Container(
                              padding: const EdgeInsets.all(22),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.62),
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.70),
                                    width: 1.2),
                              ),
                              child: const Icon(
                                Icons.lock_outline_rounded,
                                size: 52,
                                color: AppTheme.primary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.62),
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.70),
                                    width: 1.2),
                              ),
                              child: Column(
                                children: [
                                  _buildPasswordField(
                                    controller: _currentPasswordController,
                                    label: 'Current Password',
                                    hint: 'Enter your current password',
                                    obscure: _obscureCurrent,
                                    onToggle: () => setState(() =>
                                        _obscureCurrent = !_obscureCurrent),
                                  ),
                                  const SizedBox(height: 14),
                                  _buildPasswordField(
                                    controller: _newPasswordController,
                                    label: 'New Password',
                                    hint: 'Min 6 characters',
                                    obscure: _obscureNew,
                                    onToggle: () => setState(
                                        () => _obscureNew = !_obscureNew),
                                  ),
                                  const SizedBox(height: 14),
                                  _buildPasswordField(
                                    controller: _confirmPasswordController,
                                    label: 'Confirm New Password',
                                    hint: 'Confirm your new password',
                                    obscure: _obscureConfirm,
                                    onToggle: () => setState(() =>
                                        _obscureConfirm = !_obscureConfirm),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: BackdropFilter(
                                  filter:
                                      ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                  child: OutlinedButton(
                                    onPressed: _isLoading
                                        ? null
                                        : () => Navigator.pop(context),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppTheme.textSecondary,
                                      side: BorderSide(
                                          color: AppTheme.timelineInactive
                                              .withOpacity(0.6)),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14),
                                      backgroundColor:
                                          Colors.white.withOpacity(0.40),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(16)),
                                    ),
                                    child: const Text('Cancel'),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _changePassword,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primary,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16)),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2))
                                    : const Text('Update',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w600)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.70),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.60), width: 1),
          ),
          child: TextField(
            controller: controller,
            obscureText: obscure,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
            decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              labelStyle:
                  TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              hintStyle: TextStyle(
                  color: AppTheme.textSecondary.withOpacity(0.6), fontSize: 13),
              prefixIcon: Icon(Icons.lock_outline_rounded,
                  size: 20, color: AppTheme.textSecondary),
              suffixIcon: IconButton(
                icon: Icon(
                  obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                  color: AppTheme.textSecondary,
                ),
                onPressed: onToggle,
              ),
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide:
                    const BorderSide(color: AppTheme.primary, width: 1.5),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
      ),
    );
  }
}
