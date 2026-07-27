import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../theme.dart';

class UpdateProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String token;

  const UpdateProfileScreen({
    super.key,
    required this.userData,
    required this.token,
  });

  @override
  State<UpdateProfileScreen> createState() => _UpdateProfileScreenState();
}

class _UpdateProfileScreenState extends State<UpdateProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  Map<String, dynamic> _currentUserData = {};
  File? _imageFile;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();

  String _selectedGender = 'Male';
  final List<String> _genders = ['Male', 'Female', 'Other'];

  String _baseUserImageUrl = 'https://agsdemo.in/singlemartapi/public/assets/images/user_images/';

  @override
  void initState() {
    super.initState();
    _loadBaseUrls();
    _currentUserData = Map.from(widget.userData);
    _nameController.text = _currentUserData['name']?.toString() ?? '';
    _mobileController.text = _currentUserData['mobile']?.toString() ?? '';
    _emailController.text = _currentUserData['email']?.toString() ?? '';
    _dobController.text = _currentUserData['dob']?.toString() ?? '';

    final existingGender = _currentUserData['gender']?.toString() ?? '';
    if (existingGender.isNotEmpty) {
      final matched = _genders.firstWhere(
        (g) => g.toLowerCase() == existingGender.toLowerCase(),
        orElse: () => 'Male',
      );
      _selectedGender = matched;
    }

    _fetchProfileDetails();
  }

  Future<void> _loadBaseUrls() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _baseUserImageUrl = prefs.getString('base_user_image_url') ?? _baseUserImageUrl;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  Future<void> _fetchProfileDetails() async {
    setState(() => _isLoading = true);
    try {
      final int vendorId = widget.userData['id'] is int 
          ? widget.userData['id'] 
          : int.tryParse(widget.userData['id']?.toString() ?? '0') ?? 0;

      final response = await ApiService.fetchVendor(vendorId, widget.token);

      if (response.statusCode == 200) {
        final resData = json.decode(response.body);
        final dynamic profileData = resData['data'];
        if (profileData != null) {
          final Map<String, dynamic> parsedProfile = Map<String, dynamic>.from(profileData);
          setState(() {
            _currentUserData = parsedProfile;
            _nameController.text = _currentUserData['name']?.toString() ?? '';
            _mobileController.text = _currentUserData['mobile']?.toString() ?? '';
            _emailController.text = _currentUserData['email']?.toString() ?? '';
            _dobController.text = _currentUserData['dob']?.toString() ?? '';

            final existingGender = _currentUserData['gender']?.toString() ?? '';
            if (existingGender.isNotEmpty) {
              final matched = _genders.firstWhere(
                (g) => g.toLowerCase() == existingGender.toLowerCase(),
                orElse: () => 'Male',
              );
              _selectedGender = matched;
            }
          });

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_data', json.encode(_currentUserData));
        }
      }
    } catch (e) {
      debugPrint("Fetch profile error: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

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

  Future<void> _selectDate() async {
    DateTime initial = DateTime.now().subtract(const Duration(days: 365 * 18));
    if (_dobController.text.isNotEmpty) {
      try {
        initial = DateTime.parse(_dobController.text);
      } catch (_) {}
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _dobController.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final int vendorId = _currentUserData['id'] is int 
          ? _currentUserData['id'] 
          : int.tryParse(_currentUserData['id']?.toString() ?? '0') ?? 0;

      final existingAddresses = _currentUserData['addresses'] ?? _currentUserData['address'] ?? [];

      if (_imageFile != null) {
        // Prepare Multipart payload
        final Map<String, String> fields = {
          "name": _nameController.text.trim(),
          "owner_name": _nameController.text.trim(),
          "mobile": _mobileController.text.trim(),
          "email": _emailController.text.trim(),
          "gender": _selectedGender,
          "dob": _dobController.text.trim(),
          "user_type": (_currentUserData['user_type'] ?? 1).toString(),
          "user_position": (_currentUserData['user_position'] ?? 'User').toString(),
          "is_verified": (_currentUserData['is_verified'] ?? 1).toString(),
          "upi_id": "",
          "qr_code": "",
          "business_document": "",
          "gst_number": "",
          "pan_number": "",
          "status": (_currentUserData['status'] ?? 'Active').toString()
        };

        if (existingAddresses is List) {
          for (int i = 0; i < existingAddresses.length; i++) {
            final addr = existingAddresses[i];
            fields['addresses[$i][id]'] = (addr['id'] ?? '').toString();
            fields['addresses[$i][address_line_1]'] = (addr['address_line_1'] ?? '').toString();
            fields['addresses[$i][address_line_2]'] = (addr['address_line_2'] ?? '').toString();
            fields['addresses[$i][landmark]'] = (addr['landmark'] ?? '').toString();
            fields['addresses[$i][city]'] = (addr['city'] ?? '').toString();
            fields['addresses[$i][district]'] = (addr['district'] ?? '').toString();
            fields['addresses[$i][state]'] = (addr['state'] ?? '').toString();
            fields['addresses[$i][country]'] = (addr['country'] ?? '').toString();
            fields['addresses[$i][pincode]'] = (addr['pincode'] ?? '').toString();
            fields['addresses[$i][address_type]'] = (addr['address_type'] ?? '').toString();
            fields['addresses[$i][is_default]'] = (addr['is_default'] ?? 0).toString();

            fields['address[$i][id]'] = (addr['id'] ?? '').toString();
            fields['address[$i][address_line_1]'] = (addr['address_line_1'] ?? '').toString();
            fields['address[$i][address_line_2]'] = (addr['address_line_2'] ?? '').toString();
            fields['address[$i][landmark]'] = (addr['landmark'] ?? '').toString();
            fields['address[$i][city]'] = (addr['city'] ?? '').toString();
            fields['address[$i][district]'] = (addr['district'] ?? '').toString();
            fields['address[$i][state]'] = (addr['state'] ?? '').toString();
            fields['address[$i][country]'] = (addr['country'] ?? '').toString();
            fields['address[$i][pincode]'] = (addr['pincode'] ?? '').toString();
            fields['address[$i][address_type]'] = (addr['address_type'] ?? '').toString();
            fields['address[$i][is_default]'] = (addr['is_default'] ?? 0).toString();
          }
        }

        final response = await ApiService.updateVendorWithImage(
          vendorId: vendorId,
          fields: fields,
          imageFile: _imageFile,
          token: widget.token,
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          final resData = json.decode(response.body);
          final dynamic profileData = resData['data'];
          final prefs = await SharedPreferences.getInstance();
          
          final Map<String, dynamic> localUserData = Map.from(_currentUserData);
          localUserData['name'] = fields['name'];
          localUserData['owner_name'] = fields['name'];
          localUserData['mobile'] = fields['mobile'];
          localUserData['email'] = fields['email'];
          localUserData['gender'] = fields['gender'];
          localUserData['dob'] = fields['dob'];

          if (profileData != null && profileData is Map) {
            localUserData['user_image'] = profileData['user_image'];
          }

          await prefs.setString('user_data', json.encode(localUserData));

          setState(() => _isLoading = false);

          _showSnackBar(
            resData['message'] ?? 'Profile updated successfully!',
            Colors.green,
            Icons.check_circle_rounded,
          );

          Future.delayed(const Duration(milliseconds: 1000), () {
            if (mounted) {
              Navigator.pop(context, true);
            }
          });
        } else {
          setState(() => _isLoading = false);
          final resData = json.decode(response.body);
          _showSnackBar(
            resData['message'] ?? 'Connection error. Status: ${response.statusCode}',
            AppColors.error,
            Icons.warning_rounded,
          );
        }
      } else {
        // Standard JSON PUT request if no image is updated
        final Map<String, dynamic> body = {
          "name": _nameController.text.trim(),
          "owner_name": _nameController.text.trim(),
          "mobile": _mobileController.text.trim(),
          "email": _emailController.text.trim(),
          "gender": _selectedGender,
          "dob": _dobController.text.trim(),
          "user_type": _currentUserData['user_type'] ?? 1,
          "user_position": _currentUserData['user_position'] ?? 'User',
          "is_verified": _currentUserData['is_verified'] ?? 1,
          "upi_id": "",
          "qr_code": "",
          "business_document": "",
          "gst_number": "",
          "pan_number": "",
          "status": _currentUserData['status'] ?? 'Active',
          "addresses": existingAddresses,
          "address": existingAddresses
        };

        final response = await ApiService.updateVendor(vendorId, body, widget.token);

        if (response.statusCode == 200 || response.statusCode == 201) {
          final resData = json.decode(response.body);
          final prefs = await SharedPreferences.getInstance();
          
          final Map<String, dynamic> localUserData = Map.from(_currentUserData);
          localUserData['name'] = body['name'];
          localUserData['owner_name'] = body['name'];
          localUserData['mobile'] = body['mobile'];
          localUserData['email'] = body['email'];
          localUserData['gender'] = body['gender'];
          localUserData['dob'] = body['dob'];

          await prefs.setString('user_data', json.encode(localUserData));

          setState(() => _isLoading = false);

          _showSnackBar(
            resData['message'] ?? 'Profile updated successfully!',
            Colors.green,
            Icons.check_circle_rounded,
          );

          Future.delayed(const Duration(milliseconds: 1000), () {
            if (mounted) {
              Navigator.pop(context, true);
            }
          });
        } else {
          setState(() => _isLoading = false);
          final resData = json.decode(response.body);
          _showSnackBar(
            resData['message'] ?? 'Connection error. Status: ${response.statusCode}',
            AppColors.error,
            Icons.warning_rounded,
          );
        }
      }
    } catch (e) {
      debugPrint("Update profile error: $e");
      setState(() => _isLoading = false);
      _showSnackBar(
        'Server error. Please verify your connection.',
        AppColors.error,
        Icons.warning_rounded,
      );
    }
  }

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
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildLeftProfileCard(String imageUrl, LinearGradient gradient, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Avatar Stack
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: gradient,
                ),
              ),
              Container(
                width: 134,
                height: 134,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
              ),
              CircleAvatar(
                radius: 62,
                backgroundColor: AppColors.primary.withOpacity(0.05),
                backgroundImage: _imageFile != null
                    ? FileImage(_imageFile!)
                    : (imageUrl.isNotEmpty ? NetworkImage(imageUrl) as ImageProvider : null),
                child: (_imageFile == null && imageUrl.isEmpty)
                    ? const Icon(
                        Icons.person_rounded,
                        size: 64,
                        color: AppColors.primary,
                      )
                    : null,
              ),
              Positioned(
                bottom: 4,
                right: 4,
                child: GestureDetector(
                  onTap: _showImagePickerOptions,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          Text(
            _currentUserData['name']?.toString() ?? 'Profile User',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _currentUserData['email']?.toString() ?? '',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textLight,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),
          const Divider(color: Color(0xFFF1F5F9), height: 1),
          const SizedBox(height: 24),

          _buildInfoRow(Icons.calendar_today_rounded, 'Date Joined', _currentUserData['created_at']?.toString().split('T')[0] ?? '2026-07-27'),
          const SizedBox(height: 14),
          _buildInfoRow(Icons.verified_user_rounded, 'Status', 'Active Account', valueColor: const Color(0xFF10B981)),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Row(
      children: [
        Icon(icon, color: AppColors.textLight, size: 18),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppColors.textLight, fontWeight: FontWeight.w500),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 13, 
            fontWeight: FontWeight.bold, 
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildRightFormCard(ThemeData theme, LinearGradient gradient) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Personal Details',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _nameController,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  decoration: _buildInputDecoration('Name', Icons.person_outline_rounded, theme),
                  validator: (value) => value == null || value.trim().isEmpty ? 'Enter name' : null,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedGender,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                  items: _genders.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedGender = val);
                    }
                  },
                  decoration: _buildInputDecoration('Gender', Icons.wc_rounded, theme),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _dobController,
                  readOnly: true,
                  onTap: _selectDate,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  decoration: _buildInputDecoration('Date of Birth', Icons.calendar_today_rounded, theme),
                  validator: (value) => value == null || value.isEmpty ? 'Select date of birth' : null,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: TextFormField(
                  controller: _mobileController,
                  readOnly: true,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textSecondary),
                  decoration: _buildInputDecoration('Mobile Number', Icons.lock_outline_rounded, theme).copyWith(
                    fillColor: const Color(0xFFF1F5F9),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            decoration: _buildInputDecoration('Email Address', Icons.mail_outline_rounded, theme),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return 'Enter email address';
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) return 'Enter valid email';
              return null;
            },
          ),
          const SizedBox(height: 36),

          Align(
            alignment: Alignment.centerRight,
            child: Container(
              width: 200,
              height: 48,
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'Save Changes',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const LinearGradient gradient = LinearGradient(
      colors: [AppColors.primary, AppColors.secondary],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    final String? serverImage = _currentUserData['user_image']?.toString();
    final String imageUrl = (serverImage != null && serverImage.isNotEmpty)
        ? "${_baseUserImageUrl}$serverImage"
        : "";

    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth > 850;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Edit Profile',
          style: TextStyle(
            color: AppColors.textPrimary, 
            fontWeight: FontWeight.w900,
            fontSize: 20,
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            isDesktop
                ? Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(40),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1000),
                        child: Form(
                          key: _formKey,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 2,
                                child: _buildLeftProfileCard(imageUrl, gradient, theme),
                              ),
                              const SizedBox(width: 32),
                              Expanded(
                                flex: 3,
                                child: _buildRightFormCard(theme, gradient),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: gradient,
                                  ),
                                ),
                                Container(
                                  width: 114,
                                  height: 114,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                  ),
                                ),
                                CircleAvatar(
                                  radius: 52,
                                  backgroundColor: AppColors.primary.withOpacity(0.05),
                                  backgroundImage: _imageFile != null
                                      ? FileImage(_imageFile!)
                                      : (imageUrl.isNotEmpty ? NetworkImage(imageUrl) as ImageProvider : null),
                                  child: (_imageFile == null && imageUrl.isEmpty)
                                      ? const Icon(
                                          Icons.person_rounded,
                                          size: 54,
                                          color: AppColors.primary,
                                        )
                                      : null,
                                ),
                                Positioned(
                                  bottom: 2,
                                  right: 2,
                                  child: GestureDetector(
                                    onTap: _showImagePickerOptions,
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 2.5),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.primary.withOpacity(0.3),
                                            blurRadius: 8,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.camera_alt_rounded,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 36),

                          const Text(
                            'Personal Information',
                            style: TextStyle(
                              fontSize: 16, 
                              fontWeight: FontWeight.w900, 
                              color: AppColors.textPrimary,
                              letterSpacing: 0.1,
                            ),
                          ),
                          const SizedBox(height: 20),

                          TextFormField(
                            controller: _nameController,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            decoration: _buildInputDecoration('Name', Icons.person_outline_rounded, theme),
                            validator: (value) => value == null || value.trim().isEmpty ? 'Enter name' : null,
                          ),
                          const SizedBox(height: 18),

                          TextFormField(
                            controller: _mobileController,
                            readOnly: true,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textSecondary),
                            decoration: _buildInputDecoration('Mobile Number', Icons.lock_outline_rounded, theme).copyWith(
                              fillColor: const Color(0xFFF1F5F9),
                            ),
                          ),
                          const SizedBox(height: 18),

                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            decoration: _buildInputDecoration('Email Address', Icons.mail_outline_rounded, theme),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) return 'Enter email address';
                              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) return 'Enter valid email';
                              return null;
                            },
                          ),
                          const SizedBox(height: 18),

                          DropdownButtonFormField<String>(
                            value: _selectedGender,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                            items: _genders.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedGender = val);
                              }
                            },
                            decoration: _buildInputDecoration('Gender', Icons.wc_rounded, theme),
                          ),
                          const SizedBox(height: 18),

                          TextFormField(
                            controller: _dobController,
                            readOnly: true,
                            onTap: _selectDate,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            decoration: _buildInputDecoration('Date of Birth', Icons.calendar_today_rounded, theme),
                            validator: (value) => value == null || value.isEmpty ? 'Select date of birth' : null,
                          ),
                          const SizedBox(height: 40),

                          Container(
                            width: double.infinity,
                            height: 52,
                            decoration: BoxDecoration(
                              gradient: gradient,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _saveProfile,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: const Text(
                                'Save Changes',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
            if (_isLoading)
              Container(
                color: Colors.white.withOpacity(0.45),
                child: const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              ),
          ],
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String label, IconData icon, ThemeData theme) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textLight),
      floatingLabelStyle: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
      prefixIcon: Icon(icon, color: AppColors.textLight, size: 20),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
        borderSide: const BorderSide(color: AppColors.primary, width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.error, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.error, width: 1.8),
      ),
    );
  }
}
