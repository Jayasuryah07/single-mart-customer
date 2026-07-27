import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../theme.dart';

class ManageAddressScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String token;

  const ManageAddressScreen({
    super.key,
    required this.userData,
    required this.token,
  });

  @override
  State<ManageAddressScreen> createState() => _ManageAddressScreenState();
}

class _ManageAddressScreenState extends State<ManageAddressScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _addresses = [];
  List<String> _states = [];
  Map<String, dynamic> _currentUserData = {};

  @override
  void initState() {
    super.initState();
    _currentUserData = Map.from(widget.userData);
    _loadAddresses();
    _fetchAddressesFromServer();
    _loadStatesList();
  }

  void _loadAddresses() {
    final rawList = _currentUserData['addresses'] ?? _currentUserData['address'];
    if (rawList != null && rawList is List) {
      setState(() {
        _addresses = rawList.map((addr) => Map<String, dynamic>.from(addr)).toList();
      });
    }
  }

  Future<void> _fetchAddressesFromServer() async {
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
          final rawList = parsedProfile['addresses'] ?? parsedProfile['address'];
          
          setState(() {
            _currentUserData = parsedProfile;
            if (rawList != null && rawList is List) {
              _addresses = rawList.map((addr) => Map<String, dynamic>.from(addr)).toList();
            }
          });

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_data', json.encode(_currentUserData));
        }
      }
    } catch (e) {
      debugPrint("Fetch addresses list error: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadStatesList() async {
    if (!mounted) return;
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
      debugPrint('Error fetching states: $e');
    }
  }

  Future<void> _updateAddressesOnServer(List<Map<String, dynamic>> newAddressesList) async {
    setState(() => _isLoading = true);

    try {
      final int vendorId = _currentUserData['id'] is int 
          ? _currentUserData['id'] 
          : int.tryParse(_currentUserData['id']?.toString() ?? '0') ?? 0;

      final Map<String, dynamic> body = {
        "name": _currentUserData['name']?.toString() ?? '',
        "owner_name": _currentUserData['owner_name']?.toString() ?? _currentUserData['name']?.toString() ?? '',
        "mobile": _currentUserData['mobile']?.toString() ?? '',
        "email": _currentUserData['email']?.toString() ?? '',
        "gender": _currentUserData['gender']?.toString() ?? 'Male',
        "dob": _currentUserData['dob']?.toString() ?? '',
        "user_type": _currentUserData['user_type'] ?? 1,
        "user_position": _currentUserData['user_position'] ?? 'User',
        "is_verified": _currentUserData['is_verified'] ?? 1,
        "upi_id": "",
        "qr_code": "",
        "business_document": "",
        "gst_number": "",
        "pan_number": "",
        "status": _currentUserData['status'] ?? 'Active',
        "addresses": newAddressesList,
        "address": newAddressesList
      };

      final response = await ApiService.updateVendor(vendorId, body, widget.token);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final resData = json.decode(response.body);
        final prefs = await SharedPreferences.getInstance();
        
        final Map<String, dynamic> localUserData = Map.from(_currentUserData);
        localUserData['addresses'] = newAddressesList;
        localUserData['address'] = newAddressesList;

        await prefs.setString('user_data', json.encode(localUserData));

        _showSnackBar(
          resData['message'] ?? 'Address settings updated successfully!',
          Colors.green,
          Icons.check_circle_rounded,
        );

        await _fetchAddressesFromServer();
      } else {
        setState(() => _isLoading = false);
        final resData = json.decode(response.body);
        _showSnackBar(
          resData['message'] ?? 'Connection error. Status: ${response.statusCode}',
          AppColors.error,
          Icons.warning_rounded,
        );
      }
    } catch (e) {
      debugPrint("Update addresses list error: $e");
      setState(() => _isLoading = false);
      _showSnackBar(
        'Server error. Please verify your connection.',
        AppColors.error,
        Icons.warning_rounded,
      );
    }
  }

  void _setDefaultAddress(int index) {
    final addr = _addresses[index];
    final bool isAlreadyDefault = addr['is_default'].toString() == '1' || addr['is_default'].toString() == 'true';
    if (isAlreadyDefault) return; // Already default

    // Construct updated address list, changing default flags
    final List<Map<String, dynamic>> updated = _addresses.map((a) {
      final item = Map<String, dynamic>.from(a);
      item['is_default'] = 0;
      return item;
    }).toList();

    updated[index]['is_default'] = 1;

    _updateAddressesOnServer(updated);
  }

  void _showAddressDialog({Map<String, dynamic>? addressToEdit, int? editIndex}) {
    final formKey = GlobalKey<FormState>();
    final theme = Theme.of(context);
    
    final line1Ctrl = TextEditingController(text: addressToEdit?['address_line_1']?.toString() ?? '');
    final line2Ctrl = TextEditingController(text: addressToEdit?['address_line_2']?.toString() ?? '');
    final landmarkCtrl = TextEditingController(text: addressToEdit?['landmark']?.toString() ?? '');
    final cityCtrl = TextEditingController(text: addressToEdit?['city']?.toString() ?? '');
    final districtCtrl = TextEditingController(text: addressToEdit?['district']?.toString() ?? '');
    final stateCtrl = TextEditingController(text: addressToEdit?['state']?.toString() ?? '');
    final countryCtrl = TextEditingController(text: addressToEdit?['country']?.toString() ?? 'India');
    final pincodeCtrl = TextEditingController(text: addressToEdit?['pincode']?.toString() ?? '');

    String addressType = 'Home';
    if (addressToEdit != null && addressToEdit['address_type'] != null) {
      final String rawType = addressToEdit['address_type'].toString().toLowerCase();
      if (rawType == 'work') {
        addressType = 'Work';
      } else if (rawType == 'other') {
        addressType = 'Other';
      }
    }

    bool isDefault = false;
    if (addressToEdit != null) {
      final defaultVal = addressToEdit['is_default'];
      isDefault = defaultVal.toString() == '1' || defaultVal.toString() == 'true';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 24,
            left: 24,
            right: 24,
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        addressToEdit == null ? 'Add New Address' : 'Edit Address',
                        style: const TextStyle(
                          fontSize: 20, 
                          fontWeight: FontWeight.w900, 
                          color: AppColors.textPrimary,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Line 1
                  TextFormField(
                    controller: line1Ctrl,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                    decoration: _buildInputDecoration('Address Line 1', Icons.location_on_outlined, theme),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required field' : null,
                  ),
                  const SizedBox(height: 14),

                  // Line 2
                  TextFormField(
                    controller: line2Ctrl,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                    decoration: _buildInputDecoration('Address Line 2 (Optional)', Icons.location_city_outlined, theme),
                  ),
                  const SizedBox(height: 14),

                  // Landmark
                  TextFormField(
                    controller: landmarkCtrl,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                    decoration: _buildInputDecoration('Landmark (Optional)', Icons.streetview_outlined, theme),
                  ),
                  const SizedBox(height: 14),

                  // City / District Row
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: cityCtrl,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                          decoration: _buildInputDecoration('City', Icons.map_outlined, theme),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: districtCtrl,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                          decoration: _buildInputDecoration('District', Icons.domain_outlined, theme),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // State / Pincode Row
                  Row(
                    children: [
                      Expanded(
                        child: _states.isEmpty
                            ? TextFormField(
                                controller: stateCtrl,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                                decoration: _buildInputDecoration('State', Icons.explore_outlined, theme),
                                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                              )
                            : DropdownButtonFormField<String>(
                                isExpanded: true,
                                value: _states.contains(stateCtrl.text) ? stateCtrl.text : null,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: AppColors.textPrimary),
                                items: _states.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    stateCtrl.text = val;
                                  }
                                },
                                decoration: _buildInputDecoration('State', Icons.explore_outlined, theme),
                                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                              ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: pincodeCtrl,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                          decoration: _buildInputDecoration('Pincode', Icons.pin_drop_outlined, theme),
                          validator: (v) => v == null || v.trim().length != 6 ? '6 Digits' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Country
                  TextFormField(
                    controller: countryCtrl,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                    decoration: _buildInputDecoration('Country', Icons.flag_outlined, theme),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 20),

                  // Modern Chip selection for address type
                  const Text(
                    'Address Type',
                    style: TextStyle(
                      fontSize: 14, 
                      fontWeight: FontWeight.bold, 
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: ['Home', 'Work', 'Other'].map((type) {
                      final bool isSelected = addressType.toLowerCase() == type.toLowerCase();
                      IconData typeIcon = Icons.home_rounded;
                      if (type == 'Work') typeIcon = Icons.business_rounded;
                      if (type == 'Other') typeIcon = Icons.location_on_rounded;

                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: ChoiceChip(
                            avatar: Icon(
                              typeIcon, 
                              color: isSelected ? Colors.white : AppColors.textLight, 
                              size: 16,
                            ),
                            label: Text(type),
                            selected: isSelected,
                            onSelected: (val) {
                              if (val) {
                                setModalState(() => addressType = type);
                              }
                            },
                            selectedColor: AppColors.primary,
                            backgroundColor: Colors.white,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
                              ),
                            ),
                            showCheckmark: false,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  SwitchListTile(
                    title: const Text('Set as Default Address', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
                    value: isDefault,
                    activeColor: AppColors.primary,
                    onChanged: (val) {
                      setModalState(() => isDefault = val);
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 28),

                  // Save Button with gradient
                  Container(
                    width: double.infinity,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.secondary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () {
                        if (!formKey.currentState!.validate()) return;

                        final List<Map<String, dynamic>> copy = List.from(_addresses);

                        final Map<String, dynamic> newAddress = {
                          "id": addressToEdit?['id'],
                          "address_line_1": line1Ctrl.text.trim(),
                          "address_line_2": line2Ctrl.text.trim(),
                          "landmark": landmarkCtrl.text.trim(),
                          "city": cityCtrl.text.trim(),
                          "district": districtCtrl.text.trim(),
                          "state": stateCtrl.text.trim(),
                          "country": countryCtrl.text.trim(),
                          "pincode": pincodeCtrl.text.trim(),
                          "address_type": addressType,
                          "is_default": isDefault ? 1 : 0
                        };

                        if (isDefault) {
                          for (var addr in copy) {
                            addr['is_default'] = 0;
                          }
                        }

                        if (editIndex != null) {
                          copy[editIndex] = newAddress;
                        } else {
                          copy.add(newAddress);
                        }

                        Navigator.pop(context);
                        _updateAddressesOnServer(copy);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('Save Address', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
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

  void _deleteAddress(int index) {
    if (_addresses.length <= 1) {
      _showSnackBar(
        'At least one address is required. Cannot delete.',
        AppColors.error,
        Icons.warning_rounded,
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Address', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to remove this address?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx), 
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isLoading = true);

              try {
                final targetAddress = _addresses[index];
                final int? addressId = int.tryParse(targetAddress['id']?.toString() ?? '');
                final bool wasDefault = targetAddress['is_default'].toString() == '1' || targetAddress['is_default'].toString() == 'true';

                if (addressId != null) {
                  final delResponse = await ApiService.deleteAddress(addressId, widget.token);
                  if (delResponse.statusCode != 200 && delResponse.statusCode != 201) {
                    debugPrint('Delete address API status: ${delResponse.statusCode}');
                  }
                }

                final List<Map<String, dynamic>> remaining = List.from(_addresses);
                remaining.removeAt(index);

                if (wasDefault && remaining.isNotEmpty) {
                  remaining[0]['is_default'] = 1;
                }

                await _updateAddressesOnServer(remaining);
              } catch (e) {
                debugPrint('Error deleting address: $e');
                setState(() => _isLoading = false);
                _showSnackBar('Error deleting address from database.', AppColors.error, Icons.warning_rounded);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
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

  Widget _buildAddNewAddressCard() {
    return GestureDetector(
      onTap: () => _showAddressDialog(),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.add_location_alt_rounded,
                  color: AppColors.primary,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Add New Address',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Add a shipping or billing address',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textLight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddressCard(Map<String, dynamic> addr, int index, bool isDesktop) {
    final isDefault = addr['is_default'].toString() == '1' || addr['is_default'].toString() == 'true';
    final String rawType = addr['address_type']?.toString().toLowerCase() ?? 'home';
    
    IconData typeIcon = Icons.home_rounded;
    Color typeColor = const Color(0xFF4F46E5); // Home Indigo
    Color typeBg = const Color(0xFFEEF2FF);
    
    if (rawType == 'work') {
      typeIcon = Icons.business_rounded;
      typeColor = const Color(0xFF16A34A); // Work Green
      typeBg = const Color(0xFFF0FDF4);
    } else if (rawType == 'other') {
      typeIcon = Icons.location_on_rounded;
      typeColor = const Color(0xFFE11D48); // Other Red
      typeBg = const Color(0xFFFFF1F2);
    }

    return GestureDetector(
      onTap: () => _setDefaultAddress(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: isDesktop ? EdgeInsets.zero : const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDefault ? const Color(0xFFFDF8F6) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDefault ? AppColors.primary : const Color(0xFFE2E8F0),
            width: isDefault ? 1.8 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: isDefault 
                  ? AppColors.primary.withOpacity(0.04) 
                  : Colors.black.withOpacity(0.015),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: typeBg,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(typeIcon, color: typeColor, size: 18),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          addr['address_type']?.toString().toUpperCase() ?? 'ADDRESS',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900, 
                            fontSize: 13,
                            color: AppColors.textPrimary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    if (isDefault)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.check_circle_rounded, color: Colors.white, size: 12),
                            SizedBox(width: 4),
                            Text(
                              'Default',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      const Text(
                        'Tap to Set Default',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
                const Divider(height: 24, color: Color(0xFFF1F5F9)),

                Text(
                  "${addr['address_line_1']}",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14.5, 
                    color: AppColors.textPrimary, 
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (addr['address_line_2'] != null && addr['address_line_2'].toString().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    "${addr['address_line_2']}",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                  ),
                ],
                if (addr['landmark'] != null && addr['landmark'].toString().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    "Landmark: ${addr['landmark']}",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12, 
                      color: AppColors.textLight, 
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  "${addr['city']}, ${addr['district']}, ${addr['state']} - ${addr['pincode']}",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13, 
                    color: AppColors.textSecondary, 
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "${addr['country']}",
                  style: const TextStyle(
                    fontSize: 12.5, 
                    color: AppColors.textLight,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),

            Column(
              children: [
                const Divider(height: 24, color: Color(0xFFF1F5F9)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    InkWell(
                      onTap: () => _showAddressDialog(addressToEdit: addr, editIndex: index),
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.edit_location_alt_rounded, size: 16, color: AppColors.primary),
                            SizedBox(width: 4),
                            Text(
                              'Edit',
                              style: TextStyle(
                                color: AppColors.primary, 
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    InkWell(
                      onTap: () => _deleteAddress(index),
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.delete_sweep_rounded, size: 16, color: AppColors.error),
                            SizedBox(width: 4),
                            Text(
                              'Delete',
                              style: TextStyle(
                                color: AppColors.error, 
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          'Manage Addresses',
          style: TextStyle(
            color: AppColors.textPrimary, 
            fontWeight: FontWeight.w900,
            fontSize: 20,
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_location_alt_rounded, color: AppColors.primary),
            tooltip: 'Add Address',
            onPressed: () => _showAddressDialog(),
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : _addresses.isEmpty
                ? _buildEmptyState()
                : (isDesktop
                    ? Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(40),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1000),
                            child: GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 450,
                                mainAxisExtent: 290,
                                crossAxisSpacing: 24,
                                mainAxisSpacing: 24,
                              ),
                              itemCount: _addresses.length + 1,
                              itemBuilder: (context, index) {
                                if (index == _addresses.length) {
                                  return CustomPaint(
                                    painter: DashedBorderPainter(color: const Color(0xFFCBD5E1)),
                                    child: _buildAddNewAddressCard(),
                                  );
                                }
                                return _buildAddressCard(_addresses[index], index, true);
                              },
                            ),
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        physics: const BouncingScrollPhysics(),
                        itemCount: _addresses.length,
                        itemBuilder: (context, index) {
                          return _buildAddressCard(_addresses[index], index, false);
                        },
                      )),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(26),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add_road_rounded, size: 60, color: AppColors.primary),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Address Found',
              style: TextStyle(
                fontWeight: FontWeight.w900, 
                color: AppColors.textPrimary, 
                fontSize: 18.5,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Please add shipping addresses to easily process checkouts and locate deliveries.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textLight, fontSize: 13.5, height: 1.45),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => _showAddressDialog(),
              icon: const Icon(Icons.add_location_alt_rounded, color: Colors.white, size: 18),
              label: const Text('Add Shipping Address', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
      labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: AppColors.textLight),
      floatingLabelStyle: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
      prefixIcon: Icon(icon, color: AppColors.textLight, size: 20),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
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

class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;
  final double radius;

  DashedBorderPainter({
    required this.color,
    this.strokeWidth = 1.5,
    this.gap = 5,
    this.radius = 20,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final RRect rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(radius),
    );

    final Path path = Path()..addRRect(rrect);
    final Path dashPath = Path();

    double distance = 0.0;
    for (PathMetric measurePath in path.computeMetrics()) {
      while (distance < measurePath.length) {
        dashPath.addPath(
          measurePath.extractPath(distance, distance + gap),
          Offset.zero,
        );
        distance += gap * 2;
      }
    }

    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

