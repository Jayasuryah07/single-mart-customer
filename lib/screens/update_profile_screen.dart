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

  late TextEditingController _nameController;
  late TextEditingController _ownerNameController;
  late TextEditingController _mobileController;
  late TextEditingController _emailController;
  late TextEditingController _dobController;

  String _selectedGender = 'Male';
  final List<String> _genders = ['Male', 'Female', 'Other'];

  String _baseUserImageUrl = 'https://agsdemo.in/singlemartapi/public/assets/images/user_images/';

  @override
  void initState() {
    super.initState();
    _loadBaseUrls();
    _currentUserData = Map.from(widget.userData);
    _nameController = TextEditingController(text: _currentUserData['name']?.toString() ?? '');
    _ownerNameController = TextEditingController(text: _currentUserData['owner_name']?.toString() ?? '');
    _mobileController = TextEditingController(text: _currentUserData['mobile']?.toString() ?? '');
    _emailController = TextEditingController(text: _currentUserData['email']?.toString() ?? '');
    _dobController = TextEditingController(text: _currentUserData['dob']?.toString() ?? '');

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
    _ownerNameController.dispose();
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
            _ownerNameController.text = _currentUserData['owner_name']?.toString() ?? '';
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
          "owner_name": _ownerNameController.text.trim(),
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
          localUserData['owner_name'] = fields['owner_name'];
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
          "owner_name": _ownerNameController.text.trim(),
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
          localUserData['owner_name'] = body['owner_name'];
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const LinearGradient gradient = LinearGradient(
      colors: [AppColors.primary, AppColors.secondary],
    );

    final String? serverImage = _currentUserData['user_image']?.toString();
    final String imageUrl = (serverImage != null && serverImage.isNotEmpty)
        ? "${_baseUserImageUrl}$serverImage"
        : "";

    return Scaffold(
      backgroundColor: const Color(0xFFFAFBFD),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: const Text(
          'Update Profile',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
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
                              backgroundColor: AppColors.primary.withOpacity(0.08),
                              backgroundImage: _imageFile != null
                                  ? FileImage(_imageFile!)
                                  : (imageUrl.isNotEmpty ? NetworkImage(imageUrl) as ImageProvider : null),
                              child: (_imageFile == null && imageUrl.isEmpty)
                                  ? const Icon(
                                      Icons.person_rounded,
                                      size: 48,
                                      color: AppColors.primary,
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
                                    color: AppColors.primary,
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
                      const SizedBox(height: 32),

                      const Text(
                        'Edit Profile Information',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 24),

                      // User Name Field
                      TextFormField(
                        controller: _nameController,
                        decoration: _buildInputDecoration('Name', Icons.person_outline_rounded, theme),
                        validator: (value) => value == null || value.trim().isEmpty ? 'Enter name' : null,
                      ),
                      const SizedBox(height: 16),

                      // Owner Name Field
                      TextFormField(
                        controller: _ownerNameController,
                        decoration: _buildInputDecoration('Owner Name', Icons.person_rounded, theme),
                        validator: (value) => value == null || value.trim().isEmpty ? 'Enter owner name' : null,
                      ),
                      const SizedBox(height: 16),

                      // Mobile Field
                      TextFormField(
                        controller: _mobileController,
                        keyboardType: TextInputType.phone,
                        decoration: _buildInputDecoration('Mobile Number', Icons.phone_iphone_rounded, theme),
                        validator: (value) => value == null || value.trim().length != 10 ? 'Enter valid 10-digit number' : null,
                      ),
                      const SizedBox(height: 16),

                      // Email Field
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: _buildInputDecoration('Email Address', Icons.email_rounded, theme),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) return 'Enter email address';
                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) return 'Enter valid email';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Gender Dropdown Row
                      DropdownButtonFormField<String>(
                        value: _selectedGender,
                        items: _genders.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedGender = val);
                          }
                        },
                        decoration: _buildInputDecoration('Gender', Icons.wc_rounded, theme),
                      ),
                      const SizedBox(height: 16),

                      // DOB Picker Field
                      TextFormField(
                        controller: _dobController,
                        readOnly: true,
                        onTap: _selectDate,
                        decoration: _buildInputDecoration('Date of Birth', Icons.calendar_today_rounded, theme),
                        validator: (value) => value == null || value.isEmpty ? 'Select date of birth' : null,
                      ),
                      const SizedBox(height: 32),

                      // Submit Button
                      Container(
                        width: double.infinity,
                        height: 50,
                        decoration: BoxDecoration(
                          gradient: gradient,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _saveProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text(
                            'Save Changes',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
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

  InputDecoration _buildInputDecoration(String label, IconData icon, ThemeData theme) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AppColors.textLight),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
      ),
    );
  }
}
