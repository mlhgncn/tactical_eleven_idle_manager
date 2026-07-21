import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/profile.dart';
import '../models/referral_info.dart';
import '../providers/game_provider.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/level_frame.dart';
import 'leaderboard_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _usernameController = TextEditingController();
  bool _isUpdatingEmail = false;
  bool _isUpdatingPassword = false;
  bool _isUpdatingUsername = false;
  bool _usernamePrefilled = false;
  bool _isUploadingAvatar = false;
  bool _isClaimingDaily = false;
  String? _claimingAchievement;
  String? _claimingSocial;

  @override
  void initState() {
    super.initState();
    _emailController.text = _authService.currentUserEmail ?? '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<GameProvider>().refreshGameState();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _updateUsername() async {
    final newUsername = _usernameController.text.trim();
    if (newUsername.length < 3) {
      AppSnackBar.show(context, 'auth.username_short'.tr());
      return;
    }

    setState(() => _isUpdatingUsername = true);
    try {
      await context.read<GameProvider>().updateUsername(newUsername);
      if (!mounted) return;
      AppSnackBar.showSuccess(context, 'profile.usernameUpdated'.tr());
    } catch (error) {
      if (!mounted) return;
      AppSnackBar.showErrorFromException(context, error);
    } finally {
      if (mounted) setState(() => _isUpdatingUsername = false);
    }
  }

  Future<void> _updateEmail() async {
    final newEmail = _emailController.text.trim();
    if (newEmail.isEmpty || !newEmail.contains('@')) {
      AppSnackBar.show(context, 'profile.invalidEmail'.tr());
      return;
    }

    setState(() => _isUpdatingEmail = true);
    try {
      await _authService.updateEmail(newEmail);
      if (!mounted) return;
      AppSnackBar.showSuccess(context, 'profile.emailUpdateSent'.tr());
    } catch (error) {
      if (!mounted) return;
      AppSnackBar.showErrorFromException(context, error);
    } finally {
      if (mounted) setState(() => _isUpdatingEmail = false);
    }
  }

  Future<void> _updatePassword() async {
    final newPassword = _passwordController.text;
    if (newPassword.length < 6) {
      AppSnackBar.show(context, 'profile.passwordTooShort'.tr());
      return;
    }
    if (newPassword != _confirmPasswordController.text) {
      AppSnackBar.show(context, 'profile.passwordsMismatch'.tr());
      return;
    }

    setState(() => _isUpdatingPassword = true);
    try {
      await _authService.updatePassword(newPassword);
      if (!mounted) return;
      _passwordController.clear();
      _confirmPasswordController.clear();
      AppSnackBar.showSuccess(context, 'profile.passwordUpdated'.tr());
    } catch (error) {
      if (!mounted) return;
      AppSnackBar.showErrorFromException(context, error);
    } finally {
      if (mounted) setState(() => _isUpdatingPassword = false);
    }
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 800, maxHeight: 800, imageQuality: 85);
    if (picked == null) return;

    setState(() => _isUploadingAvatar = true);
    try {
      final bytes = await File(picked.path).readAsBytes();
      final extension = picked.path.split('.').last.toLowerCase();
      await context.read<GameProvider>().uploadAndSetAvatar(bytes, extension);
      if (!mounted) return;
      AppSnackBar.showSuccess(context, 'profile.avatarUpdated'.tr());
    } catch (error) {
      if (!mounted) return;
      AppSnackBar.showErrorFromException(context, error);
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  Future<void> _claimAchievement(String achievement) async {
    setState(() => _claimingAchievement = achievement);
    try {
      await context.read<GameProvider>().claimAchievementReward(achievement);
      if (!mounted) return;
      AppSnackBar.showSuccess(context, 'profile.achievementClaimed'.tr());
    } catch (error) {
      if (!mounted) return;
      AppSnackBar.showErrorFromException(context, error);
    } finally {
      if (mounted) setState(() => _claimingAchievement = null);
    }
  }

  Future<void> _claimDaily() async {
    setState(() => _isClaimingDaily = true);
    try {
      final result = await context.read<GameProvider>().claimDailyLoginReward();
      if (!mounted) return;
      final diamonds = (result['diamonds_awarded'] as num?)?.toInt() ?? 0;
      final gp = (result['gp_awarded'] as num?)?.toInt() ?? 0;
      final message = diamonds > 0
          ? 'profile.dailyClaimedDiamonds'.tr(namedArgs: {'count': diamonds.toString()})
          : 'profile.dailyClaimedGp'.tr(namedArgs: {'count': gp.toString()});
      AppSnackBar.showSuccess(context, message);
    } catch (error) {
      if (!mounted) return;
      AppSnackBar.showErrorFromException(context, error);
    } finally {
      if (mounted) setState(() => _isClaimingDaily = false);
    }
  }

  Future<void> _openSocialAndClaim(String platform, String url) async {
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}

    setState(() => _claimingSocial = platform);
    try {
      await context.read<GameProvider>().claimSocialReward(platform);
      if (!mounted) return;
      AppSnackBar.showSuccess(context, 'profile.socialRewardClaimed'.tr());
    } catch (error) {
      if (!mounted) return;
      AppSnackBar.showErrorFromException(context, error);
    } finally {
      if (mounted) setState(() => _claimingSocial = null);
    }
  }

  bool _isTodayClaimed(Profile profile) {
    final last = profile.lastDailyClaimDate;
    if (last == null) return false;
    final now = DateTime.now();
    return last.year == now.year && last.month == now.month && last.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    final gameProvider = context.watch<GameProvider>();
    final profile = gameProvider.profile;
    final leagueTitles = profile?.leagueTitles ?? 0;
    final level = profile?.level ?? ProfileLevel.none;
    final activeClub = gameProvider.activeClub;
    final hasMaxFacility = activeClub != null &&
        (activeClub.stadiumCapacity >= 100000 || activeClub.trainingFacilityLevel >= 10);

    if (!_usernamePrefilled && profile?.username != null) {
      _usernameController.text = profile!.username!;
      _usernamePrefilled = true;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('profile.title'.tr()),
        actions: [
          IconButton(
            icon: const Icon(Icons.leaderboard_outlined),
            tooltip: 'leaderboard.title'.tr(),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LeaderboardScreen())),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Column(
              children: [
                LevelFrame(
                  level: level,
                  padding: 4,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 44,
                        backgroundColor: AppColors.cardBottom,
                        backgroundImage: profile?.avatarUrl != null ? NetworkImage(profile!.avatarUrl!) : null,
                        child: profile?.avatarUrl == null
                            ? const Icon(Icons.person, size: 44, color: AppColors.textMuted)
                            : null,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: InkWell(
                          onTap: _isUploadingAvatar ? null : _pickAvatar,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(color: AppColors.gold, shape: BoxShape.circle),
                            child: _isUploadingAvatar
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.camera_alt, size: 14, color: AppColors.goldOnGoldText),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  LevelFrame.labelKey(level).tr(),
                  style: TextStyle(color: LevelFrame.solidColor(level), fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.emoji_events, color: Colors.amber, size: 32),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$leagueTitles', style: Theme.of(context).textTheme.headlineMedium),
                          Text('profile.leagueTitlesLabel'.tr(), style: const TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (profile != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('profile.dailyStreakTitle'.tr(), style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(7, (index) {
                        final day = index + 1;
                        final isDone = day <= profile.dailyStreakDay && _isTodayClaimed(profile);
                        final isNext = !_isTodayClaimed(profile) &&
                            day == (profile.dailyStreakDay >= 7 ? 1 : profile.dailyStreakDay + 1);
                        return Column(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isDone
                                    ? AppColors.green.withValues(alpha: 0.2)
                                    : isNext
                                        ? AppColors.gold.withValues(alpha: 0.2)
                                        : AppColors.cardBottom,
                                border: Border.all(
                                  color: isDone ? AppColors.green : (isNext ? AppColors.gold : AppColors.cardBorder),
                                ),
                              ),
                              child: day == 7
                                  ? const Icon(Icons.diamond, size: 14, color: AppColors.blue)
                                  : Text('$day', style: const TextStyle(fontSize: 12)),
                            ),
                          ],
                        );
                      }),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: (_isClaimingDaily || _isTodayClaimed(profile)) ? null : _claimDaily,
                        child: _isClaimingDaily
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : Text(_isTodayClaimed(profile) ? 'profile.dailyAlreadyClaimed'.tr() : 'profile.dailyClaimButton'.tr()),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('profile.achievementsTitle'.tr(), style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    _AchievementRow(
                      icon: Icons.military_tech,
                      title: 'profile.achievement100WinsTitle'.tr(),
                      progress: '${profile.totalWins}/100',
                      reward: 100,
                      isComplete: profile.totalWins >= 100,
                      isClaimed: profile.achievement100WinsClaimed,
                      isLoading: _claimingAchievement == '100_wins',
                      onClaim: () => _claimAchievement('100_wins'),
                    ),
                    const SizedBox(height: 10),
                    _AchievementRow(
                      icon: Icons.local_fire_department,
                      title: 'profile.achievementWinStreak10Title'.tr(),
                      progress: '${profile.bestWinStreak}/10',
                      reward: 50,
                      isComplete: profile.bestWinStreak >= 10,
                      isClaimed: profile.achievementWinStreak10Claimed,
                      isLoading: _claimingAchievement == 'win_streak_10',
                      onClaim: () => _claimAchievement('win_streak_10'),
                    ),
                    const SizedBox(height: 10),
                    _AchievementRow(
                      icon: Icons.emoji_events,
                      title: 'profile.achievementUnbeatenChampionTitle'.tr(),
                      progress: profile.hasUnbeatenTitle
                          ? 'profile.achievementConditionMet'.tr()
                          : 'profile.achievementConditionNotMet'.tr(),
                      reward: 200,
                      isComplete: profile.hasUnbeatenTitle,
                      isClaimed: profile.achievementUnbeatenChampionClaimed,
                      isLoading: _claimingAchievement == 'unbeaten_champion',
                      onClaim: () => _claimAchievement('unbeaten_champion'),
                    ),
                    const SizedBox(height: 10),
                    _AchievementRow(
                      icon: Icons.factory,
                      title: 'profile.achievementMaxFacilityTitle'.tr(),
                      progress: hasMaxFacility
                          ? 'profile.achievementConditionMet'.tr()
                          : 'profile.achievementConditionNotMet'.tr(),
                      reward: 80,
                      isComplete: hasMaxFacility,
                      isClaimed: profile.achievementMaxFacilityClaimed,
                      isLoading: _claimingAchievement == 'max_facility',
                      onClaim: () => _claimAchievement('max_facility'),
                    ),
                    const SizedBox(height: 10),
                    _AchievementRow(
                      icon: Icons.emoji_people,
                      title: 'profile.achievement45DayStreakTitle'.tr(),
                      progress: '${profile.longestLoginStreak}/45',
                      reward: 150,
                      isComplete: profile.longestLoginStreak >= 45,
                      isClaimed: profile.achievement45DayStreakClaimed,
                      isLoading: _claimingAchievement == '45_day_streak',
                      onClaim: () => _claimAchievement('45_day_streak'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('profile.socialTitle'.tr(), style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    _SocialRow(
                      icon: Icons.camera_alt,
                      label: 'Instagram',
                      isFollowed: profile.socialInstagramFollowed,
                      isLoading: _claimingSocial == 'instagram',
                      onTap: () => _openSocialAndClaim('instagram', 'https://instagram.com'),
                    ),
                    const SizedBox(height: 8),
                    _SocialRow(
                      icon: Icons.alternate_email,
                      label: 'X (Twitter)',
                      isFollowed: profile.socialXFollowed,
                      isLoading: _claimingSocial == 'x',
                      onTap: () => _openSocialAndClaim('x', 'https://x.com'),
                    ),
                    const SizedBox(height: 8),
                    _SocialRow(
                      icon: Icons.music_note,
                      label: 'TikTok',
                      isFollowed: profile.socialTiktokFollowed,
                      isLoading: _claimingSocial == 'tiktok',
                      onTap: () => _openSocialAndClaim('tiktok', 'https://tiktok.com'),
                    ),
                    if (!profile.socialEngagementClaimed) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _claimingSocial == 'engagement' ? null : () => _openSocialAndClaim('engagement', 'https://instagram.com'),
                          child: _claimingSocial == 'engagement'
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : Text('profile.socialEngagementButton'.tr()),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          const _ReferralCard(),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('profile.usernameTitle'.tr(), style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _usernameController,
                    autocorrect: false,
                    decoration: InputDecoration(labelText: 'auth.username'.tr()),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isUpdatingUsername ? null : _updateUsername,
                      child: _isUpdatingUsername
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text('profile.updateUsernameButton'.tr()),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('profile.emailAddressTitle'.tr(), style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(labelText: 'auth.email'.tr()),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isUpdatingEmail ? null : _updateEmail,
                      child: _isUpdatingEmail
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text('profile.updateEmailButton'.tr()),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('profile.changePasswordTitle'.tr(), style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(labelText: 'profile.newPasswordLabel'.tr()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _confirmPasswordController,
                    obscureText: true,
                    decoration: InputDecoration(labelText: 'profile.confirmNewPasswordLabel'.tr()),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isUpdatingPassword ? null : _updatePassword,
                      child: _isUpdatingPassword
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text('profile.updatePasswordButton'.tr()),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AchievementRow extends StatelessWidget {
  const _AchievementRow({
    required this.icon,
    required this.title,
    required this.progress,
    required this.reward,
    required this.isComplete,
    required this.isClaimed,
    required this.isLoading,
    required this.onClaim,
  });

  final IconData icon;
  final String title;
  final String progress;
  final int reward;
  final bool isComplete;
  final bool isClaimed;
  final bool isLoading;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: isClaimed ? AppColors.green : AppColors.gold, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(progress, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
              Row(
                children: [
                  const Icon(Icons.diamond, color: AppColors.blue, size: 12),
                  const SizedBox(width: 3),
                  Text(
                    'profile.achievementReward'.tr(namedArgs: {'count': reward.toString()}),
                    style: const TextStyle(color: AppColors.blue, fontSize: 11.5, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (isClaimed)
          const Icon(Icons.check_circle, color: AppColors.green, size: 20)
        else
          SizedBox(
            height: 32,
            child: ElevatedButton(
              onPressed: (isComplete && !isLoading) ? onClaim : null,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12)),
              child: isLoading
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text('profile.claimButton'.tr(), style: const TextStyle(fontSize: 12)),
            ),
          ),
      ],
    );
  }
}

class _SocialRow extends StatelessWidget {
  const _SocialRow({
    required this.icon,
    required this.label,
    required this.isFollowed,
    required this.isLoading,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isFollowed;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.textMuted),
        const SizedBox(width: 10),
        Expanded(child: Text(label)),
        if (isFollowed)
          const Icon(Icons.check_circle, color: AppColors.green, size: 20)
        else
          SizedBox(
            height: 32,
            child: OutlinedButton(
              onPressed: isLoading ? null : onTap,
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12)),
              child: isLoading
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text('profile.followButton'.tr(), style: const TextStyle(fontSize: 12)),
            ),
          ),
      ],
    );
  }
}

class _ReferralCard extends StatefulWidget {
  const _ReferralCard();

  @override
  State<_ReferralCard> createState() => _ReferralCardState();
}

class _ReferralCardState extends State<_ReferralCard> {
  bool _loading = true;
  ReferralInfo? _info;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _info = await context.read<GameProvider>().loadMyReferralInfo();
    } catch (_) {
      _info = null;
    }
    if (mounted) setState(() => _loading = false);
  }

  void _share(String code) {
    Share.share('auth.referralShareMessage'.tr(namedArgs: {'code': code}));
  }

  @override
  Widget build(BuildContext context) {
    final code = _info?.referralCode;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.card_giftcard, color: AppColors.gold, size: 20),
                const SizedBox(width: 8),
                Text('profile.referralTitle'.tr(), style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'profile.referralDescription'.tr(),
              style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted, height: 1.4),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (code == null)
              Text('profile.referralUnavailable'.tr(), style: const TextStyle(color: AppColors.textMuted))
            else ...[
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.cardTop,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Text(code, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 2)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: () => _share(code),
                    icon: const Icon(Icons.share, size: 16),
                    label: Text('profile.referralShareButton'.tr()),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'profile.referralCount'.tr(namedArgs: {'count': (_info?.successfulReferrals ?? 0).toString()}),
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
