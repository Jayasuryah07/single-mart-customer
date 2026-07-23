import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../widgets/cart_button.dart';
import 'cart_screen.dart';
import 'login_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final Map<String, dynamic> product;
  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _quantity = 1;
  int _selectedImageIndex = 0;
  final PageController _detailPageController = PageController();
  List<Map<String, dynamic>> _cartItems = [];

  // Review states
  bool _isLoggedIn = false;
  String? _token;
  Map<String, dynamic>? _userData;
  List<dynamic> _localReviews = [];
  bool _showAllReviews = false;

  int _selectedVariantIndex = 0;
  List<dynamic> _relatedProducts = [];
  bool _isLoadingRelated = false;
  String _baseNoImageUrl = 'https://agsdemo.in/singlemartapi/public/assets/images/no_image.jpg';
  String _baseUserImageUrl = 'https://agsdemo.in/singlemartapi/public/assets/images/user_images/';
  String _baseProductImageUrl = 'https://agsdemo.in/singlemartapi/public/assets/images/product_images/';
  String _baseProductVariantImageUrl = 'https://agsdemo.in/singlemartapi/public/assets/images/product_variant_images/';

  bool get _hasVariants {
    final variants = widget.product['variants'];
    final hasVarFlag = widget.product['has_variants'];
    return (hasVarFlag == 1 || hasVarFlag == '1') && variants != null && variants is List && variants.isNotEmpty;
  }

  Map<String, dynamic>? get _selectedVariant {
    if (!_hasVariants) return null;
    final variants = widget.product['variants'] as List;
    if (_selectedVariantIndex >= variants.length) return Map<String, dynamic>.from(variants[0]);
    return Map<String, dynamic>.from(variants[_selectedVariantIndex]);
  }

  String _formatVariantAttributes(Map<String, dynamic> variant) {
    final List<dynamic>? attrs = variant['attributes'];
    if (attrs != null && attrs.isNotEmpty) {
      final List<String> attrTexts = [];
      for (var attr in attrs) {
        final String? name = attr['attribute_name']?.toString();
        final String? val = attr['attribute_value']?.toString();
        if (val != null && val.isNotEmpty) {
          if (name != null && name.isNotEmpty) {
            attrTexts.add("$name: $val");
          } else {
            attrTexts.add(val);
          }
        }
      }
      if (attrTexts.isNotEmpty) {
        return attrTexts.join(", ");
      }
    }
   
    return "Variant #${variant['id']}";
  }

  @override
  void initState() {
    super.initState();
    _loadCart();
    _checkLoginStatus();
    _fetchRelatedProducts();
  }

  Future<void> _checkLoginStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final userDataStr = prefs.getString('user_data');
      
      _baseNoImageUrl = prefs.getString('base_no_image_url') ?? _baseNoImageUrl;
      _baseUserImageUrl = prefs.getString('base_user_image_url') ?? _baseUserImageUrl;
      _baseProductImageUrl = prefs.getString('base_product_image_url') ?? _baseProductImageUrl;
      _baseProductVariantImageUrl = prefs.getString('base_product_variant_image_url') ?? _baseProductVariantImageUrl;

      setState(() {
        _token = token;
        _isLoggedIn = token != null && token.isNotEmpty;
        if (userDataStr != null && userDataStr.isNotEmpty) {
          _userData = json.decode(userDataStr);
        }
        
        final reviews = widget.product['review'] ?? widget.product['reviews'] ?? widget.product['product_reviews'];
        if (reviews != null && reviews is List) {
          _localReviews = List<dynamic>.from(reviews);
        } else {
          _localReviews = [];
        }
      });
    } catch (e) {
      debugPrint("Error loading login status or reviews: $e");
    }
  }

  @override
  void dispose() {
    _detailPageController.dispose();
    super.dispose();
  }

  Future<void> _fetchRelatedProducts() async {
    setState(() => _isLoadingRelated = true);
    try {
      final response = await ApiService.fetchActiveProducts();
      if (response.statusCode == 200) {
        final resData = json.decode(response.body);
        final List<dynamic> allProductsList = resData['data'] ?? [];
        
        final dynamic currentSubCategoryId = widget.product['product_sub_category_id'] ?? widget.product['subcategory_id'];
        
        if (currentSubCategoryId != null) {
          final int subId = currentSubCategoryId is int 
              ? currentSubCategoryId 
              : int.tryParse(currentSubCategoryId.toString()) ?? 0;
          
          if (subId > 0) {
            setState(() {
              _relatedProducts = allProductsList.where((p) {
                final bool isNotCurrent = p['id']?.toString() != widget.product['id']?.toString();
                
                final dynamic pSubIdRaw = p['product_sub_category_id'] ?? p['subcategory_id'];
                final int pSubId = pSubIdRaw is int 
                    ? pSubIdRaw 
                    : int.tryParse(pSubIdRaw?.toString() ?? '') ?? 0;
                
                return isNotCurrent && pSubId == subId;
              }).toList();
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching related products: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoadingRelated = false);
      }
    }
  }

  Widget _buildRelatedProductsSection(ThemeData theme) {
    if (_isLoadingRelated) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }
    if (_relatedProducts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 32),
        const Text(
          'Related Products',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 230,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _relatedProducts.length,
            itemBuilder: (context, index) {
              final prod = _relatedProducts[index];
              
              final String pName = prod['product_name'] ?? prod['name'] ?? 'Product';
              final double regP = double.tryParse(prod['product_price']?.toString() ?? '') ?? 0.0;
              final double discP = double.tryParse(prod['product_discount_price']?.toString() ?? '') ?? 0.0;
              final double displayPrice = discP > 0 ? discP : regP;

              String? pImg;
              if (prod['images'] != null && prod['images'] is List && (prod['images'] as List).isNotEmpty) {
                pImg = prod['images'][0]['product_images']?.toString();
              }
              
              final String finalImgUrl = (pImg != null && pImg.isNotEmpty)
                  ? '$_baseProductImageUrl$pImg'
                  : _baseNoImageUrl;

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProductDetailScreen(product: prod),
                    ),
                  );
                },
                child: Container(
                  width: 150,
                  margin: const EdgeInsets.only(right: 16, bottom: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.015),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          decoration: const BoxDecoration(
                            color: Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.vertical(top: Radius.circular(19)),
                          ),
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
                            child: Image.network(
                              finalImgUrl,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) => const Icon(
                                Icons.broken_image_rounded,
                                color: AppColors.textLight,
                                size: 40,
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
                              pName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Text(
                                  "₹${displayPrice.toStringAsFixed(0)}",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                                if (discP > 0 && regP > discP) ...[
                                  const SizedBox(width: 4),
                                  Text(
                                    "₹${regP.toStringAsFixed(0)}",
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      decoration: TextDecoration.lineThrough,
                                      color: AppColors.textLight,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
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
    );
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

  Future<void> _addToCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? cartStr = prefs.getString('cart_data');
      List<Map<String, dynamic>> currentCart = [];
      if (cartStr != null && cartStr.isNotEmpty) {
        final List<dynamic> parsed = json.decode(cartStr);
        currentCart = parsed.map((item) => Map<String, dynamic>.from(item)).toList();
      }

      final selectedVar = _selectedVariant;

      final double discP = selectedVar != null
          ? (double.tryParse(selectedVar['product_discount_price']?.toString() ?? '') ?? 0.0)
          : (double.tryParse(widget.product['product_discount_price']?.toString() ?? '') ?? 0.0);
      final double regP = selectedVar != null
          ? (double.tryParse(selectedVar['product_price']?.toString() ?? '') ?? 0.0)
          : (double.tryParse(widget.product['product_price']?.toString() ?? '') ?? 0.0);

      final double price = (discP > 0) ? discP : (regP > 0 ? regP : double.tryParse(widget.product['price']?.toString() ?? '') ?? 0.0);
      final double originalPrice = (discP > 0 && regP > discP) ? regP : (regP > price ? regP : 0.0);

      String? productImg;
      if (selectedVar != null && selectedVar['images'] != null && selectedVar['images'] is List && (selectedVar['images'] as List).isNotEmpty) {
        productImg = selectedVar['images'][0]['product_variant_images']?.toString();
      } else if (widget.product['images'] != null && widget.product['images'] is List && (widget.product['images'] as List).isNotEmpty) {
        productImg = widget.product['images'][0]['product_images']?.toString();
      }

      final String variantAttrStr = selectedVar != null ? _formatVariantAttributes(selectedVar) : '';
      final int? varId = selectedVar != null ? int.tryParse(selectedVar['id']?.toString() ?? '') : null;
      final String cartMatchId = varId != null ? "${widget.product['id']}_v$varId" : "${widget.product['id']}";

      setState(() {
        final existingIndex = currentCart.indexWhere((item) {
          if (item['cart_item_id'] != null) {
            return item['cart_item_id'].toString() == cartMatchId;
          }
          if (varId != null) {
            return item['id'] == widget.product['id'] && item['variant_id'] == varId;
          }
          return item['id'] == widget.product['id'] && item['variant_id'] == null;
        });

        if (existingIndex != -1) {
          currentCart[existingIndex]['quantity'] = (currentCart[existingIndex]['quantity'] ?? 1) + _quantity;
        } else {
          currentCart.add({
            "cart_item_id": cartMatchId,
            "id": widget.product['id'],
            "variant_id": varId,
            "product_sku": selectedVar?['product_sku'] ?? widget.product['product_sku'],
            "variant_attributes": variantAttrStr.isNotEmpty ? variantAttrStr : null,
            "is_variant": selectedVar != null,
            "name": widget.product['product_name'] ?? widget.product['name'] ?? 'Product',
            "price": price,
            "original_price": originalPrice,
            "product_price": regP > 0 ? regP : originalPrice,
            "desc": widget.product['product_short_description'] ?? widget.product['desc'] ?? '',
            "image": widget.product['categories_name'] ?? widget.product['image'] ?? 'Products',
            "quantity": _quantity,
            "product_vendor_id": widget.product['product_vendor_id'],
            "created_by": widget.product['created_by'],
            "vendor_id": widget.product['vendor_id'] ?? widget.product['created_by'],
            "product_image": productImg,
          });
        }
        _cartItems = currentCart;
        _quantity = 1;
      });

      await prefs.setString('cart_data', json.encode(currentCart));
      CartManager.updateCartCount();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("${widget.product['product_name'] ?? widget.product['name'] ?? 'Product'} added to cart!"),
          duration: const Duration(seconds: 2),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      debugPrint("Error adding to cart: $e");
    }
  }

  List<String> _getProductImageUrls() {
    final List<String> urls = [];
    final selectedVar = _selectedVariant;
    if (selectedVar != null) {
      final varImages = selectedVar['images'];
      if (varImages != null && varImages is List && varImages.isNotEmpty) {
        for (var img in varImages) {
          final String? filename = img['product_variant_images'];
          if (filename != null && filename.isNotEmpty) {
            urls.add('$_baseProductVariantImageUrl$filename');
          }
        }
      }
    }

    if (urls.isEmpty) {
      final images = widget.product['images'];
      if (images != null && images is List && images.isNotEmpty) {
        for (var img in images) {
          final String? filename = img['product_images'];
          if (filename != null && filename.isNotEmpty) {
            urls.add('${_baseProductImageUrl}$filename');
          }
        }
      }
    }
    if (urls.isEmpty) {
      urls.add(_baseNoImageUrl);
    }
    return urls;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final List<String> imageUrls = _getProductImageUrls();

    // Safe bounds check
    if (_selectedImageIndex >= imageUrls.length) {
      _selectedImageIndex = 0;
    }

    final selectedVar = _selectedVariant;

    final String name = widget.product['product_name'] ?? widget.product['name'] ?? 'Product Detail';
    final String vendor = widget.product['vendor_name'] ?? 'SingleMart Merchant';
    final String category = widget.product['categories_name'] ?? widget.product['image'] ?? 'General';
    final String subcategory = widget.product['categories_subs_name'] ?? 'General Sub';
    final String brand = widget.product['brands_name'] ?? 'Generic';
    final String shortDesc = widget.product['product_short_description'] ?? widget.product['desc'] ?? '';
    final String longDesc = widget.product['product_long_description'] ?? '';

    double price = 0.0;
    double? discountPrice;
    String stockStatus = widget.product['product_status'] ?? 'In Stock';

    if (selectedVar != null) {
      final double? discP = double.tryParse(selectedVar['product_discount_price']?.toString() ?? '');
      final double regP = double.tryParse(selectedVar['product_price']?.toString() ?? '') ?? 0.0;
      if (discP != null && discP > 0) {
        price = regP;
        discountPrice = discP;
      } else {
        price = regP;
      }

      final int qty = int.tryParse(selectedVar['product_quantity']?.toString() ?? '0') ?? 0;
      if (qty <= 0) {
        stockStatus = 'Out of Stock';
      } else {
        stockStatus = 'In Stock';
      }
    } else {
      price = double.tryParse(widget.product['product_price']?.toString() ?? '') ??
          double.tryParse(widget.product['price']?.toString() ?? '') ??
          0.0;
      discountPrice = double.tryParse(widget.product['product_discount_price']?.toString() ?? '');
    }

    final bool isDesktop = MediaQuery.of(context).size.width > 850;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFBFD),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: Text(
          name,
          style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: const [
          CartButton(),
          SizedBox(width: 12),
        ],
      ),
      body: isDesktop
          ? _buildDesktopLayout(
              context: context,
              theme: theme,
              name: name,
              price: price,
              discountPrice: discountPrice,
              category: category,
              subcategory: subcategory,
              brand: brand,
              vendor: vendor,
              shortDesc: shortDesc,
              longDesc: longDesc,
              stockStatus: stockStatus,
              imageUrls: imageUrls,
            )
          : Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Main product image container (Swipe scroll enabled PageView)
                  Container(
                    height: 280,
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.border, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.01),
                          blurRadius: 15,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: PageView.builder(
                        controller: _detailPageController,
                        itemCount: imageUrls.length,
                        onPageChanged: (index) {
                          setState(() {
                            _selectedImageIndex = index;
                          });
                        },
                        itemBuilder: (context, index) {
                          return Image.network(
                            imageUrls[index],
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: theme.colorScheme.primary.withOpacity(0.05),
                              child: Icon(Icons.broken_image_rounded, color: theme.colorScheme.primary, size: 64),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  
                  // Interactive scrollable thumbnail selector below the main view
                  if (imageUrls.length > 1) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 65,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: imageUrls.length,
                        itemBuilder: (context, index) {
                          final bool isSelected = index == _selectedImageIndex;
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedImageIndex = index;
                              });
                              _detailPageController.animateToPage(
                                index,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                            child: Container(
                              width: 60,
                              height: 60,
                              margin: const EdgeInsets.only(right: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected ? theme.colorScheme.primary : AppColors.border,
                                  width: isSelected ? 2.5 : 1.5,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  imageUrls[index],
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 24),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),

                  // Content metadata details container block
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Brand name and Stock Status
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                brand.toUpperCase(),
                                style: TextStyle(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: stockStatus.toLowerCase().contains("out") 
                                    ? AppColors.error.withOpacity(0.1) 
                                    : Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                stockStatus,
                                style: TextStyle(
                                  color: stockStatus.toLowerCase().contains("out") 
                                      ? AppColors.error 
                                      : Colors.green,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Star Rating at the top of the product name
                        if (_localReviews.isNotEmpty) ...[
                          Row(
                            children: [
                              Row(
                                children: List.generate(5, (index) {
                                  return Icon(
                                    index < _averageRating.round() ? Icons.star : Icons.star_border,
                                    color: AppColors.secondary,
                                    size: 18,
                                  );
                                }),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${_averageRating.toStringAsFixed(1)} (${_localReviews.length})',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],

                        // Product Title
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Highlighted Category & Subcategory Pill Badges
                        Wrap(
                          spacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                category,
                                style: TextStyle(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.textLight),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.secondary.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                subcategory,
                                style: TextStyle(
                                  color: theme.colorScheme.secondary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Variant Selector Block
                        _buildVariantSelector(theme),

                        // Price block (Indian Rupees ₹)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            if (discountPrice != null && discountPrice > 0) ...[
                              Text(
                                "₹${discountPrice.toStringAsFixed(2)}",
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                "₹${price.toStringAsFixed(2)}",
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textLight,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                            ] else ...[
                              Text(
                                "₹${price.toStringAsFixed(2)}",
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ]
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Merchant/Vendor Info
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border, width: 1.5),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: theme.colorScheme.secondary.withOpacity(0.1),
                                child: Icon(Icons.storefront_rounded, color: theme.colorScheme.secondary),
                              ),
                              const SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Sold By',
                                    style: TextStyle(fontSize: 11, color: AppColors.textLight, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    vendor,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Short Description
                        if (shortDesc.isNotEmpty) ...[
                          const Text(
                            'Overview',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            shortDesc,
                            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
                          ),
                          const SizedBox(height: 24),
                        ],

                        // Dynamic Specifications & Variant Dimensions Block
                        _buildSpecificationsSection(theme, longDesc),

                        // Customer Reviews Block
                        _buildReviewsSection(context, theme),

                        // Related Products
                        _buildRelatedProductsSection(theme),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Bar for Add to Cart and Quantities
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppColors.border, width: 1.5)),
            ),
            child: Row(
              children: [
                // Quantity Counter
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove, size: 18),
                        onPressed: () {
                          if (_quantity > 1) {
                            setState(() => _quantity--);
                          }
                        },
                      ),
                      Text(
                        '$_quantity',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add, size: 18),
                        onPressed: () {
                          setState(() => _quantity++);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),

                // Add to Cart Button
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _addToCart,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.add_shopping_cart, color: Colors.white),
                      label: const Text(
                        'Add to Cart',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // FLIPKART STYLE DESKTOP LAYOUT (Width > 850)
  // ==========================================
  Widget _buildDesktopLayout({
    required BuildContext context,
    required ThemeData theme,
    required String name,
    required double price,
    required double? discountPrice,
    required String category,
    required String subcategory,
    required String brand,
    required String vendor,
    required String shortDesc,
    required String longDesc,
    required String stockStatus,
    required List<String> imageUrls,
  }) {
    final double displayPrice = (discountPrice != null && discountPrice > 0) ? discountPrice : price;
    final double? regularPrice = (discountPrice != null && discountPrice > 0) ? price : null;
    int discountPercent = 0;
    if (regularPrice != null && regularPrice > displayPrice) {
      discountPercent = (((regularPrice - displayPrice) / regularPrice) * 100).round();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1240),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(28),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // LEFT STICKY MEDIA & FLIPKART ACTION BUTTONS COLUMN (Width 450)
              SizedBox(
                width: 450,
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Leftmost Vertical Thumbnail Strip
                        if (imageUrls.length > 1) ...[
                          SizedBox(
                            width: 65,
                            height: 380,
                            child: ListView.builder(
                              itemCount: imageUrls.length,
                              itemBuilder: (context, index) {
                                final bool isSelected = index == _selectedImageIndex;
                                return GestureDetector(
                                  onTap: () {
                                    setState(() => _selectedImageIndex = index);
                                    if (_detailPageController.hasClients) {
                                      _detailPageController.jumpToPage(index);
                                    }
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: 60,
                                    height: 60,
                                    margin: const EdgeInsets.only(bottom: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isSelected ? theme.colorScheme.primary : AppColors.border,
                                        width: isSelected ? 2.5 : 1,
                                      ),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        imageUrls[index],
                                        fit: BoxFit.contain,
                                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 20),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],

                        // Main Preview Display Box
                        Expanded(
                          child: Container(
                            height: 380,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFAFAFA),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.border, width: 1),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: PageView.builder(
                                controller: _detailPageController,
                                itemCount: imageUrls.length,
                                onPageChanged: (index) {
                                  setState(() => _selectedImageIndex = index);
                                },
                                itemBuilder: (context, index) {
                                  return Image.network(
                                    imageUrls[index],
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) => Container(
                                      color: theme.colorScheme.primary.withOpacity(0.05),
                                      child: Icon(Icons.broken_image_rounded, color: theme.colorScheme.primary, size: 64),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Quantity Counter Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Quantity: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove, size: 18),
                                onPressed: () {
                                  if (_quantity > 1) {
                                    setState(() => _quantity--);
                                  }
                                },
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Text('$_quantity', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add, size: 18),
                                onPressed: () {
                                  setState(() => _quantity++);
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Flipkart Style Action Buttons (ADD TO CART & BUY NOW)
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 52,
                            child: OutlinedButton.icon(
                              onPressed: _addToCart,
                              icon: const Icon(Icons.add_shopping_cart_rounded, size: 20),
                              label: const Text('ADD TO CART', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: theme.colorScheme.primary,
                                side: BorderSide(color: theme.colorScheme.primary, width: 2),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 52,
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                await _addToCart();
                                if (mounted) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const CartScreen(),
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(Icons.flash_on_rounded, size: 20, color: Colors.white),
                              label: const Text('BUY NOW', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white, letterSpacing: 0.5)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange.shade700,
                                elevation: 2,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 36),

              // RIGHT SCROLLABLE DETAILS & SPECIFICATIONS COLUMN
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Breadcrumb Trail
                    Row(
                      children: [
                        Text(category, style: TextStyle(fontSize: 13, color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 6),
                        const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.textMuted),
                        const SizedBox(width: 6),
                        Text(subcategory, style: TextStyle(fontSize: 13, color: theme.colorScheme.secondary, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Brand & Stock status badges
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            brand.toUpperCase(),
                            style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: stockStatus.toLowerCase().contains("out") 
                                ? AppColors.error.withOpacity(0.08) 
                                : Colors.green.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            stockStatus,
                            style: TextStyle(
                              color: stockStatus.toLowerCase().contains("out") ? AppColors.error : Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Title
                    Text(
                      name,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary, height: 1.3),
                    ),
                    const SizedBox(height: 12),

                    // Ratings pill badge
                    if (_localReviews.isNotEmpty) ...[
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.shade700,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  _averageRating.toStringAsFixed(1),
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.star, color: Colors.white, size: 12),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '${_localReviews.length} Ratings & Reviews',
                            style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                    ],

                    // Flipkart-style Price Box
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          "₹${displayPrice.toStringAsFixed(2)}",
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                        ),
                        if (regularPrice != null) ...[
                          const SizedBox(width: 12),
                          Text(
                            "₹${regularPrice.toStringAsFixed(2)}",
                            style: const TextStyle(
                              fontSize: 16,
                              color: AppColors.textMuted,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ],
                        if (discountPercent > 0) ...[
                          const SizedBox(width: 12),
                          Text(
                            "$discountPercent% off",
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.green.shade700),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 22),

                    // Variant Selector Block
                    _buildVariantSelector(theme),

                    // Merchant/Vendor Info Box
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAFAFA),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.storefront_rounded, color: theme.colorScheme.secondary, size: 22),
                          const SizedBox(width: 12),
                          const Text('Seller: ', style: TextStyle(fontSize: 13, color: AppColors.textLight)),
                          Text(vendor, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Short Description
                    if (shortDesc.isNotEmpty) ...[
                      const Text('Overview', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      const SizedBox(height: 8),
                      Text(shortDesc, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4)),
                      const SizedBox(height: 24),
                    ],

                    // Dynamic Specifications & Variant Dimensions Table
                    _buildSpecificationsSection(theme, longDesc),

                    // Customer Reviews & Ratings Section
                    _buildReviewsSection(context, theme),

                    // Related Products
                    _buildRelatedProductsSection(theme),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // REVIEW RATING CALCULATIONS AND UI WIDGETS
  // ==========================================

  double get _averageRating {
    if (_localReviews.isEmpty) return 0.0;
    double total = 0.0;
    for (var r in _localReviews) {
      final ratingVal = double.tryParse(r['product_rating']?.toString() ?? r['rating']?.toString() ?? '') ?? 0.0;
      total += ratingVal;
    }
    return total / _localReviews.length;
  }

  bool get _hasUserReviewed {
    if (!_isLoggedIn || _userData == null) return false;
    final currentUserId = _userData!['id']?.toString() ?? _userData!['user_id']?.toString();
    if (currentUserId == null) return false;
    
    return _localReviews.any((r) {
      final rUserId = r['user_id']?.toString() ?? r['customer_id']?.toString() ?? r['created_by']?.toString() ?? r['user']?['id']?.toString();
      return rUserId != null && rUserId == currentUserId;
    });
  }

  Widget _buildReviewsSection(BuildContext context, ThemeData theme) {
    final double avgRating = _averageRating;
    final int reviewCount = _localReviews.length;
    final int displayedCount = _showAllReviews ? reviewCount : (reviewCount > 5 ? 5 : reviewCount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 36, color: AppColors.border, thickness: 1.5),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Customer Reviews',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            if (_isLoggedIn)
              if (_hasUserReviewed)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.teal.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.teal.withOpacity(0.2)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle_rounded, color: Colors.teal, size: 14),
                      SizedBox(width: 6),
                      Text(
                        'Reviewed',
                        style: TextStyle(
                          color: Colors.teal,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                )
              else
                TextButton.icon(
                  onPressed: () => _showWriteReviewBottomSheet(context),
                  icon: const Icon(Icons.rate_review_outlined, size: 18, color: AppColors.primary),
                  label: const Text(
                    'Write Review',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                )
            else
              TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                  ).then((_) {
                    _checkLoginStatus();
                  });
                },
                icon: const Icon(Icons.login_rounded, size: 18, color: AppColors.primary),
                label: const Text(
                  'Login to Review',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),

        // Rating summary card
        if (reviewCount > 0) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border, width: 1.5),
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      avgRating.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(5, (index) {
                        return Icon(
                          index < avgRating.round() ? Icons.star : Icons.star_border,
                          color: AppColors.secondary,
                          size: 18,
                        );
                      }),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$reviewCount ${reviewCount == 1 ? 'Review' : 'Reviews'}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textLight,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    children: List.generate(5, (index) {
                      final starNum = 5 - index;
                      final count = _localReviews.where((r) {
                        final val = double.tryParse(r['product_rating']?.toString() ?? r['rating']?.toString() ?? '') ?? 0.0;
                        return val.round() == starNum;
                      }).length;
                      final pct = reviewCount > 0 ? (count / reviewCount) : 0.0;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Text(
                              '$starNum ★',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textLight,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: pct,
                                  minHeight: 6,
                                  backgroundColor: const Color(0xFFF1F5F9),
                                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.secondary),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              count.toString(),
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Reviews List
        if (reviewCount == 0)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border, width: 1.5),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.rate_review_outlined,
                  size: 44,
                  color: theme.colorScheme.primary.withOpacity(0.2),
                ),
                const SizedBox(height: 12),
                const Text(
                  'No Reviews Yet',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Be the first to share your thoughts about this product!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textLight,
                  ),
                ),
              ],
            ),
          )
        else ...[
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: displayedCount,
            itemBuilder: (context, index) {
              final r = _localReviews[index];
              
              final double rating = double.tryParse(r['product_rating']?.toString() ?? r['rating']?.toString() ?? '') ?? 0.0;
              final String reviewText = r['product_review']?.toString() ?? r['review']?.toString() ?? '';
              
              String reviewerName = 'Verified Buyer';
              if (r['customer_name'] != null && r['customer_name'].toString().isNotEmpty) {
                reviewerName = r['customer_name'].toString();
              } else if (r['user_name'] != null && r['user_name'].toString().isNotEmpty) {
                reviewerName = r['user_name'].toString();
              } else if (r['user'] != null && r['user'] is Map && r['user']['name'] != null) {
                reviewerName = r['user']['name'].toString();
              } else if (r['name'] != null) {
                reviewerName = r['name'].toString();
              }
              
              String dateStr = '';
              if (r['product_rating_date'] != null && r['product_rating_date'].toString().isNotEmpty) {
                dateStr = r['product_rating_date'].toString();
              } else if (r['created_at'] != null) {
                try {
                  final parsedDate = DateTime.parse(r['created_at'].toString());
                  dateStr = "${parsedDate.day}/${parsedDate.month}/${parsedDate.year}";
                } catch (_) {
                  dateStr = r['created_at'].toString().split('T')[0];
                }
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border, width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: (r['customer_image'] != null && r['customer_image'].toString().isNotEmpty)
                                ? Image.network(
                                    '${_baseUserImageUrl}${r['customer_image']}',
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => Center(
                                      child: Text(
                                        reviewerName.isNotEmpty ? reviewerName[0].toUpperCase() : 'U',
                                        style: TextStyle(
                                          color: theme.colorScheme.primary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  )
                                : Center(
                                    child: Text(
                                      reviewerName.isNotEmpty ? reviewerName[0].toUpperCase() : 'U',
                                      style: TextStyle(
                                        color: theme.colorScheme.primary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                reviewerName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              if (dateStr.isNotEmpty)
                                Text(
                                  dateStr,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textLight,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Row(
                          children: List.generate(5, (starIdx) {
                            return Icon(
                              starIdx < rating.round() ? Icons.star : Icons.star_border,
                              color: AppColors.secondary,
                              size: 16,
                            );
                          }),
                        ),
                      ],
                    ),
                    if (reviewText.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        reviewText,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
          if (reviewCount > 5) ...[
            const SizedBox(height: 8),
            Center(
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    _showAllReviews = !_showAllReviews;
                  });
                },
                icon: Icon(
                  _showAllReviews ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                  color: AppColors.primary,
                ),
                label: Text(
                  _showAllReviews ? 'Show Less' : 'See All Reviews ($reviewCount)',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  void _showWriteReviewBottomSheet(BuildContext context) {
    final theme = Theme.of(context);
    final reviewController = TextEditingController();
    int selectedRating = 5;
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Write a Review',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Share your experience with this product to help others.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textLight,
                    ),
                  ),
                  const SizedBox(height: 24),

                  const Text(
                    'YOUR RATING',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: List.generate(5, (index) {
                      final starIdx = index + 1;
                      final isLit = starIdx <= selectedRating;
                      return GestureDetector(
                        onTap: () {
                          setModalState(() {
                            selectedRating = starIdx;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Icon(
                            isLit ? Icons.star_rounded : Icons.star_border_rounded,
                            color: AppColors.secondary,
                            size: 40,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 24),

                  const Text(
                    'YOUR REVIEW',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: reviewController,
                    maxLines: 4,
                    maxLength: 300,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'What did you like or dislike? Write your review...',
                      hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                      filled: true,
                      fillColor: AppColors.surface,
                      contentPadding: const EdgeInsets.all(16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final comment = reviewController.text.trim();

                              setModalState(() {
                                isSubmitting = true;
                              });

                              try {
                                final response = await ApiService.postProductReview(
                                  productId: widget.product['id'].toString(),
                                  productRating: selectedRating.toString(),
                                  productReview: comment,
                                  token: _token!,
                                );

                                final resBody = json.decode(response.body);

                                if (response.statusCode == 200 || response.statusCode == 201) {
                                  setState(() {
                                    _localReviews.insert(0, {
                                      'product_rating': selectedRating.toString(),
                                      'product_review': comment,
                                      'customer_name': _userData?['name'] ?? 'You',
                                      'user_name': _userData?['name'] ?? 'You',
                                      'customer_id': _userData?['id']?.toString(),
                                      'user_id': _userData?['id']?.toString(),
                                      'product_rating_date': DateTime.now().toIso8601String().split('T')[0],
                                      'created_at': DateTime.now().toIso8601String(),
                                    });
                                  });

                                  if (mounted) {
                                    Navigator.pop(context);
                                    _showSuccessSnackBar('Thank you! Review submitted successfully.');
                                  }
                                } else {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(resBody['message'] ?? 'Review submission failed.'),
                                        backgroundColor: AppColors.error,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                    );
                                  }
                                }
                              } catch (e) {
                                debugPrint("Error submitting review: $e");
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text('Network error. Failed to submit review.'),
                                      backgroundColor: AppColors.error,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  );
                                }
                              } finally {
                                if (mounted) {
                                  setModalState(() {
                                    isSubmitting = false;
                                  });
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: isSubmitting
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Submit Review',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSpecificationsSection(ThemeData theme, String longDesc) {
    final selectedVar = _selectedVariant;

    final String? weight = selectedVar != null
        ? selectedVar['product_weight']?.toString()
        : widget.product['product_weight']?.toString();

    final String? length = selectedVar != null
        ? selectedVar['product_length']?.toString()
        : widget.product['product_length']?.toString();

    final String? width = selectedVar != null
        ? selectedVar['product_width']?.toString()
        : widget.product['product_width']?.toString();

    final String? height = selectedVar != null
        ? selectedVar['product_height']?.toString()
        : widget.product['product_height']?.toString();

    final String? tax = selectedVar != null
        ? selectedVar['product_tax_percentage']?.toString()
        : widget.product['product_tax_percentage']?.toString();


    // Check if any specs exist
    final bool hasWeight = weight != null && weight.isNotEmpty && weight != '0' && weight != '0.00';
    final bool hasLength = length != null && length.isNotEmpty && length != '0' && length != '0.00';
    final bool hasWidth = width != null && width.isNotEmpty && width != '0' && width != '0.00';
    final bool hasHeight = height != null && height.isNotEmpty && height != '0' && height != '0.00';
    final bool hasDimensions = hasLength || hasWidth || hasHeight;
    final bool hasTax = tax != null && tax.isNotEmpty && tax != '0' && tax != '0.00';
    
    final bool hasAttrs = selectedVar != null && selectedVar['attributes'] != null && (selectedVar['attributes'] as List).isNotEmpty;

    

    final List<Map<String, String>> specRows = [];

   
    if (hasAttrs) {
      final List<dynamic> attrs = selectedVar['attributes'];
      for (var attr in attrs) {
        final String? aName = attr['attribute_name']?.toString();
        final String? aVal = attr['attribute_value']?.toString();
        if (aVal != null && aVal.isNotEmpty) {
          specRows.add({'key': aName ?? 'Attribute', 'value': aVal});
        }
      }
    }
    if (hasWeight) {
      final double? weightNum = double.tryParse(weight!);
      final String formattedWeight = weightNum != null ? "${weightNum} kg" : "$weight kg";
      specRows.add({'key': 'Weight', 'value': formattedWeight});
    }
    if (hasDimensions) {
      final String lStr = (length != null && length.isNotEmpty) ? length : '-';
      final String wStr = (width != null && width.isNotEmpty) ? width : '-';
      final String hStr = (height != null && height.isNotEmpty) ? height : '-';
      specRows.add({'key': 'Dimensions (L × W × H)', 'value': '$lStr × $wStr × $hStr cm'});
    }
    if (hasTax) {
      final double? taxNum = double.tryParse(tax!);
      specRows.add({'key': 'Tax / GST Rate', 'value': taxNum != null ? "${taxNum}%" : "$tax%"});
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Specifications',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 10),
        if (longDesc.isNotEmpty) ...[
          Text(
            longDesc,
            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 14),
        ],
        if (specRows.isNotEmpty) ...[
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border, width: 1.2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Column(
                children: List.generate(specRows.length, (index) {
                  final row = specRows[index];
                  final bool isEven = index % 2 == 0;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    color: isEven ? AppColors.surface.withOpacity(0.5) : Colors.white,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          flex: 4,
                          child: Text(
                            row['key']!,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                          ),
                        ),
                        Expanded(
                          flex: 5,
                          child: Text(
                            row['value']!,
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildVariantSelector(ThemeData theme) {
    if (!_hasVariants) return const SizedBox.shrink();
    final List variants = widget.product['variants'] as List;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Variant',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: List.generate(variants.length, (index) {
              final varMap = Map<String, dynamic>.from(variants[index]);
              final bool isSelected = index == _selectedVariantIndex;
              final String attrText = _formatVariantAttributes(varMap);
              final double discP = double.tryParse(varMap['product_discount_price']?.toString() ?? '') ?? 0.0;
              final double regP = double.tryParse(varMap['product_price']?.toString() ?? '') ?? 0.0;
              final double displayP = discP > 0 ? discP : regP;

              return Container(
                width: 170,
                margin: const EdgeInsets.only(right: 12, bottom: 4, top: 4),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedVariantIndex = index;
                      _selectedImageIndex = 0;
                    });
                    if (_detailPageController.hasClients) {
                      _detailPageController.jumpToPage(0);
                    }
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected ? theme.colorScheme.primary.withOpacity(0.06) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? theme.colorScheme.primary : const Color(0xFFE2E8F0),
                        width: isSelected ? 2.0 : 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isSelected 
                              ? theme.colorScheme.primary.withOpacity(0.06) 
                              : Colors.black.withOpacity(0.01),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isSelected ? theme.colorScheme.primary : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                "Option ${index + 1}",
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? Colors.white : AppColors.textSecondary,
                                ),
                              ),
                            ),
                            Icon(
                              isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                              size: 16,
                              color: isSelected ? theme.colorScheme.primary : const Color(0xFF94A3B8),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          attrText,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? theme.colorScheme.primary : AppColors.textPrimary,
                          ),
                        ),
                        // const SizedBox(height: 8),
                        // Text(
                        //   "₹${displayP.toStringAsFixed(2)}",
                        //   style: TextStyle(
                        //     fontSize: 13.5,
                        //     fontWeight: FontWeight.bold,
                        //     color: isSelected ? theme.colorScheme.primary : AppColors.primary,
                        //   ),
                        // ),
                        // if (discP > 0 && regP > discP) ...[
                        //   const SizedBox(height: 2),
                        //   Text(
                        //     "₹${regP.toStringAsFixed(2)}",
                        //     style: const TextStyle(
                        //       fontSize: 11,
                        //       decoration: TextDecoration.lineThrough,
                        //       color: AppColors.textLight,
                        //     ),
                        //   ),
                        // ],
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  void _showSuccessSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.teal,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
