import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../theme.dart';

class UserRegisterScreen extends StatefulWidget {
  const UserRegisterScreen({super.key});

  @override
  State<UserRegisterScreen> createState() => _UserRegisterScreenState();
}

class _UserRegisterScreenState extends State<UserRegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();

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

  String? _selectedGender;
  File? _imageFile;

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Take Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        // Format: YYYY-MM-DD
        _dobController.text =
            "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  Widget _buildGenderOption(String gender, IconData icon) {
    final bool isSelected = _selectedGender == gender;
    const primaryColor = AppColors.primary;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedGender = gender;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor.withOpacity(0.08)
              : AppColors.surface,
          border: Border.all(
            color: isSelected ? primaryColor : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? primaryColor : const Color(0xFF64748B),
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              gender,
              style: TextStyle(
                color: isSelected ? primaryColor : const Color(0xFF0F172A),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

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
    _dobController.dispose();
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

  Future<void> _registerUser() async {
    if (_selectedGender == null) {
      _showSnackBar('Please select your gender', Colors.redAccent,
          Icons.warning_rounded);
      return;
    }
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
    final String dob = _dobController.text.trim();
    // Gender is already in correct format (Male/Female/Other)
    final String gender = _selectedGender ?? '';

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
      request.fields['gender'] = gender; // Male/Female/Other
      request.fields['dob'] = dob; // YYYY-MM-DD format
      request.fields['user_type'] = '1';
      request.fields['user_position'] = 'User';
      request.fields['is_verified'] = '1';
      
      // Set all optional fields to empty string
      request.fields['upi_id'] = '';
      request.fields['qr_code'] = '';
      request.fields['business_document'] = '';
      request.fields['gst_number'] = '';
      request.fields['pan_number'] = '';

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

      // Add image file if selected
      if (_imageFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'user_image',
            _imageFile!.path,
          ),
        );
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      // Log response for debugging
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      final resData = json.decode(response.body);

      // Check for duplicate entry error
      if (response.statusCode == 422 || response.statusCode == 500) {
        String errorMessage = resData['message'] ?? '';
        
        // Check if it's a duplicate mobile number error
        if (errorMessage.contains('Duplicate entry') && 
            (errorMessage.contains('mobile') || errorMessage.contains("'mobile'"))) {
          setState(() => _isLoading = false);
          _showSnackBar(
            'This phone number is already registered. Please use a different number or login.',
            Colors.orange,
            Icons.warning_rounded,
          );
          return;
        }
        
        // Check for duplicate email error
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
          setState(() => _isLoading = false);
          _showSuccessDialog();
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
        
        // Extract user-friendly message from SQL error
        if (errorMessage.contains('Duplicate entry') && 
            (errorMessage.contains('mobile') || errorMessage.contains("'mobile'"))) {
          errorMessage = 'This phone number is already registered. Please use a different number or login.';
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
      debugPrint('Registration exception: $e');
      setState(() => _isLoading = false);
      _showSnackBar(
        'Server unreachable. Please check your internet connection.',
        Colors.redAccent,
        Icons.warning_rounded,
      );
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
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
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

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: AppColors.primary,
                  size: 36,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Account Created!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your shopper profile has been registered successfully. You can now log in using your phone number.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textLight,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    Navigator.pop(context); // Exit register screen
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text('Back to Login',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
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
          'Register ',
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
                  // Profile Avatar with Image Upload
                  Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 54,
                          backgroundColor: primaryColor.withOpacity(0.08),
                          backgroundImage:
                              _imageFile != null ? FileImage(_imageFile!) : null,
                          child: _imageFile == null
                              ? Icon(
                                  Icons.person_rounded,
                                  size: 48,
                                  color: primaryColor,
                                )
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _showImagePickerOptions,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: primaryColor,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
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
                          'Join SingleMart!',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Register as a shopper to search products, discover exclusive discounts, and place local store orders.',
                          style: TextStyle(
                              fontSize: 14, color: Color(0xFF64748B), height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Section Title: Personal Info
                  const Text(
                    'Personal Information',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Full Name Field
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

                  // Email Field
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

                  // Phone Number Field
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
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(10),
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          validator: (val) =>
                              val == null || val.trim().length != 10
                                  ? 'Enter a valid 10-digit number'
                                  : null,
                          decoration: _buildInputDecoration(
                            hint: 'Enter phone number',
                            icon: Icons.phone_outlined,
                            activeColor: primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Gender Selector
                  _buildLabel('GENDER'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _buildGenderOption('Male', Icons.male_rounded)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildGenderOption('Female', Icons.female_rounded)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildGenderOption('Other', Icons.transgender_rounded)),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Date of Birth Selector
                  _buildLabel('DATE OF BIRTH (DOB)'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _dobController,
                    readOnly: true,
                    onTap: () => _selectDate(context),
                    validator: (val) =>
                        val == null || val.trim().isEmpty ? 'Please select your Date of Birth' : null,
                    decoration: _buildInputDecoration(
                      hint: 'YYYY-MM-DD',
                      icon: Icons.calendar_today_rounded,
                      activeColor: primaryColor,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Section Title: Address Info
                  const Text(
                    'Default Shopper Address',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Address Line 1
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

                  // Address Line 2 (Optional)
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

                  // Landmark (Optional)
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

                  // City & District in Row
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

                  // State & Country
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

                  // Country & Address Type
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

                  // Register Button
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
                      onPressed: _isLoading ? null : _registerUser,
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
                              'Register Shopper',
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