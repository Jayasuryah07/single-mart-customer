import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../theme.dart';

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

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await ApiService.fetchOrders(widget.token);
      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        setState(() {
          _orders = body['data'] ?? [];
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load order history. Please try again.';
        });
      }
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
                                                return Padding(
                                                  padding: const EdgeInsets.symmetric(vertical: 3.0),
                                                  child: Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          '• ${item['product_name']} (x${item['order_quantity']})',
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                          style: const TextStyle(fontSize: 12, color: AppColors.textLight),
                                                        ),
                                                      ),
                                                      Text(
                                                        '₹${item['order_amount']}',
                                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                                      ),
                                                    ],
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
                                                    if (screenshot != null && screenshot.toString().trim().isNotEmpty)
                                                      GestureDetector(
                                                        onTap: () => _showProofDialog(screenshot.toString()),
                                                        child: const Row(
                                                          children: [
                                                            Icon(Icons.image_outlined, size: 14, color: AppColors.primary),
                                                            SizedBox(width: 4),
                                                            Text(
                                                              'View Proof',
                                                              style: TextStyle(
                                                                fontSize: 11,
                                                                fontWeight: FontWeight.bold,
                                                                color: AppColors.primary,
                                                                decoration: TextDecoration.underline,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
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
}
