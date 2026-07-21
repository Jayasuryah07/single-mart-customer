import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';
import '../widgets/cart_button.dart';
import 'products_list_screen.dart';

class CategoriesListScreen extends StatefulWidget {
  final List<dynamic> categories;
  const CategoriesListScreen({super.key, required this.categories});

  @override
  State<CategoriesListScreen> createState() => _CategoriesListScreenState();
}

class _CategoriesListScreenState extends State<CategoriesListScreen> {
  String _baseNoImageUrl = 'https://agsdemo.in/singlemartapi/public/assets/images/no_image.jpg';
  String _baseCategoryImageUrl = 'https://agsdemo.in/singlemartapi/public/assets/images/category_images/';

  @override
  void initState() {
    super.initState();
    _loadBaseUrls();
  }

  Future<void> _loadBaseUrls() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _baseNoImageUrl = prefs.getString('base_no_image_url') ?? _baseNoImageUrl;
        _baseCategoryImageUrl = prefs.getString('base_category_image_url') ?? _baseCategoryImageUrl;
      });
    } catch (_) {}
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFFAFBFD),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: const Text(
          'All Categories',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: const [
          CartButton(),
          SizedBox(width: 12),
        ],
      ),
      body: widget.categories.isEmpty
          ? const Center(child: Text("No categories found."))
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.9,
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
                        // Image Card
                        Expanded(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                            child: Image.network(
                              imageUrl,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: theme.colorScheme.primary.withOpacity(0.05),
                                  child: Icon(Icons.broken_image_rounded, color: theme.colorScheme.primary, size: 30),
                                );
                              },
                            ),
                          ),
                        ),
                        
                        // Name Info
                        Padding(
                          padding: const EdgeInsets.all(14),
                          child: Text(
                            cat['categories_name'] ?? 'Category',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
