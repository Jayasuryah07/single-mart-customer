import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';
import 'update_profile_screen.dart';
import 'manage_address_screen.dart';
import 'order_history_screen.dart';
import 'login_screen.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class ProfileScreen extends StatefulWidget {
  final bool isLoggedIn;
  final Map<String, dynamic>? userData;
  final String? token;
  final VoidCallback onLogout;
  final VoidCallback onLoginSuccess;
  final Future<void> Function() onRefreshProfile;

  const ProfileScreen({
    super.key,
    required this.isLoggedIn,
    required this.userData,
    required this.token,
    required this.onLogout,
    required this.onLoginSuccess,
    required this.onRefreshProfile,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isSyncing = false;

  Future<void> _triggerLocalNotification() async {
    final theme = Theme.of(context);
    try {
      final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings initializationSettingsDarwin =
          DarwinInitializationSettings();

      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsDarwin,
      );

      await flutterLocalNotificationsPlugin.initialize(settings: initializationSettings);

      const AndroidNotificationDetails androidNotificationDetails =
          AndroidNotificationDetails(
        'test_channel',
        'Test Channel',
        channelDescription: 'Used for local test notifications',
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'ticker',
      );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidNotificationDetails,
        iOS: DarwinNotificationDetails(presentSound: true, presentAlert: true, presentBadge: true),
      );

      await flutterLocalNotificationsPlugin.show(
        id: 999,
        title: 'SingleMart Local Test',
        body: 'This is a local test notification. App notifications are working!',
        notificationDetails: notificationDetails,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Local test notification triggered successfully!"),
          backgroundColor: theme.colorScheme.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      debugPrint("Error showing local notification: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e"),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _handleRefresh() async {
    setState(() => _isSyncing = true);
    try {
      await widget.onRefreshProfile();
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  int _getSavedAddressCount() {
    if (widget.userData == null) return 0;
    final addresses = widget.userData!['addresses'] ?? widget.userData!['address'];
    if (addresses is List) {
      return addresses.length;
    }
    return 0;
  }

  String _getProfileCompletion() {
    if (widget.userData == null) return "0%";
    int score = 0;
    int total = 4;
    
    if (widget.userData!['name'] != null && widget.userData!['name'].toString().isNotEmpty) score++;
    if (widget.userData!['email'] != null && widget.userData!['email'].toString().isNotEmpty) score++;
    if (widget.userData!['mobile'] != null && widget.userData!['mobile'].toString().isNotEmpty) score++;
    if (widget.userData!['user_image'] != null && widget.userData!['user_image'].toString().isNotEmpty) score++;

    return "${((score / total) * 100).round()}%";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 1. Fallback UI if not logged in
    if (!widget.isLoggedIn) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.account_circle_outlined,
                  size: 90,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Welcome to SingleMart',
                style: TextStyle(
                  fontSize: 24, 
                  fontWeight: FontWeight.w900, 
                  color: AppColors.textPrimary,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Join us to track orders, manage your profile, and save delivery addresses.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textLight, fontSize: 14.5, height: 1.45),
              ),
              const SizedBox(height: 36),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                    ).then((_) {
                      widget.onLoginSuccess();
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 1.5,
                  ),
                  child: const Text(
                    'Sign In / Register',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // SizedBox(
              //   width: double.infinity,
              //   height: 52,
              //   child: OutlinedButton.icon(
              //     onPressed: _triggerLocalNotification,
              //     style: OutlinedButton.styleFrom(
              //       foregroundColor: theme.colorScheme.primary,
              //       side: BorderSide(color: theme.colorScheme.primary, width: 1.5),
              //       shape: RoundedRectangleBorder(
              //         borderRadius: BorderRadius.circular(16),
              //       ),
              //     ),
              //     icon: const Icon(Icons.notifications_active_rounded, size: 20),
              //     label: const Text(
              //       'Trigger Test Notification',
              //       style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              //     ),
              //   ),
              // ),
            ],
          ),
        ),
      );
    }

    // 2. Active User Profile details
    final String name = widget.userData?['name'] ?? 'Shopper Member';
    final String email = widget.userData?['email'] ?? 'shopper@singlemart.com';
    final String mobile = widget.userData?['mobile'] ?? '';
    final String? userImage = widget.userData?['user_image']?.toString();
    final String imageUrl = (userImage != null && userImage.isNotEmpty)
        ? "https://agsdemo.in/singlemartapi/public/assets/images/user_images/$userImage"
        : "";

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'My Profile',
          style: TextStyle(
            color: AppColors.textPrimary, 
            fontWeight: FontWeight.w900,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: _isSyncing 
                ? const SizedBox(
                    width: 20, 
                    height: 20, 
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                  )
                : const Icon(Icons.sync_rounded, color: AppColors.textSecondary),
            tooltip: 'Sync Profile details',
            onPressed: _handleRefresh,
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            // Unique Premium Gradient Profile Header Block
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)], // Premium Royal Blue Mesh
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1E3A8A).withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withOpacity(0.9), width: 3.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 38,
                          backgroundColor: Colors.white,
                          backgroundImage: imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
                          child: imageUrl.isEmpty
                              ? const Icon(Icons.person, size: 40, color: Color(0xFF1E3A8A))
                              : null,
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 19.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              email,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 13.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (mobile.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                mobile,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Container(
                    height: 1,
                    color: Colors.white.withOpacity(0.15),
                  ),
                  const SizedBox(height: 20),
                  // Dashboard quick stat metrics
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildQuickStatItem(
                        icon: Icons.location_on_rounded,
                        value: _getSavedAddressCount().toString(),
                        label: 'Saved Places',
                      ),
                      Container(
                        height: 35,
                        width: 1.5,
                        color: Colors.white.withOpacity(0.15),
                      ),
                      _buildQuickStatItem(
                        icon: Icons.verified_user_rounded,
                        value: _getProfileCompletion(),
                        label: 'Setup Completed',
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Profile Configuration Options List Menu
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFF1F5F9)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.015),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildProfileOption(
                    context: context,
                    icon: Icons.manage_accounts_outlined,
                    iconBgColor: const Color(0xFFEEF2FF),
                    iconColor: const Color(0xFF4F46E5),
                    title: 'Update Profile',
                    subtitle: 'Edit contact info, name, and profile photo',
                    onTap: () async {
                      final prefs = await SharedPreferences.getInstance();
                      final String? token = prefs.getString('auth_token');
                      final String? userDataStr = prefs.getString('user_data');
                      if (token != null && userDataStr != null) {
                        final Map<String, dynamic> parsedUserData = json.decode(userDataStr);
                        if (context.mounted) {
                          final updated = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => UpdateProfileScreen(
                                userData: parsedUserData,
                                token: token,
                              ),
                            ),
                          );
                          if (updated == true) {
                            widget.onLoginSuccess();
                          }
                        }
                      }
                    },
                  ),
                  const Divider(height: 1, indent: 56, endIndent: 16, color: Color(0xFFF1F5F9)),
                  _buildProfileOption(
                    context: context,
                    icon: Icons.location_on_outlined,
                    iconBgColor: const Color(0xFFF0FDF4),
                    iconColor: const Color(0xFF16A34A),
                    title: 'Manage Addresses',
                    subtitle: 'Add, edit, or delete delivery addresses',
                    onTap: () async {
                      final prefs = await SharedPreferences.getInstance();
                      final String? token = prefs.getString('auth_token');
                      final String? userDataStr = prefs.getString('user_data');
                      if (token != null && userDataStr != null) {
                        final Map<String, dynamic> parsedUserData = json.decode(userDataStr);
                        if (context.mounted) {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ManageAddressScreen(
                                userData: parsedUserData,
                                token: token,
                              ),
                            ),
                          );
                          widget.onLoginSuccess();
                        }
                      }
                    },
                  ),
                  const Divider(height: 1, indent: 56, endIndent: 16, color: Color(0xFFF1F5F9)),
                  _buildProfileOption(
                    context: context,
                    icon: Icons.receipt_long_outlined,
                    iconBgColor: const Color(0xFFFAF5FF),
                    iconColor: const Color(0xFF9333EA),
                    title: 'Order History',
                    subtitle: 'Track status and download PDF invoices',
                    onTap: () async {
                      final prefs = await SharedPreferences.getInstance();
                      final String? token = prefs.getString('auth_token');
                      if (token != null) {
                        if (context.mounted) {
                          await Navigator.pushNamed(context, '/orders', arguments: token);
                        }
                      }
                    },
                  ),
                ],
              ),
            ),

            // Padding(
            //   padding: const EdgeInsets.symmetric(horizontal: 16),
            //   child: SizedBox(
            //     width: double.infinity,
            //     height: 52,
            //     child: ElevatedButton.icon(
            //       onPressed: _triggerLocalNotification,
            //       style: ElevatedButton.styleFrom(
            //         backgroundColor: theme.colorScheme.primary,
            //         foregroundColor: Colors.white,
            //         shape: RoundedRectangleBorder(
            //           borderRadius: BorderRadius.circular(16),
            //         ),
            //         elevation: 1.0,
            //       ),
            //       icon: const Icon(Icons.notifications_active_rounded, size: 20),
            //       label: const Text(
            //         'Trigger Test Notification',
            //         style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5),
            //       ),
            //     ),
            //   ),
            // ),
            const SizedBox(height: 12),
            // Logout row button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: TextButton.icon(
                  onPressed: () => _showLogoutConfirmDialog(context),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.error,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: Color(0xFFFEE2E2), width: 1.5),
                    ),
                    backgroundColor: const Color(0xFFFEF2F2),
                  ),
                  icon: const Icon(Icons.logout_rounded, size: 20),
                  label: const Text(
                    'Log Out Account',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15.5),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStatItem({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white70, size: 16),
            const SizedBox(width: 6),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildProfileOption({
    required BuildContext context,
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: iconBgColor,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 14.5,
          fontWeight: FontWeight.w900,
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          subtitle,
          style: const TextStyle(
            fontSize: 11.5,
            color: AppColors.textLight,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: Color(0xFF94A3B8),
        size: 20,
      ),
    );
  }

  void _showLogoutConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to log out from SingleMart?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.onLogout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Log Out', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
