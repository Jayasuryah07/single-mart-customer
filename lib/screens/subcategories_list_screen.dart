import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../widgets/cart_button.dart';
import 'products_list_screen.dart';
import 'ecommerce_home_screen.dart';

class SubcategoriesListScreen extends StatefulWidget {
  final int? categoryId;
  final String? categoryName;
  const SubcategoriesListScreen({super.key, this.categoryId, this.categoryName});

  @override
  State<SubcategoriesListScreen> createState() => _SubcategoriesListScreenState();
}

class _SubcategoriesListScreenState extends State<SubcategoriesListScreen> {
  bool _isLoading = true;
  List<dynamic> _subcategories = [];

  String _baseNoImageUrl = 'https://agsdemo.in/singlemartapi/public/assets/images/no_image.jpg';
  String _baseSubcategoryImageUrl = 'https://agsdemo.in/singlemartapi/public/assets/images/category_images/';

  bool _isLoggedIn = false;
  Map<String, dynamic>? _userData;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

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

  @override
  void initState() {
    super.initState();
    _loadBaseUrls();
    _loadSubcategories();
    _loadSession();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadBaseUrls() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _baseNoImageUrl = prefs.getString('base_no_image_url') ?? _baseNoImageUrl;
        _baseSubcategoryImageUrl = prefs.getString('base_subcategory_image_url') ?? prefs.getString('base_category_image_url') ?? _baseSubcategoryImageUrl;
      });
    } catch (_) {}
  }

  Future<void> _loadSubcategories() async {
    try {
      final response = await ApiService.fetchActiveSubCategories();
      if (response.statusCode == 200) {
        final Map<String, dynamic> body = json.decode(response.body);
        final List<dynamic> allSubs = body['data'] ?? [];
        
        final dynamic imageUrls = body['image_url'];
        if (imageUrls != null && imageUrls is List) {
          final prefs = await SharedPreferences.getInstance();
          for (var item in imageUrls) {
            final imageFor = item['image_for']?.toString();
            final url = item['image_url']?.toString();
            if (imageFor == 'Category' && url != null) {
              await prefs.setString('base_subcategory_image_url', url);
            } else if (imageFor == 'No Image' && url != null) {
              await prefs.setString('base_no_image_url', url);
            }
          }
        }
        setState(() {
          _subcategories = allSubs;
          _isLoading = false;
        });
        return;
      }
      throw Exception();
    } catch (e) {
      debugPrint("Failed to fetch subcategories, loading local fallbacks: $e");
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
        {"id": 17, "category_id": 5, "categories_subs_name": "Gym Equipment"},
        {"id": 18, "category_id": 5, "categories_subs_name": "Cricket"},
        {"id": 19, "category_id": 5, "categories_subs_name": "Football"},
        {"id": 9, "category_id": 3, "categories_subs_name": "Furniture"},
        {"id": 11, "category_id": 3, "categories_subs_name": "Home Decor"},
        {"id": 15, "category_id": 4, "categories_subs_name": "Makeup"},
        {"id": 5, "category_id": 2, "categories_subs_name": "Men Clothing"},
        {"id": 6, "category_id": 2, "categories_subs_name": "Women Clothing"},
        {"id": 20, "category_id": 5, "categories_subs_name": "Yoga Mats"}
      ];

      setState(() {
        _subcategories = localFallbacks;
        _isLoading = false;
      });
    }
  }

  String _getSubcategoryImage(dynamic subsImage) {
    if (subsImage == null || subsImage.toString().isEmpty) {
      return _baseNoImageUrl;
    }
    final String pathStr = subsImage.toString();
    if (pathStr.startsWith('/tmp') || pathStr.startsWith('/var') || pathStr.contains('/')) {
      if (!pathStr.contains('category_images') && (pathStr.startsWith('/') || pathStr.startsWith('\\'))) {
        return _baseNoImageUrl;
      }
    }
    return '${_baseSubcategoryImageUrl}$pathStr';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isDesktop = MediaQuery.of(context).size.width > 850;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(context, isDesktop, theme),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isDesktop ? 1200 : double.infinity,
          ),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : (_subcategories.isEmpty
                  ? _buildEmptyState()
                  : GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: isDesktop ? 8 : 4,
                        crossAxisSpacing: isDesktop ? 16 : 10,
                        mainAxisSpacing: isDesktop ? 20 : 16,
                        childAspectRatio: isDesktop ? 0.85 : 0.72,
                      ),
                      itemCount: _subcategories.length,
                      itemBuilder: (context, index) {
                        final sub = _subcategories[index];
                        final String imageUrl = _getSubcategoryImage(sub['categories_subs_image']);

                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ProductsListScreen(
                                  categoryId: sub['category_id'],
                                  subcategoryId: sub['id'],
                                  subcategoryName: sub['categories_subs_name'] ?? 'Subcategory',
                                ),
                              ),
                            );
                          },
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Expanded(
                                child: AspectRatio(
                                  aspectRatio: 1.0,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppColors.border.withOpacity(0.6),
                                        width: 1.0,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.02),
                                          blurRadius: 6,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: ClipOval(
                                      child: Image.network(
                                        imageUrl,
                                        fit: BoxFit.cover,
                                        cacheWidth: 200,
                                        cacheHeight: 200,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(
                                            color: theme.colorScheme.primary.withOpacity(0.05),
                                            child: const Icon(
                                              Icons.broken_image_rounded,
                                              color: AppColors.textLight,
                                              size: 24,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                sub['categories_subs_name'] ?? 'Subcategory',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: isDesktop ? 13 : 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    )),
        ),
      ),
    );
  }

  PreferredSizeWidget? _buildAppBar(BuildContext context, bool isDesktop, ThemeData theme) {
    if (!isDesktop) {
      return AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          widget.categoryName ?? 'All Subcategories',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w900,
            fontSize: 20,
            letterSpacing: 0.3,
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: const [
          CartButton(),
          SizedBox(width: 12),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: AppColors.border,
            height: 1.0,
          ),
        ),
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
            _buildDesktopNavItem(
              icon: Icons.grid_view_outlined,
              activeIcon: Icons.grid_view_rounded,
              label: 'Categories',
              index: 1,
              isActive: true,
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
                  index: 2,
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
                          builder: (context) => const ECommerceHomeScreen(initialTabIndex: 3),
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
                      builder: (context) => const ECommerceHomeScreen(initialTabIndex: 3),
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
    final Color itemColor = isActive ? theme.colorScheme.primary : AppColors.textLight;

    return InkWell(
      onTap: () {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => ECommerceHomeScreen(initialTabIndex: index),
          ),
          (route) => false,
        );
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
            child: const Icon(Icons.hourglass_empty_rounded, size: 64, color: AppColors.textMuted),
          ),
          const SizedBox(height: 20),
          const Text(
            'No subcategory found',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          const Text('Check back later for subcategories.', style: TextStyle(color: AppColors.textLight)),
        ],
      ),
    );
  }
}
