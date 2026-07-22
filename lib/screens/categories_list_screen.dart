import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../widgets/cart_button.dart';
import 'products_list_screen.dart';
import 'subcategories_list_screen.dart';

class CategoriesListScreen extends StatefulWidget {
  final List<dynamic> categories;
  final bool isEmbedded;
  const CategoriesListScreen({super.key, required this.categories, this.isEmbedded = false});

  @override
  State<CategoriesListScreen> createState() => _CategoriesListScreenState();
}

class _CategoriesListScreenState extends State<CategoriesListScreen> {
  String _baseNoImageUrl = 'https://agsdemo.in/singlemartapi/public/assets/images/no_image.jpg';
  String _baseCategoryImageUrl = 'https://agsdemo.in/singlemartapi/public/assets/images/category_images/';
  String _baseBrandImageUrl = 'https://agsdemo.in/singlemartapi/public/assets/images/brand_images/';

  bool _isLoadingBrands = true;
  List<dynamic> _brands = [];

  @override
  void initState() {
    super.initState();
    _loadBaseUrls();
    _loadBrands();
  }

  Future<void> _loadBaseUrls() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _baseNoImageUrl = prefs.getString('base_no_image_url') ?? _baseNoImageUrl;
        _baseCategoryImageUrl = prefs.getString('base_category_image_url') ?? _baseCategoryImageUrl;
        _baseBrandImageUrl = prefs.getString('base_brand_image_url') ?? _baseBrandImageUrl;
      });
    } catch (_) {}
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
      debugPrint("Failed to fetch brands dynamically: $e");
      // Fallback local mocks
      final List<dynamic> localBrands = [
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
      setState(() {
        _brands = localBrands;
        _isLoadingBrands = false;
      });
    }
  }

  String _getCategoryImage(dynamic categoriesImage) {
    if (categoriesImage == null || categoriesImage.toString().isEmpty) {
      return _baseNoImageUrl;
    }
    final String pathStr = categoriesImage.toString();
    if (pathStr.startsWith('/tmp') || pathStr.startsWith('/var') || pathStr.contains('/')) {
      if (!pathStr.contains('category_images') && (pathStr.startsWith('/') || pathStr.startsWith('\\'))) {
        return _baseNoImageUrl;
      }
    }
    return '${_baseCategoryImageUrl}$pathStr';
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: !widget.isEmbedded,
        title: Text(
          widget.isEmbedded ? 'Categories' : 'All Categories',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w900,
            fontSize: 20,
            letterSpacing: 0.3,
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: widget.isEmbedded
            ? null
            : const [
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
      ),
      body: widget.categories.isEmpty
          ? const Center(child: Text("No categories found."))
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quick Navigation Row
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                          MaterialPageRoute(builder: (context) => const ProductsListScreen()),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [AppColors.primary, AppColors.secondary],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withOpacity(0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.shopping_bag_rounded, color: Colors.white, size: 18),
                                  SizedBox(width: 8),
                                  Text(
                                    'All Products',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                          MaterialPageRoute(builder: (context) => const SubcategoriesListScreen()),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.border, width: 1.2),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.02),
                                    blurRadius: 6,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.category_rounded, color: AppColors.primary, size: 18),
                                  SizedBox(width: 8),
                                  Text(
                                    'Subcategories',
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const Padding(
                    padding: EdgeInsets.fromLTRB(24, 20, 24, 12),
                    child: Text(
                      'Explore Categories',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ),
                  
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.72,
                    ),
                    itemCount: widget.categories.length,
                    itemBuilder: (context, index) {
                      final cat = widget.categories[index];
                      final String imageUrl = _getCategoryImage(cat['categories_image']);
                      
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ProductsListScreen(
                                categoryId: cat['id'],
                                subcategoryName: cat['categories_name'] ?? 'Category',
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
                                    border: Border.all(color: AppColors.border, width: 1.0),
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
                              cat['categories_name'] ?? 'Category',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  // Shop by Brand Section
                  // if (!_isLoadingBrands && _brands.isNotEmpty) ...[
                  //   const Padding(
                  //     padding: EdgeInsets.fromLTRB(24, 24, 24, 12),
                  //     child: Text(
                  //       'Shop by Brand',
                  //       style: TextStyle(
                  //         fontSize: 16,
                  //         fontWeight: FontWeight.w900,
                  //         color: AppColors.textPrimary,
                  //         letterSpacing: 0.1,
                  //       ),
                  //     ),
                  //   ),

                  //   GridView.builder(
                  //     shrinkWrap: true,
                  //     physics: const NeverScrollableScrollPhysics(),
                  //     padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  //     gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  //       crossAxisCount: 4,
                  //       crossAxisSpacing: 10,
                  //       mainAxisSpacing: 16,
                  //       childAspectRatio: 0.72,
                  //     ),
                  //     itemCount: _brands.length,
                  //     itemBuilder: (context, index) {
                  //       final brand = _brands[index];
                  //       final String imageUrl = _getBrandImage(brand['brands_image']);

                  //       return GestureDetector(
                  //         onTap: () {
                  //           Navigator.push(
                  //             context,
                  //             MaterialPageRoute(
                  //               builder: (context) => ProductsListScreen(
                  //                 initialBrandId: brand['id'],
                  //                 subcategoryName: brand['brands_name'] ?? 'Brand',
                  //               ),
                  //             ),
                  //           );
                  //         },
                  //         child: Column(
                  //           mainAxisAlignment: MainAxisAlignment.center,
                  //           children: [
                  //             Expanded(
                  //               child: AspectRatio(
                  //                 aspectRatio: 1.0,
                  //                 child: Container(
                  //                   decoration: BoxDecoration(
                  //                     color: Colors.white,
                  //                     shape: BoxShape.circle,
                  //                     border: Border.all(color: AppColors.border, width: 1.0),
                  //                   ),
                  //                   child: ClipOval(
                  //                     child: Padding(
                  //                       padding: const EdgeInsets.all(12.0),
                  //                       child: imageUrl.isNotEmpty
                  //                           ? Image.network(
                  //                               imageUrl,
                  //                               fit: BoxFit.contain,
                  //                               cacheWidth: 200,
                  //                               cacheHeight: 200,
                  //                               errorBuilder: (context, error, stackTrace) => Container(
                  //                                 color: theme.colorScheme.primary.withOpacity(0.05),
                  //                                 child: Center(
                  //                                   child: Text(
                  //                                     (brand['brands_name']?.toString().substring(0, min(2, brand['brands_name']?.toString().length ?? 1)) ?? 'B').toUpperCase(),
                  //                                     style: TextStyle(
                  //                                       fontSize: 14,
                  //                                       fontWeight: FontWeight.w900,
                  //                                       color: theme.colorScheme.primary,
                  //                                     ),
                  //                                   ),
                  //                                 ),
                  //                               ),
                  //                             )
                  //                           : Container(
                  //                               color: theme.colorScheme.primary.withOpacity(0.05),
                  //                               child: Center(
                  //                                 child: Text(
                  //                                   (brand['brands_name']?.toString().substring(0, min(2, brand['brands_name']?.toString().length ?? 1)) ?? 'B').toUpperCase(),
                  //                                   style: TextStyle(
                  //                                     fontSize: 14,
                  //                                     fontWeight: FontWeight.w900,
                  //                                     color: theme.colorScheme.primary,
                  //                                   ),
                  //                                 ),
                  //                               ),
                  //                             ),
                  //                     ),
                  //                   ),
                  //                 ),
                  //               ),
                  //             ),
                  //             const SizedBox(height: 10),
                  //             Text(
                  //               brand['brands_name'] ?? 'Brand',
                  //               maxLines: 1,
                  //               overflow: TextOverflow.ellipsis,
                  //               textAlign: TextAlign.center,
                  //               style: const TextStyle(
                  //                 fontSize: 11,
                  //                 fontWeight: FontWeight.w900,
                  //                 color: AppColors.textPrimary,
                  //               ),
                  //             ),
                  //           ],
                  //         ),
                  //       );
                  //     },
                  //   ),
                  // ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}
