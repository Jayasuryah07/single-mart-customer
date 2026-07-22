import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../widgets/cart_button.dart';
import 'product_detail_screen.dart';

class ProductsListScreen extends StatefulWidget {
  final int? categoryId;
  final int? subcategoryId;
  final String? subcategoryName;
  final int? initialBrandId;

  const ProductsListScreen({
    super.key,
    this.categoryId,
    this.subcategoryId,
    this.subcategoryName,
    this.initialBrandId,
  });

  @override
  State<ProductsListScreen> createState() => _ProductsListScreenState();
}

class _ProductsListScreenState extends State<ProductsListScreen> {
  bool _isLoadingSubcategories = true;
  bool _isLoadingBrands = true;
  bool _isLoadingProducts = true;

  List<dynamic> _subcategories = [];
  List<dynamic> _brands = [];
  List<dynamic> _allProducts = [];

  int? _selectedSubcategoryId;
  int? _selectedBrandId;
  List<Map<String, dynamic>> _cartItems = [];

  String _baseNoImageUrl = 'https://agsdemo.in/singlemartapi/public/assets/images/no_image.jpg';
  String _baseProductImageUrl = 'https://agsdemo.in/singlemartapi/public/assets/images/product_images/';
  String _baseProductVariantImageUrl = 'https://agsdemo.in/singlemartapi/public/assets/images/product_variant_images/';
  String _baseBrandImageUrl = 'https://agsdemo.in/singlemartapi/public/assets/images/brand_images/';

