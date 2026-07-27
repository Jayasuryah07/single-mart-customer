import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../widgets/cart_button.dart';
import 'categories_list_screen.dart';
import 'cart_screen.dart';
import 'subcategories_list_screen.dart';
import 'products_list_screen.dart';
import 'login_screen.dart';
import 'product_detail_screen.dart';
import 'filter_screen.dart';
import 'profile_screen.dart';

class ECommerceHomeScreen extends StatefulWidget {
  final int initialTabIndex;
  final String initialSearchQuery;
  const ECommerceHomeScreen({
    super.key,
    this.initialTabIndex = 0,
    this.initialSearchQuery = '',
  });

  @override
  State<ECommerceHomeScreen> createState() => _ECommerceHomeScreenState();
}

class _ECommerceHomeScreenState extends State<ECommerceHomeScreen> {
  bool _isLoading = true;
  int _currentTabIndex = 0;
  final ScrollController _scrollController = ScrollController();
  List<dynamic> _categories = [];
  List<dynamic> _subcategories = [];
  List<dynamic> _brands = [];
  List<dynamic> _allProducts = [];
  List<dynamic> _banners = [];

  // Page tracking for banner carousel indicator and automatic timer
  int _currentBannerIndex = 0;
  final PageController _bannerPageController = PageController();
  Timer? _bannerTimer;

  // Search States
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isSearchFocused = false;
  String _searchQuery = '';

  // Filter Selections (Maintained as Sets to support multi-select returning from FilterScreen)
  Set<int> _selectedCategoryIds = {};
  Set<int> _selectedSubcategoryIds = {};
  Set<int> _selectedBrandIds = {};

  // User Auth State
  Map<String, dynamic>? _userData;
  bool _isLoggedIn = false;
  String? _authToken;

  // Local Cart State
  List<Map<String, dynamic>> _cartItems = [];

  String _baseNoImageUrl = 'https://agsdemo.in/singlemartapi/public/assets/images/no_image.jpg';
  String _baseProductImageUrl = 'https://agsdemo.in/singlemartapi/public/assets/images/product_images/';
  String _baseProductVariantImageUrl = 'https://agsdemo.in/singlemartapi/public/assets/images/product_variant_images/';

  // Fallback products mock database
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
    _currentTabIndex = widget.initialTabIndex;
    _searchQuery = widget.initialSearchQuery;
    _searchController.text = widget.initialSearchQuery;
    _searchFocusNode.addListener(() {
      setState(() {
        _isSearchFocused = _searchFocusNode.hasFocus;
      });
      if (_searchFocusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 150), () {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              0.0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    });
    _allProducts = List.from(_fallbackProducts);
    _loadSession();
    _loadCatalog();
    _loadCart();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _bannerPageController.dispose();
    _scrollController.dispose();
    _bannerTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    _baseNoImageUrl = prefs.getString('base_no_image_url') ?? _baseNoImageUrl;
    _baseProductImageUrl = prefs.getString('base_product_image_url') ?? _baseProductImageUrl;
    _baseProductVariantImageUrl = prefs.getString('base_product_variant_image_url') ?? _baseProductVariantImageUrl;
    final String? token = prefs.getString('auth_token');
    final String? userDataStr = prefs.getString('user_data');
    if (token != null && token.isNotEmpty && userDataStr != null && userDataStr.isNotEmpty) {
      setState(() {
        _isLoggedIn = true;
        _authToken = token;
        _userData = json.decode(userDataStr);
      });
      _refreshProfileFromServerSilent();
    } else {
      setState(() {
        _isLoggedIn = false;
        _authToken = null;
        _userData = null;
      });
    }
  }

