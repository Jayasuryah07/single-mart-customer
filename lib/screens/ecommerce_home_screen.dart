import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../widgets/cart_button.dart';
import 'categories_list_screen.dart';
import 'subcategories_list_screen.dart';
import 'products_list_screen.dart';
import 'login_screen.dart';

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

  // Search States
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Multi-Select Filter Selections
  Set<int> _selectedCategoryIds = {};
  Set<int> _selectedSubcategoryIds = {};
  Set<int> _selectedBrandIds = {};

  // User Auth State
  Map<String, dynamic>? _userData;
  bool _isLoggedIn = false;

  // Local Cart State
  List<Map<String, dynamic>> _cartItems = [];

  // Mock Products database
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
    _loadSession();
    _loadCatalog();
    _loadCart();
  }

  @override
  void dispose() {
    _searchController.dispose();
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
    } else {
      setState(() {
        _isLoggedIn = false;
        _userData = null;
      });
    }
  }

  Future<void> _loadCatalog() async {
    setState(() => _isLoading = true);
    try {
      final responses = await Future.wait([
        ApiService.fetchActiveCategories(),
        ApiService.fetchActiveSubCategories(),
        ApiService.fetchActiveBrands(),
      ]);

      final catRes = responses[0];
      final subRes = responses[1];
      final brandRes = responses[2];

      List<dynamic> loadedCats = [];
      List<dynamic> loadedSubs = [];
      List<dynamic> loadedBrands = [];

      if (catRes.statusCode == 200) {
        loadedCats = json.decode(catRes.body)['data'] ?? [];
      }
      if (subRes.statusCode == 200) {
        loadedSubs = json.decode(subRes.body)['data'] ?? [];
      }
      if (brandRes.statusCode == 200) {
        loadedBrands = json.decode(brandRes.body)['data'] ?? [];
      }

      setState(() {
        _categories = loadedCats;
        _subcategories = loadedSubs;
        _brands = loadedBrands;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Failed to load catalog from APIs: $e");
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

  Future<void> _logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      if (token.isNotEmpty) {
        await ApiService.logout(token);
      }
    } catch (e) {
      debugPrint("Error invalidating session during logout: $e");
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_data');

    setState(() {
      _isLoggedIn = false;
      _userData = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Logged out successfully.")),
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

  // Custom filter sheets launcher with Back Button and Multi-Select tags
  void _showFilterBottomSheet() {
    final theme = Theme.of(context);
    
    // Copy main filter state into bottom sheet local variables to enable cancellation on Back
    Set<int> localCategoryIds = Set.from(_selectedCategoryIds);
    Set<int> localSubcategoryIds = Set.from(_selectedSubcategoryIds);
    Set<int> localBrandIds = Set.from(_selectedBrandIds);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            // Filter active subcategories matching any selected categories (or show all if empty)
            final sheetActiveSubs = localCategoryIds.isEmpty 
                ? _subcategories 
                : _subcategories.where((s) => localCategoryIds.contains(s['category_id'])).toList();

            return Padding(
              padding: EdgeInsets.only(
                top: 12,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle Bar
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Header with Back Button
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
                          onPressed: () => Navigator.pop(context), // Back button dismisses changes
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Filters',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                    const Divider(color: AppColors.border),
                    const SizedBox(height: 12),

                    // 1. Categories Wrap (Multi-select)
                    const Text('Categories', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _categories.map((cat) {
                        final int id = cat['id'];
                        final bool isSelected = localCategoryIds.contains(id);
                        return ChoiceChip(
                          label: Text(cat['categories_name'] ?? ''),
                          selected: isSelected,
                          selectedColor: theme.colorScheme.primary.withOpacity(0.15),
                          checkmarkColor: theme.colorScheme.primary,
                          labelStyle: TextStyle(
                            color: isSelected ? theme.colorScheme.primary : AppColors.textPrimary,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          backgroundColor: const Color(0xFFF1F5F9),
                          side: BorderSide(color: isSelected ? theme.colorScheme.primary : Colors.transparent),
                          onSelected: (val) {
                            setSheetState(() {
                              if (val) {
                                localCategoryIds.add(id);
                              } else {
                                localCategoryIds.remove(id);
                                // Clean up subcategories matching this category
                                localSubcategoryIds.removeWhere((subId) {
                                  final matchingSub = _subcategories.firstWhere(
                                    (s) => s['id'] == subId,
                                    orElse: () => null,
                                  );
                                  return matchingSub != null && matchingSub['category_id'] == id;
                                });
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // 2. Subcategories Wrap (Multi-select)
                    if (sheetActiveSubs.isNotEmpty) ...[
                      const Text('Subcategories', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: sheetActiveSubs.map((sub) {
                          final int id = sub['id'];
                          final bool isSelected = localSubcategoryIds.contains(id);
                          return ChoiceChip(
                            label: Text(sub['categories_subs_name'] ?? ''),
                            selected: isSelected,
                            selectedColor: theme.colorScheme.secondary.withOpacity(0.15),
                            checkmarkColor: theme.colorScheme.secondary,
                            labelStyle: TextStyle(
                              color: isSelected ? theme.colorScheme.secondary : AppColors.textPrimary,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                            backgroundColor: const Color(0xFFF1F5F9),
                            side: BorderSide(color: isSelected ? theme.colorScheme.secondary : Colors.transparent),
                            onSelected: (val) {
                              setSheetState(() {
                                if (val) {
                                  localSubcategoryIds.add(id);
                                } else {
                                  localSubcategoryIds.remove(id);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // 3. Brands Wrap (Multi-select)
                    if (_brands.isNotEmpty) ...[
                      const Text('Brands', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _brands.map((brand) {
                          final int id = brand['id'];
                          final bool isSelected = localBrandIds.contains(id);
                          return ChoiceChip(
                            label: Text(brand['brands_name'] ?? ''),
                            selected: isSelected,
                            selectedColor: theme.colorScheme.primary.withOpacity(0.15),
                            checkmarkColor: theme.colorScheme.primary,
                            labelStyle: TextStyle(
                              color: isSelected ? theme.colorScheme.primary : AppColors.textPrimary,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                            backgroundColor: const Color(0xFFF1F5F9),
                            side: BorderSide(color: isSelected ? theme.colorScheme.primary : Colors.transparent),
                            onSelected: (val) {
                              setSheetState(() {
                                if (val) {
                                  localBrandIds.add(id);
                                } else {
                                  localBrandIds.remove(id);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 28),
                    ],

                    // Control Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setSheetState(() {
                                localCategoryIds.clear();
                                localSubcategoryIds.clear();
                                localBrandIds.clear();
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: const BorderSide(color: AppColors.border),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Reset All', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _selectedCategoryIds = Set.from(localCategoryIds);
                                _selectedSubcategoryIds = Set.from(localSubcategoryIds);
                                _selectedBrandIds = Set.from(localBrandIds);
                              });
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              backgroundColor: theme.colorScheme.primary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Apply Filters', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
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
          if (_isLoggedIn)
            Builder(
              builder: (ctx) => IconButton(
                icon: const Icon(Icons.account_circle, color: AppColors.primary, size: 28),
                onPressed: () => Scaffold.of(ctx).openEndDrawer(),
              ),
            )
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
      
      // Floating Filter Action Button on the bottom-right corner
      floatingActionButton: FloatingActionButton(
        onPressed: _showFilterBottomSheet,
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
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.person, size: 40, color: AppColors.primary),
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

  Widget _buildDashboardBody(ThemeData theme, bool isDesktop) {
    // Dynamic local products filtering logic
    final List<Map<String, dynamic>> filteredProducts = _allProducts.where((p) {
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
            // Top Banner Card
            Container(
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
            ),

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

            // Minimal Category Section (Name above Image, no borders/cards)
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
                        if (isSelected) {
                          _selectedCategoryIds.remove(id);
                          // Clear matching subcategories
                          _selectedSubcategoryIds.removeWhere((subId) {
                            final matchingSub = _subcategories.firstWhere(
                              (s) => s['id'] == subId,
                              orElse: () => null,
                            );
                            return matchingSub != null && matchingSub['category_id'] == id;
                          });
                        } else {
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
