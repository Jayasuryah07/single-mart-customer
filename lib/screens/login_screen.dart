import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../theme.dart';
import 'user_register_screen.dart';
import 'otp_screen.dart';

// --- Main Login Screen ---
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _phoneController = TextEditingController();
  bool _isLoading = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // --- Lifecycle ---
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _sendOTP() async {
    final phone = _phoneController.text.trim();
    if (phone.length != 10) {
      _showSnackBar(
        'Please enter a valid 10-digit phone number',
        AppColors.error,
        Icons.warning_rounded,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await ApiService.checkMobile(phone);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final resData = json.decode(response.body);
        final int code = resData['code'] is int 
            ? resData['code'] 
            : int.tryParse(resData['code']?.toString() ?? '200') ?? 200;

        if (code == 200) {
          final otpCode = resData['data']?.toString() ?? '';

          _showSnackBar(
            'OTP sent! (For Demo: $otpCode)',
            AppColors.secondary,
            Icons.check_circle_rounded,
          );

          // Firebase OTP verification trigger
          try {
            await FirebaseAuth.instance.verifyPhoneNumber(
              phoneNumber: '+91$phone',
              verificationCompleted: (PhoneAuthCredential credential) async {
                // Auto-retrieval completed, login will happen inside OTPScreen
              },
              verificationFailed: (FirebaseAuthException e) {
                debugPrint('Firebase phone verification failed: ${e.message}');
                _showSnackBar('Firebase Auth: ${e.message}', AppColors.error, Icons.error_outline_rounded);
                // Navigate to OTPScreen anyway so fallback API OTP can be verified
                if (mounted) {
                  setState(() => _isLoading = false);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => OTPScreen(
                        phoneNumber: phone,
                        verificationId: '',
                        apiOtp: otpCode,
                      ),
                    ),
                  );
                }
              },
              codeSent: (String verificationId, int? resendToken) {
                if (mounted) {
                  setState(() => _isLoading = false);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => OTPScreen(
                        phoneNumber: phone,
                        verificationId: verificationId,
                        apiOtp: otpCode,
                      ),
                    ),
                  );
                }
              },
              codeAutoRetrievalTimeout: (String verificationId) {},
            );
          } catch (firebaseErr) {
            debugPrint('Firebase Phone Auth setup error: $firebaseErr');
            if (mounted) {
              setState(() => _isLoading = false);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => OTPScreen(
                    phoneNumber: phone,
                    verificationId: '',
                    apiOtp: otpCode,
                  ),
                ),
              );
            }
          }

        } else {
          setState(() => _isLoading = false);
          _showSnackBar(
            resData['message'] ?? 'Mobile verification failed.',
            AppColors.error,
            Icons.warning_rounded,
          );
        }
      } else {
        final resData = json.decode(response.body);
        setState(() => _isLoading = false);
        _showSnackBar(
          resData['message'] ?? 'Connection error. Status code: ${response.statusCode}',
          AppColors.error,
          Icons.warning_rounded,
        );
      }
    } catch (e) {
      debugPrint('Error sending mobile check: $e');
      setState(() => _isLoading = false);
      _showSnackBar(
        'Server unreachable. Please check your connection.',
        AppColors.error,
        Icons.warning_rounded,
      );
    }
  }

  // --- UI Helpers ---
  void _showSnackBar(String message, Color color, IconData icon) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: const TextStyle(fontSize: 14))),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _navigateToRegister() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const UserRegisterScreen()),
    );
  }

  // --- Build ---
  @override
  Widget build(BuildContext context) {
    const Color primaryColor = AppColors.primary;
    const Color secondaryColor = AppColors.secondary;
    const LinearGradient gradient = LinearGradient(
      colors: [primaryColor, secondaryColor],
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.3),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: TextButton(
              onPressed: _navigateToRegister,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Register',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  // Header
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          primaryColor.withOpacity(0.1),
                          secondaryColor.withOpacity(0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Welcome Back!',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Sign in to discover amazing local deals',
                          style: TextStyle(
                            fontSize: 15,
                            color: AppColors.textLight,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Form Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.border, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Phone
                        const Text(
                          'PHONE NUMBER',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              height: 56,
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Center(
                                  child: Text(
                                    '+91',
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                style: const TextStyle(
                                    color: AppColors.textPrimary, fontSize: 15),
                                decoration: InputDecoration(
                                  hintText: 'Enter phone number',
                                  hintStyle: const TextStyle(
                                      color: AppColors.textMuted, fontSize: 14),
                                  prefixIcon: Icon(
                                    Icons.phone_rounded,
                                    color: primaryColor.withOpacity(0.7),
                                    size: 20,
                                  ),
                                  filled: true,
                                  fillColor: AppColors.surface,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 16),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide:
                                        const BorderSide(color: AppColors.border),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide:
                                        const BorderSide(color: AppColors.border),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide:
                                        const BorderSide(color: primaryColor, width: 1.5),
                                  ),
                                  errorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(
                                        color: AppColors.error, width: 1),
                                  ),
                                ),
                                inputFormatters: [
                                  LengthLimitingTextInputFormatter(10),
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (_phoneController.text.isNotEmpty &&
                            _phoneController.text.length < 10)
                          Padding(
                            padding: const EdgeInsets.only(top: 8, left: 4),
                            child: Text(
                              'Please enter a valid 10-digit number',
                              style: TextStyle(
                                color: AppColors.error,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        const SizedBox(height: 32),
                        // Login Button
                        Container(
                          width: double.infinity,
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: gradient,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: primaryColor.withOpacity(0.3),
                                blurRadius: 20,
                                spreadRadius: 5,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _sendOTP,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      valueColor:
                                          AlwaysStoppedAnimation<Color>(
                                              Colors.white),
                                    ),
                                  )
                                : const Text(
                                    'Send OTP',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Footer
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "New to SingleMart? ",
                        style: TextStyle(color: AppColors.textLight, fontSize: 14),
                      ),
                      GestureDetector(
                        onTap: _navigateToRegister,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: gradient,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Create Account',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}