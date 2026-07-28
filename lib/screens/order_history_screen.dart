import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../utils/file_saver.dart';
import 'product_detail_screen.dart';
// ignore: depend_on_referenced_packages
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
// open_file is only used on mobile/native paths
// ignore: depend_on_referenced_packages
import 'package:open_file/open_file.dart';

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
  bool _isRefreshing = false;
  String _errorMessage = '';
  String _selectedFilter = 'All';
  List<dynamic> _activeProducts = [];
  Timer? _refreshTimer;
  
  final Map<int, Map<String, dynamic>> _vendorsData = {};

  String _baseNoImageUrl = 'https://agsdemo.in/singlemartapi/public/assets/images/no_image.jpg';
  String _baseProductImageUrl = 'https://agsdemo.in/singlemartapi/public/assets/images/product_images/';
  String _baseProductVariantImageUrl = 'https://agsdemo.in/singlemartapi/public/assets/images/product_variant_images/';
  String _basePaymentImageUrl = 'https://agsdemo.in/singlemartapi/public/assets/images/payment_images/';

  final List<String> _statuses = [
    'All',
    'Pending',
    'Confirmed',
    'Processing',
    'Packed',
    'Shipped',
    'Out for Delivery',
    'Delivered',
    'Cancelled',
    'Returned',
    'Refunded'
  ];

  @override
  void initState() {
    super.initState();
    _loadBaseUrls();
    _loadOrders();
    
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _loadOrders(isSilent: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadBaseUrls() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _baseNoImageUrl = prefs.getString('base_no_image_url') ?? _baseNoImageUrl;
        _baseProductImageUrl = prefs.getString('base_product_image_url') ?? _baseProductImageUrl;
        _baseProductVariantImageUrl = prefs.getString('base_product_variant_image_url') ?? _baseProductVariantImageUrl;
        _basePaymentImageUrl = prefs.getString('base_payment_image_url') ?? _basePaymentImageUrl;
      });
    } catch (_) {}
  }

  Future<void> _loadOrders({bool isSilent = false}) async {
    if (isSilent && _isRefreshing) return;
    _isRefreshing = true;

    if (!isSilent) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });
    }

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
        // Parse dynamic image base URLs from API response
        final List<dynamic> imageUrls = body['image_url'] ?? [];
        for (final img in imageUrls) {
          final imageFor = img['image_for']?.toString() ?? '';
          final imageUrl = img['image_url']?.toString() ?? '';
          if (imageFor == 'Payment' && imageUrl.isNotEmpty) {
            _basePaymentImageUrl = imageUrl;
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('base_payment_image_url', imageUrl);
          }
        }
      } else {
        if (!isSilent) {
          setState(() {
            _errorMessage = 'Failed to load order history. Please try again.';
          });
        }
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

      final Set<int> vendorIds = {};
      for (var order in loadedOrders) {
        final List<dynamic> subs = order['subs'] ?? [];
        for (var sub in subs) {
          final int vId = sub['order_vendor_id'] is int 
              ? sub['order_vendor_id'] 
              : int.tryParse(sub['order_vendor_id']?.toString() ?? '0') ?? 0;
          if (vId != 0) {
            vendorIds.add(vId);
          }
        }
      }

      for (var vId in vendorIds) {
        if (!_vendorsData.containsKey(vId)) {
          try {
            final response = await ApiService.fetchVendor(vId, widget.token);
            if (response.statusCode == 200) {
              final resData = json.decode(response.body);
              if (resData['data'] != null) {
                _vendorsData[vId] = Map<String, dynamic>.from(resData['data']);
              }
            }
          } catch (e) {
            debugPrint("Error fetching vendor detail inside history: $e");
          }
        }
      }

      if (mounted) {
        setState(() {
          _orders = loadedOrders;
          _activeProducts = activeProducts;
          _errorMessage = '';
        });
      }
    } catch (e) {
      debugPrint("Error loading order history: $e");
      if (!isSilent && mounted) {
        setState(() {
          _errorMessage = 'Network error loading orders. Please check connection.';
        });
      }
    } finally {
      _isRefreshing = false;
      if (mounted && !isSilent) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

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
    
    return _orders.where((order) {
      final List<dynamic> subs = order['subs'] ?? [];
      return subs.any((sub) {
        final String status = sub['order_status']?.toString().toLowerCase() ?? '';
        return status == _selectedFilter.toLowerCase();
      });
    }).toList();
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase().trim()) {
      case 'delivered':
        return const Color(0xFF2E7D32);
      case 'confirmed':
      case 'processing':
        return const Color(0xFF1976D2);
      case 'packed':
        return const Color(0xFF008080);
      case 'shipped':
        return const Color(0xFF3F51B5);
      case 'out for delivery':
        return const Color(0xFF9C27B0);
      case 'cancelled':
      case 'returned':
      case 'refunded':
        return const Color(0xFFD32F2F);
      case 'pending':
      default:
        return const Color(0xFFEF6C00);
    }
  }

  Widget _buildDeliveryProgressBar(String status) {
    double progressValue = 0.2;
    String description = 'Order Confirmed';
    Color color = Colors.orange;

    final String s = status.toLowerCase().trim();
    if (s == 'pending') {
      progressValue = 0.1;
      description = 'Pending Approval';
      color = const Color(0xFFEF6C00);
    } else if (s == 'confirmed') {
      progressValue = 0.25;
      description = 'Confirmed by Merchant';
      color = const Color(0xFF1976D2);
    } else if (s == 'processing') {
      progressValue = 0.4;
      description = 'Being Processed';
      color = const Color(0xFF1976D2);
    } else if (s == 'packed') {
      progressValue = 0.55;
      description = 'Packed & Ready';
      color = const Color(0xFF008080);
    } else if (s == 'shipped') {
      progressValue = 0.7;
      description = 'Shipped via Partner';
      color = const Color(0xFF3F51B5);
    } else if (s == 'out for delivery') {
      progressValue = 0.85;
      description = 'Out for Delivery';
      color = const Color(0xFF9C27B0);
    } else if (s == 'delivered') {
      progressValue = 1.0;
      description = 'Delivered successfully';
      color = const Color(0xFF2E7D32);
    } else if (s == 'cancelled') {
      progressValue = 1.0;
      description = 'Cancelled';
      color = const Color(0xFFD32F2F);
    } else if (s == 'returned') {
      progressValue = 1.0;
      description = 'Returned';
      color = const Color(0xFFD32F2F);
    } else if (s == 'refunded') {
      progressValue = 1.0;
      description = 'Refunded';
      color = const Color(0xFFD32F2F);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              description,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            Text(
              '${(progressValue * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progressValue,
            backgroundColor: const Color(0xFFF1F5F9),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 4,
          ),
        ),
      ],
    );
  }

  Future<void> _downloadInvoice(Map<String, dynamic> order) async {
    try {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final pdfBytes = await _generateBeautifulPdf(order);

      final orderRef = order['order_ref'] ?? 'Order_${order['id']}';
      final safeRef = orderRef
          .replaceAll(RegExp(r'[/\\:#*?"<>|]'), '_')
          .replaceAll(RegExp(r'_+'), '_');
      final fileName = 'Invoice_$safeRef.pdf';

      // Cross-platform save: uses browser blob download on Web, file system on mobile
      final savedPath = await saveAndDownloadFile(pdfBytes, fileName);

      if (!mounted) return;
      Navigator.pop(context);

      if (kIsWeb) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invoice "$fileName" downloaded successfully.'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        _showDownloadSuccessDialog(savedPath);
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _showErrorDialog('Failed to download PDF: ${e.toString()}');
    }
  }

  Future<List<int>> _generateBeautifulPdf(Map<String, dynamic> order) async {
    final pdf = pw.Document();
    
    final String orderRef = order['order_ref'] ?? 'Order #${order['id']}';
    final String orderDate = order['order_date'] ?? '';
    final String orderTotal = order['order_total_amount'] ?? '0.00';
    final String rawAddress = order['order_address'] ?? '';
    final cleanAddress = rawAddress.replaceAll('"', '').replaceAll('\n', ', ').trim();
    final subs = order['subs'] ?? [];

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [
            // Header Section
            pw.Container(
              padding: const pw.EdgeInsets.only(bottom: 20),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(
                    color: PdfColors.grey300,
                    width: 1,
                  ),
                ),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'SINGLEMART',
                        style: pw.TextStyle(
                          fontSize: 28,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue900,
                        ),
                      ),
                      pw.Text(
                        'Your Trusted Online Store',
                        style: pw.TextStyle(
                          fontSize: 12,
                          color: PdfColors.grey600,
                        ),
                      ),
                    ],
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.blue50,
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'INVOICE',
                          style: pw.TextStyle(
                            fontSize: 20,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue900,
                          ),
                        ),
                        pw.Text(
                          '#$orderRef',
                          style: pw.TextStyle(
                            fontSize: 12,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            pw.SizedBox(height: 20),
            
            // Order Info Section
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey50,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Order Details',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue900,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Order Date: $orderDate',
                        style: pw.TextStyle(
                          fontSize: 11,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.Text(
                        'Payment Status: Paid',
                        style: pw.TextStyle(
                          fontSize: 11,
                          color: PdfColors.green700,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Total Amount',
                        style: pw.TextStyle(
                          fontSize: 11,
                          color: PdfColors.grey600,
                        ),
                      ),
                      pw.Text(
                        'Rs. ${double.parse(orderTotal).toStringAsFixed(2)}',
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.green700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            pw.SizedBox(height: 20),
            
            // Items Table Header
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue50,
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Row(
                children: [
                  pw.Expanded(
                    flex: 4,
                    child: pw.Text(
                      'Product',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                      ),
                    ),
                  ),
                  pw.Expanded(
                    flex: 1,
                    child: pw.Text(
                      'Qty',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                  pw.Expanded(
                    flex: 1,
                    child: pw.Text(
                      'Price',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                      ),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                  pw.Expanded(
                    flex: 1,
                    child: pw.Text(
                      'Total',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                      ),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
            
            pw.SizedBox(height: 8),
            
            // Items List
            ...subs.map((item) {
              final name = item['product_name'] ?? 'Product';
              final qty = item['order_quantity'] ?? 1;
              final amt = double.tryParse(item['order_amount']?.toString() ?? '0') ?? 0;
              final price = double.tryParse(item['order_price']?.toString() ?? '0') ?? 0;
              
              final int vendorId = item['order_vendor_id'] is int 
                  ? item['order_vendor_id'] 
                  : int.tryParse(item['order_vendor_id']?.toString() ?? '0') ?? 0;
              final merchant = _vendorsData[vendorId];
              final sellerName = merchant?['name'] ?? item['vendor_name'] ?? 'Seller';
              
              return pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                decoration: pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(
                      color: PdfColors.grey200,
                      width: 0.5,
                    ),
                  ),
                ),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      flex: 4,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            name,
                            style: pw.TextStyle(
                              fontSize: 11,
                              color: PdfColors.black,
                            ),
                          ),
                          pw.Text(
                            'Sold by: $sellerName',
                            style: pw.TextStyle(
                              fontSize: 9,
                              color: PdfColors.grey600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    pw.Expanded(
                      flex: 1,
                      child: pw.Text(
                        qty.toString(),
                        style: pw.TextStyle(
                          fontSize: 11,
                          color: PdfColors.black,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    pw.Expanded(
                      flex: 1,
                      child: pw.Text(
                        'Rs. ${price.toStringAsFixed(2)}',
                        style: pw.TextStyle(
                          fontSize: 11,
                          color: PdfColors.black,
                        ),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                    pw.Expanded(
                      flex: 1,
                      child: pw.Text(
                        'Rs. ${amt.toStringAsFixed(2)}',
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.black,
                        ),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            
            pw.SizedBox(height: 16),
            
            // Summary Section
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey50,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Subtotal: ',
                        style: pw.TextStyle(
                          fontSize: 11,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.Text(
                        'Rs. ${double.parse(orderTotal).toStringAsFixed(2)}',
                        style: pw.TextStyle(
                          fontSize: 11,
                          color: PdfColors.black,
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Delivery Fee: ',
                        style: pw.TextStyle(
                          fontSize: 11,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.Text(
                        'FREE',
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.green700,
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 8),
                  pw.Container(
                    width: 200,
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.green50,
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'Total Paid:',
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.green900,
                          ),
                        ),
                        pw.Text(
                          'Rs. ${double.parse(orderTotal).toStringAsFixed(2)}',
                          style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.green700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            pw.SizedBox(height: 20),
            
            // Delivery Address
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey50,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Delivery Address',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    cleanAddress,
                    style: pw.TextStyle(
                      fontSize: 11,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
            ),
            
            pw.SizedBox(height: 30),
            
            // Footer
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey50,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                children: [
                  pw.Text(
                    'Thank you for shopping with SingleMart!',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'For any queries, please contact our support team.',
                    style: pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey600,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'support@singlemart.com | +91-XXX-XXX-XXXX',
                    style: pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey500,
                    ),
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  void _showDownloadSuccessDialog(String filePath) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('PDF Generated', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your invoice PDF has been Generated successfully.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          if (!kIsWeb)
            ElevatedButton.icon(
              onPressed: () async {
                try {
                  await OpenFile.open(filePath);
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Could not open file: ${e.toString()}')),
                    );
                  }
                }
              },
              icon: const Icon(Icons.open_in_new, size: 18, color: Colors.white),
              label: const Text('Open File', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.error_outline, color: AppColors.error),
            SizedBox(width: 8),
            Text('Error', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showProofDialog(String screenshotFilename) {
    final String url = '$_basePaymentImageUrl$screenshotFilename';
    final screenSize = MediaQuery.of(context).size;
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 520,
            maxHeight: screenSize.height * 0.85,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: const BoxDecoration(
                    color: Color(0xFF16213E),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.receipt_long, color: AppColors.primary, size: 18),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Payment Screenshot',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.close, color: Colors.white70, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),
                // Hint row
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: const Color(0xFF0F3460),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.pinch, color: Colors.white54, size: 14),
                      const SizedBox(width: 6),
                      const Text(
                        'Pinch to zoom · Double tap to reset',
                        style: TextStyle(fontSize: 11, color: Colors.white54),
                      ),
                    ],
                  ),
                ),
                // Image area — constrained + zoomable
                Flexible(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                    child: Container(
                      color: const Color(0xFF0D0D1A),
                      child: InteractiveViewer(
                        panEnabled: true,
                        minScale: 0.8,
                        maxScale: 5.0,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Image.network(
                            url,
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return SizedBox(
                                height: 260,
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      CircularProgressIndicator(
                                        value: loadingProgress.expectedTotalBytes != null
                                            ? loadingProgress.cumulativeBytesLoaded /
                                                loadingProgress.expectedTotalBytes!
                                            : null,
                                        color: AppColors.primary,
                                        strokeWidth: 2,
                                      ),
                                      const SizedBox(height: 12),
                                      const Text(
                                        'Loading screenshot…',
                                        style: TextStyle(fontSize: 12, color: Colors.white54),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                height: 220,
                                alignment: Alignment.center,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.broken_image_outlined, color: Colors.white24, size: 48),
                                    const SizedBox(height: 12),
                                    const Text(
                                      'Screenshot not found on server',
                                      style: TextStyle(fontSize: 13, color: Colors.white38),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      screenshotFilename,
                                      style: const TextStyle(fontSize: 10, color: Colors.white24),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
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


  @override
  Widget build(BuildContext context) {
    final filteredOrders = _getFilteredOrders();
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Row(
          children: [
            const Text(
              'Order History',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w900,
                fontSize: 20,
                letterSpacing: 0.3,
              ),
            ),
            if (_isRefreshing) ...[
              const SizedBox(width: 8),
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
              ),
            ],
          ],
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _loadOrders(),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: AppColors.border,
            height: 1.0,
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            children: [
          Container(
            color: Colors.white,
            height: 54,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              itemCount: _statuses.length,
              itemBuilder: (context, index) {
                final filter = _statuses[index];
                final isSelected = _selectedFilter == filter;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedFilter = filter;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? theme.colorScheme.primary : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? theme.colorScheme.primary : const Color(0xFFE2E8F0),
                        width: 1.0,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        filter,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                          color: isSelected ? Colors.white : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            height: 1.0,
            color: AppColors.border,
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
                              onPressed: () => _loadOrders(),
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
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary.withOpacity(0.08),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.receipt_long_rounded, size: 40, color: theme.colorScheme.primary),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _selectedFilter == 'All' 
                                      ? 'No orders placed yet' 
                                      : 'No $_selectedFilter orders found',
                                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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

                              return Container(
                                margin: const EdgeInsets.only(bottom: 16),
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
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Row(
                                              children: [
                                                Icon(Icons.receipt_rounded, size: 18, color: theme.colorScheme.primary),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    orderRef,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.w900,
                                                      fontSize: 14.5,
                                                      color: AppColors.textPrimary,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          GestureDetector(
                                            onTap: () => _downloadInvoice(order),
                                            child: Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: BoxDecoration(
                                                color: theme.colorScheme.secondary.withOpacity(0.1),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                Icons.picture_as_pdf_rounded,
                                                size: 16,
                                                color: theme.colorScheme.secondary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Placed on: $orderDate',
                                            style: const TextStyle(fontSize: 11.5, color: AppColors.textLight, fontWeight: FontWeight.w500),
                                          ),
                                          Text(
                                            'Total: ₹${double.parse(orderTotal).toStringAsFixed(0)}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 15,
                                              color: theme.colorScheme.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Container(
                                        height: 1.0,
                                        color: const Color(0xFFF1F5F9),
                                      ),
                                      const SizedBox(height: 12),

                                      const Text(
                                        'Seller Packages',
                                        style: TextStyle(fontSize: 11.5, color: AppColors.textPrimary, fontWeight: FontWeight.w900),
                                      ),
                                      const SizedBox(height: 8),
                                      
                                      ...vendorGroups.keys.map((vId) {
                                        final groupItems = vendorGroups[vId]!;
                                        final firstItem = groupItems.first;
                                        
                                        final merchant = _vendorsData[vId];
                                        final sellerName = merchant?['name'] ?? firstItem['vendor_name'] ?? 'Seller ($vId)';
                                        final sellerMobile = merchant?['mobile'] ?? '';

                                        final deliveryStatus = firstItem['order_status'] ?? 'Pending';
                                        final paymentStatus = firstItem['payment_status'] ?? 'Pending';

                                        double groupSubtotal = 0.0;
                                        for (var item in groupItems) {
                                          final double amount = double.tryParse(item['order_amount']?.toString() ?? '') ?? 0.0;
                                          groupSubtotal += amount;
                                        }

                                        return Container(
                                          margin: const EdgeInsets.only(bottom: 12),
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF8FAFC),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: const Color(0xFFE2E8F0)),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Expanded(
                                                    child: Row(
                                                      children: [
                                                        Icon(Icons.storefront_rounded, size: 14, color: theme.colorScheme.primary),
                                                        const SizedBox(width: 6),
                                                        Expanded(
                                                          child: Text(
                                                            sellerName + (sellerMobile.isNotEmpty ? ' (Ph: +91 $sellerMobile)' : ''),
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppColors.textPrimary),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
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
                                                        fontSize: 8.5,
                                                        fontWeight: FontWeight.w900,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 10),
                                              _buildDeliveryProgressBar(deliveryStatus),
                                              const SizedBox(height: 12),
                                              
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
                                                            border: Border.all(color: const Color(0xFFE2E8F0)),
                                                          ),
                                                          child: ClipRRect(
                                                            borderRadius: BorderRadius.circular(5),
                                                            child: Image.network(
                                                              imgUrl,
                                                              fit: BoxFit.contain,
                                                              errorBuilder: (context, error, stackTrace) =>
                                                                  const Icon(Icons.shopping_bag_outlined, size: 14, color: AppColors.textMuted),
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
                                                                const SizedBox(height: 1),
                                                                Text(
                                                                  'Variant: ${_formatItemVariantAttributes(item)}',
                                                                  maxLines: 1,
                                                                  overflow: TextOverflow.ellipsis,
                                                                  style: const TextStyle(fontSize: 10, color: AppColors.textLight, fontWeight: FontWeight.w600),
                                                                ),
                                                              ],
                                                            ],
                                                          ),
                                                        ),
                                                        const SizedBox(width: 8),
                                                        Column(
                                                          crossAxisAlignment: CrossAxisAlignment.end,
                                                          children: [
                                                            Text(
                                                              '₹${double.parse(item['order_amount']?.toString() ?? '0').toStringAsFixed(0)}',
                                                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                                                            ),
                                                            if (_hasItemDiscountPrice(item)) ...[
                                                              const SizedBox(height: 1),
                                                              Text(
                                                                '₹${double.parse(_getItemOriginalTotal(item)).toStringAsFixed(0)}',
                                                                style: const TextStyle(
                                                                  fontSize: 10,
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
                                              Container(
                                                height: 1.0,
                                                color: const Color(0xFFE2E8F0),
                                              ),
                                              const SizedBox(height: 8),
                                              
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                crossAxisAlignment: CrossAxisAlignment.end,
                                                children: [
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Row(
                                                          children: [
                                                            const Text(
                                                              'Pay: ',
                                                              style: TextStyle(fontSize: 11, color: AppColors.textLight, fontWeight: FontWeight.w500),
                                                            ),
                                                            Text(
                                                              paymentStatus,
                                                              style: TextStyle(
                                                                fontSize: 11,
                                                                fontWeight: FontWeight.w900,
                                                                color: paymentStatus.toLowerCase() == 'received' ? const Color(0xFF2E7D32) : const Color(0xFFEF6C00),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        const SizedBox(height: 4),
                                                        Row(
                                                          children: [
                                                            Icon(
                                                              (firstItem['order_payment_type']?.toString().toLowerCase() == 'cash on delivery')
                                                                  ? Icons.money_rounded
                                                                  : Icons.payment_rounded,
                                                              size: 13,
                                                              color: AppColors.textLight,
                                                            ),
                                                            const SizedBox(width: 4),
                                                            Text(
                                                              firstItem['order_payment_type']?.toString() ?? 'Online',
                                                              style: const TextStyle(
                                                                fontSize: 11,
                                                                fontWeight: FontWeight.w600,
                                                                color: AppColors.textSecondary,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        if (firstItem['order_payment_type']?.toString().toLowerCase() != 'cash on delivery' &&
                                                            firstItem['order_payment_screenshot'] != null &&
                                                            firstItem['order_payment_screenshot'].toString().trim().isNotEmpty) ...[
                                                          const SizedBox(height: 6),
                                                          InkWell(
                                                            onTap: () => _showProofDialog(firstItem['order_payment_screenshot'].toString()),
                                                            borderRadius: BorderRadius.circular(6),
                                                            child: Container(
                                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                              decoration: BoxDecoration(
                                                                color: theme.colorScheme.primary.withOpacity(0.08),
                                                                borderRadius: BorderRadius.circular(6),
                                                                border: Border.all(color: theme.colorScheme.primary.withOpacity(0.12)),
                                                              ),
                                                              child: Row(
                                                                mainAxisSize: MainAxisSize.min,
                                                                children: [
                                                                  Icon(
                                                                    Icons.receipt_long_rounded,
                                                                    size: 11,
                                                                    color: theme.colorScheme.primary,
                                                                  ),
                                                                  const SizedBox(width: 4),
                                                                  Text(
                                                                    'View Proof',
                                                                    style: TextStyle(
                                                                      fontSize: 10,
                                                                      fontWeight: FontWeight.w900,
                                                                      color: theme.colorScheme.primary,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ],
                                                    ),
                                                  ),
                                                  Text(
                                                    'Subtotal: ₹${groupSubtotal.toStringAsFixed(0)}',
                                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                      
                                      const SizedBox(height: 4),
                                      Container(
                                        height: 1.0,
                                        color: const Color(0xFFF1F5F9),
                                      ),
                                      const SizedBox(height: 8),
                                      
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textLight),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              'Shipping Address: $cleanAddress',
                                              style: const TextStyle(fontSize: 11.5, color: AppColors.textLight, fontWeight: FontWeight.w500),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ))),
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