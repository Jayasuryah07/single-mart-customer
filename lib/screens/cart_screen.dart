import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../widgets/cart_button.dart';
import 'login_screen.dart';
import 'checkout_screen.dart';
import 'product_detail_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  List<Map<String, dynamic>> _cartItems = [];
  bool _isLoading = true;
  List<dynamic> _activeProducts = [];

  String _baseNoImageUrl = 'https://agsdemo.in/singlemartapi/public/assets/images/no_image.jpg';
  String _baseProductImageUrl = 'https://agsdemo.in/singlemartapi/public/assets/images/product_images/';
  String _baseProductVariantImageUrl = 'https://agsdemo.in/singlemartapi/public/assets/images/product_variant_images/';

  @override
  void initState() {
    super.initState();
    _loadCart();
  }

  Future<void> _loadCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _baseNoImageUrl = prefs.getString('base_no_image_url') ?? _baseNoImageUrl;
      _baseProductImageUrl = prefs.getString('base_product_image_url') ?? _baseProductImageUrl;
      _baseProductVariantImageUrl = prefs.getString('base_product_variant_image_url') ?? _baseProductVariantImageUrl;
      final String? cartStr = prefs.getString('cart_data');
      if (cartStr != null && cartStr.isNotEmpty) {
        final List<dynamic> parsed = json.decode(cartStr);
        setState(() {
          _cartItems = parsed.map((item) => Map<String, dynamic>.from(item)).toList();
        });
      }

      // Fetch active products in cart to allow detailed navigation and match missing images
      final productsResponse = await ApiService.fetchActiveProducts();
      if (productsResponse.statusCode == 200) {
        final body = json.decode(productsResponse.body);
        final List<dynamic> allProds = body['data'] ?? [];

        final dynamic imageUrls = body['image_url'];
        if (imageUrls != null && imageUrls is List) {
          for (var imgItem in imageUrls) {
            final imageFor = imgItem['image_for']?.toString();
            final url = imgItem['image_url']?.toString();
            if (imageFor != null && url != null) {
              if (imageFor == 'No Image') {
                await prefs.setString('base_no_image_url', url);
                _baseNoImageUrl = url;
              } else if (imageFor == 'Product') {
                await prefs.setString('base_product_image_url', url);
                _baseProductImageUrl = url;
              } else if (imageFor == 'Product Variant') {
                await prefs.setString('base_product_variant_image_url', url);
                _baseProductVariantImageUrl = url;
              }
            }
          }
        }

        setState(() {
          _activeProducts = allProds;
          
          for (var item in _cartItems) {
            final matched = allProds.firstWhere(
              (p) => p['id']?.toString() == item['id']?.toString(),
              orElse: () => null,
            );
            if (matched != null) {
              dynamic matchedVar;
              if (item['variant_id'] != null && matched['variants'] != null && (matched['variants'] as List).isNotEmpty) {
                matchedVar = (matched['variants'] as List).firstWhere(
                  (v) => v['id']?.toString() == item['variant_id']?.toString(),
                  orElse: () => null,
                );
              }

              if (item['product_image'] == null) {
                if (matchedVar != null && matchedVar['images'] != null && (matchedVar['images'] as List).isNotEmpty) {
                  item['product_image'] = matchedVar['images'][0]['product_variant_images']?.toString();
                  item['is_variant'] = true;
                }
                if (item['product_image'] == null && matched['images'] != null && (matched['images'] as List).isNotEmpty) {
                  item['product_image'] = matched['images'][0]['product_images']?.toString();
                }
              }

              // Resolve and inject missing original_price or product_price
              if (matchedVar != null) {
                final double discP = double.tryParse(matchedVar['product_discount_price']?.toString() ?? '') ?? 0.0;
                final double regP = double.tryParse(matchedVar['product_price']?.toString() ?? '') ?? 0.0;
                if (discP > 0 && regP > discP) {
                  item['original_price'] = regP;
                  item['product_price'] = regP;
                } else if (regP > (double.tryParse(item['price']?.toString() ?? '') ?? 0.0)) {
                  item['original_price'] = regP;
                  item['product_price'] = regP;
                }
              } else {
                final double discP = double.tryParse(matched['product_discount_price']?.toString() ?? '') ?? 0.0;
                final double regP = double.tryParse(matched['product_price']?.toString() ?? '') ?? 0.0;
                if (discP > 0 && regP > discP) {
                  item['original_price'] = regP;
                  item['product_price'] = regP;
                } else if (regP > (double.tryParse(item['price']?.toString() ?? '') ?? 0.0)) {
                  item['original_price'] = regP;
                  item['product_price'] = regP;
                }
              }
            }
          }
        });
        _saveCart();
      }
    } catch (e) {
      debugPrint("Error loading cart: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cart_data', json.encode(_cartItems));
      CartManager.updateCartCount();
    } catch (e) {
      debugPrint("Error saving cart: $e");
    }
  }

  void _updateQuantity(int productId, int delta) {
    setState(() {
      final index = _cartItems.indexWhere((item) => item['id'] == productId);
      if (index != -1) {
        final newQuantity = (_cartItems[index]['quantity'] ?? 1) + delta;
        if (newQuantity <= 0) {
          _cartItems.removeAt(index);
        } else {
          _cartItems[index]['quantity'] = newQuantity;
        }
      }
    });
    _saveCart();
  }

  double _getCartTotal() {
    double total = 0.0;
    for (var item in _cartItems) {
      total += (item['price'] as double) * (item['quantity'] as int);
    }
    return total;
  }

  Future<void> _proceedToCheckout() async {
    if (_cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Your cart is empty.")),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('auth_token');

    if (token != null && token.isNotEmpty) {
      final bool? orderPlaced = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CheckoutScreen(
            cartItems: _cartItems,
            token: token,
          ),
        ),
      );
      if (orderPlaced == true) {
        setState(() {
          _cartItems.clear();
        });
        await _saveCart();
        if (mounted) {
          Navigator.pop(context);
        }
      }
    } else {
      _showAuthRequiredDialog();
    }
  }

  void _showCheckoutSuccessDialog() {
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
                  color: AppColors.secondary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_outline_rounded,
                  color: AppColors.primary,
                  size: 50,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Order Placed!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Thank you for shopping with SingleMart! Your checkout completed successfully.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.textLight, height: 1.4),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _cartItems.clear();
                    });
                    _saveCart();
                    Navigator.pop(ctx);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Back to Home', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAuthRequiredDialog() {
    showDialog(
      context: context,
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
                  color: AppColors.error.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_outline_rounded,
                  color: AppColors.error,
                  size: 45,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Login Required',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'To secure your checkout and complete the payment, you must sign in or create an account on SingleMart.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.textLight, height: 1.4),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: const BorderSide(color: AppColors.border),
                      ),
                      child: const Text('Cancel', style: TextStyle(color: AppColors.textLight)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const LoginScreen()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Log In', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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
          'Shopping Cart',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : (_cartItems.isEmpty ? _buildEmptyCart() : _buildCartBody(theme)),
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.border.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.shopping_cart_outlined, size: 64, color: AppColors.textMuted),
          ),
          const SizedBox(height: 20),
          const Text(
            'Your cart is empty',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          const Text('Add products to your cart to start shopping!', style: TextStyle(color: AppColors.textLight)),
        ],
      ),
    );
  }

  Widget _buildCartBody(ThemeData theme) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _cartItems.length,
            itemBuilder: (context, index) {
              final item = _cartItems[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          final matched = _activeProducts.firstWhere(
                            (p) => p['id']?.toString() == item['id']?.toString(),
                            orElse: () => null,
                          );
                          if (matched != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ProductDetailScreen(product: matched),
                              ),
                            ).then((_) {
                              _loadCart();
                            });
                          } else {
                            final fallbackProduct = {
                              "id": item['id'],
                              "product_name": item['name'],
                              "product_price": item['price']?.toString(),
                              "product_short_description": item['desc'],
                              "images": item['product_image'] != null ? [
                                {
                                  "product_images": item['product_image']
                                }
                              ] : [],
                            };
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ProductDetailScreen(product: fallbackProduct),
                              ),
                            ).then((_) {
                              _loadCart();
                            });
                          }
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Row(
                          children: [
                            item['product_image'] != null && item['product_image'].toString().isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(
                                      (item['is_variant'] == true || item['variant_id'] != null)
                                          ? "${_baseProductVariantImageUrl}${item['product_image']}"
                                          : "${_baseProductImageUrl}${item['product_image']}",
                                      width: 64,
                                      height: 64,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Container(
                                          width: 64,
                                          height: 64,
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme.primary.withOpacity(0.05),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Center(
                                            child: Icon(Icons.shopping_bag_outlined, color: theme.colorScheme.primary, size: 28),
                                          ),
                                        );
                                      },
                                    ),
                                  )
                                : Container(
                                    width: 64,
                                    height: 64,
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Center(
                                      child: Icon(Icons.shopping_bag_outlined, color: theme.colorScheme.primary, size: 28),
                                    ),
                                  ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item['name'],
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                                        ),
                                      ),
                                      // Delete Button
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                                        onPressed: () {
                                          setState(() {
                                            _cartItems.removeAt(index);
                                          });
                                          _saveCart();
                                        },
                                      ),
                                    ],
                                  ),
                                  if (item['variant_attributes'] != null && item['variant_attributes'].toString().isNotEmpty) ...[
                                    Text(
                                      'Variant: ${item['variant_attributes']}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(height: 2),
                                  ],
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Text(
                                        '₹${(item['price'] is num ? item['price'] : double.tryParse(item['price']?.toString() ?? '0') ?? 0.0).toStringAsFixed(2)}',
                                        style: TextStyle(fontSize: 14, color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                                      ),
                                      if (_getItemOriginalPrice(item) > (item['price'] is num ? item['price'] : double.tryParse(item['price']?.toString() ?? '0') ?? 0.0)) ...[
                                        const SizedBox(width: 6),
                                        Text(
                                          '₹${_getItemOriginalPrice(item).toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontSize: 12,
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
                            ),
                          ],
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, size: 22, color: AppColors.textLight),
                          onPressed: () => _updateQuantity(item['id'], -1),
                        ),
                        Text(
                          '${item['quantity']}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        IconButton(
                          icon: Icon(Icons.add_circle_outline, size: 22, color: theme.colorScheme.primary),
                          onPressed: () => _updateQuantity(item['id'], 1),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        
        // Cart Summary
        Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Amount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textLight)),
                  Text(
                    '₹${_getCartTotal().toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: theme.colorScheme.primary),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _proceedToCheckout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text(
                    'Proceed to Payment',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
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
