import 'package:singlemart/router.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../theme.dart';
import 'ecommerce_home_screen.dart';
import 'user_register_screen.dart';
import 'guest_register_screen.dart';
import 'checkout_screen.dart';
import '../widgets/cart_button.dart';

import 'package:flutter/foundation.dart' show kIsWeb;

class OTPScreen extends StatefulWidget {
  final String phoneNumber;
  final String verificationId;
  final ConfirmationResult? confirmationResult;
  final bool isNotRegistered;
  final String apiPassword;
  final bool isGuestMode;
  final List<Map<String, dynamic>>? cartItems;

  const OTPScreen({
    super.key,
    required this.phoneNumber,
    required this.verificationId,
    this.confirmationResult,
    this.isNotRegistered = false,
    required this.apiPassword,
    this.isGuestMode = false,
    this.cartItems,
  });

  @override
  State<OTPScreen> createState() => _OTPScreenState();
}

class _OTPScreenState extends State<OTPScreen> with SingleTickerProviderStateMixin {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  
  bool _isLoading = false;
  int _timerSeconds = 30;
  Timer? _timer;
  bool _isResendEnabled = false;
  String _currentVerificationId = '';

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _currentVerificationId = widget.verificationId;
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    _animationController.dispose();
    super.dispose();
  }

  void _startTimer() {
    setState(() {
      _timerSeconds = 30;
      _isResendEnabled = false;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_timerSeconds > 0) {
          _timerSeconds--;
        } else {
          _isResendEnabled = true;
          timer.cancel();
        }
      });
    });
  }

  Future<void> _resendOTP() async {
    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: '+91${widget.phoneNumber}',
        verificationCompleted: (PhoneAuthCredential credential) async {
          setState(() => _isLoading = true);
          try {
            await FirebaseAuth.instance.signInWithCredential(credential);
            await _completeLoginSession();
          } catch (e) {
            debugPrint('Auto sign in failed: $e');
            setState(() => _isLoading = false);
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          debugPrint('Resend verification failed: ${e.message}');
          setState(() => _isLoading = false);
          _showSnackBar('Firebase Resend failed: ${e.message}', AppColors.error, Icons.error_outline_rounded);
        },
        codeSent: (String verId, int? resendToken) {
          setState(() {
            _currentVerificationId = verId;
            _isLoading = false;
          });
          _startTimer();
        },
        codeAutoRetrievalTimeout: (String verId) {
          setState(() {
            _currentVerificationId = verId;
          });
        },
      );
    } catch (e) {
      debugPrint('Error resending OTP: $e');
      setState(() => _isLoading = false);
      _showSnackBar('Error resending code. Please try again.', AppColors.error, Icons.warning_rounded);
    }
  }

  Future<void> _verifyCode() async {
    final otpCode = _controllers.map((e) => e.text).join();

    if (otpCode.length != 6) {
      _showSnackBar(
        "Enter 6 digit OTP",
        AppColors.error,
        Icons.error,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (kIsWeb && widget.confirmationResult != null) {
        await widget.confirmationResult!.confirm(otpCode);
      } else {
        final credential = PhoneAuthProvider.credential(
          verificationId: _currentVerificationId,
          smsCode: otpCode,
        );
        await FirebaseAuth.instance.signInWithCredential(credential);
      }
      if (widget.isNotRegistered) {
        setState(() => _isLoading = false);
        if (widget.isGuestMode && widget.cartItems != null) {
          _showSnackBar(
            'Redirecting to checkout details...',
            AppColors.secondary,
            Icons.person_add_rounded,
          );
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => GuestRegisterScreen(
                    prefilledPhone: widget.phoneNumber,
                    verifiedOtp: widget.apiPassword,
                    cartItems: widget.cartItems!,
                  ),
                ),
              );
            }
          });
        } else {
          _showSnackBar(
            'Phone number not registered. Redirecting to setup...',
            AppColors.secondary,
            Icons.person_add_rounded,
          );
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => UserRegisterScreen(
                    prefilledPhone: widget.phoneNumber,
                    verifiedOtp: widget.apiPassword,
                  ),
                ),
              );
            }
          });
        }
      } else {
        await _completeLoginSession();
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showSnackBar(
        e.message ?? "Invalid OTP",
        AppColors.error,
        Icons.error,
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showSnackBar(
        e.toString(),
        AppColors.error,
        Icons.error,
      );
    }
  }

  Future<String> _getDeviceId() async {
    try {
      final String? token = await FirebaseMessaging.instance.getToken().timeout(
        const Duration(seconds: 2),
      );
      print("================================");
      print("FCM TOKEN: $token");
      print("================================");
      return token ?? await ApiService.getOrCreateDeviceId();
    } catch (e) {
      debugPrint("FCM token fetch timed out or failed: $e");
      return await ApiService.getOrCreateDeviceId();
    }
  }

  Future<void> _completeLoginSession() async {
    final deviceId = await _getDeviceId();

    try {
      final response = await ApiService.login(
        mobile: widget.phoneNumber,
        password: widget.apiPassword,
        deviceId: deviceId,
      );

      bool isNotRegistered = false;
      String errorMessage = 'Login failed.';

      debugPrint("Login response status: ${response.statusCode}");
      debugPrint("Login response body: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        final resData = json.decode(response.body);
        final int code = resData['code'] is int
            ? resData['code']
            : int.tryParse(resData['code']?.toString() ?? '200') ?? 200;

        if (code == 200) {
          final loginData = resData['data'];
          if (loginData != null && loginData['user'] != null) {
            final String token = loginData['token']?.toString() ?? '';
            final Map<String, dynamic> user = loginData['user'];

            final int userType = user['user_type'] is int
                ? user['user_type']
                : int.tryParse(user['user_type']?.toString() ?? '1') ?? 1;

            if (userType != 1) {
              setState(() => _isLoading = false);
              _showSnackBar(
                'Unauthorized: This application is for customers only.',
                AppColors.error,
                Icons.error_outline_rounded,
              );
              return;
            }

            try {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('auth_token', token);
              
              final Map<String, dynamic> userCopy = Map<String, dynamic>.from(user);
              final dynamic addressList = resData['address'];
              if (addressList != null) {
                userCopy['addresses'] = addressList;
              } else {
                userCopy['addresses'] = [];
              }
              await prefs.setString('user_data', json.encode(userCopy));
              await CartManager.migrateGuestCartToUser();
            } catch (prefsErr) {
              debugPrint('Error saving session: $prefsErr');
            }

            setState(() => _isLoading = false);
            if (widget.isGuestMode && widget.cartItems != null) {
              _showSnackBar('Login successful. Continuing to checkout...', Colors.green, Icons.check_circle_rounded);
              
              // Push ECommerceHomeScreen as root, then CheckoutScreen on top
              final target = AppRouter.pendingRoute ?? '/home';
              AppRouter.pendingRoute = null;
              Navigator.of(context).pushNamedAndRemoveUntil(
                target,
                (route) => false,
              );
              
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => CheckoutScreen(
                    cartItems: widget.cartItems!,
                    token: token,
                  ),
                ),
              );
            } else {
              _showSuccessDialog(user, token);
            }
            return;
          }
        }
        errorMessage = resData['message'] ?? 'Login failed.';
      } else {
        try {
          final resData = json.decode(response.body);
          errorMessage = resData['message'] ?? 'Login failed.';
        } catch (_) {
          errorMessage = 'Server error: ${response.statusCode}';
        }
      }

      final lowerMsg = errorMessage.toLowerCase();
      if (lowerMsg.contains('not register') || 
          lowerMsg.contains('not found') || 
          lowerMsg.contains('no vendor') || 
          lowerMsg.contains('no user') ||
          lowerMsg.contains('not exist') ||
          response.statusCode == 404) {
        isNotRegistered = true;
      }

      if (isNotRegistered) {
        setState(() => _isLoading = false);
        
        if (widget.isGuestMode && widget.cartItems != null) {
          _showSnackBar(
            'Redirecting to checkout details...',
            AppColors.secondary,
            Icons.person_add_rounded,
          );
          
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => GuestRegisterScreen(
                    prefilledPhone: widget.phoneNumber,
                    cartItems: widget.cartItems!,
                  ),
                ),
              );
            }
          });
        } else {
          _showSnackBar(
            'Phone number not registered. Redirecting to setup...',
            AppColors.secondary,
            Icons.person_add_rounded,
          );
          
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => UserRegisterScreen(
                    prefilledPhone: widget.phoneNumber,
                  ),
                ),
              );
            }
          });
        }
      } else {
        setState(() => _isLoading = false);
        _showSnackBar(errorMessage, AppColors.error, Icons.warning_rounded);
      }
    } catch (e) {
      debugPrint('Error submitting login details: $e');
      setState(() => _isLoading = false);
      _showSnackBar('Login submission failed. Please try again.', AppColors.error, Icons.warning_rounded);
    }
  }

  void _showSnackBar(String message, Color bgColor, IconData icon) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: bgColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  void _showSuccessDialog(Map<String, dynamic> user, String token) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.verified_user_rounded,
                    color: AppColors.secondary,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Success!',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Welcome back, ${user['name'] ?? 'User'}!',
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.textLight,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context); // Close dialog
                      final target = AppRouter.pendingRoute ?? '/home';
                      AppRouter.pendingRoute = null;
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        target,
                        (route) => false,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text('Continue', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onDigitInput(int index, String val) {
    if (val.isNotEmpty) {
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
        _verifyCode();
      }
    } else {
      if (index > 0) {
        _focusNodes[index - 1].requestFocus();
      }
    }
  }

  Widget _buildLeftHeroSection(LinearGradient gradient) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 8),
              const Text(
                'Back',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const Spacer(),
          
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.shopping_bag_rounded,
              color: Colors.white,
              size: 48,
            ),
          ),
          const SizedBox(height: 28),
          
          const Text(
            'Your Neighborhood\nMarketplace',
            style: TextStyle(
              fontSize: 38,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.2,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Discover local products, order instantly, and get lightning fast delivery directly from merchants you trust.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white70,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 40),
          
          _buildHeroBenefit('Faster checkouts & saved addresses'),
          const SizedBox(height: 16),
          _buildHeroBenefit('Direct interaction with local shops'),
          const SizedBox(height: 16),
          _buildHeroBenefit('Instant delivery & order tracking status'),
          
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildHeroBenefit(String text) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_rounded, color: AppColors.primary, size: 14),
        ),
        const SizedBox(width: 14),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14.5,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildOtpCard(Color primaryColor, LinearGradient gradient) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Container(
          padding: const EdgeInsets.all(36),
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
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Verify Code',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter the 6-digit OTP code sent to +91 ${widget.phoneNumber}',
                style: const TextStyle(fontSize: 14, color: AppColors.textLight),
              ),
              const SizedBox(height: 36),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (index) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    width: 48,
                    height: 56,
                    child: TextFormField(
                      controller: _controllers[index],
                      focusNode: _focusNodes[index],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(1),
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      onChanged: (val) => _onDigitInput(index, val),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.surface,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: primaryColor, width: 2),
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 28),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!_isResendEnabled)
                    Text(
                      'Resend code in ${_timerSeconds}s',
                      style: const TextStyle(color: AppColors.textLight, fontSize: 14),
                    )
                  else
                    TextButton(
                      onPressed: _isLoading ? null : _resendOTP,
                      style: TextButton.styleFrom(foregroundColor: primaryColor),
                      child: const Text(
                        'Resend OTP Code',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 36),

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
                  onPressed: _isLoading ? null : _verifyCode,
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
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Verify & Log In',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                        ),
                ),
              ),
            ],
          ),
        ),
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

    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth > 850;

    if (isDesktop) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: SafeArea(
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: _buildLeftHeroSection(gradient),
              ),
              Expanded(
                flex: 5,
                child: Container(
                  color: const Color(0xFFF8FAFC),
                  child: Stack(
                    children: [
                      Positioned(
                        top: 16,
                        left: 16,
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: _buildOtpCard(primaryColor, gradient),
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

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Verify Code',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter the 6-digit OTP code sent to +91 ${widget.phoneNumber}',
                  style: const TextStyle(fontSize: 14, color: AppColors.textLight),
                ),
                const SizedBox(height: 40),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(6, (index) {
                    return SizedBox(
                      width: 48,
                      height: 56,
                      child: TextFormField(
                        controller: _controllers[index],
                        focusNode: _focusNodes[index],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(1),
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: (val) => _onDigitInput(index, val),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: AppColors.surface,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: primaryColor, width: 2),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 32),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (!_isResendEnabled)
                      Text(
                        'Resend code in ${_timerSeconds}s',
                        style: const TextStyle(color: AppColors.textLight, fontSize: 14),
                      )
                    else
                      TextButton(
                        onPressed: _isLoading ? null : _resendOTP,
                        style: TextButton.styleFrom(foregroundColor: primaryColor),
                        child: const Text(
                          'Resend OTP Code',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 48),

                Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 2,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _verifyCode,
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
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Verify & Log In',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
