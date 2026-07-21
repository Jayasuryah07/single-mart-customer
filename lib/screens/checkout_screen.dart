import 'dart:convert';
import 'dart:io';
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
        for (var vId in grouped.keys) {
          _utrByVendor[vId] = '';
          _screenshotFileByVendor[vId] = null;
          _screenshotBase64ByVendor[vId] = '';
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
      backgroundColor: const Color(0xFFFAFBFD),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: const Text(
          'Checkout',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: _isLoadingProfile
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Reference Details card
                  _buildSectionHeader('User Details (Reference)'),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.person_outline_rounded, color: AppColors.textLight, size: 20),
                            const SizedBox(width: 10),
                            Text(
                              _userData?['name'] ?? 'Guest User',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.phone_iphone_rounded, color: AppColors.textLight, size: 20),
                            const SizedBox(width: 10),
                            Text(
                              _userData?['mobile'] != null && _userData!['mobile'].toString().isNotEmpty
                                  ? '+91 ${_userData!['mobile']}'
                                  : 'No Phone Provided',
                              style: const TextStyle(fontSize: 15, color: AppColors.textLight),
                            ),
                          ],
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
                          size: 18,
                        ),
                        label: Text(
                          _defaultAddress != null ? 'Change' : 'Add',
                          style: const TextStyle(fontWeight: FontWeight.bold),
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
                      border: Border.all(color: AppColors.border),
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
                                  backgroundColor: AppColors.primary.withOpacity(0.08),
                                  foregroundColor: AppColors.primary,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: const Text('Manage Addresses'),
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      (_defaultAddress!['address_type']?.toString().toUpperCase() ?? 'HOME'),
                                      style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w900),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text('Default Address', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _formatAddress(_defaultAddress!).replaceAll('"', ''),
                                style: const TextStyle(fontSize: 15, color: AppColors.textPrimary, height: 1.4, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 24),

                  // 3. Split Payment Cards grouped by Vendor
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

                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Merchant Header
                                  Row(
                                    children: [
                                      const CircleAvatar(
                                        backgroundColor: AppColors.secondary,
                                        radius: 16,
                                        child: Icon(Icons.storefront_rounded, color: AppColors.primary, size: 16),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              merchant?['name'] ?? 'Merchant ($vendorId)',
                                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                            ),
                                            if (merchant?['owner_name'] != null)
                                              Text(
                                                'Owner: ${merchant!['owner_name']}',
                                                style: const TextStyle(fontSize: 11, color: AppColors.textLight),
                                              ),
                                          ],
                                        ),
                                      ),
                                      if (merchant?['mobile'] != null)
                                        Text(
                                          'Ph: ${merchant!['mobile']}',
                                          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  const Divider(),
                                  const SizedBox(height: 8),

                                  // Vendor items list
                                  const Text('Items from this seller:', style: TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 6),
                                  ...vendorItems.map((item) {
                                    final String? imgFile = item['product_image']?.toString();
                                    final String imgUrl = (imgFile != null && imgFile.isNotEmpty)
                                        ? ((item['is_variant'] == true || item['variant_id'] != null)
                                            ? '${_baseProductVariantImageUrl}$imgFile'
                                            : '${_baseProductImageUrl}$imgFile')
                                        : _baseNoImageUrl;

                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              color: AppColors.surface,
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: AppColors.border),
                                            ),
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(6),
                                              child: Image.network(
                                                imgUrl,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error, stackTrace) =>
                                                    const Icon(Icons.image_not_supported_rounded, size: 18, color: AppColors.textMuted),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item['name'] ?? 'Product',
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                                                ),
                                                if (item['variant_attributes'] != null && item['variant_attributes'].toString().isNotEmpty)
                                                  Text(
                                                    'Variant: ${item['variant_attributes']}',
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                                                  ),
                                                const SizedBox(height: 2),
                                                Text(
                                                   'Qty: ${item['quantity']}',
                                                   style: const TextStyle(fontSize: 11, color: AppColors.textLight),
                                                 ),
                                               ],
                                             ),
                                           ),
                                           const SizedBox(width: 12),
                                           Column(
                                             crossAxisAlignment: CrossAxisAlignment.end,
                                             mainAxisAlignment: MainAxisAlignment.center,
                                             children: [
                                               Text(
                                                 '₹${((item['price'] is num ? item['price'] : double.tryParse(item['price']?.toString() ?? '0') ?? 0.0) * (item['quantity'] is num ? item['quantity'] : int.tryParse(item['quantity']?.toString() ?? '1') ?? 1)).toStringAsFixed(2)}',
                                                 style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                               ),
                                               if (_getItemOriginalPrice(item) > (item['price'] is num ? item['price'] : double.tryParse(item['price']?.toString() ?? '0') ?? 0.0)) ...[
                                                 const SizedBox(height: 2),
                                                 Text(
                                                   '₹${(_getItemOriginalPrice(item) * (item['quantity'] is num ? item['quantity'] : int.tryParse(item['quantity']?.toString() ?? '1') ?? 1)).toStringAsFixed(2)}',
                                                   style: const TextStyle(
                                                     fontSize: 11,
                                                     fontWeight: FontWeight.w500,
                                                     color: AppColors.textMuted,
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
                                  const SizedBox(height: 10),
                                  
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Seller Subtotal', style: TextStyle(fontSize: 13, color: AppColors.textLight, fontWeight: FontWeight.bold)),
                                      Text(
                                        '₹${vendorSubtotal.toStringAsFixed(2)}',
                                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: theme.colorScheme.primary),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  const Divider(),

                                  // Seller Payment UPI and QR
                                  if (merchant != null) ...[
                                    const SizedBox(height: 8),
                                    if (merchant['upi_id'] != null && merchant['upi_id'].toString().trim().isNotEmpty) ...[
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text('UPI ID', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                                const SizedBox(height: 2),
                                                Text(
                                                  merchant['upi_id'],
                                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                                ),
                                              ],
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.copy_rounded, color: AppColors.primary, size: 18),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            onPressed: () {
                                              Clipboard.setData(ClipboardData(text: merchant['upi_id'])).then((_) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(
                                                    content: Text('UPI ID copied to clipboard!'),
                                                    duration: Duration(seconds: 1),
                                                  ),
                                                );
                                              });
                                            },
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                    ],

                                    if (merchant['qr_code'] != null && merchant['qr_code'].toString().trim().isNotEmpty) ...[
                                      const Text('Scan QR Code to Pay:', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                      const SizedBox(height: 8),
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
                                                  border: Border.all(color: AppColors.border),
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: ClipRRect(
                                                  borderRadius: BorderRadius.circular(6),
                                                  child: Image.network(
                                                    "https://agsdemo.in/singlemartapi/public/assets/images/user_images/${merchant['qr_code']}",
                                                    width: 100,
                                                    height: 100,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (context, error, stackTrace) {
                                                      return Container(
                                                        width: 100,
                                                        height: 100,
                                                        color: AppColors.border.withOpacity(0.3),
                                                        child: const Center(
                                                          child: Icon(Icons.broken_image, color: AppColors.textMuted, size: 24),
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                ),
                                              ),
                                              Positioned(
                                                bottom: 6,
                                                right: 6,
                                                child: Container(
                                                  padding: const EdgeInsets.all(3),
                                                  decoration: const BoxDecoration(
                                                    color: Colors.white,
                                                    shape: BoxShape.circle,
                                                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 2)],
                                                  ),
                                                  child: const Icon(Icons.fullscreen_rounded, color: AppColors.primary, size: 14),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                    ],

                                    if (merchant['gst_number'] != null && merchant['gst_number'].toString().trim().isNotEmpty) ...[
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text('GST Number', style: TextStyle(fontSize: 12, color: AppColors.textLight)),
                                            Text(merchant['gst_number'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                          ],
                                        ),
                                      ),
                                    ],

                                    if (merchant['pan_number'] != null && merchant['pan_number'].toString().trim().isNotEmpty) ...[
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text('PAN Number', style: TextStyle(fontSize: 12, color: AppColors.textLight)),
                                            Text(merchant['pan_number'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                          ],
                                        ),
                                      ),
                                    ],
                                    
                                    const Divider(),
                                  ],

                                  // UTR and Screenshot Upload Section
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Payment Verification',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                  ),
                                  const SizedBox(height: 10),

                                  // UTR Number Field
                                  TextFormField(
                                    initialValue: _utrByVendor[vendorId],
                                    decoration: InputDecoration(
                                      labelText: 'Transaction UTR Number',
                                      labelStyle: const TextStyle(fontSize: 12, color: AppColors.textLight),
                                      hintText: 'Enter 12-digit UTR/Ref Number',
                                      prefixIcon: const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 20),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    ),
                                    keyboardType: TextInputType.text,
                                    onChanged: (val) {
                                      setState(() {
                                        _utrByVendor[vendorId] = val;
                                      });
                                    },
                                  ),
                                  const SizedBox(height: 12),

                                  // Screenshot Picker Button & Preview
                                  Row(
                                    children: [
                                      ElevatedButton.icon(
                                        onPressed: () => _pickScreenshot(vendorId),
                                        icon: Icon(
                                          _screenshotFileByVendor[vendorId] != null ? Icons.change_circle_rounded : Icons.add_photo_alternate_rounded,
                                          size: 18,
                                          color: Colors.white,
                                        ),
                                        label: Text(
                                          _screenshotFileByVendor[vendorId] != null ? 'Change Screen' : 'Upload Screenshot',
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primary,
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      if (_screenshotFileByVendor[vendorId] != null)
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Image.file(
                                            _screenshotFileByVendor[vendorId]!,
                                            width: 48,
                                            height: 48,
                                            fit: BoxFit.cover,
                                          ),
                                        )
                                      else
                                        const Row(
                                          children: [
                                            Icon(Icons.info_outline, color: Colors.orange, size: 16),
                                            SizedBox(width: 6),
                                            Text(
                                              'No screenshot chosen',
                                              style: TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),

                                  // Verification indicator
                                  Row(
                                    children: [
                                      Icon(
                                        isPayDetailsComplete ? Icons.check_circle_rounded : Icons.pending_rounded,
                                        color: isPayDetailsComplete ? Colors.green : Colors.orange,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        isPayDetailsComplete ? 'Payment details complete' : 'Details required',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: isPayDetailsComplete ? Colors.green : Colors.orange,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                  const SizedBox(height: 12),

                  // 4. Order Remarks text field
                  _buildSectionHeader('Order Remarks (Optional)'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _remarksController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Enter instruction/remarks for the delivery here...',
                      hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppColors.border),
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
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Items Subtotal', style: TextStyle(color: AppColors.textLight)),
                            Text('₹${totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Delivery Charges', style: TextStyle(color: AppColors.textLight)),
                            Text('FREE', style: TextStyle(color: Colors.green, fontWeight: FontWeight.w900)),
                          ],
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12.0),
                          child: Divider(),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total Amount Payable',
                              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 15),
                            ),
                            Text(
                              '₹${totalAmount.toStringAsFixed(2)}',
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
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: (_isSubmittingOrder || !_areAllPaymentsDone() || _defaultAddress == null) ? null : _placeOrder,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
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
                            fontWeight: FontWeight.bold,
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
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w900,
        color: AppColors.textLight,
        letterSpacing: 0.5,
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
