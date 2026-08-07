import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'ecommerce_home_screen.dart';
import 'maintenance_screen.dart';
import 'update_screen.dart';
import 'package:singlemart/router.dart';
import 'package:firebase_core/firebase_core.dart';
import '../main.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<Offset> _slideAnimation;

  bool _hasError = false;
  String _errorMessage = '';
  String _installedVersion = '1.0.0';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    // Scale animation with elastic effect
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );

    // Opacity animation
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    // Slide animation for subtitle
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 0.7, curve: Curves.easeOut),
      ),
    );

    _controller.forward();

    _initializeAppAndCheckStatus();
  }

  Future<void> _initializeAppAndCheckStatus() async {
    final startTime = DateTime.now();

    try {
      if (mounted) {
        setState(() {
          _hasError = false;
          _errorMessage = '';
        });
      }

      // 1. Get package info
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      
      if (mounted) {
        setState(() {
          _installedVersion = currentVersion;
        });
      }

      // 2. Fetch app status from API
      final response = await ApiService.checkStatus();

      // 3. Await background Firebase initialization
      await firebaseInitialization;

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        final String success = data['success']?.toString() ?? 'false';

        // Wait to complete at least 2.5 seconds of splash screen animations
        final elapsed = DateTime.now().difference(startTime);
        final remainingTime = const Duration(milliseconds: 2500) - elapsed;
        if (remainingTime > Duration.zero) {
          await Future.delayed(remainingTime);
        }

        if (!mounted) return;

        // Check for Maintenance
        if (success != 'true') {
          // Extract company logo URL
          String? logoUrl;
          final companyDetails = data['company_detils'];
          final imageUrlList = data['image_url'] as List?;
          if (companyDetails != null && imageUrlList != null) {
            final logoName = companyDetails['company_logo'];
            final companyImgObj = imageUrlList.firstWhere(
              (img) => img['image_for'] == 'Company',
              orElse: () => null,
            );
            if (companyImgObj != null && logoName != null) {
              logoUrl = '${companyImgObj['image_url']}$logoName';
            }
          }

          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => MaintenanceScreen(
                companyDetails: companyDetails,
                logoUrl: logoUrl,
              ),
            ),
          );
          return;
        }

        // Check for Version Update
        final versionObj = data['version'];
        final String panelVersion = versionObj?['version_panel']?.toString() ?? '1.0.0';

        if (currentVersion != panelVersion) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => UpdateScreen(
                installedVersion: currentVersion,
                latestVersion: panelVersion,
              ),
            ),
          );
          return;
        }

        // Version matches and app is not in maintenance, proceed to next screen (auto-login check)
        _navigateToNextScreen();
      } else {
        throw Exception('Server returned status code ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error checking app status: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Unable to connect. Please check your internet connection.';
        });
      }
    }
  }

  Future<void> _navigateToNextScreen() async {
    if (!mounted) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('auth_token');
      final String? userDataStr = prefs.getString('user_data');

      if (token != null && token.isNotEmpty && userDataStr != null && userDataStr.isNotEmpty) {
        final Map<String, dynamic> userData = json.decode(userDataStr);
        final int userType = userData['user_type'] is int
            ? userData['user_type']
            : int.tryParse(userData['user_type']?.toString() ?? '1') ?? 1;

        if (userType != 1) {
          // Discard session if not a user (e.g. is Vendor or Admin)
          await prefs.remove('auth_token');
          await prefs.remove('user_data');
        } else {
          _performRouting();
          return;
        }
      }
    } catch (e) {
      debugPrint('Error loading auto-login session: $e');
    }

    _performRouting();
  }

  void _performRouting() {
    if (!mounted) return;
    AppRouter.isInitialized = true;
    
    final currentRouteName = ModalRoute.of(context)?.settings.name ?? '/';
    final String target = currentRouteName == '/' ? '/home' : currentRouteName;
    
    Navigator.of(context).pushReplacementNamed(target);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFFFFF), // Pure white
              Color(0xFFF8FAFC), // Off-white
              Color(0xFFF1F5F9), // Light gray
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Decorative background circles
              ..._buildBackgroundDecorations(),
              
              // Main content
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Animated Logo
                    AnimatedBuilder(
                      animation: _controller,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _scaleAnimation.value,
                          child: Opacity(
                            opacity: _opacityAnimation.value,
                            child: child,
                          ),
                        );
                      },
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF6C63FF),
                              Color(0xFF8B83FF),
                              Color(0xFFA59FFF),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6C63FF).withOpacity(0.2),
                              blurRadius: 40,
                              spreadRadius: 10,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.shopping_bag_outlined,
                            color: Colors.white,
                            size: 70,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    
                    // App Name with shimmer effect
                    AnimatedBuilder(
                      animation: _controller,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _opacityAnimation.value,
                          child: ShaderMask(
                            shaderCallback: (Rect bounds) {
                              return const LinearGradient(
                                colors: [
                                  Color(0xFF1E1B4B),
                                  Color(0xFF4F46E5),
                                  Color(0xFF1E1B4B),
                                ],
                                stops: [0.0, 0.5, 1.0],
                              ).createShader(bounds);
                            },
                            child: const Text(
                              'SingleMart',
                              style: TextStyle(
                                fontSize: 44,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 2.0,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    
                    // Subtitle with slide animation
                    AnimatedBuilder(
                      animation: _controller,
                      builder: (context, child) {
                        return SlideTransition(
                          position: _slideAnimation,
                          child: Opacity(
                            opacity: _opacityAnimation.value,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6C63FF).withOpacity(0.08),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'Your Unified Local Marketplace',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Color(0xFF64748B),
                                  letterSpacing: 1.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 60),
                    
                    // Loading indicator with dots or Error state
                    AnimatedBuilder(
                      animation: _controller,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _opacityAnimation.value,
                          child: _hasError
                              ? Column(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 40.0),
                                      child: Text(
                                        _errorMessage,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Colors.redAccent,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    ElevatedButton.icon(
                                      onPressed: _initializeAppAndCheckStatus,
                                      icon: const Icon(Icons.refresh_rounded, size: 18),
                                      label: const Text('Retry'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF6C63FF),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                      ),
                                    ),
                                  ],
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _buildDot(0, Colors.deepPurple),
                                    const SizedBox(width: 10),
                                    _buildDot(1, Colors.deepPurple.shade300),
                                    const SizedBox(width: 10),
                                    _buildDot(2, Colors.deepPurple.shade100),
                                  ],
                                ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              
              // Version text at bottom
              Positioned(
                bottom: 30,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    'Version $_installedVersion',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF94A3B8),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildBackgroundDecorations() {
    return [
      // Top right circle
      Positioned(
        top: -80,
        right: -80,
        child: Container(
          width: 250,
          height: 250,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                const Color(0xFF6C63FF).withOpacity(0.05),
                const Color(0xFF6C63FF).withOpacity(0.02),
                Colors.transparent,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        ),
      ),
      
      // Bottom left circle
      Positioned(
        bottom: -100,
        left: -100,
        child: Container(
          width: 300,
          height: 300,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                const Color(0xFF8B83FF).withOpacity(0.05),
                const Color(0xFF8B83FF).withOpacity(0.02),
                Colors.transparent,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        ),
      ),
      
      // Center-left small circle
      Positioned(
        left: -50,
        top: MediaQuery.of(context).size.height * 0.4,
        child: Container(
          width: 150,
          height: 150,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                const Color(0xFFA59FFF).withOpacity(0.04),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
      
      // Bottom-right small circle
      Positioned(
        right: -30,
        bottom: MediaQuery.of(context).size.height * 0.3,
        child: Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                const Color(0xFF4F46E5).withOpacity(0.04),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
    ];
  }

  Widget _buildDot(int index, Color color) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        double value = _controller.value * 3 - index.toDouble();
        double scale = (value.clamp(0.0, 1.0) * 0.5 + 0.5);
        
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}