import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../widgets/cart_button.dart';
import 'categories_list_screen.dart';
import 'subcategories_list_screen.dart';
import 'products_list_screen.dart';
import 'login_screen.dart';
import 'product_detail_screen.dart';
import 'filter_screen.dart';
import 'update_profile_screen.dart';
import 'manage_address_screen.dart';
import 'order_history_screen.dart';

class ECommerceHomeScreen extends StatefulWidget {
  const ECommerceHomeScreen({super.key});

  @override
  State<ECommerceHomeScreen> createState() => _ECommerceHomeScreenState();
}

class _ECommerceHomeScreenState extends State<ECommerceHomeScreen> {
  // Loading & Data States
  bool _isLoading = true;
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
  String _searchQuery = '';

  // Filter Selections (Maintained as Sets to support multi-select returning from FilterScreen)
  Set<int> _selectedCategoryIds = {};
  Set<int> _selectedSubcategoryIds = {};
  Set<int> _selectedBrandIds = {};

  // User Auth State
  Map<String, dynamic>? _userData;
  bool _isLoggedIn = false;

  // Local Cart State
  List<Map<String, dynamic>> _cartItems = [];

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
    _allProducts = List.from(_fallbackProducts);
    _loadSession();
    _loadCatalog();
    _loadCart();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _bannerPageController.dispose();
    _bannerTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('auth_token');
    final String? userDataStr = prefs.getString('user_data');
    if (token != null && token.isNotEmpty && userDataStr != null && userDataStr.isNotEmpty) {
      setState(() {
        _isLoggedIn = true;
        _userData = json.decode(userDataStr);
      });
      _refreshProfileFromServerSilent();
    } else {
      setState(() {
        _isLoggedIn = false;
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
        loadedCats = json.decode(catRes.body)['data'] ?? [];
      }
      if (subRes.statusCode == 200) {
        loadedSubs = json.decode(subRes.body)['data'] ?? [];
      }
      if (brandRes.statusCode == 200) {
        loadedBrands = json.decode(brandRes.body)['data'] ?? [];
      }
      if (prodRes.statusCode == 200) {
        loadedProds = json.decode(prodRes.body)['data'] ?? [];
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
            final double pPrice = double.tryParse(p['product_discount_price']?.toString() ?? '') ??
                double.tryParse(p['product_price']?.toString() ?? '') ??
                0.0;
            return {
              "id": p['id'],
              "name": p['product_name'] ?? 'Product',
              "price": pPrice,
              "desc": p['product_short_description'] ?? '',
              "image": p['categories_name'] ?? '',
              "category_id": p['product_category_id'],
              "subcategory_id": p['product_sub_category_id'],
              "brand_id": p['product_brand_id'],
              "product_vendor_id": p['product_vendor_id'],
              // Retain source payload maps for detail screen
              "images": p['images'],
              "product_name": p['product_name'],
              "vendor_name": p['vendor_name'],
              "categories_name": p['categories_name'],
              "categories_subs_name": p['categories_subs_name'],
              "brands_name": p['brands_name'],
              "product_short_description": p['product_short_description'],
              "product_long_description": p['product_long_description'],
              "product_price": p['product_price'],
              "product_discount_price": p['product_discount_price'],
              "product_status": p['product_status'],
            };
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

  Future<void> _logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      await prefs.remove('user_data');
      setState(() {
        _isLoggedIn = false;
        _userData = null;
      });
    } catch (e) {
      debugPrint("Error during logout: $e");
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

      setState(() {
        final existingIndex = currentCart.indexWhere((item) => item['id'] == product['id']);
        if (existingIndex != -1) {
          currentCart[existingIndex]['quantity'] = (currentCart[existingIndex]['quantity'] ?? 1) + 1;
        } else {
          currentCart.add({
            "id": product['id'],
            "name": product['name'],
            "price": product['price'],
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.of(context).size.width;
    final bool isDesktop = width > 850;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFBFD),
      appBar: AppBar(
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
            IconButton(
              icon: const Icon(Icons.sync_rounded, color: AppColors.primary),
              tooltip: 'Sync profile details',
              onPressed: _refreshProfileFromServer,
            ),
            Builder(
              builder: (ctx) {
                final String? userImage = _userData?['user_image']?.toString();
                final String imageUrl = (userImage != null && userImage.isNotEmpty)
                    ? "https://agsdemo.in/singlemartapi/public/assets/images/user_images/$userImage"
                    : "";

                return GestureDetector(
                  onTap: () => Scaffold.of(ctx).openEndDrawer(),
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
            )]
          else
            TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              },
              icon: const Icon(Icons.login_rounded, size: 18, color: AppColors.primary),
              label: const Text(
                'Sign In',
                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
              ),
            ),
          
          const CartButton(),
          const SizedBox(width: 12),
        ],
      ),
      // Left Navigation Drawer
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary, AppColors.secondary],
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.shopping_bag, color: Colors.white, size: 28),
                    SizedBox(width: 12),
                    Text(
                      'SingleMart Explore',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.grid_view_rounded, color: AppColors.textPrimary),
                title: const Text('Browse All Categories', style: TextStyle(fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => CategoriesListScreen(categories: _categories)),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.category_outlined, color: AppColors.textPrimary),
                title: const Text('Browse Subcategories', style: TextStyle(fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SubcategoriesListScreen()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.shopping_bag_outlined, color: AppColors.textPrimary),
                title: const Text('Browse All Products', style: TextStyle(fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ProductsListScreen()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      endDrawer: _isLoggedIn ? _buildProfileDrawer() : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildDashboardBody(theme, isDesktop),
      
      // Floating Filter Action Button redirects to full-screen FilterScreen
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToFilterScreen,
        backgroundColor: theme.colorScheme.primary,
        child: const Icon(Icons.filter_list_rounded, color: Colors.white),
      ),
    );
  }

  Widget _buildProfileDrawer() {
    final String name = _userData?['name'] ?? 'User';
    final String email = _userData?['email'] ?? 'shopper@singlemart.com';
    final String mobile = _userData?['mobile'] ?? '';

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.secondary],
                ),
              ),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                backgroundImage: _userData?['user_image'] != null && _userData!['user_image'].toString().isNotEmpty
                    ? NetworkImage("https://agsdemo.in/singlemartapi/public/assets/images/user_images/${_userData!['user_image']}")
                    : null,
                child: (_userData?['user_image'] == null || _userData!['user_image'].toString().isEmpty)
                    ? const Icon(Icons.person, size: 40, color: AppColors.primary)
                    : null,
              ),
              accountName: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              accountEmail: Text(email),
            ),
            if (mobile.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.phone_iphone_rounded, color: AppColors.textLight),
                title: Text('+91 $mobile', style: const TextStyle(fontWeight: FontWeight.w500)),
              ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.manage_accounts_rounded, color: AppColors.primary),
              title: const Text('Update Profile', style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () async {
                Navigator.pop(context);
                final String? token = (await SharedPreferences.getInstance()).getString('auth_token');
                if (token != null && _userData != null) {
                  final updated = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => UpdateProfileScreen(
                        userData: _userData!,
                        token: token,
                      ),
                    ),
                  );
                  if (updated == true) {
                    _loadSession();
                  }
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.location_on_rounded, color: AppColors.primary),
              title: const Text('Manage Addresses', style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () async {
                Navigator.pop(context);
                final String? token = (await SharedPreferences.getInstance()).getString('auth_token');
                if (token != null && _userData != null) {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ManageAddressScreen(
                        userData: _userData!,
                        token: token,
                      ),
                    ),
                  );
                  _loadSession();
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long_rounded, color: AppColors.primary),
              title: const Text('Order History', style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () async {
                Navigator.pop(context);
                final String? token = (await SharedPreferences.getInstance()).getString('auth_token');
                if (token != null) {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => OrderHistoryScreen(
                        token: token,
                      ),
                    ),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.sync_rounded, color: AppColors.primary),
              title: const Text('Refresh Profile', style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context);
                _refreshProfileFromServer();
              },
            ),
            const Divider(),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _logout();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.logout_rounded, color: Colors.white),
                  label: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ),
          ],
        ),
      ),
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

    return Container(
      height: 180,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Banner Carousel Slider
            _buildBannerSlider(theme),

            // Top Search Input bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: TextField(
                controller: _searchController,
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search products...',
                  prefixIcon: const Icon(Icons.search, color: AppColors.textLight),
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
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: theme.colorScheme.primary),
                  ),
                ),
              ),
            ),

            // Minimal Category Section (Single-select, Name above Image, no borders/cards)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(
                'Categories',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
            ),
            Container(
              height: 110,
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
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            cat['categories_name'] ?? 'Category',
                            style: TextStyle(
                              color: isSelected ? theme.colorScheme.primary : AppColors.textPrimary,
                              fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              imageUrl,
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                width: 60,
                                height: 60,
                                color: theme.colorScheme.primary.withOpacity(0.05),
                                child: Icon(
                                  _getCategoryIcon(cat['categories_name'] ?? ''),
                                  color: theme.colorScheme.primary,
                                  size: 24,
                                ),
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
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(
                'Featured Products',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
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
                      crossAxisCount: isDesktop ? 4 : 2,
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
    // Construct real product network image path
    final images = product['images'];
    String imageUrl = 'https://agsdemo.in/singlemartapi/public/assets/images/no_image.jpg';
    if (images != null && images is List && images.isNotEmpty) {
      final String? filename = images[0]['product_images'];
      if (filename != null && filename.isNotEmpty) {
        imageUrl = 'https://agsdemo.in/singlemartapi/public/assets/images/product_images/$filename';
      }
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
      child: Container(
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
                width: double.infinity,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.05),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                  child: Image.network(
                    imageUrl,
                    width: double.infinity,
                    fit: BoxFit.contain,
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
                        "₹${product['price']?.toStringAsFixed(2)}",
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
      ),
    );
  }
}
