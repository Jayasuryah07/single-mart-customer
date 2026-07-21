import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../theme.dart';
import 'ecommerce_home_screen.dart';

class OTPScreen extends StatefulWidget {
  final String phoneNumber;
  final String verificationId;
  final String apiOtp;

  const OTPScreen({
    super.key,
    required this.phoneNumber,
    required this.verificationId,
    required this.apiOtp,
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
      // 1. Trigger backend check-mobile to generate OTP
      final response = await ApiService.checkMobile(widget.phoneNumber);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final resData = json.decode(response.body);
        final int code = resData['code'] is int 
            ? resData['code'] 
            : int.tryParse(resData['code']?.toString() ?? '200') ?? 200;

        if (code == 200) {
          final newApiOtp = resData['data']?.toString() ?? '';
          _showSnackBar('OTP resent! (For Demo: $newApiOtp)', AppColors.secondary, Icons.check_circle_rounded);

          // 2. Trigger Firebase Phone Verification again
          await FirebaseAuth.instance.verifyPhoneNumber(
            phoneNumber: '+91${widget.phoneNumber}',
            verificationCompleted: (PhoneAuthCredential credential) async {
              setState(() => _isLoading = true);
              try {
                await FirebaseAuth.instance.signInWithCredential(credential);
                _completeLoginSession(newApiOtp);
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
        } else {
          setState(() => _isLoading = false);
          _showSnackBar(resData['message'] ?? 'Failed to resend code.', AppColors.error, Icons.warning_rounded);
        }
      } else {
        setState(() => _isLoading = false);
        _showSnackBar('Server connection error.', AppColors.error, Icons.warning_rounded);
      }
    } catch (e) {
      debugPrint('Error resending OTP: $e');
      setState(() => _isLoading = false);
      _showSnackBar('Error resending code. Please try again.', AppColors.error, Icons.warning_rounded);
    }
  }

  Future<void> _verifyCode() async {
    final otpCode = _controllers.map((c) => c.text).join();
    if (otpCode.length != 6) {
      _showSnackBar('Please enter all 6 digits of the OTP', AppColors.error, Icons.warning_rounded);
      return;
    }

    setState(() => _isLoading = true);

    bool verified = false;

    // 1. Try manual Firebase verification
    if (_currentVerificationId.isNotEmpty) {
      try {
        final credential = PhoneAuthProvider.credential(
          verificationId: _currentVerificationId,
          smsCode: otpCode,
        );
        await FirebaseAuth.instance.signInWithCredential(credential);
        verified = true;
      } catch (e) {
        debugPrint('Firebase SMS verification error: $e');
      }
    }

    // 2. Resilient fallback check: Compare against backend check-mobile API returned OTP
    if (!verified && widget.apiOtp.isNotEmpty && otpCode == widget.apiOtp) {
      verified = true;
    }

    if (verified) {
      await _completeLoginSession(widget.apiOtp);
    } else {
      setState(() => _isLoading = false);
      _showSnackBar('Invalid OTP. Please check and try again.', AppColors.error, Icons.warning_rounded);
    }
  }

  Future<String> _getDeviceId() async {
    return await ApiService.getOrCreateDeviceId();
  }

  Future<void> _completeLoginSession(String apiPassword) async {
    final deviceId = await _getDeviceId();

    try {
      final response = await ApiService.login(
        mobile: widget.phoneNumber,
        deviceId: deviceId,
        password: apiPassword,
      );

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

            // Role Verification - Reject if user_type is not 1 (e.g. 2 = Vendor, 3 = Admin)
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

            // Store session locally
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
            } catch (prefsErr) {
              debugPrint('Error saving session: $prefsErr');
            }

            setState(() => _isLoading = false);
            _showSuccessDialog(user, token);
            return;
          }
        }
        
        setState(() => _isLoading = false);
        _showSnackBar(resData['message'] ?? 'Login verification failed.', AppColors.error, Icons.warning_rounded);
      } else {
        setState(() => _isLoading = false);
        _showSnackBar('Login server error.', AppColors.error, Icons.warning_rounded);
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
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (context) => const ECommerceHomeScreen(),
                      ),
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

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = AppColors.primary;

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

                // OTP Digits input row
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

                // Timer & Resend Option
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

                // Verify Button
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
