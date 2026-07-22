import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../widgets/cart_button.dart';
import 'products_list_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _loadBaseUrls();
    _loadSubcategories();
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

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
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
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : (_subcategories.isEmpty
              ? _buildEmptyState()
              : GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.72,
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
                                  color: const Color(0xFFF2F2F4), // Light gray background matching categories
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
                            sub['categories_subs_name'] ?? 'Subcategory',
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
                )),
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
