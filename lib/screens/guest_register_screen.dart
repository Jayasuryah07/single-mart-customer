import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../theme.dart';
import 'ecommerce_home_screen.dart';
import 'checkout_screen.dart';

class GuestRegisterScreen extends StatefulWidget {
  final String prefilledPhone;
  final String? verifiedOtp;
  final List<Map<String, dynamic>> cartItems;

  const GuestRegisterScreen({
    super.key,
    required this.prefilledPhone,
    this.verifiedOtp,
    required this.cartItems,
  });

  @override
  State<GuestRegisterScreen> createState() => _GuestRegisterScreenState();
}

class _GuestRegisterScreenState extends State<GuestRegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  // Address controllers
  final TextEditingController _addressLine1Controller = TextEditingController();
  final TextEditingController _addressLine2Controller = TextEditingController();
  final TextEditingController _landmarkController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _districtController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();
  final TextEditingController _pincodeController = TextEditingController();
  final TextEditingController _countryController =
      TextEditingController(text: 'India');
  final TextEditingController _addressTypeController =
      TextEditingController(text: 'Home');

  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  List<String> _states = [
    '',
  ];
  String? _selectedState;
  bool _isLoadingStates = false;

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
    _animationController.forward();
    _loadStatesList();
    _phoneController.text = widget.prefilledPhone;
  }

  Future<void> _loadStatesList() async {
    setState(() => _isLoadingStates = true);
    try {
      final response = await ApiService.fetchStates();
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> list = data['data'] ?? [];
        final fetchedStates = list
            .map((item) => item['state_name']?.toString() ?? '')
            .where((val) => val.isNotEmpty)
            .toList();
        if (fetchedStates.isNotEmpty) {
          setState(() {
            _states = fetchedStates;
            _states.sort();
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching states from API: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingStates = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressLine1Controller.dispose();
    _addressLine2Controller.dispose();
    _landmarkController.dispose();
    _cityController.dispose();
    _districtController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    _countryController.dispose();
    _addressTypeController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _submitGuestDetails() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final String name = _nameController.text.trim();
    final String email = _emailController.text.trim();
    final String mobile = _phoneController.text.trim();
    final String addressLine1 = _addressLine1Controller.text.trim();
    final String addressLine2 = _addressLine2Controller.text.trim();
    final String landmark = _landmarkController.text.trim();
    final String city = _cityController.text.trim();
    final String district = _districtController.text.trim();
    final String state = _stateController.text.trim();
    final String pincode = _pincodeController.text.trim();
    final String country = _countryController.text.trim();
    final String addressType = _addressTypeController.text.trim();

    // Hiding gender and dob: supply mock values to backend
    const String gender = 'Other';
    const String dob = '1990-01-01';

    String token = '';
    try {
      final prefs = await SharedPreferences.getInstance();
      token = prefs.getString('auth_token') ?? '';
    } catch (e) {
      debugPrint('Error looking up token: $e');
    }

    try {
      final uri = Uri.parse('https://agsdemo.in/singlemartapi/public/api/createvendor');
      final request = http.MultipartRequest('POST', uri);
      
      // Headers
      request.headers['Accept'] = 'application/json';
      if (token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      // Add all text fields with proper values
      request.fields['name'] = name;
      request.fields['owner_name'] = name;
      request.fields['mobile'] = mobile;
      request.fields['email'] = email;
      request.fields['gender'] = gender;
      request.fields['dob'] = dob;
      request.fields['user_type'] = '1';
      request.fields['user_position'] = 'User';
      request.fields['is_verified'] = '1';
      
      request.fields['upi_id'] = '';
      request.fields['qr_code'] = '';
      request.fields['business_document'] = '';
      request.fields['gst_number'] = '';
      request.fields['pan_number'] = '';
      request.fields['user_image'] = '';

      // Address fields - Send as array format
      request.fields['addresses[0][address_line_1]'] = addressLine1;
      request.fields['addresses[0][address_line_2]'] = addressLine2;
      request.fields['addresses[0][landmark]'] = landmark;
      request.fields['addresses[0][city]'] = city;
      request.fields['addresses[0][district]'] = district.isNotEmpty ? district : city;
      request.fields['addresses[0][state]'] = state;
      request.fields['addresses[0][country]'] = country;
      request.fields['addresses[0][pincode]'] = pincode;
      request.fields['addresses[0][address_type]'] = addressType;
      request.fields['addresses[0][is_default]'] = '1';

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('Guest Reg response status: ${response.statusCode}');
      print('Guest Reg response body: ${response.body}');

      final resData = json.decode(response.body);

      // Check for duplicate entry error
      if (response.statusCode == 422 || response.statusCode == 500) {
        String errorMessage = resData['message'] ?? '';
        
        if (errorMessage.contains('Duplicate entry') && 
            (errorMessage.contains('mobile') || errorMessage.contains("'mobile'"))) {
          setState(() => _isLoading = false);
          _showSnackBar(
            'This phone number is already registered. Please go back and login.',
            Colors.orange,
            Icons.warning_rounded,
          );
          return;
        }
        
        if (errorMessage.contains('Duplicate entry') && 
            (errorMessage.contains('email') || errorMessage.contains("'email'"))) {
          setState(() => _isLoading = false);
          _showSnackBar(
            'This email address is already registered. Please use a different email.',
            Colors.orange,
            Icons.warning_rounded,
          );
          return;
        }
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final int code = resData['code'] is int
            ? resData['code']
            : int.tryParse(resData['code']?.toString() ?? '200') ?? 200;

        if (code == 200 || code == 201) {
          final String otpPass = widget.verifiedOtp ?? '123456';
          _loginAndNavigate(mobile, otpPass);
        } else {
          setState(() => _isLoading = false);
          _showSnackBar(
            resData['message'] ?? 'Registration failed.',
            Colors.redAccent,
            Icons.warning_rounded,
          );
        }
      } else {
        setState(() => _isLoading = false);
        String errorMessage = resData['message'] ?? 'Server error ${response.statusCode}. Please try again.';
        
        if (errorMessage.contains('Duplicate entry') && 
            (errorMessage.contains('mobile') || errorMessage.contains("'mobile'"))) {
          errorMessage = 'This phone number is already registered. Please login.';
        } else if (errorMessage.contains('Duplicate entry') && 
                   (errorMessage.contains('email') || errorMessage.contains("'email'"))) {
          errorMessage = 'This email address is already registered. Please use a different email.';
        }
        
        _showSnackBar(
          errorMessage,
          Colors.redAccent,
          Icons.warning_rounded,
        );
      }
    } catch (e) {
      debugPrint('Guest registration exception: $e');
      setState(() => _isLoading = false);
      _showSnackBar(
        'Server unreachable. Please check your connection.',
        Colors.redAccent,
        Icons.warning_rounded,
      );
    }
  }

  Future<void> _loginAndNavigate(String phone, String otpPassword) async {
    try {
      // Step 1: Call checkMobile to generate a valid login OTP/password for this newly registered user
      String activePassword = otpPassword;
      try {
        final checkResponse = await ApiService.checkMobile(phone);
        if (checkResponse.statusCode == 200 || checkResponse.statusCode == 201) {
          final checkData = json.decode(checkResponse.body);
          final int checkCode = checkData['code'] is int
              ? checkData['code']
              : int.tryParse(checkData['code']?.toString() ?? '200') ?? 200;
          if (checkCode == 200) {
            final String fetchedOtp = checkData['data']?.toString() ?? '';
            if (fetchedOtp.isNotEmpty) {
              activePassword = fetchedOtp;
            }
          }
        }
      } catch (checkErr) {
        debugPrint("Error fetching active OTP during guest direct login check: $checkErr");
      }

      // Step 2: Perform the login request using the active OTP/password
      final deviceId = await ApiService.getOrCreateDeviceId();
      final response = await ApiService.login(
        mobile: phone,
        deviceId: deviceId,
        password: activePassword,
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

            if (mounted) {
              _showSnackBar('Details saved. Continuing to checkout...', Colors.green, Icons.check_circle_rounded);
              
              // Clean navigation: Push Home as root of stack, then push Checkout on top of it.
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (context) => const ECommerceHomeScreen(),
                ),
                (route) => false,
              );
              
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => CheckoutScreen(
                    cartItems: widget.cartItems,
                    token: token,
                  ),
                ),
              );
            }
            return;
          }
        }
      }

      if (mounted) {
        _showSnackBar('Details saved successfully! Please login to complete checkout.', Colors.green, Icons.check_circle_rounded);
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      debugPrint("Guest direct login error: $e");
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = AppColors.primary;
    const Color secondaryColor = Color(0xFFF59E0B);
    final LinearGradient gradient =
        LinearGradient(colors: [primaryColor, secondaryColor]);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Checkout Details',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          primaryColor.withOpacity(0.08),
                          secondaryColor.withOpacity(0.03),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Checkout as Guest',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Please provide your name, email, and delivery details to proceed with your payment.',
                          style: TextStyle(
                              fontSize: 14, color: Color(0xFF64748B), height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Contact Details
                  const Text(
                    'Contact Information',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 16),

                  _buildLabel('FULL NAME'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _nameController,
                    validator: (val) =>
                        val == null || val.trim().isEmpty ? 'Please enter your full name' : null,
                    decoration: _buildInputDecoration(
                      hint: 'Enter your full name',
                      icon: Icons.person_outline_rounded,
                      activeColor: primaryColor,
                    ),
                  ),
                  const SizedBox(height: 20),

                  _buildLabel('EMAIL ADDRESS'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Please enter your email address';
                      }
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                          .hasMatch(val.trim())) {
                        return 'Please enter a valid email address';
                      }
                      return null;
                    },
                    decoration: _buildInputDecoration(
                      hint: 'name@example.com',
                      icon: Icons.mail_outline_rounded,
                      activeColor: primaryColor,
                    ),
                  ),
                  const SizedBox(height: 20),

                  _buildLabel('PHONE NUMBER'),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 56,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 14),
                          child: Center(
                            child: Text(
                              '+91',
                              style: TextStyle(
                                color: Color(0xFF0F172A),
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
                          readOnly: true, // Phone number verified via OTP, keep read-only
                          decoration: _buildInputDecoration(
                            hint: 'Phone number',
                            icon: Icons.phone_outlined,
                            activeColor: primaryColor,
                          ).copyWith(
                            fillColor: const Color(0xFFF1F5F9), // Grayed out read-only style
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Delivery Address
                  const Text(
                    'Delivery Address',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 16),

                  _buildLabel('STREET ADDRESS / APARTMENT'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _addressLine1Controller,
                    validator: (val) =>
                        val == null || val.trim().isEmpty ? 'Please enter your street address' : null,
                    decoration: _buildInputDecoration(
                      hint: 'Flat/House no., Building, Street',
                      icon: Icons.home_outlined,
                      activeColor: primaryColor,
                    ),
                  ),
                  const SizedBox(height: 16),

                  _buildLabel('ADDRESS LINE 2 (OPTIONAL)'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _addressLine2Controller,
                    decoration: _buildInputDecoration(
                      hint: 'Apartment, Suite, Unit etc.',
                      icon: Icons.home_work_outlined,
                      activeColor: primaryColor,
                    ),
                  ),
                  const SizedBox(height: 16),

                  _buildLabel('LANDMARK (OPTIONAL)'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _landmarkController,
                    decoration: _buildInputDecoration(
                      hint: 'Nearby landmark',
                      icon: Icons.place_outlined,
                      activeColor: primaryColor,
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('CITY'),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _cityController,
                              validator: (val) =>
                                  val == null || val.trim().isEmpty ? 'Enter city' : null,
                              decoration: _buildInputDecoration(
                                hint: 'City name',
                                icon: Icons.location_city_outlined,
                                activeColor: primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('DISTRICT (OPTIONAL)'),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _districtController,
                              decoration: _buildInputDecoration(
                                hint: 'District name',
                                icon: Icons.map_outlined,
                                activeColor: primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('STATE'),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              value: _selectedState,
                              items: _states.map((state) {
                                return DropdownMenuItem<String>(
                                  value: state,
                                  child: Text(
                                    state,
                                    style: const TextStyle(
                                        fontSize: 13, color: Color(0xFF0F172A)),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                setState(() {
                                  _selectedState = val;
                                  _stateController.text = val ?? '';
                                });
                              },
                              validator: (val) =>
                                  val == null || val.isEmpty ? 'Select state' : null,
                              decoration: _buildInputDecoration(
                                hint: _isLoadingStates ? 'Loading states...' : 'Select state',
                                icon: Icons.map_outlined,
                                activeColor: primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('PINCODE'),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _pincodeController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                LengthLimitingTextInputFormatter(6),
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              validator: (val) =>
                                  val == null || val.trim().length != 6
                                      ? 'Enter 6-digit pin'
                                      : null,
                              decoration: _buildInputDecoration(
                                hint: '6-digit pin',
                                icon: Icons.pin_drop_outlined,
                                activeColor: primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('COUNTRY'),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _countryController,
                              validator: (val) =>
                                  val == null || val.trim().isEmpty ? 'Enter country' : null,
                              decoration: _buildInputDecoration(
                                hint: 'Country',
                                icon: Icons.public_outlined,
                                activeColor: primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('ADDRESS TYPE'),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              value: _addressTypeController.text,
                              items: const [
                                DropdownMenuItem(value: 'Home', child: Text('Home')),
                                DropdownMenuItem(value: 'Office', child: Text('Office')),
                                DropdownMenuItem(value: 'Other', child: Text('Other')),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  _addressTypeController.text = val;
                                }
                              },
                              decoration: _buildInputDecoration(
                                hint: 'Select type',
                                icon: Icons.tag_rounded,
                                activeColor: primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 48),

                  // Submit Button
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
                          spreadRadius: 2,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitGuestDetails,
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
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Continue to Checkout',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0),
                            ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        color: Color(0xFF475569),
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.0,
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required String hint,
    required IconData icon,
    required Color activeColor,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
      prefixIcon: Icon(icon, color: const Color(0xFF94A3B8), size: 20),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
        borderSide: BorderSide(color: activeColor, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1),
      ),
    );
  }
}
