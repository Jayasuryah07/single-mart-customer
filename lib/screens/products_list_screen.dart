import 'dart:convert';
import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../widgets/cart_button.dart';
import 'product_detail_screen.dart';
import 'ecommerce_home_screen.dart';
import 'filter_screen.dart';
import 'cart_screen.dart';
import 'login_screen.dart';

class ProductsListScreen extends StatefulWidget {
  final int? categoryId;
  final int? subcategoryId;
  final String? subcategoryName;
  final int? initialBrandId;
  final bool isEmbedded;

  const ProductsListScreen({
    super.key,
    this.categoryId,
    this.subcategoryId,
    this.subcategoryName,
    this.initialBrandId,
    this.isEmbedded = false,
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

  final Set<int> _selectedCategoryIds = {};
  final Set<int> _selectedSubcategoryIds = {};
  final Set<int> _selectedBrandIds = {};
  bool _showInlineFilters = false;
  List<Map<String, dynamic>> _cartItems = [];

  List<dynamic> _categories = [];
  bool _isLoggedIn = false;
  Map<String, dynamic>? _userData;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<double> _filtersHeightNotifier = ValueNotifier<double>(282.0);
  double _lastScrollOffset = 0.0;

  final ValueNotifier<int?> _activeCategoryId = ValueNotifier<int?>(null);
  final ValueNotifier<int?> _hoveredCategoryIndex = ValueNotifier<int?>(null);
  Timer? _menuCloseTimer;

  void _scrollListener() {
    if (!mounted) return;
    final double currentOffset = _scrollController.offset;
    final double delta = currentOffset - _lastScrollOffset;

    final List<dynamic> displayedCats = _selectedCategoryIds.isEmpty
        ? _categories
        : _categories.where((c) => _selectedCategoryIds.contains(c['id'])).toList();

    final List<dynamic> displayedSubs = _selectedSubcategoryIds.isEmpty
        ? (_selectedCategoryIds.isEmpty
            ? _subcategories
            : _subcategories.where((s) => _selectedCategoryIds.contains(s['category_id'])).toList())
        : _subcategories.where((s) => _selectedSubcategoryIds.contains(s['id'])).toList();

    final List<dynamic> displayedBrnds = _selectedBrandIds.isEmpty
        ? (_selectedCategoryIds.isEmpty
            ? _brands
            : _brands.where((b) {
                final int brandId = b['id'];
                return _allProducts.any((p) {
                  final int? pCatId = p['category_id'] != null ? int.tryParse(p['category_id'].toString()) : null;
                  final int? pBrandId = p['brand_id'] != null ? int.tryParse(p['brand_id'].toString()) : null;
                  return _selectedCategoryIds.contains(pCatId) && pBrandId == brandId;
                });
              }).toList())
        : _brands.where((b) => _selectedBrandIds.contains(b['id'])).toList();

    final double maxFiltersHeight = _getQuickFiltersHeight(displayedCats, displayedSubs, displayedBrnds);

    if (maxFiltersHeight > 0) {
      _filtersHeightNotifier.value = (_filtersHeightNotifier.value - delta).clamp(0.0, maxFiltersHeight);
    }
    _lastScrollOffset = currentOffset;
  }

  double _getQuickFiltersHeight(List<dynamic> displayedCategories, List<dynamic> displayedSubcategories, List<dynamic> displayedBrands) {
    double h = 0.0;
    if (displayedCategories.isNotEmpty) h += 92.0;
    if (!_isLoadingSubcategories && displayedSubcategories.isNotEmpty) h += 92.0;
    if (!_isLoadingBrands && displayedBrands.isNotEmpty) h += 98.0;
    return h;
  }

  Future<void> _loadSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('auth_token');
      final String? userDataStr = prefs.getString('user_data');
      if (token != null && token.isNotEmpty && userDataStr != null && userDataStr.isNotEmpty) {
        setState(() {
          _isLoggedIn = true;
          _userData = json.decode(userDataStr);
        });
      } else {
        setState(() {
          _isLoggedIn = false;
          _userData = null;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadCategories() async {
    try {
      final response = await ApiService.fetchActiveCategories();
      if (response.statusCode == 200) {
        final Map<String, dynamic> body = json.decode(response.body);
        setState(() {
          _categories = body['data'] ?? [];
        });
      }
    } catch (_) {}
  }

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
    if (widget.categoryId != null) {
      _selectedCategoryIds.add(widget.categoryId!);
    }
    if (widget.subcategoryId != null) {
      _selectedSubcategoryIds.add(widget.subcategoryId!);
    }
    if (widget.initialBrandId != null) {
      _selectedBrandIds.add(widget.initialBrandId!);
    }
    _loadSubcategories();
    _loadBrands();
    _loadProducts();
    _loadCart();
    _loadSession();
    _loadCategories();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _filtersHeightNotifier.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
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
      final String? cartStr = await CartManager.getCartData();
      if (cartStr != null && cartStr.isNotEmpty) {
        final List<dynamic> parsed = json.decode(cartStr);
        setState(() {
          _cartItems = List<Map<String, dynamic>>.from(
            parsed.map((item) => Map<String, dynamic>.from(item))
          );
        });
      }
    } catch (e) {
      debugPrint("Error loading cart: $e");
    }
  }

  Future<void> _saveCart() async {
    try {
      await CartManager.setCartData(json.encode(_cartItems));
    } catch (e) {
      debugPrint("Error saving cart: $e");
    }
  }

  Future<void> _addToCart(Map<String, dynamic> product) async {
    try {
      final String? cartStr = await CartManager.getCartData();
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

      await CartManager.setCartData(json.encode(currentCart));

      ShowSnackBar.show(context, "${product['name']} added to cart!");
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
    final bool isDesktop = MediaQuery.of(context).size.width > 850;

    // Apply Filter Logic dynamically
    final List<dynamic> filtered = _allProducts.where((p) {
      if (_selectedCategoryIds.isNotEmpty) {
        if (!_selectedCategoryIds.contains(p['category_id'])) {
          return false;
        }
      } else if (widget.categoryId != null) {
        if (p['category_id'] != widget.categoryId) {
          return false;
        }
      }
      if (_selectedSubcategoryIds.isNotEmpty) {
        if (!_selectedSubcategoryIds.contains(p['subcategory_id'])) {
          return false;
        }
      }
      if (_selectedBrandIds.isNotEmpty) {
        if (!_selectedBrandIds.contains(p['brand_id'])) {
          return false;
        }
      }
      return true;
    }).toList();

    // Apply dynamic visibility filters: if any filter is selected, show only that selected one.
    final List<dynamic> displayedCategories = _selectedCategoryIds.isEmpty
        ? _categories
        : _categories.where((c) => _selectedCategoryIds.contains(c['id'])).toList();

    final List<dynamic> displayedSubcategories = _selectedSubcategoryIds.isEmpty
        ? (_selectedCategoryIds.isEmpty
            ? _subcategories
            : _subcategories.where((s) => _selectedCategoryIds.contains(s['category_id'])).toList())
        : _subcategories.where((s) => _selectedSubcategoryIds.contains(s['id'])).toList();

    final List<dynamic> displayedBrands = _selectedBrandIds.isEmpty
        ? (_selectedCategoryIds.isEmpty
            ? _brands
            : _brands.where((b) {
                final int brandId = b['id'];
                return _allProducts.any((p) {
                  final int? pCatId = p['category_id'] != null ? int.tryParse(p['category_id'].toString()) : null;
                  final int? pBrandId = p['brand_id'] != null ? int.tryParse(p['brand_id'].toString()) : null;
                  return _selectedCategoryIds.contains(pCatId) && pBrandId == brandId;
                });
              }).toList())
        : _brands.where((b) => _selectedBrandIds.contains(b['id'])).toList();

    final double maxFiltersHeight = _getQuickFiltersHeight(displayedCategories, displayedSubcategories, displayedBrands);

    if (!_scrollController.hasClients || _scrollController.offset <= 0) {
      _filtersHeightNotifier.value = maxFiltersHeight;
    } else {
      _filtersHeightNotifier.value = _filtersHeightNotifier.value.clamp(0.0, maxFiltersHeight);
    }

    if (isDesktop) {
      return Scaffold(
        backgroundColor: const Color(0xFFFAFBFD),
        body: Stack(
          children: [
            Column(
              children: [
                if (!widget.isEmbedded)
                  _buildDesktopHeader(theme),
                _buildDesktopCategoryMenuRow(theme),
                Expanded(
                  child: _isLoadingProducts
                      ? const Center(child: CircularProgressIndicator())
                      : SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Center(
                                child: Container(
                                  constraints: const BoxConstraints(maxWidth: double.infinity),
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildBreadcrumbs(theme),
                                      const SizedBox(height: 8),
                                      // Title + Stats
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                                textBaseline: TextBaseline.alphabetic,
                                                children: [
                                                  Text(
                                                    widget.subcategoryName ?? 'Products',
                                                    style: const TextStyle(
                                                      fontSize: 24,
                                                      fontWeight: FontWeight.bold,
                                                      color: AppColors.textPrimary,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Text(
                                                    '${filtered.length} products found',
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      color: AppColors.textLight,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              Row(
                                                children: [
                                                  const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                                                  const SizedBox(width: 4),
                                                  const Text('4.8', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                                                  const SizedBox(width: 6),
                                                  Container(width: 1, height: 12, color: Colors.grey.shade300),
                                                  const SizedBox(width: 6),
                                                  const Text('91.7K Reviews', style: TextStyle(fontSize: 13, color: Colors.blueAccent, decoration: TextDecoration.underline)),
                                                ],
                                              ),
                                            ],
                                          ),
                                          // Filters show/hide toggle button
                                          OutlinedButton.icon(
                                            onPressed: () {
                                              setState(() {
                                                _showInlineFilters = !_showInlineFilters;
                                              });
                                            },
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: theme.colorScheme.primary,
                                              side: BorderSide(color: theme.colorScheme.primary, width: 1.5),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                            ),
                                            icon: Icon(_showInlineFilters ? Icons.close_rounded : Icons.filter_list_rounded, size: 18),
                                            label: Text(_showInlineFilters ? 'Hide Filters' : 'Filters'),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      _buildTopCategoriesBar(theme),
                                      const SizedBox(height: 16),
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          ClipRect(
                                            child: AnimatedContainer(
                                              duration: const Duration(milliseconds: 300),
                                              curve: Curves.fastOutSlowIn,
                                              width: _showInlineFilters ? 280.0 : 0.0,
                                              child: _showInlineFilters
                                                  ? Padding(
                                                      padding: const EdgeInsets.only(right: 20),
                                                      child: _buildInlineFilterPanel(context, true, theme),
                                                    )
                                                  : const SizedBox.shrink(),
                                            ),
                                          ),
                                          Expanded(
                                            child: filtered.isEmpty
                                                ? _buildEmptyState()
                                                : LayoutBuilder(
                                                    builder: (context, constraints) {
                                                      final double width = constraints.maxWidth;
                                                      final int crossAxisCount = (width / 240).floor().clamp(2, 6);
                                                      return GridView.builder(
                                                        shrinkWrap: true,
                                                        physics: const NeverScrollableScrollPhysics(),
                                                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                                          crossAxisCount: crossAxisCount,
                                                          crossAxisSpacing: 16,
                                                          mainAxisSpacing: 16,
                                                          childAspectRatio: 0.72,
                                                        ),
                                                        itemCount: filtered.length,
                                                        itemBuilder: (context, index) {
                                                          return _buildProductCard(filtered[index], theme);
                                                        },
                                                      );
                                                    }
                                                  ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              _buildDesktopFooter(theme),
                            ],
                          ),
                        ),
                ),
              ],
            ),
            Positioned(
              top: widget.isEmbedded ? 48 : (60 + 44),
              left: 40,
              right: 40,
                child: MouseRegion(
                  onEnter: (_) => _cancelMenuCloseTimer(),
                  onExit: (_) => _startMenuCloseTimer(),
                  child: ValueListenableBuilder<int?>(
                    valueListenable: _activeCategoryId,
                    builder: (context, activeId, child) {
                      return AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        child: activeId != null
                            ? _buildMegaMenuOverlay(theme, activeId)
                            : const SizedBox.shrink(),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFAFBFD),
      appBar: widget.isEmbedded ? null : _buildAppBar(context, isDesktop, theme),
      body: _isLoadingProducts
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: double.infinity,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRect(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.fastOutSlowIn,
                        width: (isDesktop && _showInlineFilters) ? 280.0 : 0.0,
                        child: SizedBox(
                          width: 280,
                          child: _buildInlineFilterPanel(context, true, theme),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  widget.subcategoryName ?? 'Products',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Builder(
                                  builder: (context) {
                                    final int filterCount = _selectedCategoryIds.length + _selectedSubcategoryIds.length + _selectedBrandIds.length;
                                    return OutlinedButton.icon(
                                      onPressed: () async {
                                        if (isDesktop) {
                                          setState(() {
                                            _showInlineFilters = !_showInlineFilters;
                                          });
                                        } else {
                                          final result = await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => FilterScreen(
                                                categories: _categories,
                                                subcategories: _subcategories,
                                                brands: _brands,
                                                initialCategoryIds: _selectedCategoryIds,
                                                initialSubcategoryIds: _selectedSubcategoryIds,
                                                initialBrandIds: _selectedBrandIds,
                                              ),
                                            ),
                                          );

                                          if (result != null && result is Map<String, dynamic>) {
                                            setState(() {
                                              _selectedCategoryIds.clear();
                                              _selectedCategoryIds.addAll(Set<int>.from(result['categoryIds'] ?? {}));
                                              _selectedSubcategoryIds.clear();
                                              _selectedSubcategoryIds.addAll(Set<int>.from(result['subcategoryIds'] ?? {}));
                                              _selectedBrandIds.clear();
                                              _selectedBrandIds.addAll(Set<int>.from(result['brandIds'] ?? {}));
                                            });
                                          }
                                        }
                                      },
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: theme.colorScheme.primary,
                                        side: BorderSide(color: theme.colorScheme.primary, width: 1.5),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      ),
                                      icon: Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          Icon(isDesktop && _showInlineFilters ? Icons.close_rounded : Icons.filter_list_rounded, size: 18),
                                          if (filterCount > 0)
                                            Positioned(
                                              top: -6,
                                              right: -6,
                                              child: Container(
                                                padding: const EdgeInsets.all(2),
                                                decoration: const BoxDecoration(
                                                  color: Colors.redAccent,
                                                  shape: BoxShape.circle,
                                                ),
                                                constraints: const BoxConstraints(
                                                  minWidth: 12,
                                                  minHeight: 12,
                                                ),
                                                child: Text(
                                                  '$filterCount',
                                                  style: const TextStyle(fontSize: 7, color: Colors.white, fontWeight: FontWeight.bold),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      label: Text(
                                        isDesktop && _showInlineFilters ? 'Hide Filters' : 'Filters',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          ValueListenableBuilder<double>(
                            valueListenable: _filtersHeightNotifier,
                            builder: (context, heightValue, child) {
                              final double currentHeight = heightValue.clamp(0.0, maxFiltersHeight);
                              final double displayHeight = (isDesktop && _showInlineFilters) ? 0.0 : currentHeight;
                              return ClipRect(
                                child: SizedBox(
                                  height: displayHeight,
                                  child: child,
                                ),
                              );
                            },
                            child: SingleChildScrollView(
                              physics: const NeverScrollableScrollPhysics(),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Categories filter horizontal bar
                                  if (displayedCategories.isNotEmpty) ...[
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                              child: Text(
                                'Categories',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                              ),
                            ),
                            Container(
                              height: 52,
                              margin: const EdgeInsets.only(bottom: 6),
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: displayedCategories.length,
                                itemBuilder: (context, index) {
                                  final cat = displayedCategories[index];
                                  final bool isSelected = _selectedCategoryIds.contains(cat['id']);
                                  final String imageUrl = _getCategoryImage(cat['categories_image']);
                                  
                                  return GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        if (isSelected) {
                                          _selectedCategoryIds.remove(cat['id']);
                                          // Clean up subcategories
                                          _selectedSubcategoryIds.removeWhere((subId) {
                                            final s = _subcategories.firstWhere((item) => item['id'] == subId, orElse: () => null);
                                            return s != null && s['category_id'] == cat['id'];
                                          });
                                        } else {
                                          _selectedCategoryIds.add(cat['id']);
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
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.02),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
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
                                                child: Icon(
                                                  _getCategoryIcon(cat['categories_name'] ?? ''),
                                                  size: 12,
                                                  color: isSelected ? Colors.white : theme.colorScheme.primary,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            constraints: const BoxConstraints(maxWidth: 120),
                                            child: Text(
                                              cat['categories_name'] ?? 'Category',
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

                          // 1. Subcategories Filter Bar (Dual header)
                          if (!_isLoadingSubcategories && displayedSubcategories.isNotEmpty) ...[
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
                      itemCount: displayedSubcategories.length,
                      itemBuilder: (context, index) {
                        final sub = displayedSubcategories[index];
                        final bool isSelected = _selectedSubcategoryIds.contains(sub['id']);
                        final String imageUrl = _getSubcategoryImage(sub['categories_subs_image']);
                        
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _selectedSubcategoryIds.remove(sub['id']);
                              } else {
                                _selectedSubcategoryIds.add(sub['id']);
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
                if (!_isLoadingBrands && displayedBrands.isNotEmpty) ...[
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
                      itemCount: displayedBrands.length,
                      itemBuilder: (context, index) {
                        final brand = displayedBrands[index];
                        final bool isSelected = _selectedBrandIds.contains(brand['id']);
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _selectedBrandIds.remove(brand['id']);
                              } else {
                                _selectedBrandIds.add(brand['id']);
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
                                    ],
                                  ),
                            ),
                          ),

                // Grid list
                Expanded(
                  child: filtered.isEmpty
                      ? _buildEmptyState()
                      : GridView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: isDesktop ? 6 : 2,
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
          ),
        ],
      ),
    ),
    ),
    );
  }

  String _getCategoryImage(dynamic categoriesImage) {
    if (categoriesImage == null || categoriesImage.toString().isEmpty) {
      return 'https://agsdemo.in/singlemartapi/public/assets/images/no_image.jpg';
    }
    final String pathStr = categoriesImage.toString();
    if (pathStr.startsWith('/tmp') || pathStr.startsWith('/var') || pathStr.contains('/')) {
      if (!pathStr.contains('category_images') && (pathStr.startsWith('/') || pathStr.startsWith('\\'))) {
        return 'https://agsdemo.in/singlemartapi/public/assets/images/no_image.jpg';
      }
    }
    return 'https://agsdemo.in/singlemartapi/public/assets/images/category_images/$pathStr';
  }

  Widget _buildFilterSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildFilterCheckboxItem({
    required String name,
    required bool isSelected,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: isSelected ? theme.colorScheme.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isSelected ? theme.colorScheme.primary : AppColors.textMuted,
                  width: 1.5,
                ),
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check,
                      size: 12,
                      color: Colors.white,
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? AppColors.textPrimary : AppColors.textLight,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _resetAllFilters() {
    setState(() {
      _selectedCategoryIds.clear();
      _selectedSubcategoryIds.clear();
      _selectedBrandIds.clear();
    });
  }

  Widget _buildInlineFilterPanel(BuildContext context, bool isDesktop, ThemeData theme) {
    final List<dynamic> activeSubs = _selectedCategoryIds.isEmpty
        ? _subcategories
        : _subcategories.where((s) => _selectedCategoryIds.contains(s['category_id'])).toList();

    if (isDesktop) {
      return Container(
        width: 260,
        height: 650,
        margin: const EdgeInsets.only(right: 20, top: 16, bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Filters',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                TextButton(
                  onPressed: _resetAllFilters,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(50, 30),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Clear All', style: TextStyle(fontSize: 12, color: AppColors.primary)),
                ),
              ],
            ),
            const Divider(height: 20),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFilterSectionTitle('Categories'),
                    ..._categories.map((cat) => _buildFilterCheckboxItem(
                      name: cat['categories_name'] ?? 'Category',
                      isSelected: _selectedCategoryIds.contains(cat['id']),
                      onTap: () {
                        setState(() {
                          if (_selectedCategoryIds.contains(cat['id'])) {
                            _selectedCategoryIds.remove(cat['id']);
                            _selectedSubcategoryIds.removeWhere((subId) {
                              final s = _subcategories.firstWhere((item) => item['id'] == subId, orElse: () => null);
                              return s != null && s['category_id'] == cat['id'];
                            });
                          } else {
                            _selectedCategoryIds.add(cat['id']);
                          }
                        });
                      },
                      theme: theme,
                    )),
                    const SizedBox(height: 16),
                    if (activeSubs.isNotEmpty) ...[
                      _buildFilterSectionTitle('Subcategories'),
                      ...activeSubs.map((sub) => _buildFilterCheckboxItem(
                        name: sub['categories_subs_name'] ?? 'Subcategory',
                        isSelected: _selectedSubcategoryIds.contains(sub['id']),
                        onTap: () {
                          setState(() {
                            if (_selectedSubcategoryIds.contains(sub['id'])) {
                              _selectedSubcategoryIds.remove(sub['id']);
                            } else {
                              _selectedSubcategoryIds.add(sub['id']);
                            }
                          });
                        },
                        theme: theme,
                      )),
                      const SizedBox(height: 16),
                    ],
                    _buildFilterSectionTitle('Brands'),
                    ..._brands.map((brand) => _buildFilterCheckboxItem(
                      name: brand['brands_name'] ?? 'Brand',
                      isSelected: _selectedBrandIds.contains(brand['id']),
                      onTap: () {
                        setState(() {
                          if (_selectedBrandIds.contains(brand['id'])) {
                            _selectedBrandIds.remove(brand['id']);
                          } else {
                            _selectedBrandIds.add(brand['id']);
                          }
                        });
                      },
                      theme: theme,
                    )),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.tune_rounded, size: 16, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  const Text(
                    'Quick Filters',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                ],
              ),
              Row(
                children: [
                  TextButton(
                    onPressed: _resetAllFilters,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(50, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Clear All', style: TextStyle(fontSize: 12, color: AppColors.primary)),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.textLight),
                    onPressed: () => setState(() => _showInlineFilters = false),
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 12),
          DefaultTabController(
            length: 3,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TabBar(
                  labelColor: theme.colorScheme.primary,
                  unselectedLabelColor: AppColors.textLight,
                  indicatorColor: theme.colorScheme.primary,
                  indicatorSize: TabBarIndicatorSize.label,
                  labelPadding: EdgeInsets.zero,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
                  tabs: [
                    Tab(text: 'Categories (${_selectedCategoryIds.length})'),
                    Tab(text: 'Subcategories (${_selectedSubcategoryIds.length})'),
                    Tab(text: 'Brands (${_selectedBrandIds.length})'),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 180,
                  child: TabBarView(
                    children: [
                      ListView(
                        padding: EdgeInsets.zero,
                        children: _categories.map((cat) => _buildFilterCheckboxItem(
                          name: cat['categories_name'] ?? 'Category',
                          isSelected: _selectedCategoryIds.contains(cat['id']),
                          onTap: () {
                            setState(() {
                              if (_selectedCategoryIds.contains(cat['id'])) {
                                _selectedCategoryIds.remove(cat['id']);
                                _selectedSubcategoryIds.removeWhere((subId) {
                                  final s = _subcategories.firstWhere((item) => item['id'] == subId, orElse: () => null);
                                  return s != null && s['category_id'] == cat['id'];
                                });
                              } else {
                                _selectedCategoryIds.add(cat['id']);
                              }
                            });
                          },
                          theme: theme,
                        )).toList(),
                      ),
                      activeSubs.isEmpty
                          ? const Center(
                              child: Text(
                                'Select a category first',
                                style: TextStyle(color: AppColors.textLight, fontSize: 12),
                              ),
                            )
                          : ListView(
                              padding: EdgeInsets.zero,
                              children: activeSubs.map((sub) => _buildFilterCheckboxItem(
                                name: sub['categories_subs_name'] ?? 'Subcategory',
                                isSelected: _selectedSubcategoryIds.contains(sub['id']),
                                onTap: () {
                                  setState(() {
                                    if (_selectedSubcategoryIds.contains(sub['id'])) {
                                      _selectedSubcategoryIds.remove(sub['id']);
                                    } else {
                                      _selectedSubcategoryIds.add(sub['id']);
                                    }
                                  });
                                },
                                theme: theme,
                              )).toList(),
                            ),
                      ListView(
                        padding: EdgeInsets.zero,
                        children: _brands.map((brand) => _buildFilterCheckboxItem(
                          name: brand['brands_name'] ?? 'Brand',
                          isSelected: _selectedBrandIds.contains(brand['id']),
                          onTap: () {
                            setState(() {
                              if (_selectedBrandIds.contains(brand['id'])) {
                                _selectedBrandIds.remove(brand['id']);
                              } else {
                                _selectedBrandIds.add(brand['id']);
                              }
                            });
                          },
                          theme: theme,
                        )).toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget? _buildAppBar(BuildContext context, bool isDesktop, ThemeData theme) {
    if (!isDesktop) {
      return AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: Text(
          widget.subcategoryName ?? 'Products',
          style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          Builder(
            builder: (context) {
              final int filterCount = _selectedCategoryIds.length + _selectedSubcategoryIds.length + _selectedBrandIds.length;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: const Icon(Icons.filter_list_rounded, color: AppColors.textPrimary),
                    tooltip: 'Filters',
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FilterScreen(
                            categories: _categories,
                            subcategories: _subcategories,
                            brands: _brands,
                            initialCategoryIds: _selectedCategoryIds,
                            initialSubcategoryIds: _selectedSubcategoryIds,
                            initialBrandIds: _selectedBrandIds,
                          ),
                        ),
                      );

                      if (result != null && result is Map<String, dynamic>) {
                        setState(() {
                          _selectedCategoryIds.clear();
                          _selectedCategoryIds.addAll(Set<int>.from(result['categoryIds'] ?? {}));
                          
                          _selectedSubcategoryIds.clear();
                          _selectedSubcategoryIds.addAll(Set<int>.from(result['subcategoryIds'] ?? {}));
                          
                          _selectedBrandIds.clear();
                          _selectedBrandIds.addAll(Set<int>.from(result['brandIds'] ?? {}));
                        });
                      }
                    },
                  ),
                  if (filterCount > 0)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '$filterCount',
                          style: const TextStyle(
                            fontSize: 9,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const CartButton(),
          const SizedBox(width: 12),
        ],
      );
    }

    return PreferredSize(
      preferredSize: const Size.fromHeight(72),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
        child: Row(
          children: [
            GestureDetector(
              onTap: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const ECommerceHomeScreen(initialTabIndex: 0)),
                  (route) => false,
                );
              },
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.shopping_bag, color: theme.colorScheme.primary, size: 26),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'SingleMart',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w900,
                      fontSize: 24,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 48),
            Expanded(
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        onSubmitted: (val) {
                          if (val.isNotEmpty) {
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ECommerceHomeScreen(
                                  initialTabIndex: 0,
                                  initialSearchQuery: val,
                                ),
                              ),
                              (route) => false,
                            );
                          }
                        },
                        decoration: const InputDecoration(
                          hintText: 'Search for local products, stores, brands...',
                          hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        final val = _searchController.text;
                        if (val.isNotEmpty) {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ECommerceHomeScreen(
                                initialTabIndex: 0,
                                initialSearchQuery: val,
                              ),
                            ),
                            (route) => false,
                          );
                        } else {
                          _searchFocusNode.requestFocus();
                        }
                      },
                      child: Container(
                        width: 54,
                        height: 44,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(10),
                            bottomRight: Radius.circular(10),
                          ),
                        ),
                        child: const Icon(Icons.search_rounded, color: Colors.white, size: 22),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 48),
            _buildDesktopNavItem(
              icon: Icons.home_outlined,
              activeIcon: Icons.home_rounded,
              label: 'Home',
              index: 0,
              theme: theme,
            ),
            const SizedBox(width: 24),
            PopupMenuButton<int>(
              tooltip: 'Browse Categories',
              offset: const Offset(0, 48),
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              color: Colors.white,
              onSelected: (val) {
                if (val == -1) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const ECommerceHomeScreen(initialTabIndex: 1)),
                    (route) => false,
                  );
                } else {
                  final cat = _categories.firstWhere((c) => c['id'] == val, orElse: () => null);
                  if (cat != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProductsListScreen(
                          categoryId: val,
                          subcategoryName: cat['categories_name'] ?? 'Category',
                        ),
                      ),
                    );
                  }
                }
              },
              itemBuilder: (context) {
                final top5 = _categories.take(5).toList();
                final List<PopupMenuEntry<int>> items = [];
                items.add(
                  const PopupMenuItem<int>(
                    enabled: false,
                    child: Text(
                      'Explore Top Categories',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                );
                items.add(const PopupMenuDivider());
                for (var cat in top5) {
                  items.add(
                    PopupMenuItem<int>(
                      value: cat['id'],
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: theme.colorScheme.primary.withOpacity(0.1),
                            ),
                            child: Center(
                              child: Icon(
                                _getCategoryIcon(cat['categories_name'] ?? ''),
                                size: 14,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            cat['categories_name'] ?? 'Category',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                items.add(const PopupMenuDivider());
                items.add(
                  PopupMenuItem<int>(
                    value: -1,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'View More Categories',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
                return items;
              },
              child: _buildDesktopNavItem(
                icon: Icons.grid_view_outlined,
                activeIcon: Icons.grid_view_rounded,
                label: 'Categories',
                index: 1,
                theme: theme,
              ),
            ),
            const SizedBox(width: 24),
            _buildDesktopNavItem(
              icon: Icons.local_mall_outlined,
              activeIcon: Icons.local_mall_rounded,
              label: 'Products',
              index: 2,
              theme: theme,
            ),
            const SizedBox(width: 24),
            _buildDesktopNavItem(
              icon: Icons.filter_list_rounded,
              activeIcon: Icons.filter_list_rounded,
              label: 'Filters',
              index: 5,
              badgeCount: _selectedCategoryIds.length + _selectedSubcategoryIds.length + _selectedBrandIds.length,
              theme: theme,
            ),
            const SizedBox(width: 24),
            ValueListenableBuilder<int>(
              valueListenable: CartManager.cartCountNotifier,
              builder: (context, count, child) {
                return _buildDesktopNavItem(
                  icon: Icons.shopping_cart_outlined,
                  activeIcon: Icons.shopping_cart_rounded,
                  label: 'Cart',
                  index: 3,
                  badgeCount: count,
                  theme: theme,
                );
              },
            ),
            const SizedBox(width: 32),
            if (_isLoggedIn)
              Builder(
                builder: (ctx) {
                  final String? userImage = _userData?['user_image']?.toString();
                  final String imageUrl = (userImage != null && userImage.isNotEmpty)
                      ? "https://agsdemo.in/singlemartapi/public/assets/images/user_images/$userImage"
                      : "";
                  final String name = _userData?['name']?.toString() ?? 'User';
                  return InkWell(
                    onTap: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ECommerceHomeScreen(initialTabIndex: 4),
                        ),
                        (route) => false,
                      );
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: AppColors.primary,
                            backgroundImage: imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
                            child: imageUrl.isEmpty
                                ? const Icon(Icons.person, size: 16, color: Colors.white)
                                : null,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              )
            else
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ECommerceHomeScreen(initialTabIndex: 4),
                    ),
                    (route) => false,
                  );
                },
                icon: const Icon(Icons.login_rounded, size: 16, color: Colors.white),
                label: const Text(
                  'Sign In',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
    bool isActive = false,
    int badgeCount = 0,
    required ThemeData theme,
  }) {
    final bool isItemActive = isActive || (index == 5 && _showInlineFilters);
    final Color itemColor = isItemActive ? theme.colorScheme.primary : AppColors.textLight;

    return InkWell(
      onTap: () async {
        if (index == 5) {
          setState(() {
            _showInlineFilters = !_showInlineFilters;
          });
        } else {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => ECommerceHomeScreen(initialTabIndex: index),
            ),
            (route) => false,
          );
        }
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? theme.colorScheme.primary.withOpacity(0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(isActive ? activeIcon : icon, color: itemColor, size: 20),
                if (badgeCount > 0)
                  Positioned(
                    top: -6,
                    right: -8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        '$badgeCount',
                        style: const TextStyle(
                          fontSize: 9,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: itemColor,
              ),
            ),
          ],
        ),
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
    return ProductCardWidget(
      product: product,
      theme: theme,
      baseProductImageUrl: _baseProductImageUrl,
      baseProductVariantImageUrl: _baseProductVariantImageUrl,
      baseNoImageUrl: _baseNoImageUrl,
      getBrandName: _getBrandName,
      getCategoryIcon: _getCategoryIcon,
      onTap: () {
        Navigator.pushNamed(context, '/product/${product['id']}', arguments: product).then((_) {
          CartManager.updateCartCount();
          _loadCart();
        });
      },
      onAddToCart: () => _addToCart(product),
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

  // ==================== BREADCRUMBS & TOP BUBBLE CATEGORIES ====================

  Widget _buildBreadcrumbs(ThemeData theme) {
    final String currentTitle = widget.subcategoryName ?? 'All Products';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 12.0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const ECommerceHomeScreen(initialTabIndex: 0)),
                (route) => false,
              );
            },
            child: const Text(
              'Home',
              style: TextStyle(fontSize: 12, color: AppColors.textLight, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right_rounded, size: 14, color: AppColors.textMuted),
          const SizedBox(width: 6),
          Text(
            currentTitle,
            style: const TextStyle(fontSize: 12, color: AppColors.textLight, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildTopCategoriesBar(ThemeData theme) {
    final List<dynamic> listToUse = widget.categoryId != null ? _subcategories : _categories;
    if (listToUse.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        SizedBox(
          height: 110,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: listToUse.length,
            itemBuilder: (context, index) {
              final item = listToUse[index];
              final String name = widget.categoryId != null 
                  ? (item['categories_subs_name'] ?? 'Subcategory') 
                  : (item['categories_name'] ?? 'Category');
              
              final int itemId = item['id'];
              final bool isSelected = widget.categoryId != null 
                  ? _selectedSubcategoryIds.contains(itemId)
                  : _selectedCategoryIds.contains(itemId);

              final String imageUrl = widget.categoryId != null 
                  ? _getSubcategoryImage(item['categories_subs_image'])
                  : _getCategoryImage(item['categories_image']);

              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (widget.categoryId != null) {
                      if (isSelected) {
                        _selectedSubcategoryIds.remove(itemId);
                      } else {
                        _selectedSubcategoryIds.add(itemId);
                      }
                    } else {
                      if (isSelected) {
                        _selectedCategoryIds.remove(itemId);
                        _selectedSubcategoryIds.removeWhere((subId) {
                          final s = _subcategories.firstWhere((x) => x['id'] == subId, orElse: () => null);
                          return s != null && s['category_id'] == itemId;
                        });
                      } else {
                        _selectedCategoryIds.add(itemId);
                      }
                    }
                  });
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 20),
                  child: Column(
                    children: [
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: Colors.white,
                          border: Border.all(
                            color: isSelected ? theme.colorScheme.primary : const Color(0xFFE2E8F0),
                            width: isSelected ? 2.5 : 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(4),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: const Color(0xFFF1F5F9),
                              child: Icon(
                                Icons.category_rounded,
                                color: theme.colorScheme.primary.withOpacity(0.5),
                                size: 26,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? theme.colorScheme.primary : AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  // ==================== DESKTOP MENU ROW & OVERLAY ====================

  void _startMenuCloseTimer() {
    _menuCloseTimer?.cancel();
    _menuCloseTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        _activeCategoryId.value = null;
        _hoveredCategoryIndex.value = null;
      }
    });
  }

  void _cancelMenuCloseTimer() {
    _menuCloseTimer?.cancel();
  }

  List<dynamic> _getProductsByCategoryId(int categoryId) {
    return _allProducts.where((p) => p['product_category_id'] == categoryId || p['category_id'] == categoryId).take(5).toList();
  }

  Widget _buildMegaMenuOverlay(ThemeData theme, int activeId) {
    final catDetails = _categories.firstWhere(
      (c) => c['id'] == activeId,
      orElse: () => null,
    );
    final catName = catDetails != null ? (catDetails['categories_name'] ?? 'Category') : 'Category';
    final catProducts = _getProductsByCategoryId(activeId);

    return Center(
      key: ValueKey('mega_menu_$activeId'),
      child: Container(
        width: 780,
        height: 280,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(color: const Color(0xFFF1F5F9), width: 1),
        ),
        child: Row(
          children: [
            Expanded(
              child: catProducts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shopping_bag_outlined, size: 32, color: theme.colorScheme.primary.withOpacity(0.3)),
                          const SizedBox(height: 8),
                          const Text('No products available.', style: TextStyle(color: AppColors.textLight, fontSize: 12)),
                        ],
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Featured in $catName', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                          const SizedBox(height: 12),
                          Expanded(
                            child: GridView.builder(
                              itemCount: catProducts.length,
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 5,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                                childAspectRatio: 0.72,
                              ),
                              itemBuilder: (context, index) {
                                return _buildMegaMenuItem(catProducts[index], theme);
                              },
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

  Widget _buildMegaMenuItem(dynamic prod, ThemeData theme) {
    final name = prod['product_name'] ?? prod['name'] ?? 'Product';
    final bool hasVariants = (prod['has_variants'] == 1 || prod['has_variants'] == '1') &&
        prod['variants'] != null &&
        (prod['variants'] as List).isNotEmpty;

    double regP = 0.0;
    double discP = 0.0;

    if (hasVariants) {
      final firstVar = (prod['variants'] as List).first;
      discP = double.tryParse(firstVar['product_discount_price']?.toString() ?? '') ?? 0.0;
      regP = double.tryParse(firstVar['product_price']?.toString() ?? '') ?? 0.0;
    } else {
      discP = double.tryParse(prod['product_discount_price']?.toString() ?? '') ?? 0.0;
      regP = double.tryParse(prod['product_price']?.toString() ?? '') ??
             double.tryParse(prod['price']?.toString() ?? '') ?? 0.0;
    }

    final price = discP > 0 ? discP : regP;

    String finalImgUrl = _baseNoImageUrl;
    if (hasVariants) {
      final firstVar = (prod['variants'] as List).first;
      final varImages = firstVar['images'];
      if (varImages != null && varImages is List && varImages.isNotEmpty) {
        final String? filename = varImages[0]['product_variant_images'];
        if (filename != null && filename.isNotEmpty) {
          finalImgUrl = '$_baseProductVariantImageUrl$filename';
        }
      } else {
        final prodImages = prod['images'];
        if (prodImages != null && prodImages is List && prodImages.isNotEmpty) {
          final String? filename = prodImages[0]['product_images'];
          if (filename != null && filename.isNotEmpty) {
            finalImgUrl = '$_baseProductImageUrl$filename';
          }
        }
      }
    } else {
      final images = prod['images'];
      if (images != null && images is List && images.isNotEmpty) {
        final String? filename = images[0]['product_images'];
        if (filename != null && filename.isNotEmpty) {
          finalImgUrl = '$_baseProductImageUrl$filename';
        }
      }
    }

    return GestureDetector(
      onTap: () {
        _activeCategoryId.value = null;
        Navigator.push(context, MaterialPageRoute(
          builder: (context) => ProductDetailScreen(product: prod),
        ));
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                child: Image.network(finalImgUrl, fit: BoxFit.contain,
                  errorBuilder: (c, e, s) => const Icon(Icons.broken_image, size: 20)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Column(
                children: [
                  Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text('₹${price.round()}', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: theme.colorScheme.primary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopCategoryMenuRow(ThemeData theme) {
    if (_categories.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1.5)),
      ),
      child: Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_categories.length, (index) {
              final cat = _categories[index];
              final int catId = cat['id'];
              return MouseRegion(
                onEnter: (_) {
                  _cancelMenuCloseTimer();
                  _activeCategoryId.value = catId;
                  _hoveredCategoryIndex.value = index;
                },
                onExit: (_) => _startMenuCloseTimer(),
                child: ValueListenableBuilder<int?>(
                  valueListenable: _hoveredCategoryIndex,
                  builder: (context, hoveredIdx, child) {
                    final isHovered = hoveredIdx == index;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        cat['categories_name'] ?? 'Category',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: isHovered ? theme.colorScheme.primary : AppColors.textSecondary,
                        ),
                      ),
                    );
                  },
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  // ==================== DESKTOP HEADER ====================

  Widget _buildDesktopHeader(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2))],
        border: const Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Row(
        children: [
          _buildBrandLogo(theme),
          const SizedBox(width: 16),
          _buildLocationSelector(theme),
          const SizedBox(width: 20),
          Expanded(child: _buildSearchBar(theme)),
          const SizedBox(width: 24),
          _buildHeaderDesktopNavItem(icon: Icons.local_mall_outlined, label: 'Products', isActive: true,
            onTap: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            }, theme: theme),
          ValueListenableBuilder<int>(
            valueListenable: CartManager.cartCountNotifier,
            builder: (context, count, child) => _buildHeaderDesktopNavItem(
              icon: Icons.shopping_cart_outlined, label: 'Cart', isActive: false,
              badgeCount: count, onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const CartScreen())).then((_) => _loadCart());
              }, theme: theme),
          ),
          _isLoggedIn ? _buildDesktopProfileAvatar(theme) : _buildDesktopSignInButton(theme),
        ],
      ),
    );
  }

  Widget _buildBrandLogo(ThemeData theme) {
    return GestureDetector(
      onTap: () => Navigator.of(context).popUntil((route) => route.isFirst),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: theme.colorScheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.shopping_bag, color: theme.colorScheme.primary, size: 24),
          ),
          const SizedBox(width: 10),
          Text('SingleMart', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w900, fontSize: 22)),
        ],
      ),
    );
  }

  Widget _buildLocationSelector(ThemeData theme) {
    String displayAddress = "Location missing";
    if (_isLoggedIn && _userData != null) {
      final addresses = _userData!['addresses'] ?? _userData!['address'];
      if (addresses != null && addresses is List && addresses.isNotEmpty) {
        var targetAddress = addresses.first;
        for (var addr in addresses) {
          if (addr['is_default']?.toString() == '1' || addr['is_default']?.toString() == 'true') {
            targetAddress = addr;
            break;
          }
        }
        final line1 = targetAddress['address_line_1']?.toString() ?? '';
        final line2 = targetAddress['address_line_2']?.toString() ?? '';
        if (line1.isNotEmpty) displayAddress = line1;
        else if (line2.isNotEmpty) displayAddress = line2;
      }
    }
    return Row(
      children: [
        Icon(Icons.location_on_outlined, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Deliver to', style: TextStyle(fontSize: 10, color: AppColors.textLight)),
            Text(displayAddress, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchBar(ThemeData theme) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          const Icon(Icons.search_rounded, color: AppColors.textLight, size: 18),
          const SizedBox(width: 8),
          const Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search products...',
                hintStyle: TextStyle(color: AppColors.textLight, fontSize: 13),
                border: InputBorder.none,
                isDense: true,
              ),
              style: TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderDesktopNavItem({
    required IconData icon,
    required String label,
    required bool isActive,
    int badgeCount = 0,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
    return Container(
      margin: const EdgeInsets.only(left: 20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(icon, color: isActive ? theme.colorScheme.primary : AppColors.textSecondary, size: 20),
                  if (badgeCount > 0)
                    Positioned(
                      top: -6,
                      right: -6,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                        constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                        child: Text(
                          badgeCount.toString(),
                          style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isActive ? theme.colorScheme.primary : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopProfileAvatar(ThemeData theme) {
    final String initial = (_userData?['name']?.toString().substring(0, 1) ?? 'U').toUpperCase();
    return Container(
      margin: const EdgeInsets.only(left: 24),
      width: 32,
      height: 32,
      decoration: BoxDecoration(color: theme.colorScheme.primary.withOpacity(0.1), shape: BoxShape.circle),
      child: Center(
        child: Text(initial, style: TextStyle(color: theme.colorScheme.primary, fontSize: 13, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildDesktopSignInButton(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(left: 24),
      height: 36,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          elevation: 0,
        ),
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginScreen())).then((_) => _loadSession());
        },
        child: const Text('Sign In', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // ==================== DESKTOP FOOTER ====================

  Widget _buildDesktopFooter(ThemeData theme) {
    final topCategories = _categories.take(5).toList();
    final topBrands = _brands.take(5).toList();

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF1E293B)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 28),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [theme.colorScheme.primary, theme.colorScheme.secondary]),
            ),
            child: Row(
              children: [
                const Icon(Icons.mail_outline_rounded, color: Colors.white, size: 28),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Subscribe to our Newsletter', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('Get the latest deals, offers & new arrivals straight to your inbox.',
                        style: TextStyle(color: Colors.white70, fontSize: 13)),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Container(
                  width: 320, height: 46,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30)),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 18),
                          child: TextField(
                            decoration: InputDecoration(hintText: 'Enter your email address', hintStyle: TextStyle(fontSize: 13, color: Colors.grey), border: InputBorder.none),
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                      ),
                      Container(
                        height: 46,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(color: AppColors.textPrimary, borderRadius: BorderRadius.circular(30)),
                        alignment: Alignment.center,
                        child: const Text('Subscribe', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [theme.colorScheme.primary, theme.colorScheme.secondary]),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.shopping_bag_rounded, color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 10),
                          const Text('SingleMart', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const Text('Your one-stop destination for all local neighborhood deals with zero delivery fees.',
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14, height: 1.7)),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          _buildAppBadge(Icons.apple, 'App Store'),
                          const SizedBox(width: 12),
                          _buildAppBadge(Icons.android, 'Google Play'),
                        ],
                      ),
                      const SizedBox(height: 28),
                      Row(
                        children: [
                          _buildSocialIcon(Icons.facebook, 'https://facebook.com'),
                          const SizedBox(width: 10),
                          _buildSocialIcon(Icons.camera_alt_rounded, 'https://instagram.com'),
                          const SizedBox(width: 10),
                          _buildSocialIcon(Icons.alternate_email, 'https://twitter.com'),
                          const SizedBox(width: 10),
                          _buildSocialIcon(Icons.play_circle_outline_rounded, 'https://youtube.com'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 48),
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFooterHeading('Quick Links'),
                      _buildFooterLink('Home', () {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (context) => const ECommerceHomeScreen(initialTabIndex: 0)),
                          (route) => false,
                        );
                      }),
                      _buildFooterLink('All Categories', () {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (context) => const ECommerceHomeScreen(initialTabIndex: 1)),
                          (route) => false,
                        );
                      }),
                      _buildFooterLink('Featured Products', () {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (context) => const ECommerceHomeScreen(initialTabIndex: 2)),
                          (route) => false,
                        );
                      }),
                      _buildFooterLink('My Cart', () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const CartScreen())).then((_) => _loadCart());
                      }),
                      _buildFooterLink('My Profile', () {
                        if (_isLoggedIn) {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (context) => const ECommerceHomeScreen(initialTabIndex: 4)),
                            (route) => false,
                          );
                        } else {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginScreen())).then((_) => _loadSession());
                        }
                      }),
                    ],
                  ),
                ),
                const SizedBox(width: 32),
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFooterHeading('Top Categories'),
                      ...topCategories.map((c) => _buildFooterLink(
                        c['categories_name'] ?? 'Category',
                        () => Navigator.push(context, MaterialPageRoute(
                          builder: (context) => ProductsListScreen(
                            categoryId: c['id'],
                            subcategoryName: c['categories_name'] ?? 'Category',
                          ),
                        )),
                      )),
                    ],
                  ),
                ),
                const SizedBox(width: 32),
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFooterHeading('Top Brands'),
                      ...topBrands.map((b) => _buildFooterLink(
                        b['brands_name'] ?? b['brand_name'] ?? 'Brand',
                        () {},
                      )),
                    ],
                  ),
                ),
                const SizedBox(width: 32),
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFooterHeading('Contact Us'),
                      _buildFooterContactRow(Icons.email_outlined, 'support@singlemart.in'),
                      _buildFooterContactRow(Icons.phone_outlined, '+91 98765 43210'),
                      _buildFooterContactRow(Icons.location_on_outlined, 'Bengaluru, Karnataka\nIndia - 560001'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFF334155), height: 1, thickness: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
            child: Row(
              children: [
                Text('© ${DateTime.now().year} SingleMart Technologies Pvt. Ltd. All rights reserved.',
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                const Spacer(),
                _buildFooterBottomLink('Privacy Policy'),
                const SizedBox(width: 24),
                _buildFooterBottomLink('Terms of Service'),
                const SizedBox(width: 24),
                _buildFooterBottomLink('Refund Policy'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterHeading(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
    );
  }

  Widget _buildFooterContactRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF64748B), size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.5))),
        ],
      ),
    );
  }

  Widget _buildAppBadge(IconData icon, String store) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF334155), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Download on', style: TextStyle(color: Colors.white54, fontSize: 9)),
              Text(store, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFooterBottomLink(String title) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {},
        child: Text(title, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13, decoration: TextDecoration.underline, decorationColor: Color(0xFF64748B))),
      ),
    );
  }

  Widget _buildFooterLink(String title, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(foregroundColor: Colors.white70, padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 0), alignment: Alignment.centerLeft),
        child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      ),
    );
  }

  Widget _buildSocialIcon(IconData icon, String urlString) {
    return InkWell(
      onTap: () async {
        final Uri url = Uri.parse(urlString);
        try {
          if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
            await launchUrl(url, mode: LaunchMode.inAppBrowserView);
          }
        } catch (e) {
          await launchUrl(url, mode: LaunchMode.platformDefault);
        }
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}

class ProductCardWidget extends StatefulWidget {
  final Map<String, dynamic> product;
  final ThemeData theme;
  final String baseProductImageUrl;
  final String baseProductVariantImageUrl;
  final String baseNoImageUrl;
  final String Function(dynamic) getBrandName;
  final IconData Function(String) getCategoryIcon;
  final VoidCallback onTap;
  final VoidCallback onAddToCart;

  const ProductCardWidget({
    super.key,
    required this.product,
    required this.theme,
    required this.baseProductImageUrl,
    required this.baseProductVariantImageUrl,
    required this.baseNoImageUrl,
    required this.getBrandName,
    required this.getCategoryIcon,
    required this.onTap,
    required this.onAddToCart,
  });

  @override
  State<ProductCardWidget> createState() => _ProductCardWidgetState();
}

class _ProductCardWidgetState extends State<ProductCardWidget> {
  bool _isHovered = false;
  PageController? _pageController;
  Timer? _carouselTimer;
  int _currentCarouselIndex = 0;
  List<String> _imagesList = [];

  @override
  void initState() {
    super.initState();
    _initImages();
  }

  void _initImages() {
    final product = widget.product;
    final bool hasVariants = (product['has_variants'] == 1 || product['has_variants'] == '1') &&
        product['variants'] != null &&
        (product['variants'] as List).isNotEmpty;

    List<String> list = [];

    // Add main images
    final mainImages = product['images'];
    if (mainImages != null && mainImages is List && mainImages.isNotEmpty) {
      for (var img in mainImages) {
        final filename = img['product_images'];
        if (filename != null && filename.toString().isNotEmpty) {
          list.add('${widget.baseProductImageUrl}$filename');
        }
      }
    }

    // Add variant images if any
    if (hasVariants) {
      final variants = product['variants'] as List;
      for (var v in variants) {
        final varImages = v['images'];
        if (varImages != null && varImages is List && varImages.isNotEmpty) {
          for (var img in varImages) {
            final filename = img['product_variant_images'];
            if (filename != null && filename.toString().isNotEmpty) {
              list.add('${widget.baseProductVariantImageUrl}$filename');
            }
          }
        }
      }
    }

    // Deduplicate and fallback
    list = list.toSet().toList();
    if (list.isEmpty) {
      list.add(widget.baseNoImageUrl);
    }
    _imagesList = list;
  }

  void _startCarousel() {
    if (_imagesList.length <= 1) return;
    _pageController = PageController(initialPage: _currentCarouselIndex);
    _carouselTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _currentCarouselIndex = (_currentCarouselIndex + 1) % _imagesList.length;
        _pageController?.animateToPage(
          _currentCarouselIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      });
    });
  }

  void _stopCarousel() {
    _carouselTimer?.cancel();
    _carouselTimer = null;
    _pageController?.dispose();
    _pageController = null;
    setState(() {
      _currentCarouselIndex = 0;
    });
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _pageController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final product = widget.product;

    final double price = product['price'] is num 
        ? (product['price'] as num).toDouble() 
        : (double.tryParse(product['price']?.toString() ?? '0') ?? 0.0);
    final double? originalPrice = product['original_price'] is num 
        ? (product['original_price'] as num).toDouble() 
        : (double.tryParse(product['original_price']?.toString() ?? '') ?? null);

    final hasDiscount = originalPrice != null && originalPrice > price;
    final discountPercent = hasDiscount ? (((originalPrice - price) / originalPrice) * 100).round() : 0;

    final String brandName = widget.getBrandName(product['brand_id']);
    final String prodName = product['name'] ?? 'Product Name';
    final String categoryName = product['image'] ?? '';
    final String description = product['desc'] ?? '';

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

    return MouseRegion(
      onEnter: (_) {
        setState(() {
          _isHovered = true;
        });
        _startCarousel();
      },
      onExit: (_) {
        setState(() {
          _isHovered = false;
        });
        _stopCarousel();
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isHovered ? theme.colorScheme.primary.withOpacity(0.3) : const Color(0xFFE2E8F0),
              width: _isHovered ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: _isHovered ? theme.colorScheme.primary.withOpacity(0.08) : Colors.black.withOpacity(0.02),
                blurRadius: _isHovered ? 16 : 8,
                offset: Offset(0, _isHovered ? 8 : 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Image Viewport with Bestseller/Discount overlay
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Container(
                          color: const Color(0xFFF8FAFC),
                          padding: const EdgeInsets.all(12),
                          child: _isHovered && _imagesList.length > 1
                              ? PageView.builder(
                                  controller: _pageController,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _imagesList.length,
                                  itemBuilder: (context, idx) {
                                    return Image.network(
                                      _imagesList[idx],
                                      fit: BoxFit.contain,
                                      errorBuilder: (c, e, s) => const Icon(Icons.broken_image, size: 40),
                                    );
                                  },
                                )
                              : Image.network(
                                  _imagesList[0],
                                  fit: BoxFit.contain,
                                  errorBuilder: (c, e, s) => const Icon(Icons.broken_image, size: 40),
                                ),
                        ),
                      ),
                      // "Bestseller" badge
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6B21A8), // Royal purple
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Bestseller',
                            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      // Rating overlay
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
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                ),
                                const SizedBox(width: 2),
                                const Icon(Icons.star_rounded, color: Color(0xFF008C45), size: 10),
                                const SizedBox(width: 2),
                                Text('($ratingCount)', style: const TextStyle(fontSize: 9, color: AppColors.textLight)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // 2. Info details
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        brandName.isNotEmpty ? '$brandName $prodName' : prodName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 4),
                      // Category & sold count
                      Row(
                        children: [
                          Text(categoryName, style: const TextStyle(fontSize: 11, color: AppColors.textLight, fontWeight: FontWeight.w500)),
                          const Spacer(),
                          Text('${(product['id'] ?? 1) % 15 + 2} sold', style: const TextStyle(fontSize: 11, color: AppColors.textLight)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Description snippet
                      if (description.isNotEmpty) ...[
                        Text(
                          description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11.5, color: AppColors.textLight),
                        ),
                        const SizedBox(height: 8),
                      ],
                      // Price & Hover Actions Switcher
                      SizedBox(
                        height: 38,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 150),
                          child: _isHovered
                              ? Row(
                                  key: const ValueKey('hover_actions'),
                                  children: [
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: theme.colorScheme.primary,
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          padding: EdgeInsets.zero,
                                        ),
                                        onPressed: widget.onAddToCart,
                                        icon: const Icon(Icons.shopping_cart_outlined, size: 15),
                                        label: const Text('ADD TO CART', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.2)),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      width: 36,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: theme.colorScheme.primary, width: 1.2),
                                      ),
                                      child: IconButton(
                                        padding: EdgeInsets.zero,
                                        icon: Icon(Icons.visibility_outlined, color: theme.colorScheme.primary, size: 18),
                                        onPressed: widget.onTap,
                                      ),
                                    ),
                                  ],
                                )
                              : Row(
                                  key: const ValueKey('price_display'),
                                  crossAxisAlignment: CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(
                                      "₹${price.round()}",
                                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: theme.colorScheme.primary),
                                    ),
                                    if (hasDiscount) ...[
                                      const SizedBox(width: 8),
                                      Text(
                                        "₹${originalPrice.round()}",
                                        style: const TextStyle(fontSize: 12, color: AppColors.textLight, decoration: TextDecoration.lineThrough),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        "$discountPercent% OFF",
                                        style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
