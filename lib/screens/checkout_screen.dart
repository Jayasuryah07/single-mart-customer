import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../theme.dart';
import 'manage_address_screen.dart';

class CheckoutScreen extends StatefulWidget {
  final List<Map<String, dynamic>> cartItems;
  final String token;

  const CheckoutScreen({
    super.key,
    required this.cartItems,
    required this.token,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  Map<String, dynamic>? _userData;
  Map<String, dynamic>? _defaultAddress;
  final Map<int, Map<String, dynamic>> _vendorsData = {};
  
  // Split payment inputs per vendor
  final Map<int, String> _utrByVendor = {};
  final Map<int, File?> _screenshotFileByVendor = {};
  final Map<int, String> _screenshotBase64ByVendor = {};

  // Track expanded state per merchant
  final Map<int, bool> _expandedByVendor = {};
  
  bool _isLoadingProfile = true;
  bool _isLoadingVendors = false;
  bool _isSubmittingOrder = false;
  
  final TextEditingController _remarksController = TextEditingController();

  String _baseNoImageUrl = 'https://agsdemo.in/singlemartapi/public/assets/images/no_image.jpg';
  String _baseProductImageUrl = 'https://agsdemo.in/singlemartapi/public/assets/images/product_images/';
  String _baseProductVariantImageUrl = 'https://agsdemo.in/singlemartapi/public/assets/images/product_variant_images/';

  @override
  void initState() {
    super.initState();
    _loadProfile().then((_) {
      _loadAllVendorsDetails();
    });
  }

  @override
  void dispose() {
    _remarksController.dispose();
    super.dispose();
  }

  // Group cart items by vendor ID
  Map<int, List<Map<String, dynamic>>> _groupCartItemsByVendor() {
    final Map<int, List<Map<String, dynamic>>> groups = {};
    for (var item in widget.cartItems) {
      final vIdRaw = item['product_vendor_id'] ?? item['vendor_id'] ?? item['created_by'] ?? 0;
      final int vId = vIdRaw is int ? vIdRaw : int.tryParse(vIdRaw.toString()) ?? 0;
      if (!groups.containsKey(vId)) {
        groups[vId] = [];
      }
      groups[vId]!.add(item);
    }
    return groups;
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoadingProfile = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      _baseNoImageUrl = prefs.getString('base_no_image_url') ?? _baseNoImageUrl;
      _baseProductImageUrl = prefs.getString('base_product_image_url') ?? _baseProductImageUrl;
      _baseProductVariantImageUrl = prefs.getString('base_product_variant_image_url') ?? _baseProductVariantImageUrl;

      final String? userDataStr = prefs.getString('user_data');
      if (userDataStr != null && userDataStr.isNotEmpty) {
        final localData = json.decode(userDataStr);
        final int vendorId = localData['id'] is int 
            ? localData['id'] 
            : int.tryParse(localData['id']?.toString() ?? '0') ?? 0;

        // Fetch latest profile & addresses from server
        final response = await ApiService.fetchVendor(vendorId, widget.token);
        if (response.statusCode == 200) {
          final resData = json.decode(response.body);
          final dynamic profileData = resData['data'];
          if (profileData != null) {
            final Map<String, dynamic> parsedProfile = Map<String, dynamic>.from(profileData);
            
            // Fix addresses property names
            final addressList = parsedProfile['addresses'] ?? parsedProfile['address'];
            if (addressList != null) {
              parsedProfile['addresses'] = addressList;
              parsedProfile['address'] = addressList;
            }

            await prefs.setString('user_data', json.encode(parsedProfile));
            _userData = parsedProfile;
          }
        } else {
          _userData = localData;
        }
      }

      // Identify the default address
      _findDefaultAddress();

      // Fetch active catalog to populate vendor ID, variant ID, and original_price for all cart items
      try {
        final productsResponse = await ApiService.fetchActiveProducts();
        if (productsResponse.statusCode == 200) {
          final body = json.decode(productsResponse.body);
          final List<dynamic> allProds = body['data'] ?? [];
          for (var item in widget.cartItems) {
            final matched = allProds.firstWhere(
              (p) => p['id']?.toString() == item['id']?.toString(),
              orElse: () => null,
            );
            if (matched != null) {
              if (item['product_vendor_id'] == null && item['vendor_id'] == null && item['created_by'] == null) {
                item['product_vendor_id'] = matched['product_vendor_id'];
              }
              final bool hasVars = (matched['has_variants'] == 1 || matched['has_variants'] == '1') &&
                  matched['variants'] != null && (matched['variants'] as List).isNotEmpty;

              dynamic matchedVar;
              if (hasVars) {
                final varId = item['variant_id'] ?? item['order_product_variant_id'];
                if (varId != null) {
                  matchedVar = (matched['variants'] as List).firstWhere(
                    (v) => v['id']?.toString() == varId.toString(),
                    orElse: () => null,
                  );
                } else {
                  matchedVar = matched['variants'][0];
                  final firstVarId = matchedVar['id'];
                  item['variant_id'] = firstVarId;
                  item['order_product_variant_id'] = firstVarId;
                  item['is_variant'] = true;
                }
              }

              if (item['original_price'] == null || (double.tryParse(item['original_price']?.toString() ?? '') ?? 0.0) == 0) {
                if (matchedVar != null) {
                  final double discP = double.tryParse(matchedVar['product_discount_price']?.toString() ?? '') ?? 0.0;
                  final double regP = double.tryParse(matchedVar['product_price']?.toString() ?? '') ?? 0.0;
                  if (discP > 0 && regP > discP) {
                    item['original_price'] = regP;
                  } else if (regP > (double.tryParse(item['price']?.toString() ?? '') ?? 0.0)) {
                    item['original_price'] = regP;
                  }
                } else {
                  final double discP = double.tryParse(matched['product_discount_price']?.toString() ?? '') ?? 0.0;
                  final double regP = double.tryParse(matched['product_price']?.toString() ?? '') ?? 0.0;
                  if (discP > 0 && regP > discP) {
                    item['original_price'] = regP;
                  } else if (regP > (double.tryParse(item['price']?.toString() ?? '') ?? 0.0)) {
                    item['original_price'] = regP;
                  }
                }
              }
            }
          }
        }
      } catch (e) {
        debugPrint("Error fetching active products on checkout: $e");
      }
    } catch (e) {
      debugPrint("Error loading profile on checkout: $e");
    } finally {
      setState(() => _isLoadingProfile = false);
    }
  }

  void _findDefaultAddress() {
    if (_userData == null) return;
    final dynamic addressesRaw = _userData!['addresses'] ?? _userData!['address'];
    if (addressesRaw != null && addressesRaw is List && addressesRaw.isNotEmpty) {
      final List<Map<String, dynamic>> addressList = List<Map<String, dynamic>>.from(
        addressesRaw.map((item) => Map<String, dynamic>.from(item))
      );
      
      // Look for address where is_default is 1 or '1' or true
      final found = addressList.firstWhere(
        (addr) => addr['is_default']?.toString() == '1' || addr['is_default'] == true,
        orElse: () => addressList.first,
      );
      _defaultAddress = found;
    } else {
      _defaultAddress = null;
    }
  }

  Future<void> _loadAllVendorsDetails() async {
    final Map<int, List<Map<String, dynamic>>> grouped = _groupCartItemsByVendor();
    final List<int> vendorIds = grouped.keys.where((id) => id != 0).toList();
    if (vendorIds.isEmpty) return;

    setState(() => _isLoadingVendors = true);
    final Map<int, Map<String, dynamic>> loadedData = {};

    try {
      await Future.wait(vendorIds.map((vId) async {
        try {
          final response = await ApiService.fetchVendor(vId, widget.token);
          if (response.statusCode == 200) {
            final resData = json.decode(response.body);
            if (resData['data'] != null) {
              loadedData[vId] = Map<String, dynamic>.from(resData['data']);
            }
          }
        } catch (e) {
          debugPrint("Error fetching details for vendor $vId: $e");
        }
      }));

      setState(() {
        _vendorsData.addAll(loadedData);
        // Expand the first merchant panel by default
        if (vendorIds.isNotEmpty) {
          _expandedByVendor[vendorIds.first] = true;
        }
        for (var vId in grouped.keys) {
          _utrByVendor[vId] = _utrByVendor[vId] ?? '';
          _screenshotFileByVendor[vId] = _screenshotFileByVendor[vId];
          _screenshotBase64ByVendor[vId] = _screenshotBase64ByVendor[vId] ?? '';
        }
      });
    } catch (e) {
      debugPrint("Error fetching vendor details: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoadingVendors = false);
      }
    }
  }

  Future<void> _pickScreenshot(int vendorId) async {
    final ImagePicker picker = ImagePicker();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext ctx) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
                title: const Text('Choose from Gallery'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final XFile? file = await picker.pickImage(
                    source: ImageSource.gallery,
                    imageQuality: 50,
                  );
                  if (file != null) {
                    final bytes = await File(file.path).readAsBytes();
                    setState(() {
                      _screenshotFileByVendor[vendorId] = File(file.path);
                      _screenshotBase64ByVendor[vendorId] = base64Encode(bytes);
                    });
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: AppColors.primary),
                title: const Text('Take a Photo'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final XFile? file = await picker.pickImage(
                    source: ImageSource.camera,
                    imageQuality: 50,
                  );
                  if (file != null) {
                    final bytes = await File(file.path).readAsBytes();
                    setState(() {
                      _screenshotFileByVendor[vendorId] = File(file.path);
                      _screenshotBase64ByVendor[vendorId] = base64Encode(bytes);
                    });
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatAddress(Map<String, dynamic> addr) {
    final List<String> parts = [];
    if (addr['address_line_1'] != null && addr['address_line_1'].toString().trim().isNotEmpty) {
      parts.add('"${addr['address_line_1'].toString().trim()}"');
    }
    if (addr['address_line_2'] != null && addr['address_line_2'].toString().trim().isNotEmpty) {
      parts.add('"${addr['address_line_2'].toString().trim()}"');
    }
    if (addr['landmark'] != null && addr['landmark'].toString().trim().isNotEmpty) {
      parts.add('"${addr['landmark'].toString().trim()}"');
    }
    if (addr['city'] != null && addr['city'].toString().trim().isNotEmpty) {
      parts.add('"${addr['city'].toString().trim()}"');
    }
    if (addr['district'] != null && addr['district'].toString().trim().isNotEmpty) {
      parts.add('"${addr['district'].toString().trim()}"');
    }
    
    // Combine state and pincode as state-pincode e.g., "KARNATAKA-868588"
    final String state = addr['state']?.toString().trim() ?? '';
    final String pincode = addr['pincode']?.toString().trim() ?? '';
    if (state.isNotEmpty && pincode.isNotEmpty) {
      parts.add('"$state-$pincode"');
    } else if (state.isNotEmpty) {
      parts.add('"$state"');
    } else if (pincode.isNotEmpty) {
      parts.add('"$pincode"');
    }

    if (addr['country'] != null && addr['country'].toString().trim().isNotEmpty) {
      parts.add('"${addr['country'].toString().trim()}"');
    }

    return parts.join(',');
  }

  double _getCartTotal() {
    double total = 0.0;
    for (var item in widget.cartItems) {
      total += (item['price'] as double) * (item['quantity'] as int);
    }
    return total;
  }

  bool _areAllPaymentsDone() {
    final Map<int, List<Map<String, dynamic>>> grouped = _groupCartItemsByVendor();
    for (var vendorId in grouped.keys) {
      final utr = _utrByVendor[vendorId];
      final screenshot = _screenshotFileByVendor[vendorId];
      if (utr == null || utr.trim().isEmpty || screenshot == null) {
        return false;
      }
    }
    return true;
  }

  Future<void> _placeOrder() async {
    if (_defaultAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please add a delivery address to place your order."),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (!_areAllPaymentsDone()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please upload UTR and payment screenshot for all sellers."),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSubmittingOrder = true);

    try {
      final formattedAddress = _formatAddress(_defaultAddress!);
      
      final response = await ApiService.createOrder(
        address: formattedAddress,
        remarks: _remarksController.text.trim(),
        cartItems: widget.cartItems,
        utrByVendor: _utrByVendor,
        screenshotFileByVendor: _screenshotFileByVendor,
        token: widget.token,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Clear local cart
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('cart_data');
        
        if (mounted) {
          _showOrderSuccessDialog();
        }
      } else {
        final errorMsg = json.decode(response.body)['message'] ?? "Failed to place order. Please try again.";
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMsg), backgroundColor: AppColors.error),
          );
        }
      }
    } catch (e) {
      debugPrint("Error placing order: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Network error placing order. Please try again."),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmittingOrder = false);
    }
  }

  void _showOrderSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_outline_rounded,
                  color: Colors.green,
                  size: 60,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Order Success!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Your order was placed successfully. Thank you for shopping with SingleMart!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.textLight, height: 1.4),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx); // Close dialog
                    Navigator.pop(context, true); // Pop to cart with success flag
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    'Go to Dashboard',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _redirectToManageAddress() async {
    if (_userData == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ManageAddressScreen(
          userData: _userData!,
          token: widget.token,
        ),
      ),
    );
    _loadProfile();
  }

  void _showFullQRCode(String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: const Text('QR Code Payment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              backgroundColor: Colors.transparent,
              elevation: 0,
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textPrimary),
                  onPressed: () => Navigator.pop(ctx),
                )
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 24, right: 24, bottom: 24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 200,
                      color: AppColors.border.withOpacity(0.3),
                      child: const Center(
                        child: Icon(Icons.broken_image, color: AppColors.textMuted, size: 40),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalAmount = _getCartTotal();
    final groupedCart = _groupCartItemsByVendor();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Checkout',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w900,
            fontSize: 20,
            letterSpacing: 0.3,
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: AppColors.border,
            height: 1.0,
          ),
        ),
      ),
      body: _isLoadingProfile
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Reference Details card
                  _buildSectionHeader('User Details'),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.01),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor: Color(0xFFF1F5F9),
                          radius: 20,
                          child: Icon(Icons.person_rounded, color: AppColors.textLight, size: 20),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _userData?['name'] ?? 'Guest User',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _userData?['mobile'] != null && _userData!['mobile'].toString().isNotEmpty
                                    ? '+91 ${_userData!['mobile']}'
                                    : 'No Phone Provided',
                                style: const TextStyle(fontSize: 13, color: AppColors.textLight, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 2. Shipping Address Card
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionHeader('Delivery Address'),
                      TextButton.icon(
                        onPressed: _redirectToManageAddress,
                        icon: Icon(
                          _defaultAddress != null ? Icons.edit_location_alt_rounded : Icons.add_location_alt_rounded,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                        label: Text(
                          _defaultAddress != null ? 'Change' : 'Add',
                          style: TextStyle(fontWeight: FontWeight.w900, color: theme.colorScheme.primary, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.01),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: _defaultAddress == null
                        ? Column(
                            children: [
                              const Icon(Icons.location_off_rounded, size: 40, color: AppColors.textMuted),
                              const SizedBox(height: 8),
                              const Text('No delivery addresses added yet.', style: TextStyle(color: AppColors.textLight, fontSize: 14)),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: _redirectToManageAddress,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.colorScheme.primary.withOpacity(0.08),
                                  foregroundColor: theme.colorScheme.primary,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: const Text('Manage Addresses', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          _defaultAddress!['address_type']?.toString().toLowerCase() == 'home'
                                              ? Icons.home_rounded
                                              : (_defaultAddress!['address_type']?.toString().toLowerCase() == 'office' || _defaultAddress!['address_type']?.toString().toLowerCase() == 'work')
                                                  ? Icons.business_rounded
                                                  : Icons.location_on_rounded,
                                          color: theme.colorScheme.primary,
                                          size: 14,
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          (_defaultAddress!['address_type']?.toString().toUpperCase() ?? 'HOME'),
                                          style: TextStyle(color: theme.colorScheme.primary, fontSize: 10, fontWeight: FontWeight.w900),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text('Default Address', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w700)),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.location_on_outlined,
                                    color: AppColors.textLight,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _defaultAddress!['address_line_1']?.toString().trim() ?? '',
                                          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                        ),
                                        if (_defaultAddress!['address_line_2'] != null && _defaultAddress!['address_line_2'].toString().trim().isNotEmpty) ...[
                                          const SizedBox(height: 3),
                                          Text(
                                            _defaultAddress!['address_line_2']?.toString().trim() ?? '',
                                            style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                                          ),
                                        ],
                                        if (_defaultAddress!['landmark'] != null && _defaultAddress!['landmark'].toString().trim().isNotEmpty) ...[
                                          const SizedBox(height: 3),
                                          Text(
                                            'Landmark: ${_defaultAddress!['landmark']?.toString().trim()}',
                                            style: const TextStyle(fontSize: 13, color: AppColors.textLight, fontStyle: FontStyle.italic),
                                          ),
                                        ],
                                        const SizedBox(height: 6),
                                        Text(
                                          '${_defaultAddress!['city'] ?? ''}, ${_defaultAddress!['district'] ?? ''}, ${_defaultAddress!['state'] ?? ''} - ${_defaultAddress!['pincode'] ?? ''}',
                                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                                        ),
                                        if (_defaultAddress!['country'] != null && _defaultAddress!['country'].toString().trim().isNotEmpty) ...[
                                          const SizedBox(height: 3),
                                          Text(
                                            _defaultAddress!['country']?.toString().trim() ?? '',
                                            style: const TextStyle(fontSize: 13, color: AppColors.textLight, fontWeight: FontWeight.w500),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 24),

                  // 3. Split Payment Cards grouped by Vendor (Expandable Accordion)
                  _buildSectionHeader('Split Payments by Merchant'),
                  const SizedBox(height: 8),
                  _isLoadingVendors
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 24.0),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: groupedCart.keys.length,
                          itemBuilder: (context, idx) {
                            final vendorId = groupedCart.keys.elementAt(idx);
                            final vendorItems = groupedCart[vendorId]!;
                            final merchant = _vendorsData[vendorId];

                            // Calculate subtotal for this specific vendor
                            double vendorSubtotal = 0.0;
                            for (var item in vendorItems) {
                              vendorSubtotal += (item['price'] as double) * (item['quantity'] as int);
                            }

                            final hasUtr = _utrByVendor[vendorId]?.isNotEmpty ?? false;
                            final hasScreenshot = _screenshotFileByVendor[vendorId] != null;
                            final isPayDetailsComplete = hasUtr && hasScreenshot;

                            final isExpanded = _expandedByVendor[vendorId] ?? false;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isExpanded ? theme.colorScheme.primary.withOpacity(0.5) : const Color(0xFFE2E8F0),
                                  width: isExpanded ? 1.5 : 1.0,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.015),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Expandable Accordion Header Tap target
                                  InkWell(
                                    onTap: () {
                                      setState(() {
                                        _expandedByVendor[vendorId] = !isExpanded;
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(15),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            backgroundColor: isExpanded ? theme.colorScheme.primary.withOpacity(0.12) : const Color(0xFFF1F5F9),
                                            radius: 18,
                                            child: Icon(
                                              Icons.storefront_rounded,
                                              color: isExpanded ? theme.colorScheme.primary : AppColors.textLight,
                                              size: 18,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  merchant?['name'] ?? 'Merchant ($vendorId)',
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  '${vendorItems.length} items  •  ₹${vendorSubtotal.toStringAsFixed(0)}',
                                                  style: const TextStyle(fontSize: 11.5, color: AppColors.textLight, fontWeight: FontWeight.w600),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          
                                          // Status Indicator Badge
                                          // Container(
                                          //   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          //   decoration: BoxDecoration(
                                          //     color: isPayDetailsComplete ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
                                          //     borderRadius: BorderRadius.circular(8),
                                          //   ),
                                          //   child: Row(
                                          //     mainAxisSize: MainAxisSize.min,
                                          //     children: [
                                          //       Icon(
                                          //         isPayDetailsComplete ? Icons.check_circle_rounded : Icons.pending_rounded,
                                          //         color: isPayDetailsComplete ? const Color(0xFF2E7D32) : const Color(0xFFEF6C00),
                                          //         size: 12,
                                          //       ),
                                          //       const SizedBox(width: 4),
                                          //       Text(
                                          //         isPayDetailsComplete ? 'Ready' : 'Pending',
                                          //         style: TextStyle(
                                          //           fontSize: 10,
                                          //           fontWeight: FontWeight.w900,
                                          //           color: isPayDetailsComplete ? const Color(0xFF2E7D32) : const Color(0xFFEF6C00),
                                          //         ),
                                          //       ),
                                          //     ],
                                          //   ),
                                          // ),
                                          const SizedBox(width: 8),
                                          Icon(
                                            isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                            color: AppColors.textMuted,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  // Expanded Details Pane
                                  if (isExpanded) ...[
                                    Container(
                                      height: 1.0,
                                      color: const Color(0xFFF1F5F9),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Merchant details
                                          if (merchant?['owner_name'] != null || merchant?['mobile'] != null) ...[
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                if (merchant?['owner_name'] != null)
                                                  Text(
                                                    'Owner: ${merchant!['owner_name']}',
                                                    style: const TextStyle(fontSize: 12, color: AppColors.textLight, fontWeight: FontWeight.w500),
                                                  ),
                                                if (merchant?['mobile'] != null)
                                                  Text(
                                                    'Ph: +91 ${merchant!['mobile']}',
                                                    style: const TextStyle(fontSize: 12, color: AppColors.textLight, fontWeight: FontWeight.w500),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                          ],

                                          // Vendor items list
                                          const Text('Items list:', style: TextStyle(fontSize: 11.5, color: AppColors.textLight, fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 6),
                                          ...vendorItems.map((item) {
                                            final String? imgFile = item['product_image']?.toString();
                                            final String imgUrl = (imgFile != null && imgFile.isNotEmpty)
                                                ? ((item['is_variant'] == true || item['variant_id'] != null)
                                                    ? '${_baseProductVariantImageUrl}$imgFile'
                                                    : '${_baseProductImageUrl}$imgFile')
                                                : _baseNoImageUrl;

                                            final double origP = _getItemOriginalPrice(item);
                                            final double currentP = (item['price'] is num ? item['price'] : double.tryParse(item['price']?.toString() ?? '0') ?? 0.0);

                                            return Padding(
                                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                                              child: Row(
                                                children: [
                                                  Container(
                                                    width: 36,
                                                    height: 36,
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFFF1F5F9),
                                                      borderRadius: BorderRadius.circular(8),
                                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                                    ),
                                                    child: ClipRRect(
                                                      borderRadius: BorderRadius.circular(7),
                                                      child: Image.network(
                                                        imgUrl,
                                                        fit: BoxFit.contain,
                                                        errorBuilder: (context, error, stackTrace) =>
                                                            const Icon(Icons.shopping_bag_outlined, size: 16, color: AppColors.textMuted),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          item['name'] ?? 'Product',
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                          style: const TextStyle(fontSize: 12.5, color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                                                        ),
                                                        const SizedBox(height: 2),
                                                        Text(
                                                          'Qty: ${item['quantity']}',
                                                          style: const TextStyle(fontSize: 11, color: AppColors.textLight, fontWeight: FontWeight.w500),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Column(
                                                    crossAxisAlignment: CrossAxisAlignment.end,
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: [
                                                      Text(
                                                        '₹${(currentP * (item['quantity'] as int)).toStringAsFixed(0)}',
                                                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                                                      ),
                                                      if (origP > currentP) ...[
                                                        const SizedBox(height: 2),
                                                        Text(
                                                          '₹${(origP * (item['quantity'] as int)).toStringAsFixed(0)}',
                                                          style: const TextStyle(
                                                            fontSize: 10.5,
                                                            color: AppColors.textMuted,
                                                            fontWeight: FontWeight.w500,
                                                            decoration: TextDecoration.lineThrough,
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                          const SizedBox(height: 14),

                                          // Payment credentials (UPI & QR Code)
                                          if (merchant != null) ...[
                                            const Text('Transfer Payment details:', style: TextStyle(fontSize: 11.5, color: AppColors.textLight, fontWeight: FontWeight.bold)),
                                            const SizedBox(height: 10),
                                            
                                            // UPI ID
                                            if (merchant['upi_id'] != null && merchant['upi_id'].toString().trim().isNotEmpty) ...[
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFF8FAFC),
                                                  borderRadius: BorderRadius.circular(10),
                                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                                ),
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          const Text('Merchant UPI ID', style: TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                                                          const SizedBox(height: 2),
                                                          Text(
                                                            merchant['upi_id'],
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    GestureDetector(
                                                      onTap: () {
                                                        Clipboard.setData(ClipboardData(text: merchant['upi_id'])).then((_) {
                                                          ScaffoldMessenger.of(context).showSnackBar(
                                                            const SnackBar(
                                                              content: Text('UPI ID copied!'),
                                                              duration: Duration(seconds: 1),
                                                            ),
                                                          );
                                                        });
                                                      },
                                                      child: Container(
                                                        padding: const EdgeInsets.all(6),
                                                        decoration: BoxDecoration(
                                                          color: theme.colorScheme.primary.withOpacity(0.08),
                                                          shape: BoxShape.circle,
                                                        ),
                                                        child: Icon(Icons.copy_rounded, color: theme.colorScheme.primary, size: 14),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                            ],

                                            // QR Code Scan Button & Preview
                                            if (merchant['qr_code'] != null && merchant['qr_code'].toString().trim().isNotEmpty) ...[
                                              Center(
                                                child: GestureDetector(
                                                  onTap: () {
                                                    _showFullQRCode(
                                                      "https://agsdemo.in/singlemartapi/public/assets/images/user_images/${merchant['qr_code']}"
                                                    );
                                                  },
                                                  child: Stack(
                                                    alignment: Alignment.center,
                                                    children: [
                                                      Container(
                                                        padding: const EdgeInsets.all(6),
                                                        decoration: BoxDecoration(
                                                          border: Border.all(color: const Color(0xFFE2E8F0)),
                                                          borderRadius: BorderRadius.circular(12),
                                                          color: Colors.white,
                                                        ),
                                                        child: ClipRRect(
                                                          borderRadius: BorderRadius.circular(8),
                                                          child: Image.network(
                                                            "https://agsdemo.in/singlemartapi/public/assets/images/user_images/${merchant['qr_code']}",
                                                            width: 90,
                                                            height: 90,
                                                            fit: BoxFit.cover,
                                                            errorBuilder: (context, error, stackTrace) {
                                                              return Container(
                                                                width: 90,
                                                                height: 90,
                                                                color: const Color(0xFFF1F5F9),
                                                                child: const Center(
                                                                  child: Icon(Icons.broken_image_rounded, color: AppColors.textMuted, size: 24),
                                                                ),
                                                              );
                                                            },
                                                          ),
                                                        ),
                                                      ),
                                                      Positioned(
                                                        bottom: 4,
                                                        right: 4,
                                                        child: Container(
                                                          padding: const EdgeInsets.all(4),
                                                          decoration: const BoxDecoration(
                                                            color: Colors.white,
                                                            shape: BoxShape.circle,
                                                            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 2)],
                                                          ),
                                                          child: Icon(Icons.fullscreen_rounded, color: theme.colorScheme.primary, size: 14),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                            ],

                                            // GST or PAN numbers (styled details)
                                            if ((merchant['gst_number'] != null && merchant['gst_number'].toString().trim().isNotEmpty) ||
                                                (merchant['pan_number'] != null && merchant['pan_number'].toString().trim().isNotEmpty)) ...[
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFF8FAFC),
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: Column(
                                                  children: [
                                                    if (merchant['gst_number'] != null && merchant['gst_number'].toString().trim().isNotEmpty)
                                                      Padding(
                                                        padding: const EdgeInsets.symmetric(vertical: 4),
                                                        child: Row(
                                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                          children: [
                                                            const Text('GST Number', style: TextStyle(fontSize: 11.5, color: AppColors.textLight, fontWeight: FontWeight.w500)),
                                                            Text(merchant['gst_number'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: AppColors.textPrimary)),
                                                          ],
                                                        ),
                                                      ),
                                                    if (merchant['pan_number'] != null && merchant['pan_number'].toString().trim().isNotEmpty)
                                                      Padding(
                                                        padding: const EdgeInsets.symmetric(vertical: 4),
                                                        child: Row(
                                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                          children: [
                                                            const Text('PAN Number', style: TextStyle(fontSize: 11.5, color: AppColors.textLight, fontWeight: FontWeight.w500)),
                                                            Text(merchant['pan_number'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: AppColors.textPrimary)),
                                                          ],
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(height: 16),
                                            ],
                                          ],

                                          // Payment Verification Inputs
                                          const Text('Payment Verification:', style: TextStyle(fontSize: 11.5, color: AppColors.textLight, fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 10),

                                          // UTR TextFormField
                                          TextFormField(
                                            initialValue: _utrByVendor[vendorId],
                                            onChanged: (val) {
                                              setState(() {
                                                _utrByVendor[vendorId] = val;
                                              });
                                            },
                                            decoration: InputDecoration(
                                              labelText: 'Transaction UTR / Ref Number',
                                              labelStyle: const TextStyle(fontSize: 12, color: AppColors.textLight, fontWeight: FontWeight.w500),
                                              hintText: 'Enter 12-digit payment reference',
                                              hintStyle: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                                              prefixIcon: Icon(Icons.receipt_long_rounded, color: theme.colorScheme.primary, size: 18),
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                              fillColor: const Color(0xFFF8FAFC),
                                              filled: true,
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(12),
                                                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                              ),
                                              enabledBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(12),
                                                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(12),
                                                borderSide: BorderSide(color: theme.colorScheme.primary.withOpacity(0.5), width: 1.5),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 14),

                                          // Custom Dashed Screenshot Uploader Box
                                          GestureDetector(
                                            onTap: () => _pickScreenshot(vendorId),
                                            child: Container(
                                              height: 90,
                                              width: double.infinity,
                                              child: CustomPaint(
                                                painter: DashedBorderPainter(
                                                  color: _screenshotFileByVendor[vendorId] != null ? theme.colorScheme.primary.withOpacity(0.5) : const Color(0xFFCBD5E1),
                                                ),
                                                child: ClipRRect(
                                                  borderRadius: BorderRadius.circular(12),
                                                  child: _screenshotFileByVendor[vendorId] != null
                                                      ? Stack(
                                                          children: [
                                                            Positioned.fill(
                                                              child: Image.file(
                                                                _screenshotFileByVendor[vendorId]!,
                                                                fit: BoxFit.cover,
                                                              ),
                                                            ),
                                                            // Semi-transparent overlay to clear
                                                            Positioned(
                                                              top: 8,
                                                              right: 8,
                                                              child: GestureDetector(
                                                                onTap: () {
                                                                  setState(() {
                                                                    _screenshotFileByVendor[vendorId] = null;
                                                                    _screenshotBase64ByVendor[vendorId] = '';
                                                                  });
                                                                },
                                                                child: Container(
                                                                  padding: const EdgeInsets.all(4),
                                                                  decoration: const BoxDecoration(
                                                                    color: Colors.black54,
                                                                    shape: BoxShape.circle,
                                                                  ),
                                                                  child: const Icon(
                                                                    Icons.close_rounded,
                                                                    color: Colors.white,
                                                                    size: 14,
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        )
                                                      : Center(
                                                          child: Column(
                                                            mainAxisAlignment: MainAxisAlignment.center,
                                                            children: [
                                                              Icon(
                                                                Icons.cloud_upload_outlined,
                                                                color: theme.colorScheme.primary,
                                                                size: 26,
                                                              ),
                                                              const SizedBox(height: 6),
                                                              const Text(
                                                                'Upload Transfer Screenshot / Receipt',
                                                                style: TextStyle(
                                                                  fontSize: 11.5,
                                                                  fontWeight: FontWeight.bold,
                                                                  color: AppColors.textSecondary,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                  const SizedBox(height: 16),

                  // 4. Order Remarks text field
                  _buildSectionHeader('Order Remarks (Optional)'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _remarksController,
                    maxLines: 2,
                    style: const TextStyle(fontSize: 13.5, color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Enter specific instructions for delivery...',
                      hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.all(14),
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
                        borderSide: BorderSide(color: theme.colorScheme.primary.withOpacity(0.5)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 5. Total Price Bill details card
                  _buildSectionHeader('Bill Details'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.01),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Items Subtotal', style: TextStyle(color: AppColors.textLight, fontSize: 13.5, fontWeight: FontWeight.w500)),
                            Text('₹${totalAmount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppColors.textPrimary)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Delivery Charges', style: TextStyle(color: AppColors.textLight, fontSize: 13.5, fontWeight: FontWeight.w500)),
                            Text('FREE', style: TextStyle(color: theme.colorScheme.secondary, fontWeight: FontWeight.w900, fontSize: 13.5)),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                          child: Container(
                            height: 1.0,
                            color: const Color(0xFFF1F5F9),
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total Amount Payable',
                              style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.textPrimary, fontSize: 14.5),
                            ),
                            Text(
                              '₹${totalAmount.toStringAsFixed(0)}',
                              style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                color: theme.colorScheme.primary,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
      bottomNavigationBar: _isLoadingProfile
          ? null
          : Container(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 16,
                bottom: MediaQuery.of(context).padding.bottom > 0
                    ? MediaQuery.of(context).padding.bottom + 12
                    : 16,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
                border: const Border(top: BorderSide(color: AppColors.border)),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: (_isSubmittingOrder || !_areAllPaymentsDone() || _defaultAddress == null) ? null : _placeOrder,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isSubmittingOrder
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          'Place Order',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: (_areAllPaymentsDone() && _defaultAddress != null) ? Colors.white : Colors.white60,
                          ),
                        ),
                ),
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        children: [
          Container(
            width: 3.5,
            height: 14,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  double _getItemOriginalPrice(dynamic item) {
    if (item['original_price'] != null) {
      final double origP = double.tryParse(item['original_price']?.toString() ?? '') ?? 0.0;
      if (origP > 0) return origP;
    }
    if (item['product_price'] != null) {
      final double prodP = double.tryParse(item['product_price']?.toString() ?? '') ?? 0.0;
      if (prodP > 0) return prodP;
    }
    return 0.0;
  }
}

// Custom Painter to draw a clean dashed border box for screenshot file uploader
class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;

  DashedBorderPainter({
    this.color = const Color(0xFFCBD5E1),
    this.strokeWidth = 1.5,
    this.gap = 4.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final Path path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(strokeWidth / 2, strokeWidth / 2, size.width - strokeWidth, size.height - strokeWidth),
        const Radius.circular(12),
      ));

    final double dashWidth = 5.0;
    final double dashSpace = gap;

    final Path dashedPath = Path();
    for (PathMetric metric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        dashedPath.addPath(
          metric.extractPath(distance, distance + dashWidth),
          Offset.zero,
        );
        distance += dashWidth + dashSpace;
      }
    }

    canvas.drawPath(dashedPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