  // Default fallback mock list
  final List<Map<String, dynamic>> _fallbackProducts = [
    // --- Electronics (Category ID: 1) ---
    {
      "id": 101,
      "name": "Apple iPhone 15 Pro",
      "price": 999.0,
      "desc": "Latest model with Titanium body, Action button, and 3x optical zoom.",
      "image": "Electronics",
      "category_id": 1,
      "subcategory_id": 1,
      "brand_id": 2 // Apple
    },
    {
      "id": 102,
      "name": "Samsung Galaxy S24 Ultra",
      "price": 1099.0,
      "desc": "Premium dynamic AMOLED screen, built-in S-Pen, and Galaxy AI features.",
      "image": "Electronics",
      "category_id": 1,
      "subcategory_id": 1,
      "brand_id": 1 // Samsung
    },
    {
      "id": 103,
      "name": "Dell XPS 15 Laptop",
      "price": 1299.0,
      "desc": "Intel Core i9 powerhouse with bright OLED InfinityEdge display.",
      "image": "Electronics",
      "category_id": 1,
      "subcategory_id": 2,
      "brand_id": 5 // Dell
    },
    {
      "id": 104,
      "name": "Apple MacBook Pro M3",
      "price": 1599.0,
      "desc": "Supercharged power, incredible battery life, and Liquid Retina display.",
      "image": "Electronics",
      "category_id": 1,
      "subcategory_id": 2,
      "brand_id": 2 // Apple
    },
    {
      "id": 105,
      "name": "Apple iPad Air M2",
      "price": 599.0,
      "desc": "Ultra-thin design, liquid retina display, and lightning-fast M2 chip.",
      "image": "Electronics",
      "category_id": 1,
      "subcategory_id": 3,
      "brand_id": 2 // Apple
    },
    {
      "id": 106,
      "name": "Samsung Galaxy Tab S9",
      "price": 699.0,
      "desc": "120Hz AMOLED display with premium sound and included stylus.",
      "image": "Electronics",
      "category_id": 1,
      "subcategory_id": 3,
      "brand_id": 1 // Samsung
    },
    {
      "id": 107,
      "name": "Apple Watch Ultra 2",
      "price": 799.0,
      "desc": "Rugged titanium adventure watch with dual-frequency GPS.",
      "image": "Electronics",
      "category_id": 1,
      "subcategory_id": 4,
      "brand_id": 2 // Apple
    },
    {
      "id": 108,
      "name": "Samsung Galaxy Watch 6 Pro",
      "price": 349.0,
      "desc": "Sophisticated fitness tracking, body analysis, and sleep coaching.",
      "image": "Electronics",
      "category_id": 1,
      "subcategory_id": 4,
      "brand_id": 1 // Samsung
    },

    // --- Fashion (Category ID: 2) ---
    {
      "id": 201,
      "name": "Apple FineWoven MagSafe Wallet",
      "price": 59.0,
      "desc": "Tough microtwill card holder that snaps onto the back of your phone.",
      "image": "Fashion",
      "category_id": 2,
      "subcategory_id": 8,
      "brand_id": 2 // Apple
    },
    {
      "id": 202,
      "name": "Sony Active Haptic Smart Belt",
      "price": 49.0,
      "desc": "Provides haptic feedback rhythms for yoga and core workouts.",
      "image": "Fashion",
      "category_id": 2,
      "subcategory_id": 8,
      "brand_id": 3 // Sony
    },

    // --- Home & Kitchen (Category ID: 3) ---
    {
      "id": 301,
      "name": "LG NeoChef Convection Microwave",
      "price": 199.0,
      "desc": "Smart inverter microwave oven with uniform heating and defrost.",
      "image": "Home",
      "category_id": 3,
      "subcategory_id": 12,
      "brand_id": 4 // LG
    },
    {
      "id": 302,
      "name": "Samsung FamilyHub Smart Refrigerator",
      "price": 1999.0,
      "desc": "Premium multi-door smart fridge with screen dashboard console.",
      "image": "Home",
      "category_id": 3,
      "subcategory_id": 12,
      "brand_id": 1 // Samsung
    },

    // --- Beauty & Personal Care (Category ID: 4) ---
    {
      "id": 401,
      "name": "Apple Signature Brand Parfum",
      "price": 99.0,
      "desc": "Limited-edition designer fragrance inspired by minimalist aesthetics.",
      "image": "Beauty",
      "category_id": 4,
      "subcategory_id": 16,
      "brand_id": 2 // Apple
    },

    // --- Sports & Fitness (Category ID: 5) ---
    {
      "id": 501,
      "name": "Sony Active Gym Headband",
      "price": 29.99,
      "desc": "Sweatproof headband with integrated micro haptic feedback.",
      "image": "Sports",
      "category_id": 5,
      "subcategory_id": 17,
      "brand_id": 3 // Sony
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadBaseUrls();
    _selectedSubcategoryId = widget.subcategoryId;
    _selectedBrandId = widget.initialBrandId;
    _loadSubcategories();
    _loadBrands();
    _loadProducts();
    _loadCart();
  }

  Future<void> _loadBaseUrls() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _baseNoImageUrl = prefs.getString('base_no_image_url') ?? _baseNoImageUrl;
        _baseProductImageUrl = prefs.getString('base_product_image_url') ?? _baseProductImageUrl;
        _baseBrandImageUrl = prefs.getString('base_brand_image_url') ?? _baseBrandImageUrl;
      });
    } catch (_) {}
  }

  Future<void> _loadSubcategories() async {
    try {
      final response = await ApiService.fetchActiveSubCategories();
      if (response.statusCode == 200) {
        final Map<String, dynamic> body = json.decode(response.body);
        final List<dynamic> allSubs = body['data'] ?? [];
        setState(() {
          if (widget.categoryId != null) {
            _subcategories = allSubs.where((s) => s['category_id'] == widget.categoryId).toList();
          } else {
            _subcategories = allSubs;
          }
          _isLoadingSubcategories = false;
        });
        return;
      }
      throw Exception();
    } catch (e) {
      debugPrint("Failed to load subcategories, fallback: $e");
      final List<dynamic> localFallbacks = [
        {"id": 14, "category_id": 4, "categories_subs_name": "Hair Care"},
        {"id": 13, "category_id": 4, "categories_subs_name": "Skincare"},
        {"id": 16, "category_id": 4, "categories_subs_name": "Fragrances"},
        {"id": 1, "category_id": 1, "categories_subs_name": "Mobile"},
        {"id": 2, "category_id": 1, "categories_subs_name": "Laptop"},
        {"id": 3, "category_id": 1, "categories_subs_name": "Tablet"},
        {"id": 4, "category_id": 1, "categories_subs_name": "Smart Watch"},
        {"id": 8, "category_id": 2, "categories_subs_name": "Accessories"},
        {"id": 7, "category_id": 2, "categories_subs_name": "Footwear"},
        {"id": 12, "category_id": 3, "categories_subs_name": "Kitchen Appliances"},
        {"id": 10, "category_id": 3, "categories_subs_name": "Cookware"},
        {"id": 17, "category_id": 5, "categories_subs_name": "Gym Equipment"}
      ];
      setState(() {
        if (widget.categoryId != null) {
          _subcategories = localFallbacks.where((s) => s['category_id'] == widget.categoryId).toList();
        } else {
          _subcategories = localFallbacks;
        }
        _isLoadingSubcategories = false;
      });
    }
  }

  Future<void> _loadBrands() async {
    try {
      final response = await ApiService.fetchActiveBrands();
      if (response.statusCode == 200) {
        final Map<String, dynamic> body = json.decode(response.body);
        final List<dynamic> allBrands = body['data'] ?? [];

        final dynamic imageUrls = body['image_url'];
        if (imageUrls != null && imageUrls is List) {
          final prefs = await SharedPreferences.getInstance();
          for (var item in imageUrls) {
            final imageFor = item['image_for']?.toString();
            final url = item['image_url']?.toString();
            if (imageFor == 'Brand' && url != null) {
              _baseBrandImageUrl = url;
              await prefs.setString('base_brand_image_url', url);
            }
          }
        }

        setState(() {
          _brands = allBrands;
          _isLoadingBrands = false;
        });
        return;
      }
      throw Exception();
    } catch (e) {
      debugPrint("Failed to load brands, fallback to local: $e");
      setState(() {
        _brands = [
          {"id": 2, "brands_name": "Apple", "brands_image": null},
          {"id": 17, "brands_name": "Apple Airpods", "brands_image": "17_B_20260721_154128.png"},
          {"id": 8, "brands_name": "ASUS", "brands_image": "8_B_20260721_132706.jpg"},
          {"id": 5, "brands_name": "Dell", "brands_image": "5_B_20260713_155704.jpg"},
          {"id": 10, "brands_name": "HP", "brands_image": "10_B_20260721_133303.jpg"},
          {"id": 14, "brands_name": "Levi's", "brands_image": "14_B_20260721_173351.jpg"},
          {"id": 4, "brands_name": "LG", "brands_image": null},
          {"id": 9, "brands_name": "Logitech", "brands_image": "9_B_20260721_133159.jpg"},
          {"id": 11, "brands_name": "Nike", "brands_image": "11_B_20260721_142959.jpg"},
          {"id": 13, "brands_name": "OnePlus", "brands_image": "13_B_20260721_143128.png"},
          {"id": 7, "brands_name": "Redmi", "brands_image": "7_B_20260721_131703.jpg"},
          {"id": 15, "brands_name": "Reebok", "brands_image": "15_B_20260721_150442.jpg"},
          {"id": 16, "brands_name": "Reebok club C85", "brands_image": "16_B_20260721_150545.jpg"},
          {"id": 1, "brands_name": "Samsung", "brands_image": null},
          {"id": 3, "brands_name": "Sony", "brands_image": null},
          {"id": 12, "brands_name": "Tissot", "brands_image": "12_B_20260721_143102.png"},
          {"id": 6, "brands_name": "tvbvgg", "brands_image": "6_B_20260715_100417.jpg"}
        ];
        _isLoadingBrands = false;
      });
    }
  }

  Future<void> _loadProducts() async {
    try {
      final response = await ApiService.fetchActiveProducts();
      if (response.statusCode == 200) {
        final Map<String, dynamic> body = json.decode(response.body);
        final List<dynamic> allProds = body['data'] ?? [];
        
        final dynamic imageUrls = body['image_url'];
        if (imageUrls != null && imageUrls is List) {
          final prefs = await SharedPreferences.getInstance();
          for (var item in imageUrls) {
            final imageFor = item['image_for']?.toString();
            final url = item['image_url']?.toString();
            if (imageFor != null && url != null) {
              if (imageFor == 'No Image') {
                await prefs.setString('base_no_image_url', url);
                _baseNoImageUrl = url;
              } else if (imageFor == 'User') {
                await prefs.setString('base_user_image_url', url);
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
        if (allProds.isNotEmpty) {
          setState(() {
            _allProducts = allProds.map((p) {
              final Map<String, dynamic> itemMap = Map<String, dynamic>.from(p);

              final bool hasVariants = (p['has_variants'] == 1 || p['has_variants'] == '1') &&
                  p['variants'] != null &&
                  (p['variants'] as List).isNotEmpty;

              double pPrice = 0.0;
              double pOriginalPrice = 0.0;

              if (hasVariants) {
                final firstVar = (p['variants'] as List).first;
                final double discPrice = double.tryParse(firstVar['product_discount_price']?.toString() ?? '') ?? 0.0;
                final double regPrice = double.tryParse(firstVar['product_price']?.toString() ?? '') ?? 0.0;
                if (discPrice > 0 && discPrice < regPrice) {
                  pPrice = discPrice;
                  pOriginalPrice = regPrice;
                } else {
                  pPrice = discPrice > 0 ? discPrice : regPrice;
                  pOriginalPrice = (regPrice > pPrice) ? regPrice : 0.0;
                }
              } else {
                final double discPrice = double.tryParse(p['product_discount_price']?.toString() ?? '') ?? 0.0;
                final double regPrice = double.tryParse(p['product_price']?.toString() ?? '') ?? 0.0;
                if (discPrice > 0 && discPrice < regPrice) {
                  pPrice = discPrice;
                  pOriginalPrice = regPrice;
                } else {
                  pPrice = discPrice > 0 ? discPrice : regPrice;
                  pOriginalPrice = (regPrice > pPrice) ? regPrice : 0.0;
                }
              }

              itemMap["id"] = p['id'];
              itemMap["name"] = p['product_name'] ?? 'Product';
              itemMap["price"] = pPrice;
              itemMap["original_price"] = pOriginalPrice;
              itemMap["desc"] = p['product_short_description'] ?? '';
              itemMap["image"] = p['categories_name'] ?? '';
              itemMap["category_id"] = p['product_category_id'];
              itemMap["subcategory_id"] = p['product_sub_category_id'];
              itemMap["brand_id"] = p['product_brand_id'];
              itemMap["product_vendor_id"] = p['product_vendor_id'];

              return itemMap;
            }).toList();
            _isLoadingProducts = false;
          });
          return;
        }
      }
      throw Exception();
    } catch (e) {
      debugPrint("Failed to fetch backend products, loading fallbacks: $e");
      setState(() {
        _allProducts = List.from(_fallbackProducts);
        _isLoadingProducts = false;
      });
    }
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

  Future<void> _saveCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cart_data', json.encode(_cartItems));
      CartManager.updateCartCount();
    } catch (e) {
      debugPrint("Error saving cart: $e");
    }
  }

  Future<void> _addToCart(Map<String, dynamic> product) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? cartStr = prefs.getString('cart_data');
      List<Map<String, dynamic>> currentCart = [];
      if (cartStr != null && cartStr.isNotEmpty) {
        final List<dynamic> parsed = json.decode(cartStr);
        currentCart = parsed.map((item) => Map<String, dynamic>.from(item)).toList();
      }

      String? productImg;
      if (product['images'] != null && product['images'] is List && (product['images'] as List).isNotEmpty) {
        productImg = product['images'][0]['product_images']?.toString();
      }

      final bool hasVars = (product['has_variants'] == 1 || product['has_variants'] == '1') &&
          product['variants'] != null && (product['variants'] as List).isNotEmpty;
      final dynamic firstVarId = hasVars ? product['variants'][0]['id'] : null;

      setState(() {
        final existingIndex = currentCart.indexWhere((item) => item['id'] == product['id']);
        if (existingIndex != -1) {
          currentCart[existingIndex]['quantity'] = (currentCart[existingIndex]['quantity'] ?? 1) + 1;
        } else {
          currentCart.add({
            "id": product['id'],
            "variant_id": firstVarId,
            "order_product_variant_id": firstVarId,
            "is_variant": hasVars,
            "name": product['name'],
            "price": product['price'],
            "original_price": product['original_price'],
            "product_price": product['product_price'],
            "desc": product['desc'],
            "image": product['image'],
            "quantity": 1,
            "product_vendor_id": product['product_vendor_id'],
            "product_image": productImg,
          });
        }
        _cartItems = currentCart;
      });

      await prefs.setString('cart_data', json.encode(currentCart));
      CartManager.updateCartCount();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("${product['name']} added to cart!"),
          duration: const Duration(seconds: 1),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      debugPrint("Error adding to cart: $e");
    }
  }

  IconData _getCategoryIcon(String name) {
    name = name.toLowerCase();
    if (name.contains("beauty") || name.contains("personal")) {
      return Icons.face;
    } else if (name.contains("electro")) {
      return Icons.devices;
    } else if (name.contains("fashion") || name.contains("cloth")) {
      return Icons.checkroom;
    } else if (name.contains("home") || name.contains("kitchen")) {
      return Icons.home_max_outlined;
    } else if (name.contains("sport") || name.contains("fit")) {
      return Icons.sports_gymnastics_rounded;
    }
    return Icons.shopping_bag_outlined;
  }

  IconData _getBrandIcon(String name) {
    name = name.toLowerCase();
    if (name.contains("apple")) return Icons.apple;
    if (name.contains("samsung")) return Icons.phone_android;
    if (name.contains("sony")) return Icons.settings_input_hdmi;
    if (name.contains("dell")) return Icons.laptop_chromebook;
    if (name.contains("lg")) return Icons.tv_rounded;
    return Icons.star_border_rounded;
  }

  String _getSubcategoryImage(dynamic subsImage) {
    if (subsImage == null || subsImage.toString().isEmpty) {
      return 'https://agsdemo.in/singlemartapi/public/assets/images/no_image.jpg';
    }
    final String pathStr = subsImage.toString();
    if (pathStr.startsWith('/tmp') || pathStr.startsWith('/var') || pathStr.contains('/')) {
      if (!pathStr.contains('category_images') && (pathStr.startsWith('/') || pathStr.startsWith('\\'))) {
        return 'https://agsdemo.in/singlemartapi/public/assets/images/no_image.jpg';
      }
    }
    return 'https://agsdemo.in/singlemartapi/public/assets/images/category_images/$pathStr';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Apply Filter Logic dynamically
    final List<dynamic> filtered = _allProducts.where((p) {
      if (widget.categoryId != null && p['category_id'] != widget.categoryId) {
        return false;
      }
      if (_selectedSubcategoryId != null && p['subcategory_id'] != _selectedSubcategoryId) {
        return false;
      }
      if (_selectedBrandId != null && p['brand_id'] != _selectedBrandId) {
        return false;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFFAFBFD),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: Text(
          widget.subcategoryName ?? 'Products',
          style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: const [
          CartButton(),
          SizedBox(width: 12),
        ],
      ),
      body: _isLoadingProducts
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Subcategories Filter Bar (Dual header)
                if (!_isLoadingSubcategories && _subcategories.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Text(
                      'Subcategories',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                  ),
                  Container(
                    height: 52,
                    margin: const EdgeInsets.only(bottom: 6),
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _subcategories.length,
                      itemBuilder: (context, index) {
                        final sub = _subcategories[index];
                        final bool isSelected = _selectedSubcategoryId == sub['id'];
                        final String imageUrl = _getSubcategoryImage(sub['categories_subs_image']);
                        
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _selectedSubcategoryId = null;
                              } else {
                                _selectedSubcategoryId = sub['id'];
                              }
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: isSelected ? theme.colorScheme.primary : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? theme.colorScheme.primary : const Color(0xFFE2E8F0),
                                width: 1.0,
                              ),
                            ),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.network(
                                    imageUrl,
                                    width: 22,
                                    height: 22,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => Container(
                                      width: 22,
                                      height: 22,
                                      color: isSelected ? Colors.white24 : theme.colorScheme.primary.withOpacity(0.08),
                                      child: Icon(Icons.category_rounded, size: 12, color: isSelected ? Colors.white : theme.colorScheme.primary),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  constraints: const BoxConstraints(maxWidth: 100),
                                  child: Text(
                                    sub['categories_subs_name'] ?? 'Subcategory',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : AppColors.textSecondary,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      fontSize: 12,
                                    ),
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

                // 2. Brand Filter Row (Dual header)
                if (!_isLoadingBrands && _brands.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Text(
                      'Brands',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                  ),
                  Container(
                    height: 52,
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _brands.length,
                      itemBuilder: (context, index) {
                        final brand = _brands[index];
                        final bool isSelected = _selectedBrandId == brand['id'];
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _selectedBrandId = null;
                              } else {
                                _selectedBrandId = brand['id'];
                              }
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected ? theme.colorScheme.primary : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? theme.colorScheme.primary : const Color(0xFFE2E8F0),
                                width: 1.0,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: isSelected ? Colors.white24 : const Color(0xFFF2F2F4),
                                    shape: BoxShape.circle,
                                  ),
                                  child: ClipOval(
                                    child: _getBrandImage(brand['brands_image']).isNotEmpty
                                        ? Image.network(
                                            _getBrandImage(brand['brands_image']),
                                            fit: BoxFit.contain,
                                            errorBuilder: (context, error, stackTrace) => Icon(
                                              Icons.star_rounded,
                                              color: isSelected ? Colors.white : theme.colorScheme.primary,
                                              size: 12,
                                            ),
                                          )
                                        : Center(
                                            child: Text(
                                              (brand['brands_name']?.toString().substring(0, min(1, brand['brands_name']?.toString().length ?? 1)) ?? 'B').toUpperCase(),
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: isSelected ? Colors.white : theme.colorScheme.primary,
                                              ),
                                            ),
                                          ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  brand['brands_name'] ?? 'Brand',
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : AppColors.textSecondary,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    fontSize: 12,
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

                // Grid list
                Expanded(
                  child: filtered.isEmpty
                      ? _buildEmptyState()
                      : GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: MediaQuery.of(context).size.width > 800 ? 4 : 2,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 0.72,
                          ),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final prod = filtered[index];
                            return _buildProductCard(prod, theme);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildEmptyState() {
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
            child: const Icon(Icons.search_off_rounded, size: 64, color: AppColors.textLight),
          ),
          const SizedBox(height: 20),
          const Text(
            'No product found',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          const Text('Check back later or remove active filters.', style: TextStyle(color: AppColors.textLight)),
        ],
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product, ThemeData theme) {
    // Construct real product or variant network image path
    final bool hasVariants = (product['has_variants'] == 1 || product['has_variants'] == '1') &&
        product['variants'] != null &&
        (product['variants'] as List).isNotEmpty;

    String imageUrl = _baseNoImageUrl;
    if (hasVariants) {
      final firstVar = (product['variants'] as List).first;
      final varImages = firstVar['images'];
      if (varImages != null && varImages is List && varImages.isNotEmpty) {
        final String? filename = varImages[0]['product_variant_images'];
        if (filename != null && filename.isNotEmpty) {
          imageUrl = '$_baseProductVariantImageUrl$filename';
        }
      } else {
        final prodImages = product['images'];
        if (prodImages != null && prodImages is List && prodImages.isNotEmpty) {
          final String? filename = prodImages[0]['product_images'];
          if (filename != null && filename.isNotEmpty) {
            imageUrl = '$_baseProductImageUrl$filename';
          }
        }
      }
    } else {
      final images = product['images'];
      if (images != null && images is List && images.isNotEmpty) {
        final String? filename = images[0]['product_images'];
        if (filename != null && filename.isNotEmpty) {
          imageUrl = '$_baseProductImageUrl$filename';
        }
      }
    }

    final double price = product['price'] is num 
        ? (product['price'] as num).toDouble() 
        : (double.tryParse(product['price']?.toString() ?? '0') ?? 0.0);
    final double? originalPrice = product['original_price'] is num 
        ? (product['original_price'] as num).toDouble() 
        : (double.tryParse(product['original_price']?.toString() ?? '') ?? null);

    final hasDiscount = originalPrice != null && originalPrice > price;

    final String brandName = _getBrandName(product['brand_id']);
    final String prodName = product['name'] ?? 'Product Name';

    // Fetch review ratings dynamically
    final List<dynamic> reviewsList = product['review'] is List ? product['review'] : [];
    double rating = 4.0;
    int ratingCount = 0;
    if (reviewsList.isNotEmpty) {
      double sum = 0.0;
      for (var r in reviewsList) {
        final val = double.tryParse(r['product_rating']?.toString() ?? '0') ?? 0.0;
        sum += val;
      }
      rating = sum / reviewsList.length;
      ratingCount = reviewsList.length;
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailScreen(product: product),
          ),
        ).then((_) {
          CartManager.updateCartCount();
          _loadCart();
        });
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Image Container with Rating overlay
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    // Product image
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.contain,
                          cacheWidth: 300,
                          cacheHeight: 350,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: theme.colorScheme.primary.withOpacity(0.05),
                            child: Icon(
                              _getCategoryIcon(product['image'] ?? ''),
                              size: 40,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Rating overlay at bottom left - only show if there is at least 1 review
                    if (ratingCount > 0)
                      Positioned(
                        left: 8,
                        bottom: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                rating.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 2),
                              const Icon(
                                Icons.star_rounded,
                                color: Color(0xFF008C45), // Flipkart green star
                                size: 10,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                "(${_formatNumber(ratingCount)})",
                                style: const TextStyle(
                                  fontSize: 9.0,
                                  color: AppColors.textLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          
          // 2. RichText Title (Bold Brand + Regular Name)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: RichText(
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                style: const TextStyle(fontSize: 13.0, height: 1.2),
                children: [
                  if (brandName.isNotEmpty)
                    TextSpan(
                      text: '$brandName ',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  TextSpan(
                    text: prodName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      color: AppColors.textLight,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),

          // 3. Price Display Row (Slashed Original + Bold Final)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                if (hasDiscount) ...[
                  Text(
                    _formatNumber(originalPrice.round()),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textLight,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  "₹${_formatNumber(price.round())}",
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  String _getBrandName(dynamic brandId) {
    if (brandId == null) return '';
    final id = int.tryParse(brandId.toString());
    if (id == null) return '';
    final brand = _brands.firstWhere((b) => b['id'] == id, orElse: () => null);
    if (brand != null) {
      return brand['brand_name'] ?? brand['brands_name'] ?? '';
    }
    if (id == 1) return 'Samsung';
    if (id == 2) return 'Apple';
    if (id == 3) return 'Sony';
    if (id == 4) return 'LG';
    if (id == 5) return 'Dell';
    return '';
  }

  String _getBrandImage(dynamic brandsImage) {
    if (brandsImage == null || brandsImage.toString().isEmpty) {
      return '';
    }
    final String pathStr = brandsImage.toString();
    if (pathStr.startsWith('/tmp') || pathStr.startsWith('/var') || pathStr.contains('/')) {
      if (!pathStr.contains('brand_images') && (pathStr.startsWith('/') || pathStr.startsWith('\\'))) {
        return '';
      }
    }
    return '${_baseBrandImageUrl}$pathStr';
  }

  String _formatNumber(int number) {
    final str = number.toString();
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return str.replaceAllMapped(reg, (Match m) => "${m[1]},");
  }
}
