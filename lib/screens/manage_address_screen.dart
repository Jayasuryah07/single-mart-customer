import 'dart:convert';
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
  bool _isLoadingStates = false;
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

          // Sync locally as well!
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
      debugPrint('Error fetching states: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingStates = false);
      }
    }
  }

  Future<void> _updateAddressesOnServer(List<Map<String, dynamic>> newAddressesList) async {
    setState(() => _isLoading = true);

    try {
      final int vendorId = _currentUserData['id'] is int 
          ? _currentUserData['id'] 
          : int.tryParse(_currentUserData['id']?.toString() ?? '0') ?? 0;

      // Prepare PUT body containing the entire profile payload alongside the new address list
      final Map<String, dynamic> body = {
        "name": _currentUserData['name']?.toString() ?? '',
        "owner_name": _currentUserData['owner_name']?.toString() ?? '',
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

        // Fetch the updated data from the server to show the latest state
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

  void _showAddressDialog({Map<String, dynamic>? addressToEdit, int? editIndex}) {
    final formKey = GlobalKey<FormState>();
    
    final line1Ctrl = TextEditingController(text: addressToEdit?['address_line_1']?.toString() ?? '');
    final line2Ctrl = TextEditingController(text: addressToEdit?['address_line_2']?.toString() ?? '');
    final landmarkCtrl = TextEditingController(text: addressToEdit?['landmark']?.toString() ?? '');
    final cityCtrl = TextEditingController(text: addressToEdit?['city']?.toString() ?? '');
    final districtCtrl = TextEditingController(text: addressToEdit?['district']?.toString() ?? '');
    final stateCtrl = TextEditingController(text: addressToEdit?['state']?.toString() ?? '');
    final countryCtrl = TextEditingController(text: addressToEdit?['country']?.toString() ?? 'India');
    final pincodeCtrl = TextEditingController(text: addressToEdit?['pincode']?.toString() ?? '');

    String addressType = 'Home';
    final List<String> types = ['Home', 'Work', 'Business', 'Shipping', 'Billing'];
    if (addressToEdit != null && addressToEdit['address_type'] != null) {
      final matched = types.firstWhere(
        (t) => t.toLowerCase() == addressToEdit['address_type'].toString().toLowerCase(),
        orElse: () => 'Home',
      );
      addressType = matched;
    }

    bool isDefault = false;
    final defaultVal = addressToEdit?['is_default'];
    if (defaultVal != null) {
      isDefault = defaultVal.toString() == '1' || defaultVal.toString() == 'true';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 24,
            left: 24,
            right: 24,
          ),
          child: SingleChildScrollView(
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
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: line1Ctrl,
                    decoration: const InputDecoration(labelText: 'Address Line 1', border: OutlineInputBorder()),
                    validator: (v) => v == null || v.isEmpty ? 'Required field' : null,
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: line2Ctrl,
                    decoration: const InputDecoration(labelText: 'Address Line 2 (Optional)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: landmarkCtrl,
                    decoration: const InputDecoration(labelText: 'Landmark (Optional)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: cityCtrl,
                          decoration: const InputDecoration(labelText: 'City', border: OutlineInputBorder()),
                          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: districtCtrl,
                          decoration: const InputDecoration(labelText: 'District', border: OutlineInputBorder()),
                          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: _states.isEmpty
                            ? TextFormField(
                                controller: stateCtrl,
                                decoration: const InputDecoration(labelText: 'State', border: OutlineInputBorder()),
                                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                              )
                            : DropdownButtonFormField<String>(
                                value: _states.contains(stateCtrl.text) ? stateCtrl.text : null,
                                items: _states.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    stateCtrl.text = val;
                                  }
                                },
                                decoration: const InputDecoration(labelText: 'State', border: OutlineInputBorder()),
                                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                              ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: pincodeCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Pincode', border: OutlineInputBorder()),
                          validator: (v) => v == null || v.length != 6 ? '6 Digits' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: countryCtrl,
                    decoration: const InputDecoration(labelText: 'Country', border: OutlineInputBorder()),
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<String>(
                    value: addressType,
                    items: types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() => addressType = val);
                      }
                    },
                    decoration: const InputDecoration(labelText: 'Address Type', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),

                  SwitchListTile(
                    title: const Text('Set as Default Address', style: TextStyle(fontWeight: FontWeight.bold)),
                    value: isDefault,
                    onChanged: (val) {
                      setModalState(() => isDefault = val);
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
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
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Save Address', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 24),
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
        title: const Text('Delete Address'),
        content: const Text('Are you sure you want to remove this address?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isLoading = true);

              try {
                final targetAddress = _addresses[index];
                final int? addressId = int.tryParse(targetAddress['id']?.toString() ?? '');
                final bool wasDefault = targetAddress['is_default'].toString() == '1' || targetAddress['is_default'].toString() == 'true';

                // Call DELETE endpoint if address has a valid ID
                if (addressId != null) {
                  final delResponse = await ApiService.deleteAddress(addressId, widget.token);
                  if (delResponse.statusCode != 200 && delResponse.statusCode != 201) {
                    debugPrint('Delete address API status: ${delResponse.statusCode}');
                  }
                }

                // Construct remaining address list
                final List<Map<String, dynamic>> remaining = List.from(_addresses);
                remaining.removeAt(index);

                // Auto-set another one to default if we just deleted the default address
                if (wasDefault && remaining.isNotEmpty) {
                  remaining[0]['is_default'] = 1;
                }

                // Synchronize remaining list via vendor update payload
                await _updateAddressesOnServer(remaining);
              } catch (e) {
                debugPrint('Error deleting address: $e');
                setState(() => _isLoading = false);
                _showSnackBar('Error deleting address from database.', AppColors.error, Icons.warning_rounded);
              }
            },
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFFAFBFD),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: const Text(
          'Manage Addresses',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_location_alt_rounded, color: AppColors.primary),
            onPressed: () => _showAddressDialog(),
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _addresses.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _addresses.length,
                    itemBuilder: (context, index) {
                      final addr = _addresses[index];
                      final isDefault = addr['is_default'].toString() == '1' || addr['is_default'].toString() == 'true';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDefault ? theme.colorScheme.primary : AppColors.border,
                            width: isDefault ? 2.0 : 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.01),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      addr['address_type']?.toString().toLowerCase() == 'home' 
                                          ? Icons.home_rounded 
                                          : Icons.business_rounded,
                                      color: isDefault ? theme.colorScheme.primary : AppColors.textLight,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      addr['address_type']?.toString() ?? 'Address',
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                    ),
                                  ],
                                ),
                                if (isDefault)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Default',
                                      style: TextStyle(
                                        color: theme.colorScheme.primary,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const Divider(height: 20),

                            Text(
                              "${addr['address_line_1']}",
                              style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                            ),
                            if (addr['address_line_2'] != null && addr['address_line_2'].toString().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                "${addr['address_line_2']}",
                                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                              ),
                            ],
                            if (addr['landmark'] != null && addr['landmark'].toString().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                "Landmark: ${addr['landmark']}",
                                style: const TextStyle(fontSize: 12, color: AppColors.textLight, fontStyle: FontStyle.italic),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Text(
                              "${addr['city']}, ${addr['district']}, ${addr['state']} - ${addr['pincode']}",
                              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                            ),
                            Text(
                              "${addr['country']}",
                              style: const TextStyle(fontSize: 13, color: AppColors.textLight),
                            ),

                            const Divider(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  onPressed: () => _showAddressDialog(addressToEdit: addr, editIndex: index),
                                  icon: const Icon(Icons.edit_location_alt_rounded, size: 16),
                                  label: const Text('Edit'),
                                ),
                                const SizedBox(width: 8),
                                TextButton.icon(
                                  onPressed: () => _deleteAddress(index),
                                  icon: const Icon(Icons.delete_sweep_rounded, size: 16, color: AppColors.error),
                                  label: const Text('Delete', style: TextStyle(color: AppColors.error)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
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
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.border.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add_road_rounded, size: 54, color: AppColors.textLight),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Address Configured',
              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 18),
            ),
            const SizedBox(height: 8),
            const Text(
              'Specify shipping or store location coordinates to facilitate order operations.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textLight, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showAddressDialog(),
              icon: const Icon(Icons.add_location_alt_rounded, color: Colors.white),
              label: const Text('Add Address Now', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
