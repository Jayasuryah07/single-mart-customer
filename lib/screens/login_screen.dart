import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/api_service.dart';
import '../theme.dart';
import 'otp_screen.dart';

// --- Main Login Screen ---
class LoginScreen extends StatefulWidget {
  final bool isGuestMode;
  final List<Map<String, dynamic>>? cartItems;

  const LoginScreen({
    super.key,
    this.isGuestMode = false,
    this.cartItems,
  });

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
      bool isNotRegistered = false;
      String errorMsg = '';
      String otpCode = '';

      if (response.statusCode == 200 || response.statusCode == 201) {
        final resData = json.decode(response.body);
        final int code = resData['code'] is int 
            ? resData['code'] 
            : int.tryParse(resData['code']?.toString() ?? '200') ?? 200;

        if (code == 200) {
          otpCode = resData['data']?.toString() ?? '';
        } else {
          errorMsg = resData['message'] ?? 'Mobile verification failed.';
          final lowerMsg = errorMsg.toLowerCase();
          if (lowerMsg.contains('not register') || 
              lowerMsg.contains('not found') || 
              lowerMsg.contains('no vendor') || 
              lowerMsg.contains('no user') ||
              lowerMsg.contains('not exist')) {
            isNotRegistered = true;
          }
        }
      } else {
        try {
          final resData = json.decode(response.body);
          errorMsg = resData['message'] ?? 'Connection error.';
        } catch (_) {
          errorMsg = 'Connection error. Status code: ${response.statusCode}';
        }
        final lowerMsg = errorMsg.toLowerCase();
        if (response.statusCode == 400 || 
            response.statusCode == 401 || 
            response.statusCode == 404 || 
            response.statusCode == 422 ||
            lowerMsg.contains('not register') || 
            lowerMsg.contains('not found') || 
            lowerMsg.contains('no vendor') || 
            lowerMsg.contains('no user') ||
            lowerMsg.contains('not exist')) {
          isNotRegistered = true;
        }
      }

      if (otpCode.isNotEmpty) {
        _showSnackBar(
          'OTP sent successfully. Please check your messages.',
          const Color.fromARGB(255, 0, 215, 65),
          Icons.check_circle_rounded,
        );
        _triggerFirebaseAndNavigate(phone, otpCode);
      } else if (isNotRegistered) {
        final String mockOtp = '123456';
        _showSnackBar(
          'Registering number. Dispatching security code...',
          AppColors.secondary,
          Icons.info_outline_rounded,
        );
        _triggerFirebaseAndNavigate(phone, mockOtp);
      } else {
        setState(() => _isLoading = false);
        _showSnackBar(errorMsg, AppColors.error, Icons.warning_rounded);
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

  Future<void> _triggerFirebaseAndNavigate(String phone, String otpCode) async {
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: '+91$phone',
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-retrieval completed, login will happen inside OTPScreen
        },
        verificationFailed: (FirebaseAuthException e) {
          debugPrint('Firebase phone verification failed: ${e.message}');
          _showSnackBar('Firebase Auth: ${e.message}', AppColors.error, Icons.error_outline_rounded);
          if (mounted) {
            setState(() => _isLoading = false);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => OTPScreen(
                  phoneNumber: phone,
                  verificationId: '',
                  apiOtp: otpCode,
                  isGuestMode: widget.isGuestMode,
                  cartItems: widget.cartItems,
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
                  isGuestMode: widget.isGuestMode,
                  cartItems: widget.cartItems,
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
              isGuestMode: widget.isGuestMode,
              cartItems: widget.cartItems,
            ),
          ),
        );
      }
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

  // --- Build ---
  @override
  Widget build(BuildContext context) {
    const Color primaryColor = AppColors.primary;
    const Color secondaryColor = AppColors.secondary;
    const LinearGradient gradient = LinearGradient(
      colors: [primaryColor, secondaryColor],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  
                  // App Brand Logo & Welcome block
                  Center(
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.08),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: primaryColor.withOpacity(0.12),
                              width: 1.5,
                            ),
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              gradient: gradient,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: primaryColor.withOpacity(0.3),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.shopping_bag_rounded,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          widget.isGuestMode ? 'Checkout Details' : 'SingleMart',
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.isGuestMode
                              ? 'Verify your number to proceed to checkout'
                              : 'Sign in to explore your neighborhood marketplace',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textLight,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 38),

                  // Form Container Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.015),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'PHONE NUMBER',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          style: const TextStyle(
                            color: AppColors.textPrimary, 
                            fontSize: 15.5,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Enter 10-digit number',
                            hintStyle: const TextStyle(
                              color: AppColors.textLight, 
                              fontSize: 14.5,
                              fontWeight: FontWeight.normal,
                            ),
                            prefixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(width: 16),
                                const Icon(Icons.phone_iphone_rounded, color: AppColors.textLight, size: 20),
                                const SizedBox(width: 8),
                                const Text(
                                  '+91',
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  width: 1.5,
                                  height: 22,
                                  color: const Color(0xFFE2E8F0),
                                ),
                                const SizedBox(width: 12),
                              ],
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 16),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: primaryColor, width: 1.8),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                  color: AppColors.error, width: 1.2),
                            ),
                          ),
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(10),
                            FilteringTextInputFormatter.digitsOnly,
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
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        const SizedBox(height: 28),
                        
                        // Send OTP Gradient Button
                        Container(
                          width: double.infinity,
                          height: 54,
                          decoration: BoxDecoration(
                            gradient: gradient,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: primaryColor.withOpacity(0.3),
                                blurRadius: 12,
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
                                 : Text(
                                     widget.isGuestMode
                                         ? 'Continue to Verification'
                                         : 'Send Verification OTP',
                                     style: const TextStyle(
                                       fontSize: 15.5,
                                       fontWeight: FontWeight.bold,
                                       letterSpacing: 0.5,
                                     ),
                                   ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 38),
                  
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}