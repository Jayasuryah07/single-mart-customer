import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';
import '../widgets/cart_button.dart';

class ProductDetailScreen extends StatefulWidget {
  final Map<String, dynamic> product;
  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _quantity = 1;
  int _selectedImageIndex = 0;
  final PageController _detailPageController = PageController();
  List<Map<String, dynamic>> _cartItems = [];

  @override
  void initState() {
    super.initState();
    _loadCart();
  }

  @override
  void dispose() {
    _detailPageController.dispose();
    super.dispose();
  }

  Future<void> _loadCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? cartStr = prefs.getString('cart_data');
      if (cartStr != null && cartStr.isNotEmpty) {
        final List<dynamic> parsed = json.decode(cartStr);
        setState(() {
          _cartItems = parsed.map((item) => Map<String, dynamic>.from(item)).toList();
        });
      }
    } catch (e) {
      debugPrint("Error loading cart: $e");
    }
  }

  Future<void> _addToCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? cartStr = prefs.getString('cart_data');
      List<Map<String, dynamic>> currentCart = [];
      if (cartStr != null && cartStr.isNotEmpty) {
        final List<dynamic> parsed = json.decode(cartStr);
        currentCart = parsed.map((item) => Map<String, dynamic>.from(item)).toList();
      }

      final double price = double.tryParse(widget.product['product_discount_price']?.toString() ?? '') ??
          double.tryParse(widget.product['product_price']?.toString() ?? '') ??
          double.tryParse(widget.product['price']?.toString() ?? '') ??
          0.0;

      String? productImg;
      if (widget.product['images'] != null && widget.product['images'] is List && (widget.product['images'] as List).isNotEmpty) {
        productImg = widget.product['images'][0]['product_images']?.toString();
      }

      setState(() {
        final existingIndex = currentCart.indexWhere((item) => item['id'] == widget.product['id']);
        if (existingIndex != -1) {
          currentCart[existingIndex]['quantity'] = (currentCart[existingIndex]['quantity'] ?? 1) + _quantity;
        } else {
          currentCart.add({
            "id": widget.product['id'],
            "name": widget.product['product_name'] ?? widget.product['name'] ?? 'Product',
            "price": price,
            "desc": widget.product['product_short_description'] ?? widget.product['desc'] ?? '',
            "image": widget.product['categories_name'] ?? widget.product['image'] ?? 'Products',
            "quantity": _quantity,
            "product_vendor_id": widget.product['product_vendor_id'],
            "created_by": widget.product['created_by'],
            "vendor_id": widget.product['vendor_id'] ?? widget.product['created_by'],
            "product_image": productImg,
          });
        }
        _cartItems = currentCart;
        _quantity = 1;
      });

      await prefs.setString('cart_data', json.encode(currentCart));
      CartManager.updateCartCount();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("${widget.product['product_name'] ?? widget.product['name'] ?? 'Product'} added to cart!"),
          duration: const Duration(seconds: 2),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      debugPrint("Error adding to cart: $e");
    }
  }

  List<String> _getProductImageUrls() {
    final List<String> urls = [];
    final images = widget.product['images'];
    if (images != null && images is List && images.isNotEmpty) {
      for (var img in images) {
        final String? filename = img['product_images'];
        if (filename != null && filename.isNotEmpty) {
          urls.add('https://agsdemo.in/singlemartapi/public/assets/images/product_images/$filename');
        }
      }
    }
    if (urls.isEmpty) {
      urls.add('https://agsdemo.in/singlemartapi/public/assets/images/no_image.jpg');
    }
    return urls;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final List<String> imageUrls = _getProductImageUrls();

    // Safe bounds check
    if (_selectedImageIndex >= imageUrls.length) {
      _selectedImageIndex = 0;
    }

    final String name = widget.product['product_name'] ?? widget.product['name'] ?? 'Product Detail';
    final String vendor = widget.product['vendor_name'] ?? 'SingleMart Merchant';
    final String category = widget.product['categories_name'] ?? widget.product['image'] ?? 'General';
    final String subcategory = widget.product['categories_subs_name'] ?? 'General Sub';
    final String brand = widget.product['brands_name'] ?? 'Generic';
    final String shortDesc = widget.product['product_short_description'] ?? widget.product['desc'] ?? '';
    final String longDesc = widget.product['product_long_description'] ?? '';
    final String stockStatus = widget.product['product_status'] ?? 'In Stock';

    final double price = double.tryParse(widget.product['product_price']?.toString() ?? '') ??
        double.tryParse(widget.product['price']?.toString() ?? '') ??
        0.0;
    final double? discountPrice = double.tryParse(widget.product['product_discount_price']?.toString() ?? '');

    return Scaffold(
      backgroundColor: const Color(0xFFFAFBFD),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: Text(
          name,
          style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: const [
          CartButton(),
          SizedBox(width: 12),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Main product image container (Swipe scroll enabled PageView)
                  Container(
                    height: 280,
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.border, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.01),
                          blurRadius: 15,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: PageView.builder(
                        controller: _detailPageController,
                        itemCount: imageUrls.length,
                        onPageChanged: (index) {
                          setState(() {
                            _selectedImageIndex = index;
                          });
                        },
                        itemBuilder: (context, index) {
                          return Image.network(
                            imageUrls[index],
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: theme.colorScheme.primary.withOpacity(0.05),
                              child: Icon(Icons.broken_image_rounded, color: theme.colorScheme.primary, size: 64),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  
                  // Interactive scrollable thumbnail selector below the main view
                  if (imageUrls.length > 1) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 65,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: imageUrls.length,
                        itemBuilder: (context, index) {
                          final bool isSelected = index == _selectedImageIndex;
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedImageIndex = index;
                              });
                              _detailPageController.animateToPage(
                                index,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                            child: Container(
                              width: 60,
                              height: 60,
                              margin: const EdgeInsets.only(right: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected ? theme.colorScheme.primary : AppColors.border,
                                  width: isSelected ? 2.5 : 1.5,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  imageUrls[index],
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 24),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),

                  // Content metadata details container block
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Brand name and Stock Status
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                brand.toUpperCase(),
                                style: TextStyle(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: stockStatus.toLowerCase().contains("out") 
                                    ? AppColors.error.withOpacity(0.1) 
                                    : Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                stockStatus,
                                style: TextStyle(
                                  color: stockStatus.toLowerCase().contains("out") 
                                      ? AppColors.error 
                                      : Colors.green,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Product Title
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Highlighted Category & Subcategory Pill Badges
                        Wrap(
                          spacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                category,
                                style: TextStyle(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.textLight),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.secondary.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                subcategory,
                                style: TextStyle(
                                  color: theme.colorScheme.secondary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Price block (Indian Rupees ₹)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            if (discountPrice != null && discountPrice > 0) ...[
                              Text(
                                "₹${discountPrice.toStringAsFixed(2)}",
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                "₹${price.toStringAsFixed(2)}",
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textLight,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                            ] else ...[
                              Text(
                                "₹${price.toStringAsFixed(2)}",
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ]
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Merchant/Vendor Info
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border, width: 1.5),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: theme.colorScheme.secondary.withOpacity(0.1),
                                child: Icon(Icons.storefront_rounded, color: theme.colorScheme.secondary),
                              ),
                              const SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Sold By',
                                    style: TextStyle(fontSize: 11, color: AppColors.textLight, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    vendor,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Short Description
                        if (shortDesc.isNotEmpty) ...[
                          const Text(
                            'Overview',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            shortDesc,
                            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
                          ),
                          const SizedBox(height: 24),
                        ],

                        // Long Description
                        if (longDesc.isNotEmpty) ...[
                          const Text(
                            'Specifications',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            longDesc,
                            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Bar for Add to Cart and Quantities
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppColors.border, width: 1.5)),
            ),
            child: Row(
              children: [
                // Quantity Counter
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove, size: 18),
                        onPressed: () {
                          if (_quantity > 1) {
                            setState(() => _quantity--);
                          }
                        },
                      ),
                      Text(
                        '$_quantity',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add, size: 18),
                        onPressed: () {
                          setState(() => _quantity++);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),

                // Add to Cart Button
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _addToCart,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.add_shopping_cart, color: Colors.white),
                      label: const Text(
                        'Add to Cart',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
