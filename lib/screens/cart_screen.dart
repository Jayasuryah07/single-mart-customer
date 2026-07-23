import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../widgets/cart_button.dart';
import 'login_screen.dart';
import 'checkout_screen.dart';
import 'product_detail_screen.dart';
import 'products_list_screen.dart';

class CartScreen extends StatefulWidget {
  final bool isEmbedded;
  const CartScreen({super.key, this.isEmbedded = false});

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

  double _getCartSubtotal() {
    double total = 0.0;
    for (var item in _cartItems) {
      total += (item['price'] as double) * (item['quantity'] as int);
    }
    return total;
  }

  double _getCartSavings() {
    double totalSavings = 0.0;
    for (var item in _cartItems) {
      final double origP = _getItemOriginalPrice(item);
      final double currentP = (item['price'] is num ? item['price'] : double.tryParse(item['price']?.toString() ?? '0') ?? 0.0);
      if (origP > currentP) {
        totalSavings += (origP - currentP) * (item['quantity'] as int);
      }
    }
    return totalSavings;
  }

  double _getCartTotal() {
    return _getCartSubtotal(); // Delivery is Free
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
                  fontSize: 20,
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
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => LoginScreen(
                              isGuestMode: true,
                              cartItems: _cartItems,
                            ),
                          ),
                        ).then((_) => _loadCart());
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        'Checkout as Guest',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LoginScreen(),
                          ),
                        ).then((_) => _loadCart());
                      },
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: const BorderSide(color: AppColors.primary, width: 1.5),
                      ),
                      child: const Text(
                        'Sign In / Register',
                        style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: TextButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: AppColors.textLight, fontWeight: FontWeight.bold),
                      ),
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
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: !widget.isEmbedded,
        title: const Text(
          'Shopping Bag',
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : (_cartItems.isEmpty ? _buildEmptyCart() : _buildCartBody(context)),
    );
  }

  Widget _buildEmptyCart() {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.shopping_bag_outlined,
                size: 64,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Your shopping bag is empty',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Looks like you haven\'t added anything to your bag yet. Start exploring our premium collection!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textLight,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 180,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  if (widget.isEmbedded) {
                    // Switch tab to Home (implied in Tabbar)
                  } else {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const ProductsListScreen()),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.shopping_bag_rounded, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Start Shopping',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartBody(BuildContext context) {
    final theme = Theme.of(context);
    final double subtotal = _getCartSubtotal();
    final double savings = _getCartSavings();

    return Column(
      children: [
        // Cart Items List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            itemCount: _cartItems.length,
            itemBuilder: (context, index) {
              final item = _cartItems[index];
              final double origP = _getItemOriginalPrice(item);
              final double currentP = (item['price'] is num ? item['price'] : double.tryParse(item['price']?.toString() ?? '0') ?? 0.0);
              final double itemSavings = (origP > currentP) ? (origP - currentP) : 0.0;

              return Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.015),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Product image inside a circular/rounded thumbnail box
                    GestureDetector(
                      onTap: () => _navigateToProductDetail(item),
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9), // Light gray background
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(11),
                          child: item['product_image'] != null && item['product_image'].toString().isNotEmpty
                              ? Image.network(
                                  (item['is_variant'] == true || item['variant_id'] != null)
                                      ? "${_baseProductVariantImageUrl}${item['product_image']}"
                                      : "${_baseProductImageUrl}${item['product_image']}",
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) => Center(
                                    child: Icon(Icons.shopping_bag_rounded, color: theme.colorScheme.primary, size: 24),
                                  ),
                                )
                              : Center(
                                  child: Icon(Icons.shopping_bag_rounded, color: theme.colorScheme.primary, size: 24),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Product Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: () => _navigateToProductDetail(item),
                            child: Text(
                              item['name'],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                color: AppColors.textPrimary,
                                letterSpacing: 0.1,
                              ),
                            ),
                          ),
                          if (item['variant_attributes'] != null && item['variant_attributes'].toString().isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              'Variant: ${item['variant_attributes']}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textLight,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Text(
                                '₹${currentP.toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              if (origP > currentP) ...[
                                const SizedBox(width: 6),
                                Text(
                                  '₹${origP.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textMuted,
                                    fontWeight: FontWeight.w500,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (itemSavings > 0) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F5E9), // Light green background
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Save ₹${(itemSavings * item['quantity']).toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF2E7D32), // Green
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Quantity dial and delete button column
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Delete Bin Button
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _cartItems.removeAt(index);
                            });
                            _saveCart();
                          },
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFFF1F5F9), width: 1.0),
                            ),
                            child: const Icon(
                              Icons.delete_outline_rounded,
                              color: AppColors.error,
                              size: 18,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Quantity Control Dial
                        Row(
                          children: [
                            // Decrement circular button
                            GestureDetector(
                              onTap: () => _updateQuantity(item['id'], -1),
                              child: Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
                                ),
                                child: const Icon(
                                  Icons.remove_rounded,
                                  size: 14,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: Text(
                                '${item['quantity']}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            // Increment circular button
                            GestureDetector(
                              onTap: () => _updateQuantity(item['id'], 1),
                              child: Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.add_rounded,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        
        // Cart Bill Summary Card
        Container(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).padding.bottom > 0
                ? MediaQuery.of(context).padding.bottom + 12
                : 20,
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
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Bill Details',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  color: AppColors.textPrimary,
                  letterSpacing: 0.1,
                ),
              ),
              const SizedBox(height: 12),
              
              // Subtotal detail row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Subtotal', style: TextStyle(fontSize: 13.5, color: AppColors.textLight, fontWeight: FontWeight.w500)),
                  Text('₹${subtotal.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                ],
              ),
              const SizedBox(height: 8),

              // Savings detail row
              if (savings > 0) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(' Discount', style: TextStyle(fontSize: 13.5, color: AppColors.textLight, fontWeight: FontWeight.w500)),
                    Text('-₹${savings.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF2E7D32))),
                  ],
                ),
                const SizedBox(height: 8),
              ],

              // Delivery detail row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Delivery Charges', style: TextStyle(fontSize: 13.5, color: AppColors.textLight, fontWeight: FontWeight.w500)),
                  Text(
                    'FREE',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                      color: theme.colorScheme.secondary,
                    ),
                  ),
                ],
              ),
              
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Container(
                  height: 1.0,
                  color: const Color(0xFFF1F5F9),
                ),
              ),

              // Total detail row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Amount', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: AppColors.textPrimary)),
                  Text(
                    '₹${subtotal.toStringAsFixed(0)}',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: theme.colorScheme.primary),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),

              // Proceed checkout button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _proceedToCheckout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Text(
                        'Proceed to Checkout',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 0.1),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, size: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _navigateToProductDetail(Map<String, dynamic> item) {
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
