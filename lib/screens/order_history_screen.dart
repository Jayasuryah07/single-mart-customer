import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../theme.dart';
import 'product_detail_screen.dart';

class OrderHistoryScreen extends StatefulWidget {
  final String token;

  const OrderHistoryScreen({
    super.key,
    required this.token,
  });

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  List<dynamic> _orders = [];
  bool _isLoading = true;
  String _errorMessage = '';
  String _selectedFilter = 'All'; // All, Pending, Processing, Delivered
  List<dynamic> _activeProducts = [];

  String _baseNoImageUrl = 'https://agsdemo.in/singlemartapi/public/assets/images/no_image.jpg';
  String _baseProductImageUrl = 'https://agsdemo.in/singlemartapi/public/assets/images/product_images/';

  @override
  void initState() {
    super.initState();
    _loadBaseUrls();
    _loadOrders();
  }

  String _baseProductVariantImageUrl = 'https://agsdemo.in/singlemartapi/public/assets/images/product_variant_images/';

  Future<void> _loadBaseUrls() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _baseNoImageUrl = prefs.getString('base_no_image_url') ?? _baseNoImageUrl;
        _baseProductImageUrl = prefs.getString('base_product_image_url') ?? _baseProductImageUrl;
        _baseProductVariantImageUrl = prefs.getString('base_product_variant_image_url') ?? _baseProductVariantImageUrl;
      });
    } catch (_) {}
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final responses = await Future.wait([
        ApiService.fetchOrders(widget.token),
        ApiService.fetchActiveProducts(),
      ]);

      final ordersRes = responses[0];
      final prodsRes = responses[1];

      List<dynamic> loadedOrders = [];
      List<dynamic> activeProducts = [];

      if (ordersRes.statusCode == 200) {
        final body = json.decode(ordersRes.body);
        loadedOrders = body['data'] ?? [];
      } else {
        setState(() {
          _errorMessage = 'Failed to load order history. Please try again.';
        });
        return;
      }

      
      if (prodsRes.statusCode == 200) {
        final body = json.decode(prodsRes.body);
        activeProducts = body['data'] ?? [];
      }

      for (var order in loadedOrders) {
        final List<dynamic> subs = order['subs'] ?? [];
        for (var sub in subs) {
          final subProdId = sub['product_id']?.toString() ?? sub['order_product_id']?.toString();
          final subVarId = sub['product_variant_id']?.toString() ?? sub['order_product_variant_id']?.toString() ?? sub['variant_id']?.toString();
          if (subProdId != null) {
            final matchedProd = activeProducts.firstWhere(
              (p) => p['id']?.toString() == subProdId,
              orElse: () => null,
            );
            if (matchedProd != null) {
              if (subVarId != null && matchedProd['variants'] != null && matchedProd['variants'] is List) {
                final matchedVar = (matchedProd['variants'] as List).firstWhere(
                  (v) => v['id']?.toString() == subVarId,
                  orElse: () => null,
                );
                if (matchedVar != null) {
                  if (matchedVar['images'] != null && matchedVar['images'] is List && (matchedVar['images'] as List).isNotEmpty) {
                    sub['injected_product_image'] = matchedVar['images'][0]['product_variant_images']?.toString();
                    sub['is_variant_image'] = true;
                  }
                  if (sub['variant_attributes'] == null || (sub['variant_attributes'] is List && (sub['variant_attributes'] as List).isEmpty)) {
                    if (matchedVar['attributes'] != null) {
                      sub['variant_attributes'] = matchedVar['attributes'];
                    }
                  }
                }
              }
              if (sub['injected_product_image'] == null && matchedProd['images'] != null && matchedProd['images'] is List && (matchedProd['images'] as List).isNotEmpty) {
                sub['injected_product_image'] = matchedProd['images'][0]['product_images']?.toString();
              }
            }
          }
        }
      }

      setState(() {
        _orders = loadedOrders;
        _activeProducts = activeProducts;
      });
    } catch (e) {
      debugPrint("Error loading order history: $e");
      setState(() {
        _errorMessage = 'Network error loading orders. Please check connection.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Groups order subs by vendor ID
  Map<int, List<Map<String, dynamic>>> _groupSubsByVendor(List<dynamic> subs) {
    final Map<int, List<Map<String, dynamic>>> groups = {};
    for (var subRaw in subs) {
      final sub = Map<String, dynamic>.from(subRaw);
      final int vId = sub['order_vendor_id'] is int 
          ? sub['order_vendor_id'] 
          : int.tryParse(sub['order_vendor_id']?.toString() ?? '0') ?? 0;
      if (!groups.containsKey(vId)) {
        groups[vId] = [];
      }
      groups[vId]!.add(sub);
    }
    return groups;
  }

  List<dynamic> _getFilteredOrders() {
    if (_selectedFilter == 'All') {
      return _orders;
    }
    
    // An order matches the filter if ANY of its vendor packages (subs) match the status.
    return _orders.where((order) {
      final List<dynamic> subs = order['subs'] ?? [];
      return subs.any((sub) {
        final String status = sub['order_status']?.toString().toLowerCase() ?? '';
        return status == _selectedFilter.toLowerCase();
      });
    }).toList();
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'delivered':
        return Colors.green;
      case 'processing':
      case 'received':
        return Colors.blue;
      case 'pending':
      default:
        return Colors.orange;
    }
  }

  void _showProofDialog(String screenshotFilename) {
    final String url = "https://agsdemo.in/singlemartapi/public/assets/images/user_images/$screenshotFilename";
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: const Text('Payment Screenshot', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
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
              padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 250,
                      color: AppColors.border.withOpacity(0.3),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.broken_image, color: AppColors.textMuted, size: 40),
                          SizedBox(height: 8),
                          Text('Screenshot file not found on server', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                        ],
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
    final filteredOrders = _getFilteredOrders();

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: const Text(
          'Order History',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadOrders,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chip row
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: ['All', 'Pending', 'Processing', 'Delivered'].map((filter) {
                final isSelected = _selectedFilter == filter;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedFilter = filter;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : Colors.grey.shade300,
                      ),
                    ),
                    child: Text(
                      filter,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : AppColors.textLight,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage.isNotEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
                            const SizedBox(height: 12),
                            Text(_errorMessage, style: const TextStyle(color: AppColors.textLight)),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadOrders,
                              child: const Text('Try Again'),
                            ),
                          ],
                        ),
                      )
                    : filteredOrders.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.receipt_long_rounded, size: 64, color: AppColors.textMuted),
                                const SizedBox(height: 12),
                                Text(
                                  _selectedFilter == 'All' 
                                      ? 'No orders placed yet' 
                                      : 'No $_selectedFilter orders found',
                                  style: const TextStyle(color: AppColors.textLight, fontSize: 15),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: filteredOrders.length,
                            itemBuilder: (context, index) {
                              final order = filteredOrders[index];
                              final String orderRef = order['order_ref'] ?? 'Order #${order['id']}';
                              final String orderDate = order['order_date'] ?? '';
                              final String orderTotal = order['order_total_amount'] ?? '0.00';
                              final String rawAddress = order['order_address'] ?? '';
                              final cleanAddress = rawAddress.replaceAll('"', '').trim();
                              
                              final subs = order['subs'] ?? [];
                              final vendorGroups = _groupSubsByVendor(subs);

                              return Card(
                                margin: const EdgeInsets.only(bottom: 20),
                                elevation: 0.5,
                                  shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(color: AppColors.border),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Main Order Info Header
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Row(
                                              children: [
                                                const Icon(Icons.receipt_rounded, size: 20, color: AppColors.primary),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    orderRef,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.w900,
                                                      fontSize: 15,
                                                      color: AppColors.textPrimary,
                                                    ),
                                                  ),
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.copy_rounded, size: 16, color: AppColors.textLight),
                                                  padding: EdgeInsets.zero,
                                                  constraints: const BoxConstraints(),
                                                  onPressed: () {
                                                    Clipboard.setData(ClipboardData(text: orderRef)).then((_) {
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        const SnackBar(
                                                          content: Text('Order reference copied!'),
                                                          duration: Duration(seconds: 1),
                                                        ),
                                                      );
                                                    });
                                                  },
                                                ),
                                              ],
                                            ),
                                          ),
                                          Text(
                                            '₹$orderTotal',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 16,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Placed on: $orderDate',
                                        style: const TextStyle(fontSize: 12, color: AppColors.textLight),
                                      ),
                                      const SizedBox(height: 12),
                                      const Divider(),
                                      const SizedBox(height: 8),

                                      // Split list by vendor Packages
                                      const Text(
                                        'Sellers Packages:',
                                        style: TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 10),
                                      
                                      ...vendorGroups.keys.map((vId) {
                                        final groupItems = vendorGroups[vId]!;
                                        final firstItem = groupItems.first;
                                        final sellerName = firstItem['vendor_name'] ?? 'Seller ($vId)';
                                        final deliveryStatus = firstItem['order_status'] ?? 'Pending';
                                        final paymentStatus = firstItem['payment_status'] ?? 'Pending';
                                        final utr = firstItem['order_payment_utr_no'];
                                        final screenshot = firstItem['order_payment_screenshot'];

                                        double groupSubtotal = 0.0;
                                        for (var item in groupItems) {
                                          final double amount = double.tryParse(item['order_amount']?.toString() ?? '') ?? 0.0;
                                          groupSubtotal += amount;
                                        }

                                        return Container(
                                          margin: const EdgeInsets.only(bottom: 12),
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade50,
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: AppColors.border),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              // Vendor card subheader
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Row(
                                                    children: [
                                                      const Icon(Icons.storefront_rounded, size: 16, color: AppColors.primary),
                                                      const SizedBox(width: 6),
                                                      Text(
                                                        sellerName,
                                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                                                      ),
                                                    ],
                                                  ),
                                                  // Delivery Status badge
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                    decoration: BoxDecoration(
                                                      color: _getStatusColor(deliveryStatus).withOpacity(0.08),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Text(
                                                      deliveryStatus.toUpperCase(),
                                                      style: TextStyle(
                                                        color: _getStatusColor(deliveryStatus),
                                                        fontSize: 9,
                                                        fontWeight: FontWeight.w900,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 10),
                                              
                                              // Products under this vendor
                                              ...groupItems.map((item) {
                                                final imgUrl = _getProductImageUrl(item);
                                                return Padding(
                                                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                                                  child: GestureDetector(
                                                    onTap: () {
                                                      final subProdId = item['product_id']?.toString() ?? item['order_product_id']?.toString();
                                                      if (subProdId != null) {
                                                        final matched = _activeProducts.firstWhere(
                                                          (p) => p['id']?.toString() == subProdId,
                                                          orElse: () => null,
                                                        );
                                                        if (matched != null) {
                                                          Navigator.push(
                                                            context,
                                                            MaterialPageRoute(
                                                              builder: (context) => ProductDetailScreen(product: matched),
                                                            ),
                                                          ).then((_) => _loadOrders());
                                                        } else {
                                                          final fallbackProduct = {
                                                            "id": int.tryParse(subProdId) ?? 0,
                                                            "product_name": item['product_name'] ?? 'Product',
                                                            "product_price": item['order_amount']?.toString(),
                                                            "images": item['injected_product_image'] != null ? [
                                                              {
                                                                "product_images": item['injected_product_image']
                                                              }
                                                            ] : [],
                                                          };
                                                          Navigator.push(
                                                            context,
                                                            MaterialPageRoute(
                                                              builder: (context) => ProductDetailScreen(product: fallbackProduct),
                                                            ),
                                                          ).then((_) => _loadOrders());
                                                        }
                                                      }
                                                    },
                                                    behavior: HitTestBehavior.opaque,
                                                    child: Row(
                                                      children: [
                                                        Container(
                                                          width: 32,
                                                          height: 32,
                                                          decoration: BoxDecoration(
                                                            color: Colors.white,
                                                            borderRadius: BorderRadius.circular(6),
                                                            border: Border.all(color: AppColors.border),
                                                          ),
                                                          child: ClipRRect(
                                                            borderRadius: BorderRadius.circular(4),
                                                            child: Image.network(
                                                              imgUrl,
                                                              fit: BoxFit.cover,
                                                              errorBuilder: (context, error, stackTrace) =>
                                                                  const Icon(Icons.image_not_supported_rounded, size: 14, color: AppColors.textMuted),
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(width: 8),
                                                        Expanded(
                                                          child: Column(
                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                            children: [
                                                              Text(
                                                                '${item['product_name']} (x${item['order_quantity']})',
                                                                maxLines: 1,
                                                                overflow: TextOverflow.ellipsis,
                                                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                                              ),
                                                              if (_formatItemVariantAttributes(item).isNotEmpty) ...[
                                                                const SizedBox(height: 2),
                                                                Text(
                                                                  'Variant: ${_formatItemVariantAttributes(item)}',
                                                                  maxLines: 1,
                                                                  overflow: TextOverflow.ellipsis,
                                                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                                                                ),
                                                              ],
                                                            ],
                                                          ),
                                                        ),
                                                         const SizedBox(width: 8),
                                                         Column(
                                                           crossAxisAlignment: CrossAxisAlignment.end,
                                                           mainAxisAlignment: MainAxisAlignment.center,
                                                           children: [
                                                             Text(
                                                               '₹${item['order_amount']}',
                                                               style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                                             ),
                                                             if (_hasItemDiscountPrice(item)) ...[
                                                               const SizedBox(height: 2),
                                                               Text(
                                                                 '₹${_getItemOriginalTotal(item)}',
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
                                                  ),
                                                );
                                              }).toList(),
                                              
                                              const SizedBox(height: 8),
                                              const Divider(height: 12),
                                              
                                              // Package total & details
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(
                                                    'Payment Status: $paymentStatus',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold,
                                                      color: paymentStatus.toLowerCase() == 'received' ? Colors.green : Colors.orange,
                                                    ),
                                                  ),
                                                  Text(
                                                    'Subtotal: ₹${groupSubtotal.toStringAsFixed(2)}',
                                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                                                  ),
                                                ],
                                              ),
                                              
                                              // Verification UTR and proof image display
                                              if (utr != null && utr.toString().trim().isNotEmpty) ...[
                                                const SizedBox(height: 8),
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Text(
                                                      'UTR: $utr',
                                                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                                    ),
                                                    
                                                  ],
                                                ),
                                              ],
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                      
                                      const SizedBox(height: 4),
                                      const Divider(),
                                      const SizedBox(height: 6),
                                      
                                      // Delivery Address footer
                                      const Row(
                                        children: [
                                          Icon(Icons.location_on_rounded, size: 14, color: AppColors.textLight),
                                          SizedBox(width: 6),
                                          Text(
                                            'Delivery Address:',
                                            style: TextStyle(fontSize: 11, color: AppColors.textLight, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Padding(
                                        padding: const EdgeInsets.only(left: 20.0),
                                        child: Text(
                                          cleanAddress,
                                          style: const TextStyle(fontSize: 12, color: AppColors.textLight, height: 1.3),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  String _getProductImageUrl(dynamic item) {
    dynamic imgVal = item['injected_product_image'] ?? item['product_image'] ?? item['image'] ?? item['product_images'];
    final bool isVarImg = item['is_variant_image'] == true || item['is_variant'] == true;
    
    if (imgVal == null && item['product'] != null && item['product'] is Map) {
      final prod = item['product'] as Map;
      imgVal = prod['product_image'] ?? prod['image'];
      if (imgVal == null && prod['images'] != null && prod['images'] is List && (prod['images'] as List).isNotEmpty) {
        final imgList = prod['images'] as List;
        imgVal = imgList[0]['product_images'] ?? imgList[0]['image'];
      }
    }
    
    if (imgVal == null && item['images'] != null && item['images'] is List && (item['images'] as List).isNotEmpty) {
      final imgList = item['images'] as List;
      imgVal = imgList[0]['product_images'] ?? imgList[0]['image'];
    }

    if (imgVal == null || imgVal.toString().trim().isEmpty) {
      return _baseNoImageUrl;
    }
    
    final String imgStr = imgVal.toString();
    if (imgStr.startsWith('http://') || imgStr.startsWith('https://')) {
      return imgStr;
    }
    return isVarImg ? '${_baseProductVariantImageUrl}$imgStr' : '${_baseProductImageUrl}$imgStr';
  }

  String _formatItemVariantAttributes(dynamic item) {
    if (item['variant_attributes'] != null) {
      final vAttrs = item['variant_attributes'];
      if (vAttrs is List && vAttrs.isNotEmpty) {
        final List<String> parts = [];
        for (var attr in vAttrs) {
          if (attr is Map) {
            final name = attr['attribute_name']?.toString() ?? '';
            final val = attr['attribute_value']?.toString() ?? '';
            if (val.isNotEmpty) {
              parts.add(name.isNotEmpty ? '$name: $val' : val);
            }
          }
        }
        if (parts.isNotEmpty) {
          return parts.join(', ');
        }
      } else if (vAttrs is String && vAttrs.isNotEmpty) {
        return vAttrs;
      }
    }
    return '';
  }

  bool _hasItemDiscountPrice(dynamic item) {
    final double amt = double.tryParse(item['order_amount']?.toString() ?? '') ?? 0.0;
    final double unitPrice = double.tryParse(item['order_price']?.toString() ?? '') ?? 0.0;
    final double qty = double.tryParse(item['order_quantity']?.toString() ?? '') ?? 1.0;
    final double origTotal = unitPrice * qty;
    return origTotal > amt;
  }

  String _getItemOriginalTotal(dynamic item) {
    final double unitPrice = double.tryParse(item['order_price']?.toString() ?? '') ?? 0.0;
    final double qty = double.tryParse(item['order_quantity']?.toString() ?? '') ?? 1.0;
    return (unitPrice * qty).toStringAsFixed(2);
  }
}
