import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
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
  int _activeTab = 0; 

  // Review states
  bool _isLoggedIn = false;
  String? _token;
  Map<String, dynamic>? _userData;
  List<dynamic> _localReviews = [];
  bool _showAllReviews = false;

  int _selectedVariantIndex = 0;
  List<dynamic> _relatedProducts = [];
  bool _isLoadingRelated = false;
  Map<String, dynamic>? _vendorProfileData;
  
  String _baseNoImageUrl = 'https://agsdemo.in/singlemartapi/public/assets/images/no_image.jpg';
  String _baseUserImageUrl = 'https://agsdemo.in/singlemartapi/public/assets/images/user_images/';
  String _baseProductImageUrl = 'https://agsdemo.in/singlemartapi/public/assets/images/product_images/';
  String _baseProductVariantImageUrl = 'https://agsdemo.in/singlemartapi/public/assets/images/product_variant_images/';

  // Category Menu & Mega Dropdown variables
  List<dynamic> _categories = [];
  List<dynamic> _allProducts = [];
  final ValueNotifier<int?> _activeCategoryId = ValueNotifier<int?>(null);
  final ValueNotifier<int?> _hoveredCategoryIndex = ValueNotifier<int?>(null);
  Timer? _menuCloseTimer;

  // Pincode variables
  final TextEditingController _pincodeController = TextEditingController();
  String _deliveryEstimate = '';
  bool _hasCheckedPincode = false;

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
    final List<dynamic>? attrs = variant['attributes'] ?? variant['attribute_values'];
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

  String _formatNumber(int number) {
    final str = number.toString();
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return str.replaceAllMapped(reg, (Match m) => "${m[1]},");
  }

  @override
  void initState() {
    super.initState();
    
    // Check if a pre-selected variant is specified in the route arguments
    final preSelectedVarId = widget.product['selected_variant_id']?.toString();
    if (preSelectedVarId != null && _hasVariants) {
      final List variants = widget.product['variants'] as List;
      for (int i = 0; i < variants.length; i++) {
        if (variants[i]['id']?.toString() == preSelectedVarId) {
          _selectedVariantIndex = i;
          break;
        }
      }
    }

    _loadCart();
    _checkLoginStatus();
    _fetchRelatedProducts();
    _loadMenuData();
    _fetchVendorProfile();
  }

  @override
  void dispose() {
    _detailPageController.dispose();
    _menuCloseTimer?.cancel();
    _pincodeController.dispose();
    super.dispose();
  }

  Future<void> _loadMenuData() async {
    try {
      final responses = await Future.wait([
        ApiService.fetchActiveCategories(),
        ApiService.fetchActiveProducts(),
      ]);
      if (responses[0].statusCode == 200) {
        final body = json.decode(responses[0].body);
        _categories = body['data'] ?? [];
      }
      if (responses[1].statusCode == 200) {
        final body = json.decode(responses[1].body);
        _allProducts = body['data'] ?? [];
      }
      setState(() {});
    } catch (e) {
      debugPrint("Error loading menu data: $e");
    }
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

  Future<void> _addToCart() async {
    try {
      final String? cartStr = await CartManager.getCartData();
      List<Map<String, dynamic>> currentCart = [];
      if (cartStr != null && cartStr.isNotEmpty) {
        final List<dynamic> parsed = json.decode(cartStr);
        currentCart = List<Map<String, dynamic>>.from(
          parsed.map((item) => Map<String, dynamic>.from(item))
        );
      }

      // Catalog lookup mapping to resolve missing nested variant details
      final prodId = widget.product['id'];
      var targetProduct = widget.product;
      final catalogMatch = _allProducts.firstWhere(
        (p) => p['id'] == prodId,
        orElse: () => null,
      );
      if (catalogMatch != null) {
        targetProduct = Map<String, dynamic>.from(catalogMatch);
      }

      final selectedVar = _selectedVariant;

      final double discP = selectedVar != null
          ? (double.tryParse(selectedVar['product_discount_price']?.toString() ?? '') ?? 0.0)
          : (double.tryParse(targetProduct['product_discount_price']?.toString() ?? '') ?? 0.0);
      final double regP = selectedVar != null
          ? (double.tryParse(selectedVar['product_price']?.toString() ?? '') ?? 0.0)
          : (double.tryParse(targetProduct['product_price']?.toString() ?? '') ?? 0.0);

      final double price = (discP > 0) ? discP : (regP > 0 ? regP : double.tryParse(targetProduct['price']?.toString() ?? '') ?? 0.0);
      final double originalPrice = (discP > 0 && regP > discP) ? regP : (regP > price ? regP : 0.0);

      String? productImg;
      if (selectedVar != null && selectedVar['images'] != null && selectedVar['images'] is List && (selectedVar['images'] as List).isNotEmpty) {
        productImg = selectedVar['images'][0]['product_variant_images']?.toString();
      } else if (targetProduct['images'] != null && targetProduct['images'] is List && (targetProduct['images'] as List).isNotEmpty) {
        productImg = targetProduct['images'][0]['product_images']?.toString();
      }

      final String variantAttrStr = selectedVar != null ? _formatVariantAttributes(selectedVar) : '';
      final int? varId = selectedVar != null ? int.tryParse(selectedVar['id']?.toString() ?? '') : null;
      final String cartMatchId = varId != null ? "${targetProduct['id']}_v$varId" : "${targetProduct['id']}";

      setState(() {
        final existingIndex = currentCart.indexWhere((item) {
          if (item['cart_item_id'] != null) {
            return item['cart_item_id'].toString() == cartMatchId;
          }
          if (varId != null) {
            return item['id'] == targetProduct['id'] && item['variant_id'] == varId;
          }
          return item['id'] == targetProduct['id'] && item['variant_id'] == null;
        });

        if (existingIndex != -1) {
          currentCart[existingIndex]['quantity'] = (currentCart[existingIndex]['quantity'] ?? 1) + _quantity;
        } else {
          currentCart.add({
            "cart_item_id": cartMatchId,
            "id": targetProduct['id'],
            "variant_id": varId,
            "product_sku": selectedVar?['product_sku'] ?? targetProduct['product_sku'],
            "variant_attributes": variantAttrStr.isNotEmpty ? variantAttrStr : null,
            "is_variant": selectedVar != null,
            "name": targetProduct['product_name'] ?? targetProduct['name'] ?? 'Product',
            "price": price,
            "original_price": originalPrice,
            "product_price": regP > 0 ? regP : originalPrice,
            "desc": targetProduct['product_short_description'] ?? targetProduct['desc'] ?? '',
            "image": targetProduct['categories_name'] ?? targetProduct['image'] ?? 'Products',
            "quantity": _quantity,
            "product_vendor_id": targetProduct['product_vendor_id'],
            "created_by": targetProduct['created_by'],
            "vendor_id": targetProduct['vendor_id'] ?? targetProduct['created_by'],
            "product_image": productImg,
          });
        }
        _cartItems = currentCart;
        _quantity = 1;
      });

      await CartManager.setCartData(json.encode(currentCart));
      ShowSnackBar.show(context, "${targetProduct['product_name'] ?? targetProduct['name'] ?? 'Product'} added to cart!");
    } catch (e) {
      debugPrint("Error adding to cart: $e");
    }
  }

  Future<void> _buyNow() async {
    await _addToCart();
    if (mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => const CartScreen())).then((_) => _loadCart());
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
            urls.add('$_baseProductImageUrl$filename');
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
      if (qty <= 0) stockStatus = 'Out of Stock';
    } else {
      price = double.tryParse(widget.product['product_price']?.toString() ?? '') ??
          double.tryParse(widget.product['price']?.toString() ?? '') ??
          0.0;
      discountPrice = double.tryParse(widget.product['product_discount_price']?.toString() ?? '');
    }

    final bool isDesktop = MediaQuery.of(context).size.width > 850;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFBFD),
      appBar: isDesktop
          ? null
          : AppBar(
              backgroundColor: Colors.white,
              elevation: 1,
              title: Text(name, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
              iconTheme: const IconThemeData(color: AppColors.textPrimary),
              actions: const [
                CartButton(),
                SizedBox(width: 12),
              ],
            ),
      body: Stack(
        children: [
          Column(
            children: [
              if (isDesktop) ...[
                _buildDesktopHeader(theme),
                _buildDesktopCategoryMenuRow(theme),
              ],
              Expanded(
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.symmetric(horizontal: isDesktop ? 40 : 16, vertical: 20),
                  child: Center(
                    child: Container(
                      constraints: BoxConstraints(maxWidth: isDesktop ? 1240 : 600),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          isDesktop
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
                              : _buildMobileLayout(
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
                                ),
                          _buildHorizontalReviewsList(theme),
                          _buildDesktopRelatedProductsSection(theme),
                          const SizedBox(height: 48),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (isDesktop)
            Positioned(
              top: 60 + 44, // Header height estimate + MenuRow estimate
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
      bottomNavigationBar: isDesktop 
          ? null 
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))
                ],
                border: const Border(top: BorderSide(color: Color(0xFFF1F5F9), width: 1.5)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _addToCart,
                      icon: Icon(Icons.add_shopping_cart_rounded, color: theme.colorScheme.primary, size: 16),
                      label: Text('Add To Cart', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: theme.colorScheme.primary, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _buyNow,
                      icon: const Icon(Icons.flash_on_rounded, color: Colors.white, size: 16),
                      label: const Text('Buy Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

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

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15, offset: const Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(32),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Side: Image Gallery
          SizedBox(
            width: 480,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Vertical Thumbnails Strip
                if (imageUrls.length > 1) ...[
                  SizedBox(
                    width: 70,
                    height: 440,
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
                          child: Container(
                            width: 60,
                            height: 60,
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected ? theme.colorScheme.primary : const Color(0xFFE2E8F0),
                                width: isSelected ? 2.5 : 1.2,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(imageUrls[index], fit: BoxFit.contain,
                                errorBuilder: (c, e, s) => const Icon(Icons.broken_image, size: 20)),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
                // Main image preview
                Expanded(
                  child: Container(
                    height: 440,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAFAFA),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Stack(
                        children: [
                          PageView.builder(
                            controller: _detailPageController,
                            itemCount: imageUrls.length,
                            onPageChanged: (index) {
                              setState(() => _selectedImageIndex = index);
                            },
                            itemBuilder: (context, index) {
                              return Image.network(imageUrls[index], fit: BoxFit.contain,
                                errorBuilder: (c, e, s) => const Icon(Icons.broken_image, size: 48));
                            },
                          ),
                          Positioned(
                            bottom: 12, right: 12,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                              child: const Icon(Icons.fullscreen_rounded, size: 20, color: AppColors.textPrimary),
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
          const SizedBox(width: 40),
          // Right Side: Product Configuration & Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.textPrimary, height: 1.2),
                      ),
                    ),
                    if (_localReviews.isNotEmpty) ...[
                      const SizedBox(width: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              "${_averageRating.toStringAsFixed(1)} | ${_localReviews.length} Reviews",
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                            ),
                          ],
                        ),
                      ),
                    ]
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Brand Badge (Emerald green highlights)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: Text(
                        'Brand: $brand',
                        style: const TextStyle(color: Color(0xFF065F46), fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                    // Category Badge (Blue highlights)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Text(
                        'Category: $category',
                        style: const TextStyle(color: Color(0xFF1E40AF), fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                    // Subcategory Badge (Violet highlights)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F3FF),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFDDD6FE)),
                      ),
                      child: Text(
                        'Subcategory: $subcategory',
                        style: const TextStyle(color: Color(0xFF5B21B6), fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                    // Merchant Badge (Amber highlights)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Text(
                        'Merchant: $vendor',
                        style: const TextStyle(color: Color(0xFF92400E), fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Text(stockStatus, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: stockStatus.toLowerCase().contains("out") ? Colors.red : Colors.green)),
                  ],
                ),
                const SizedBox(height: 16),
                // Price Box
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      "₹${_formatNumber(displayPrice.round())}",
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                    ),
                    if (regularPrice != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        "₹${_formatNumber(regularPrice.round())}",
                        style: const TextStyle(fontSize: 16, color: AppColors.textLight, decoration: TextDecoration.lineThrough),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "$discountPercent% OFF",
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                      ),
                    ],
                    const SizedBox(width: 8),
                    const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.textMuted),
                  ],
                ),
                const SizedBox(height: 12),
                // Social Proof tag
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFFFEDD5), width: 1),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.local_fire_department_rounded, size: 15, color: Colors.orange),
                      SizedBox(width: 6),
                      Text('Ordered 180+ times in Past Month', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange)),
                    ],
                  ),
                ),
                _buildDeliveryCheckBlock(),
                _buildOffersScroller(),
                _buildVariantSelector(theme),
                _buildAccordionBlock(shortDesc, longDesc),
                const SizedBox(height: 28),
                // Sticky Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _addToCart,
                        icon: Icon(Icons.add_shopping_cart_rounded, color: theme.colorScheme.primary, size: 18),
                        label: const Text('Add To Cart', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.colorScheme.primary,
                          side: BorderSide(color: theme.colorScheme.primary, width: 2),
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _buyNow,
                        icon: const Icon(Icons.flash_on_rounded, color: Colors.white, size: 18),
                        label: const Text('Buy Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
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

  Widget _buildMobileLayout({
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Image box
        Container(
          height: 280,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border, width: 1.5),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              children: [
                PageView.builder(
                  controller: _detailPageController,
                  itemCount: imageUrls.length,
                  onPageChanged: (index) {
                    setState(() => _selectedImageIndex = index);
                  },
                  itemBuilder: (context, index) {
                    return Image.network(imageUrls[index], fit: BoxFit.contain,
                      errorBuilder: (c, e, s) => const Icon(Icons.broken_image, size: 48));
                  },
                ),
                if (imageUrls.length > 1)
                  Positioned(
                    bottom: 12, left: 0, right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(imageUrls.length, (dotIdx) {
                        final isActive = dotIdx == _selectedImageIndex;
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2.5),
                          width: isActive ? 7 : 5, height: isActive ? 7 : 5,
                          decoration: BoxDecoration(
                            color: isActive ? theme.colorScheme.primary : Colors.grey.shade400,
                            shape: BoxShape.circle,
                          ),
                        );
                      }),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // Brand Badge (Emerald green highlights)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: Text(
                'Brand: $brand',
                style: const TextStyle(color: Color(0xFF065F46), fontSize: 8, fontWeight: FontWeight.bold),
              ),
            ),
            // Category Badge (Blue highlights)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Text(
                'Category: $category',
                style: const TextStyle(color: Color(0xFF1E40AF), fontSize: 8, fontWeight: FontWeight.bold),
              ),
            ),
            // Subcategory Badge (Violet highlights)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F3FF),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFFDDD6FE)),
              ),
              child: Text(
                'Subcategory: $subcategory',
                style: const TextStyle(color: Color(0xFF5B21B6), fontSize: 8, fontWeight: FontWeight.bold),
              ),
            ),
            // Merchant Badge (Amber highlights)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Text(
                'Merchant: $vendor',
                style: const TextStyle(color: Color(0xFF92400E), fontSize: 8, fontWeight: FontWeight.bold),
              ),
            ),
            Text(stockStatus, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: stockStatus.toLowerCase().contains("out") ? Colors.red : Colors.green)),
          ],
        ),
        const SizedBox(height: 10),
        Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text("₹${_formatNumber(displayPrice.round())}", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
            if (regularPrice != null) ...[
              const SizedBox(width: 8),
              Text("₹${_formatNumber(regularPrice.round())}", style: const TextStyle(fontSize: 14, color: AppColors.textLight, decoration: TextDecoration.lineThrough)),
              const SizedBox(width: 8),
              Text("$discountPercent% OFF", style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.green)),
            ],
          ],
        ),
        const SizedBox(height: 12),
        // Social proof banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7ED),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFFFEDD5), width: 1),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.local_fire_department_rounded, size: 14, color: Colors.orange),
              SizedBox(width: 6),
              Text('Ordered 180+ times in Past Month', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.orange)),
            ],
          ),
        ),
        _buildDeliveryCheckBlock(),
        _buildOffersScroller(),
        _buildVariantSelector(theme),
        _buildAccordionBlock(shortDesc, longDesc),
      ],
    );
  }

  Widget _buildVariantSelector(ThemeData theme) {
    if (!_hasVariants) return const SizedBox.shrink();
    final List variants = widget.product['variants'] as List;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        const Text(
          'Select Option',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 75,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: variants.length,
            itemBuilder: (context, index) {
              final varMap = Map<String, dynamic>.from(variants[index]);
              final bool isSelected = index == _selectedVariantIndex;
              final String attrText = _formatVariantAttributes(varMap);
              final double discP = double.tryParse(varMap['product_discount_price']?.toString() ?? '') ?? 0.0;
              final double regP = double.tryParse(varMap['product_price']?.toString() ?? '') ?? 0.0;
              final double displayP = discP > 0 ? discP : regP;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedVariantIndex = index;
                    _selectedImageIndex = 0;
                  });
                  if (_detailPageController.hasClients) {
                    _detailPageController.jumpToPage(0);
                  }
                },
                child: Container(
                  width: 140,
                  margin: const EdgeInsets.only(right: 12, bottom: 4),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected ? theme.colorScheme.primary.withOpacity(0.06) : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? theme.colorScheme.primary : const Color(0xFFE2E8F0),
                      width: isSelected ? 2.0 : 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 4, offset: const Offset(0, 1))
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        attrText,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isSelected ? theme.colorScheme.primary : AppColors.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "₹${displayP.round()}",
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isSelected ? theme.colorScheme.primary : AppColors.textSecondary),
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

  Widget _buildHorizontalReviewsList(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Customer Reviews',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            if (_isLoggedIn)
              if (_hasUserReviewed)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: Colors.teal.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle_rounded, color: Colors.teal, size: 14),
                      SizedBox(width: 4),
                      Text('Reviewed', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 11)),
                    ],
                  ),
                )
              else
                TextButton.icon(
                  onPressed: () => _showWriteReviewBottomSheet(context),
                  icon: Icon(Icons.rate_review_outlined, size: 15, color: theme.colorScheme.primary),
                  label: Text('Write Review', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 13)),
                )
            else
              TextButton.icon(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginScreen())).then((_) => _checkLoginStatus());
                },
                icon: Icon(Icons.login_rounded, size: 15, color: theme.colorScheme.primary),
                label: Text('Login to Review', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 13)),
              ),
          ],
        ),
        const SizedBox(height: 16),
        _localReviews.isEmpty
            ? Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 36),
                alignment: Alignment.center,
                child: const Text('No reviews yet. Be the first to review!', style: TextStyle(color: AppColors.textLight, fontSize: 13)),
              )
            : SizedBox(
                height: 150,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _localReviews.length,
                  itemBuilder: (context, index) {
                    final review = _localReviews[index];
                    final String name = review['customer_name'] ?? review['customer']?['name'] ?? 'Guest User';
                    final String comment = review['product_review'] ?? '';
                    final double rating = double.tryParse(review['product_rating']?.toString() ?? '5') ?? 5.0;
                    final String initials = name.isNotEmpty ? name.substring(0, (name.length > 1 ? 2 : 1)).toUpperCase() : 'U';
                    
                    return Container(
                      width: 280,
                      margin: const EdgeInsets.only(right: 16, bottom: 4),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.015), blurRadius: 8, offset: const Offset(0, 3)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                                child: Text(initials, style: TextStyle(color: theme.colorScheme.primary, fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(name, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: List.generate(5, (starIdx) {
                                        return Icon(
                                          Icons.star,
                                          size: 11,
                                          color: starIdx < rating ? Colors.green : Colors.grey.shade300,
                                        );
                                      }),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Expanded(
                            child: Text(
                              comment,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
      ],
    );
  }

  Widget _buildDesktopRelatedProductsSection(ThemeData theme) {
    if (_isLoadingRelated) {
      return Container(
        height: 100,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (_relatedProducts.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 32),
        const Text(
          'You May Also Like',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 250,
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
              final bool hasDiscount = discP > 0 && regP > discP;
              final int pct = hasDiscount ? (((regP - discP) / regP) * 100).round() : 0;

              String? pImg;
              if (prod['images'] != null && prod['images'] is List && (prod['images'] as List).isNotEmpty) {
                pImg = prod['images'][0]['product_images']?.toString();
              }
              final String finalImgUrl = (pImg != null && pImg.isNotEmpty) ? '$_baseProductImageUrl$pImg' : _baseNoImageUrl;

              return GestureDetector(
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => ProductDetailScreen(product: prod)));
                },
                child: Container(
                  width: 170,
                  margin: const EdgeInsets.only(right: 16, bottom: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.015), blurRadius: 8, offset: const Offset(0, 3)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
                          ),
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Image.network(
                                    finalImgUrl,
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 30),
                                  ),
                                ),
                              ),
                              if (hasDiscount)
                                Positioned(
                                  left: 8,
                                  top: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text('$pct% OFF', style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                            ],
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
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  "₹${displayPrice.round()}",
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                                ),
                                if (hasDiscount) ...[
                                  const SizedBox(width: 4),
                                  Text(
                                    "₹${regP.round()}",
                                    style: const TextStyle(fontSize: 10, decoration: TextDecoration.lineThrough, color: AppColors.textLight),
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

  double get _averageRating {
    if (_localReviews.isEmpty) return 0.0;
    double sum = 0.0;
    for (var r in _localReviews) {
      final rate = double.tryParse(r['product_rating']?.toString() ?? '0') ?? 0.0;
      sum += rate;
    }
    return sum / _localReviews.length;
  }

  bool get _hasUserReviewed {
    if (!_isLoggedIn || _userData == null) return false;
    final userId = _userData!['id']?.toString();
    for (var r in _localReviews) {
      if (r['customer_id']?.toString() == userId) return true;
    }
    return false;
  }

  void _showWriteReviewBottomSheet(BuildContext context) {
    double selectedRating = 5.0;
    final TextEditingController reviewController = TextEditingController();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Write a Review', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    const SizedBox(height: 16),
                    const Text('Rating', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    Row(
                      children: List.generate(5, (index) {
                        final starRating = index + 1.0;
                        return IconButton(
                          icon: Icon(
                            starRating <= selectedRating ? Icons.star_rounded : Icons.star_outline_rounded,
                            color: Colors.amber,
                            size: 32,
                          ),
                          onPressed: () {
                            setModalState(() {
                              selectedRating = starRating;
                            });
                          },
                        );
                      }),
                    ),
                    const SizedBox(height: 16),
                    const Text('Review Description', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: reviewController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Share your experience with this product...',
                        hintStyle: const TextStyle(fontSize: 13, color: AppColors.textLight),
                        fillColor: const Color(0xFFF8FAFC),
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () async {
                          if (reviewController.text.trim().isEmpty) return;
                          Navigator.pop(context);
                          _submitReview(selectedRating.toString(), reviewController.text.trim());
                        },
                        child: const Text('Submit Review', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _submitReview(String rating, String reviewText) async {
    if (_token == null || widget.product['id'] == null) return;
    try {
      final response = await ApiService.postProductReview(
        productId: widget.product['id'].toString(),
        productRating: rating,
        productReview: reviewText,
        token: _token!,
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> newReview = {
          'id': DateTime.now().millisecondsSinceEpoch,
          'customer_id': _userData?['id'],
          'customer_name': _userData?['name'] ?? 'You',
          'product_rating': rating,
          'product_review': reviewText,
          'created_at': DateTime.now().toIso8601String(),
        };
        setState(() {
          _localReviews.insert(0, newReview);
        });
        ShowSnackBar.show(context, 'Review submitted successfully!');
      } else {
        final body = json.decode(response.body);
        ShowSnackBar.show(context, body['message'] ?? 'Failed to submit review.', isError: true);
      }
    } catch (e) {
      debugPrint("Error submitting review: $e");
      ShowSnackBar.show(context, 'Something went wrong.', isError: true);
    }
  }

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
    final regP = double.tryParse(prod['product_price']?.toString() ?? '') ?? 0.0;
    final discP = double.tryParse(prod['product_discount_price']?.toString() ?? '') ?? 0.0;
    final price = discP > 0 ? discP : regP;
    String? pImg;
    if (prod['images'] != null && prod['images'] is List && (prod['images'] as List).isNotEmpty) {
      pImg = prod['images'][0]['product_images']?.toString();
    }
    final finalImgUrl = (pImg != null && pImg.isNotEmpty) ? '$_baseProductImageUrl$pImg' : _baseNoImageUrl;

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
          _buildDesktopNavItem(icon: Icons.local_mall_outlined, label: 'Products', isActive: false,
            onTap: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            }, theme: theme),
          ValueListenableBuilder<int>(
            valueListenable: CartManager.cartCountNotifier,
            builder: (context, count, child) => _buildDesktopNavItem(
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
                hintText: 'Search products, brands and more...',
                hintStyle: TextStyle(fontSize: 13, color: AppColors.textLight),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.only(bottom: 8),
                fillColor: Colors.transparent,
                filled: false,
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }

  Widget _buildDesktopNavItem({
    required IconData icon, required String label, required bool isActive,
    required VoidCallback onTap, int badgeCount = 0, required ThemeData theme,
  }) {
    final color = isActive ? theme.colorScheme.primary : AppColors.textPrimary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, color: color, size: 22),
                if (badgeCount > 0)
                  Positioned(
                    top: -6, right: -8,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text('$badgeCount', style: const TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: isActive ? FontWeight.bold : FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopProfileAvatar(ThemeData theme) {
    final userImage = _userData?['user_image']?.toString();
    final imageUrl = (userImage != null && userImage.isNotEmpty)
        ? "https://agsdemo.in/singlemartapi/public/assets/images/user_images/$userImage" : "";
    final name = _userData?['name']?.toString() ?? 'User';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: AppColors.primary.withOpacity(0.1),
            backgroundImage: imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
            child: imageUrl.isEmpty ? const Icon(Icons.person, size: 14, color: AppColors.primary) : null,
          ),
          const SizedBox(height: 6),
          Text(name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildDesktopSignInButton(ThemeData theme) {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginScreen()))
          .then((_) => _checkLoginStatus()),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person_outline_rounded, size: 22, color: AppColors.textPrimary),
            const SizedBox(height: 6),
            const Text('Sign In', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }

  Widget _buildOffersScroller() {
    final offers = [
      {
        "title": "Paytm Cashback",
        "desc": "Get Cashback up to Rs.300 on a minimum transaction of Rs.749",
        "icon": Icons.payment_rounded,
      },
      {
        "title": "Airtel Payments Bank",
        "desc": "Flat 10% off up to Rs.200 on a minimum transaction of Rs.889",
        "icon": Icons.account_balance_wallet_rounded,
      },
      {
        "title": "MobiKwik Cashback",
        "desc": "Flat Rs.75 Cashback on a minimum transaction of Rs.1499",
        "icon": Icons.wallet_rounded,
      }
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        const Text(
          'Offers Available',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: offers.length,
            itemBuilder: (context, index) {
              final offer = offers[index];
              return Container(
                width: 260,
                margin: const EdgeInsets.only(right: 12, bottom: 4),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 4, offset: const Offset(0, 1))
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(offer['icon'] as IconData, size: 16, color: AppColors.primary),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(offer['title'] as String, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                          const SizedBox(height: 2),
                          Text(offer['desc'] as String, style: const TextStyle(fontSize: 9.5, color: AppColors.textLight, height: 1.3), maxLines: 2, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDeliveryCheckBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        const Text(
          'Choose Delivery Preference',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 16, color: AppColors.textLight),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _pincodeController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          hintText: 'Enter pincode, locality, etc.',
                          hintStyle: TextStyle(fontSize: 12.5, color: AppColors.textLight),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.only(bottom: 12),
                          fillColor: Colors.transparent,
                          filled: false,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 44,
              child: ElevatedButton(
                onPressed: () {
                  if (_pincodeController.text.trim().isNotEmpty) {
                    setState(() {
                      _hasCheckedPincode = true;
                      _deliveryEstimate = "Standard Delivery: Get it by Tomorrow!";
                    });
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Check', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
        if (_hasCheckedPincode) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.local_shipping_outlined, size: 14, color: Colors.green),
              const SizedBox(width: 6),
              Text(_deliveryEstimate, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green)),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildAccordionBlock(String shortDesc, String longDesc) {
    final selectedVar = _selectedVariant;
    final List<Widget> specRows = [];

    final String vendorName = _vendorProfileData?['name']?.toString() ?? 
                              widget.product['vendor']?['name']?.toString() ?? 
                              widget.product['vendor_name']?.toString() ?? 
                              'SingleMart Merchant';
    final String vendorMobile = _vendorProfileData?['mobile']?.toString() ?? 
                                widget.product['vendor']?['mobile']?.toString() ?? 
                                widget.product['vendor']?['phone']?.toString() ?? 
                                'Not Available';
    final String vendorEmail = _vendorProfileData?['email']?.toString() ?? 
                               widget.product['vendor']?['email']?.toString() ?? 
                               'Not Available';

    if (selectedVar != null) {
      // 1. Variant Attributes
      final List<dynamic>? attrs = selectedVar['attributes'] ?? selectedVar['attribute_values'];
      if (attrs != null && attrs.isNotEmpty) {
        for (var attr in attrs) {
          final String name = attr['attribute_name'] ?? attr['attribute']?['attribute_name'] ?? 'Option';
          final String val = attr['attribute_value']?.toString() ?? '';
          if (val.isNotEmpty) {
            specRows.add(_buildSpecRow(name, val));
          }
        }
      }

      // 2. Weight
      final weightRaw = selectedVar['product_weight'];
      if (weightRaw != null && weightRaw.toString().isNotEmpty) {
        final double? wVal = double.tryParse(weightRaw.toString());
        if (wVal != null && wVal > 0) {
          specRows.add(_buildSpecRow("Weight", "${wVal.toStringAsFixed(1)} kg"));
        }
      }

      // 3. Dimensions
      final len = selectedVar['product_dimension_length'];
      final wid = selectedVar['product_dimension_width'];
      final hgt = selectedVar['product_dimension_height'];
      if (len != null && wid != null && hgt != null) {
        final double? lVal = double.tryParse(len.toString());
        final double? wVal = double.tryParse(wid.toString());
        final double? hVal = double.tryParse(hgt.toString());
        if (lVal != null && wVal != null && hVal != null && lVal > 0) {
          specRows.add(_buildSpecRow("Dimensions (L × W × H)", "${lVal.toStringAsFixed(2)} × ${wVal.toStringAsFixed(2)} × ${hVal.toStringAsFixed(2)} cm"));
        }
      }
    }

    return Column(
      children: [
        const SizedBox(height: 20),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
          ),
          child: Column(
            children: [
              ExpansionTile(
                title: const Text('Description', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                shape: const Border(),
                children: [
                  Text(
                    shortDesc.isNotEmpty ? shortDesc : "No description available.",
                    style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.4),
                  ),
                ],
              ),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              ExpansionTile(
                title: const Text('Instructions & Specifications', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                shape: const Border(),
                children: [
                  if (longDesc.isNotEmpty) ...[
                    Text(
                      longDesc,
                      style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.4),
                    ),
                    if (specRows.isNotEmpty) const SizedBox(height: 16),
                  ],
                  if (specRows.isNotEmpty)
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                      ),
                      child: Column(
                        children: List.generate(specRows.length, (idx) {
                          return Column(
                            children: [
                              specRows[idx],
                              if (idx < specRows.length - 1)
                                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                            ],
                          );
                        }),
                      ),
                    ),
                  if (longDesc.isEmpty && specRows.isEmpty)
                    const Text(
                      "No specifications available.",
                      style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                    ),
                ],
              ),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              ExpansionTile(
                title: const Text('Merchant Details', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                shape: const Border(),
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                    ),
                    child: Column(
                      children: [
                        _buildSpecRow("Merchant Name", vendorName),
                        const Divider(height: 1, color: Color(0xFFE2E8F0)),
                        _buildSpecRow("Phone Number", vendorMobile),
                        const Divider(height: 1, color: Color(0xFFE2E8F0)),
                        _buildSpecRow("Email Address", vendorEmail),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSpecRow(String key, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(key, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
          Text(value, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  Future<void> _fetchVendorProfile() async {
    try {
      final vendorIdRaw = widget.product['product_vendor_id'] ?? widget.product['vendor_id'] ?? widget.product['vendor']?['id'];
      if (vendorIdRaw != null) {
        final int vId = vendorIdRaw is int ? vendorIdRaw : int.tryParse(vendorIdRaw.toString()) ?? 0;
        if (vId > 0) {
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString('auth_token') ?? '';
          if (token.isNotEmpty) {
            final response = await ApiService.fetchVendor(vId, token);
            if (response.statusCode == 200) {
              final resData = json.decode(response.body);
              if (resData['data'] != null) {
                setState(() {
                  _vendorProfileData = Map<String, dynamic>.from(resData['data']);
                });
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching vendor profile: $e");
    }
  }
}
