import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../widgets/cart_button.dart';

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
  
  List<dynamic> _subcategories = [];
  List<dynamic> _brands = [];
  
  int? _selectedSubcategoryId;
  int? _selectedBrandId;
  List<Map<String, dynamic>> _cartItems = [];

  // Aligned with the database IDs of Category, Subcategory, and Brand APIs
  final List<Map<String, dynamic>> _allProducts = [
    // --- Electronics (Category ID: 1) ---
    // Mobile (Subcategory ID: 1)
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
    // Laptop (Subcategory ID: 2)
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
    // Tablet (Subcategory ID: 3)
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
    // Smart Watch (Subcategory ID: 4)
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
    // Accessories (Subcategory ID: 8)
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
    // Kitchen Appliances (Subcategory ID: 12)
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
    // Fragrances (Subcategory ID: 16)
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
    // Gym Equipment (Subcategory ID: 17)
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
    _selectedSubcategoryId = widget.subcategoryId;
    _selectedBrandId = widget.initialBrandId;
    _loadSubcategories();
    _loadBrands();
    _loadCart();
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
        setState(() {
          _brands = body['data'] ?? [];
          _isLoadingBrands = false;
        });
        return;
      }
      throw Exception();
    } catch (e) {
      debugPrint("Failed to load brands, fallback to local: $e");
      setState(() {
        _brands = [
          {"id": 2, "brands_name": "Apple"},
          {"id": 5, "brands_name": "Dell"},
          {"id": 4, "brands_name": "LG"},
          {"id": 1, "brands_name": "Samsung"},
          {"id": 3, "brands_name": "Sony"}
        ];
        _isLoadingBrands = false;
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

  void _addToCart(Map<String, dynamic> product) {
    setState(() {
      final existingIndex = _cartItems.indexWhere((item) => item['id'] == product['id']);
      if (existingIndex != -1) {
        _cartItems[existingIndex]['quantity'] = (_cartItems[existingIndex]['quantity'] ?? 1) + 1;
      } else {
        _cartItems.add({
          "id": product['id'],
          "name": product['name'],
          "price": product['price'],
          "desc": product['desc'],
          "image": product['image'],
          "quantity": 1,
        });
      }
    });
    _saveCart();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("${product['name']} added to cart!"),
        duration: const Duration(seconds: 1),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
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
    final List<Map<String, dynamic>> filtered = _allProducts.where((p) {
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
      body: Column(
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
                        color: isSelected ? Colors.white : Colors.white70,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? theme.colorScheme.secondary : AppColors.border,
                          width: isSelected ? 2.0 : 1.0,
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
                                color: theme.colorScheme.secondary.withOpacity(0.1),
                                child: const Icon(Icons.category, size: 10),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            sub['categories_subs_name'] ?? 'Subcategory',
                            style: TextStyle(
                              color: isSelected ? theme.colorScheme.secondary : AppColors.textSecondary,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white : Colors.white70,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? theme.colorScheme.primary : AppColors.border,
                          width: isSelected ? 2.0 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _getBrandIcon(brand['brands_name'] ?? ''),
                            color: isSelected ? theme.colorScheme.primary : AppColors.textLight,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            brand['brands_name'] ?? 'Brand',
                            style: TextStyle(
                              color: isSelected ? theme.colorScheme.primary : AppColors.textSecondary,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border, width: 1.5),
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
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.05),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Center(
                child: Icon(
                  _getCategoryIcon(product['image'] ?? ''),
                  size: 40,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product['name'] ?? 'Product Name',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  product['desc'] ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: AppColors.textLight, height: 1.3),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "\$${product['price']?.toStringAsFixed(2)}",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _addToCart(product),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.add_shopping_cart, color: Colors.white, size: 16),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