  Future<void> _refreshProfileFromServerSilent() async {
    final prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('auth_token');
    if (token == null || token.isEmpty || _userData == null) return;

    try {
      final int vendorId = _userData!['id'] is int 
          ? _userData!['id'] 
          : int.tryParse(_userData!['id']?.toString() ?? '0') ?? 0;

      final response = await ApiService.fetchVendor(vendorId, token);
      if (response.statusCode == 200) {
        final resData = json.decode(response.body);
        final dynamic profileData = resData['data'];
        if (profileData != null) {
          final Map<String, dynamic> parsedProfile = Map<String, dynamic>.from(profileData);
          
          final addressList = parsedProfile['addresses'] ?? parsedProfile['address'];
          if (addressList != null) {
            parsedProfile['addresses'] = addressList;
            parsedProfile['address'] = addressList;
          }

          await prefs.setString('user_data', json.encode(parsedProfile));
          if (mounted) {
            setState(() {
              _userData = parsedProfile;
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Silent refresh profile error: $e");
    }
  }

  Future<void> _refreshProfileFromServer() async {
    final prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('auth_token');
    if (token == null || token.isEmpty || _userData == null) return;

    try {
      final int vendorId = _userData!['id'] is int 
          ? _userData!['id'] 
          : int.tryParse(_userData!['id']?.toString() ?? '0') ?? 0;

      final response = await ApiService.fetchVendor(vendorId, token);
      if (response.statusCode == 200) {
        final resData = json.decode(response.body);
        final dynamic profileData = resData['data'];
        if (profileData != null) {
          final Map<String, dynamic> parsedProfile = Map<String, dynamic>.from(profileData);
          
          final addressList = parsedProfile['addresses'] ?? parsedProfile['address'];
          if (addressList != null) {
            parsedProfile['addresses'] = addressList;
            parsedProfile['address'] = addressList;
          }

          await prefs.setString('user_data', json.encode(parsedProfile));
          if (mounted) {
            setState(() {
              _userData = parsedProfile;
            });
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.white, size: 24),
                  SizedBox(width: 12),
                  Text('Profile synced successfully!', style: TextStyle(fontSize: 14)),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 1),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Manual refresh profile error: $e");
    }
  }

  void _startBannerAutoScroll() {
    _bannerTimer?.cancel();
    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_banners.length > 1 && _bannerPageController.hasClients) {
        int nextPage = _bannerPageController.page!.toInt() + 1;
        if (nextPage >= _banners.length) {
          nextPage = 0;
        }
        _bannerPageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  Future<void> _loadCatalog() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('auth_token');

      final responses = await Future.wait([
        ApiService.fetchActiveCategories(),
        ApiService.fetchActiveSubCategories(),
        ApiService.fetchActiveBrands(),
        ApiService.fetchActiveProducts(),
        ApiService.fetchActiveBanners(token),
      ]);

      final catRes = responses[0];
      final subRes = responses[1];
      final brandRes = responses[2];
      final prodRes = responses[3];
      final bannerRes = responses[4];

      List<dynamic> loadedCats = [];
      List<dynamic> loadedSubs = [];
      List<dynamic> loadedBrands = [];
      List<dynamic> loadedProds = [];
      List<dynamic> loadedBanners = [];

      if (catRes.statusCode == 200) {
        final dynamic catBody = json.decode(catRes.body);
        loadedCats = catBody['data'] ?? [];
        final dynamic catImgUrls = catBody['image_url'];
        if (catImgUrls != null && catImgUrls is List) {
          for (var item in catImgUrls) {
            final imageFor = item['image_for']?.toString();
            final url = item['image_url']?.toString();
            if (imageFor == 'Category' && url != null) {
              await prefs.setString('base_category_image_url', url);
            }
          }
        }
      }
      if (subRes.statusCode == 200) {
        final dynamic subBody = json.decode(subRes.body);
        loadedSubs = subBody['data'] ?? [];
        final dynamic subImgUrls = subBody['image_url'];
        if (subImgUrls != null && subImgUrls is List) {
          for (var item in subImgUrls) {
            final imageFor = item['image_for']?.toString();
            final url = item['image_url']?.toString();
            if (imageFor == 'Category' && url != null) {
              await prefs.setString('base_subcategory_image_url', url);
            }
          }
        }
      }
      if (brandRes.statusCode == 200) {
        final dynamic brandBody = json.decode(brandRes.body);
        loadedBrands = brandBody['data'] ?? [];
        final dynamic brandImgUrls = brandBody['image_url'];
        if (brandImgUrls != null && brandImgUrls is List) {
          for (var item in brandImgUrls) {
            final imageFor = item['image_for']?.toString();
            final url = item['image_url']?.toString();
            if (imageFor == 'Brand' && url != null) {
              await prefs.setString('base_brand_image_url', url);
            }
          }
        }
      }
       if (prodRes.statusCode == 200) {
         final dynamic prodBody = json.decode(prodRes.body);
         loadedProds = prodBody['data'] ?? [];
         
         final dynamic imageUrls = prodBody['image_url'];
         if (imageUrls != null && imageUrls is List) {
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
       }
      if (bannerRes.statusCode == 200) {
        loadedBanners = json.decode(bannerRes.body)['data'] ?? [];
      }

      setState(() {
        _categories = loadedCats;
        _subcategories = loadedSubs;
        _brands = loadedBrands;
        _banners = loadedBanners;
        _currentBannerIndex = 0;

        if (loadedProds.isNotEmpty) {
          _allProducts = loadedProds.map((p) {
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
        } else {
          _allProducts = List.from(_fallbackProducts);
        }

        _isLoading = false;
      });

      // Start autoplay carousel slider if multiple banners are present
      if (_banners.length > 1) {
        _startBannerAutoScroll();
      }
    } catch (e) {
      debugPrint("Failed to load catalog from APIs, fallbacks triggered: $e");
      setState(() {
        _categories = [
          {"id": 4, "categories_name": "Beauty & Personal Care"},
          {"id": 1, "categories_name": "Electronics"},
          {"id": 2, "categories_name": "Fashion"},
          {"id": 3, "categories_name": "Home & Kitchen"},
          {"id": 5, "categories_name": "Sports & Fitness"}
        ];
        _subcategories = [
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
        _brands = [
          {"id": 2, "brands_name": "Apple"},
          {"id": 5, "brands_name": "Dell"},
          {"id": 4, "brands_name": "LG"},
          {"id": 1, "brands_name": "Samsung"},
          {"id": 3, "brands_name": "Sony"}
        ];
        _allProducts = List.from(_fallbackProducts);
        _banners = [];
        _isLoading = false;
      });
    }
  }

  Future<void> _loadCart() async {
    try {
      final String? cartStr = await CartManager.getCartData();
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

  Future<void> _logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      await prefs.remove('user_data');
      setState(() {
        _isLoggedIn = false;
        _userData = null;
        _cartItems = []; // Reset local state
      });
      await CartManager.updateCartCount(); // Refresh count badge to guest cart!
    } catch (e) {
      debugPrint("Error during logout: $e");
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

  String _getBannerImage(dynamic bannerImage) {
    if (bannerImage == null || bannerImage.toString().isEmpty) {
      return 'https://agsdemo.in/singlemartapi/public/assets/images/no_image.jpg';
    }
    return 'https://agsdemo.in/singlemartapi/public/assets/images/banner_images/${bannerImage.toString()}';
  }

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      // Launch directly via external application to bypass Android queries constraints
      final bool launched = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!launched) {
        // Fallback to inAppBrowserView if external application launch fails
        await launchUrl(url, mode: LaunchMode.inAppBrowserView);
      }
    } catch (e) {
      debugPrint("Direct URL launch failed: $e");
      try {
        // Final platformDefault fallback
        await launchUrl(url, mode: LaunchMode.platformDefault);
      } catch (e2) {
        debugPrint("Url launcher fallback failed: $e2");
      }
    }
  }

  IconData _getCategoryIcon(String categoryName) {
    final name = categoryName.toLowerCase();
    if (name.contains('electronics') || name.contains('mobile') || name.contains('laptop') || name.contains('tablet') || name.contains('watch') || name.contains('smart')) {
      return Icons.electrical_services;
    }
    if (name.contains('fashion') || name.contains('accessories') || name.contains('footwear') || name.contains('clothing')) {
      return Icons.checkroom;
    }
    if (name.contains('home') || name.contains('kitchen') || name.contains('appliance')) {
      return Icons.kitchen;
    }
    if (name.contains('beauty') || name.contains('care') || name.contains('fragrance') || name.contains('skincare')) {
      return Icons.brush;
    }
    if (name.contains('sports') || name.contains('fitness') || name.contains('gym')) {
      return Icons.sports_soccer;
    }
    return Icons.category;
  }

  // Redirect to full-screen FilterScreen and await selected parameters
  Future<void> _navigateToFilterScreen() async {
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
        _selectedCategoryIds = Set<int>.from(result['categoryIds'] ?? {});
        _selectedSubcategoryIds = Set<int>.from(result['subcategoryIds'] ?? {});
        _selectedBrandIds = Set<int>.from(result['brandIds'] ?? {});
      });
    }
  }

  PreferredSizeWidget? _buildAppBar(BuildContext context, bool isDesktop, ThemeData theme) {
    if (!isDesktop) {
      if (_currentTabIndex != 0) return null;
      return AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.shopping_bag, color: theme.colorScheme.primary, size: 24),
            ),
            const SizedBox(width: 10),
            Text(
              'SingleMart',
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 22,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        actions: [
          if (_isLoggedIn) ...[
            Builder(
              builder: (ctx) {
                final String? userImage = _userData?['user_image']?.toString();
                final String imageUrl = (userImage != null && userImage.isNotEmpty)
                    ? "https://agsdemo.in/singlemartapi/public/assets/images/user_images/$userImage"
                    : "";

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _currentTabIndex = 3;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16.0),
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.primary.withOpacity(0.08),
                      backgroundImage: imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
                      child: imageUrl.isEmpty
                          ? const Icon(Icons.person, size: 20, color: AppColors.primary)
                          : null,
                    ),
                  ),
                );
              },
            )
          ] else
            TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                ).then((_) => _loadSession());
              },
              icon: const Icon(Icons.login_rounded, size: 18, color: AppColors.primary),
              label: const Text(
                'Sign In',
                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
              ),
            ),
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
                setState(() {
                  _currentTabIndex = 0;
                });
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
                        onTap: () {
                          if (_currentTabIndex != 0) {
                            setState(() {
                              _currentTabIndex = 0;
                            });
                          }
                        },
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val;
                            if (val.isNotEmpty && _currentTabIndex != 0) {
                              _currentTabIndex = 0;
                            }
                          });
                        },
                        decoration: const InputDecoration(
                          hintText: 'Search for local products, stores, brands...',
                          hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                    if (_searchQuery.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: Icon(Icons.clear_rounded, color: AppColors.textLight, size: 18),
                        ),
                      ),
                    GestureDetector(
                      onTap: () {
                        _searchFocusNode.requestFocus();
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
                  setState(() {
                    _currentTabIndex = 1;
                  });
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
                  final bool isActive = _currentTabIndex == 4;
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _currentTabIndex = 4;
                      });
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isActive ? theme.colorScheme.primary.withOpacity(0.08) : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: AppColors.primary.withOpacity(0.1),
                            backgroundImage: imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
                            child: imageUrl.isEmpty
                                ? const Icon(Icons.person, size: 16, color: AppColors.primary)
                                : null,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isActive ? theme.colorScheme.primary : AppColors.textPrimary,
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
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                  ).then((_) => _loadSession());
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
    int badgeCount = 0,
    required ThemeData theme,
  }) {
    final bool isActive = _currentTabIndex == index;
    final Color itemColor = isActive ? theme.colorScheme.primary : AppColors.textLight;

    return InkWell(
      onTap: () {
        setState(() {
          _currentTabIndex = index;
        });
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.of(context).size.width;
    final bool isDesktop = width > 850;

    Widget activeBody;
    if (_currentTabIndex == 0) {
      activeBody = _buildDashboardBody(theme, isDesktop);
    } else if (_currentTabIndex == 1) {
      activeBody = CategoriesListScreen(categories: _categories, isEmbedded: true);
    } else if (_currentTabIndex == 2) {
      activeBody = const ProductsListScreen(isEmbedded: true);
    } else if (_currentTabIndex == 3) {
      activeBody = CartScreen(
        isEmbedded: true,
        onStartShopping: () {
          setState(() {
            _currentTabIndex = 0;
          });
        },
      );
    } else {
      activeBody = _buildProfileTab(theme);
    }

    return PopScope(
      canPop: !_isSearchFocused && _searchQuery.isEmpty,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _searchController.clear();
        _searchFocusNode.unfocus();
        setState(() {
          _searchQuery = '';
          _isSearchFocused = false;
        });
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFAFBFD),
      appBar: _buildAppBar(context, isDesktop, theme),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isDesktop ? 1200 : double.infinity,
                ),
                child: activeBody,
              ),
            ),
      floatingActionButton: _currentTabIndex == 0
          ? FloatingActionButton(
              onPressed: _navigateToFilterScreen,
              backgroundColor: theme.colorScheme.primary,
              child: const Icon(Icons.filter_list_rounded, color: Colors.white),
            )
          : null,
      bottomNavigationBar: isDesktop
          ? null
          : Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: SafeArea(
                child: SizedBox(
                  height: 45,
                  child: BottomNavigationBar(
                    currentIndex: _currentTabIndex,
                    onTap: (index) {
                      setState(() {
                        _currentTabIndex = index;
                      });
                    },
                    backgroundColor: Colors.white,
                    elevation: 0,
                    type: BottomNavigationBarType.fixed,
                    selectedItemColor: AppColors.primary,
                    unselectedItemColor: AppColors.textLight,
                    selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
                    unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 10),
                    iconSize: 18,
                    items: [
                      const BottomNavigationBarItem(
                        icon: Icon(Icons.home_outlined),
                        activeIcon: Icon(Icons.home_rounded),
                        label: 'Home',
                      ),
                      const BottomNavigationBarItem(
                        icon: Icon(Icons.grid_view_outlined),
                        activeIcon: Icon(Icons.grid_view_rounded),
                        label: 'Categories',
                      ),
                      const BottomNavigationBarItem(
                        icon: Icon(Icons.local_mall_outlined),
                        activeIcon: Icon(Icons.local_mall_rounded),
                        label: 'Products',
                      ),
                      BottomNavigationBarItem(
                        icon: ValueListenableBuilder<int>(
                          valueListenable: CartManager.cartCountNotifier,
                          builder: (context, count, child) {
                            return Stack(
                              clipBehavior: Clip.none,
                              children: [
                                const Icon(Icons.shopping_cart_outlined),
                                if (count > 0)
                                  Positioned(
                                    top: -4,
                                    right: -6,
                                    child: Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: const BoxDecoration(
                                        color: AppColors.primary,
                                        shape: BoxShape.circle,
                                      ),
                                      constraints: const BoxConstraints(
                                        minWidth: 14,
                                        minHeight: 14,
                                      ),
                                      child: Text(
                                        '$count',
                                        style: const TextStyle(
                                          fontSize: 8,
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
                        activeIcon: ValueListenableBuilder<int>(
                          valueListenable: CartManager.cartCountNotifier,
                          builder: (context, count, child) {
                            return Stack(
                              clipBehavior: Clip.none,
                              children: [
                                const Icon(Icons.shopping_cart_rounded),
                                if (count > 0)
                                  Positioned(
                                    top: -4,
                                    right: -6,
                                    child: Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: const BoxDecoration(
                                        color: AppColors.primary,
                                        shape: BoxShape.circle,
                                      ),
                                      constraints: const BoxConstraints(
                                        minWidth: 14,
                                        minHeight: 14,
                                      ),
                                      child: Text(
                                        '$count',
                                        style: const TextStyle(
                                          fontSize: 8,
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
                        label: 'Cart',
                      ),
                      const BottomNavigationBarItem(
                        icon: Icon(Icons.person_outline_rounded),
                        activeIcon: Icon(Icons.person_rounded),
                        label: 'Profile',
                      ),
                    ],
                  ),
                ),
              ),
            ),
    ),
    );
  }

  Widget _buildProfileTab(ThemeData theme) {
    return ProfileScreen(
      isLoggedIn: _isLoggedIn,
      userData: _userData,
      token: _authToken,
      onLogout: _logout,
      onLoginSuccess: _loadSession,
      onRefreshProfile: _refreshProfileFromServer,
    );
  }

  Widget _buildBannerSlider(ThemeData theme) {
    if (_banners.isEmpty) {
      // Fallback default banner card
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isLoggedIn ? 'Welcome, ${_userData?['name']}!' : 'Grand Local Deals!',
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Direct neighborhood shopping with instant delivery and zero fees.',
              style: TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
            ),
          ],
        ),
      );
    }

    final bool isDesktop = MediaQuery.of(context).size.width > 850;
    return Container(
      height: isDesktop ? 280 : 180,
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: isDesktop ? 20 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            PageView.builder(
              controller: _bannerPageController,
              itemCount: _banners.length,
              onPageChanged: (index) {
                setState(() {
                  _currentBannerIndex = index;
                });
              },
              itemBuilder: (context, index) {
                final banner = _banners[index];
                final String imageUrl = _getBannerImage(banner['banner_image']);
                final String? link = banner['banner_link'];

                return GestureDetector(
                  onTap: () {
                    if (link != null && link.isNotEmpty) {
                      _launchUrl(link);
                    }
                  },
                  child: Image.network(
                    imageUrl,
                    width: double.infinity,
                    height: 180,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: theme.colorScheme.primary.withOpacity(0.05),
                      child: Icon(Icons.broken_image, color: theme.colorScheme.primary, size: 48),
                    ),
                  ),
                );
              },
            ),
            if (_banners.length > 1)
              Positioned(
                bottom: 12,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_banners.length, (index) {
                    final bool isCurrent = index == _currentBannerIndex;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: isCurrent ? 12 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isCurrent ? theme.colorScheme.primary : theme.colorScheme.primary.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardBody(ThemeData theme, bool isDesktop) {
    // Dynamic local products filtering logic
    final List<dynamic> filteredProducts = _allProducts.where((p) {
      final bool matchesCategory = _selectedCategoryIds.isEmpty || _selectedCategoryIds.contains(p['category_id']);
      final bool matchesSubcategory = _selectedSubcategoryIds.isEmpty || _selectedSubcategoryIds.contains(p['subcategory_id']);
      final bool matchesBrand = _selectedBrandIds.isEmpty || _selectedBrandIds.contains(p['brand_id']);
      
      final bool matchesSearch = _searchQuery.isEmpty || 
          p['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) || 
          p['desc'].toString().toLowerCase().contains(_searchQuery.toLowerCase());

      return matchesCategory && matchesSubcategory && matchesBrand && matchesSearch;
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadCatalog,
      child: SingleChildScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Banner Carousel Slider
            if (_searchQuery.isEmpty && !_isSearchFocused)
              _buildBannerSlider(theme),

            // Top Search Input bar (Mobile only, hidden on desktop since header has it)
            if (!isDesktop)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  onTap: () {
                    _scrollController.animateTo(
                      0.0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  },
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search products...',
                    prefixIcon: (_isSearchFocused || _searchQuery.isNotEmpty)
                        ? IconButton(
                            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
                            onPressed: () {
                              _searchController.clear();
                              _searchFocusNode.unfocus();
                              setState(() {
                                _searchQuery = '';
                                _isSearchFocused = false;
                              });
                            },
                          )
                        : const Icon(Icons.search, color: AppColors.textLight),
                    suffixIcon: _searchQuery.isNotEmpty 
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: AppColors.textLight),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
                    ),
                  ),
                ),
              ),

            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SizeTransition(
                    sizeFactor: animation,
                    axisAlignment: -1.0,
                    child: child,
                  ),
                );
              },
              child: (_searchQuery.isNotEmpty || _isSearchFocused)
                  ? KeyedSubtree(
                      key: const ValueKey('suggestions_view'),
                      child: _buildSearchSuggestionsList(theme, filteredProducts),
                    )
                  : Column(
                      key: const ValueKey('default_view'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Minimal Category Section (Single-select, Name above Image, no borders/cards)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Categories',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                              ),
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => CategoriesListScreen(
                                        categories: _categories,
                                      ),
                                    ),
                                  );
                                },
                                child: Text(
                                  'View All',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          height: isDesktop ? 150 : 110,
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _categories.length,
                            itemBuilder: (context, index) {
                              final cat = _categories[index];
                              final int id = cat['id'];
                              final bool isSelected = _selectedCategoryIds.contains(id);
                              final String imageUrl = _getCategoryImage(cat['categories_image']);

                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedCategoryIds.clear();
                                    _selectedSubcategoryIds.clear();
                                    if (!isSelected) {
                                      _selectedCategoryIds.add(id);
                                    }
                                  });
                                },
                                child: Container(
                                  margin: EdgeInsets.symmetric(horizontal: isDesktop ? 18 : 12),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: isSelected ? theme.colorScheme.primary : AppColors.border,
                                            width: 2.0,
                                          ),
                                          boxShadow: isSelected
                                              ? [
                                                  BoxShadow(
                                                    color: theme.colorScheme.primary.withOpacity(0.2),
                                                    blurRadius: 8,
                                                    offset: const Offset(0, 3),
                                                  ),
                                                ]
                                              : [],
                                        ),
                                        padding: const EdgeInsets.all(3),
                                        child: ClipOval(
                                          child: Image.network(
                                            imageUrl,
                                            width: isDesktop ? 80 : 54,
                                            height: isDesktop ? 80 : 54,
                                            fit: BoxFit.cover,
                                            cacheWidth: 120,
                                            cacheHeight: 120,
                                            errorBuilder: (context, error, stackTrace) => Container(
                                              width: isDesktop ? 80 : 54,
                                              height: isDesktop ? 80 : 54,
                                              color: theme.colorScheme.primary.withOpacity(0.05),
                                              child: Icon(
                                                _getCategoryIcon(cat['categories_name'] ?? ''),
                                                color: theme.colorScheme.primary,
                                                size: isDesktop ? 36 : 24,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      SizedBox(
                                        width: isDesktop ? 120 : 80,
                                        child: Text(
                                          cat['categories_name'] ?? 'Category',
                                          textAlign: TextAlign.center,
                                          maxLines: isDesktop ? 2 : 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: isSelected ? theme.colorScheme.primary : AppColors.textPrimary,
                                            fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
                                            fontSize: isDesktop ? 13 : 12,
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

                        // Products Grid Title
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Featured Products',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                              ),
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const ProductsListScreen()),
                                  );
                                },
                                child: Text(
                                  'View All',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Products Grid listing
                        filteredProducts.isEmpty
                            ? _buildEmptyProductState()
                            : GridView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: isDesktop ? 6 : 2,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                  childAspectRatio: 0.72,
                                ),
                                itemCount: filteredProducts.length,
                                itemBuilder: (context, index) {
                                  final prod = filteredProducts[index];
                                  return _buildProductCard(prod, theme);
                                },
                              ),
                      ],
                    ),
            ),
            const SizedBox(height: 80), // Extra space to scroll above FAB
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyProductState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.border.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.search_off_rounded, size: 48, color: AppColors.textLight),
            ),
            const SizedBox(height: 16),
            const Text(
              'No product found',
              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 16),
            ),
            const SizedBox(height: 6),
            const Text('Try resetting or applying filters from the FAB.', style: TextStyle(color: AppColors.textLight, fontSize: 12)),
          ],
        ),
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

  Widget _buildSearchSuggestionsList(ThemeData theme, List<dynamic> matchedProducts) {
    final bool isQueryEmpty = _searchQuery.isEmpty;

    if (isQueryEmpty) {
      final List<dynamic> recommendedProducts = _allProducts.take(10).toList();
      if (recommendedProducts.isEmpty) return const SizedBox.shrink();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Text(
              'Recommended for You',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
                letterSpacing: 0.2,
              ),
            ),
          ),
          SizedBox(
            height: 185,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: recommendedProducts.length,
              itemBuilder: (context, index) {
                final prod = recommendedProducts[index];

                // Resolve image path
                final bool hasVariants = (prod['has_variants'] == 1 || prod['has_variants'] == '1') &&
                    prod['variants'] != null &&
                    (prod['variants'] as List).isNotEmpty;

                String imageUrl = _baseNoImageUrl;
                if (hasVariants) {
                  final firstVar = (prod['variants'] as List).first;
                  final varImages = firstVar['images'];
                  if (varImages != null && varImages is List && varImages.isNotEmpty) {
                    final String? filename = varImages[0]['product_variant_images'];
                    if (filename != null && filename.isNotEmpty) {
                      imageUrl = '$_baseProductVariantImageUrl$filename';
                    }
                  } else {
                    final prodImages = prod['images'];
                    if (prodImages != null && prodImages is List && prodImages.isNotEmpty) {
                      final String? filename = prodImages[0]['product_images'];
                      if (filename != null && filename.isNotEmpty) {
                        imageUrl = '$_baseProductImageUrl$filename';
                      }
                    }
                  }
                } else {
                  final images = prod['images'];
                  if (images != null && images is List && images.isNotEmpty) {
                    final String? filename = images[0]['product_images'];
                    if (filename != null && filename.isNotEmpty) {
                      imageUrl = '$_baseProductImageUrl$filename';
                    }
                  }
                }

                final double price = prod['price'] is num
                    ? (prod['price'] as num).toDouble()
                    : (double.tryParse(prod['price']?.toString() ?? '0') ?? 0.0);

                return Container(
                  width: 130,
                  margin: const EdgeInsets.only(right: 12, bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border, width: 1.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ProductDetailScreen(product: prod),
                          ),
                        ).then((_) {
                          CartManager.updateCartCount();
                          _loadCart();
                        });
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withOpacity(0.05),
                              ),
                              child: Image.network(
                                imageUrl,
                                fit: BoxFit.contain,
                                cacheWidth: 200,
                                cacheHeight: 200,
                                errorBuilder: (context, error, stackTrace) => Center(
                                  child: Icon(
                                    _getCategoryIcon(prod['image'] ?? ''),
                                    color: theme.colorScheme.primary,
                                    size: 32,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  prod['name'] ?? 'Product Name',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "₹${price.toStringAsFixed(2)}",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    color: theme.colorScheme.primary,
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
              },
            ),
          ),
        ],
      );
    }

    if (matchedProducts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.border.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.search_off_rounded, size: 48, color: AppColors.textLight),
              ),
              const SizedBox(height: 16),
              const Text(
                'No matching products found',
                style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 16),
              ),
              const SizedBox(height: 6),
              const Text(
                'Try searching for something else.',
                style: TextStyle(color: AppColors.textLight, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Text(
            'Search Results',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textLight,
            ),
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: matchedProducts.length,
          itemBuilder: (context, index) {
            final prod = matchedProducts[index];
            
            // Resolve image path
            final bool hasVariants = (prod['has_variants'] == 1 || prod['has_variants'] == '1') &&
                prod['variants'] != null &&
                (prod['variants'] as List).isNotEmpty;

            String imageUrl = _baseNoImageUrl;
            if (hasVariants) {
              final firstVar = (prod['variants'] as List).first;
              final varImages = firstVar['images'];
              if (varImages != null && varImages is List && varImages.isNotEmpty) {
                final String? filename = varImages[0]['product_variant_images'];
                if (filename != null && filename.isNotEmpty) {
                  imageUrl = '$_baseProductVariantImageUrl$filename';
                }
              } else {
                final prodImages = prod['images'];
                if (prodImages != null && prodImages is List && prodImages.isNotEmpty) {
                  final String? filename = prodImages[0]['product_images'];
                  if (filename != null && filename.isNotEmpty) {
                    imageUrl = '$_baseProductImageUrl$filename';
                  }
                }
              }
            } else {
              final images = prod['images'];
              if (images != null && images is List && images.isNotEmpty) {
                final String? filename = images[0]['product_images'];
                if (filename != null && filename.isNotEmpty) {
                  imageUrl = '$_baseProductImageUrl$filename';
                }
              }
            }

            return Container(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.border, width: 0.8)),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(
                    imageUrl,
                    width: 36,
                    height: 36,
                    fit: BoxFit.cover,
                    cacheWidth: 80,
                    cacheHeight: 80,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 36,
                      height: 36,
                      color: theme.colorScheme.primary.withOpacity(0.05),
                      child: Icon(
                        _getCategoryIcon(prod['image'] ?? ''),
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                    ),
                  ),
                ),
                title: _buildHighlightedText(
                  prod['name'] ?? 'Product Name',
                  _searchQuery,
                  const TextStyle(
                    fontSize: 13.0,
                    color: AppColors.textLight,
                    fontWeight: FontWeight.normal,
                  ),
                  const TextStyle(
                    fontSize: 13.0,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 2.0),
                  child: Text(
                    "₹${(prod['price'] is num ? prod['price'] : double.tryParse(prod['price']?.toString() ?? '0') ?? 0.0).toStringAsFixed(2)}",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                      fontSize: 12,
                    ),
                  ),
                ),
                trailing: const Icon(
                  Icons.call_made_rounded,
                  color: AppColors.textMuted,
                  size: 16,
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProductDetailScreen(product: prod),
                    ),
                  ).then((_) {
                    CartManager.updateCartCount();
                    _loadCart();
                  });
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildHighlightedText(String text, String query, TextStyle baseStyle, TextStyle highlightStyle) {
    if (query.isEmpty) {
      return Text(text, style: baseStyle, maxLines: 1, overflow: TextOverflow.ellipsis);
    }
    final String textLower = text.toLowerCase();
    final String queryLower = query.toLowerCase();
    final int startIndex = textLower.indexOf(queryLower);
    if (startIndex == -1) {
      return Text(text, style: baseStyle, maxLines: 1, overflow: TextOverflow.ellipsis);
    }
    final int endIndex = startIndex + query.length;

    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: baseStyle,
        children: [
          if (startIndex > 0)
            TextSpan(text: text.substring(0, startIndex)),
          TextSpan(
            text: text.substring(startIndex, endIndex),
            style: highlightStyle,
          ),
          if (endIndex < text.length)
            TextSpan(text: text.substring(endIndex)),
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

  String _formatNumber(int number) {
    final str = number.toString();
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return str.replaceAllMapped(reg, (Match m) => "${m[1]},");
  }
}
