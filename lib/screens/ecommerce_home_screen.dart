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
import 'profile_screen.dart';
import 'manage_address_screen.dart';

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

class _ECommerceHomeScreenState extends State<ECommerceHomeScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  
  // Animation Controllers
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Mega Menu
  final ValueNotifier<int?> _activeCategoryId = ValueNotifier(null);
  final ValueNotifier<int?> _hoveredCategoryIndex = ValueNotifier(null);
  Timer? _menuCloseTimer;

  int _currentTabIndex = 0;
  final ScrollController _scrollController = ScrollController();
  final ScrollController _bestSellerScrollController = ScrollController();
  List<dynamic> _categories = [];
  List<dynamic> _subcategories = [];
  List<dynamic> _brands = [];
  List<dynamic> _allProducts = [];
  List<dynamic> _banners = [];
  List<dynamic> _offerBanners = [];
  final ScrollController _offerBannerScrollController = ScrollController();
  Timer? _offerBannerTimer;
  bool _offerBannersHovered = false;

  Timer? _bestSellerTimer;
  bool _bestSellersHovered = false;

  final Map<int, ScrollController> _categoryScrollControllers = {};
  final Map<int, Timer> _categoryScrollTimers = {};
  final Map<int, bool> _categoriesHovered = {};

  static const int _kBannerLoopOffset = 50000;
  final PageController _bannerPageController = PageController();
  late final PageController _desktopBannerController = PageController(
    viewportFraction: 0.94,
    initialPage: _kBannerLoopOffset,
  );
  Timer? _bannerTimer;
  final ValueNotifier<int> _currentBannerIndex = ValueNotifier(0);

  // Search
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isSearchFocused = false;
  String _searchQuery = '';
  OverlayEntry? _searchOverlayEntry;
  final LayerLink _searchLayerLink = LayerLink();
  final GlobalKey _searchKey = GlobalKey();

  // User Data
  Map<String, dynamic>? _userData;
  bool _isLoggedIn = false;
  String? _authToken;
  List<Map<String, dynamic>> _cartItems = [];

  // Best Sellers
  List<dynamic> _bestSellerProducts = [];
  int _bestSellerSelectedCategoryId = -1;
  bool _isBestSellerLoading = true;

  // Image URLs
  String _baseNoImageUrl = 'https://agsdemo.in/singlemartapi/public/assets/images/no_image.jpg';
  String _baseProductImageUrl = 'https://agsdemo.in/singlemartapi/public/assets/images/product_images/';
  String _baseProductVariantImageUrl = 'https://agsdemo.in/singlemartapi/public/assets/images/product_variant_images/';

  @override
  void initState() {
    super.initState();
    _currentTabIndex = widget.initialTabIndex;
    _searchQuery = widget.initialSearchQuery;
    _searchController.text = widget.initialSearchQuery;

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _fadeController.forward();

    _searchFocusNode.addListener(() {
      setState(() => _isSearchFocused = _searchFocusNode.hasFocus);
      if (_searchFocusNode.hasFocus) {
        _showSearchOverlay();
        _scrollToTop();
      } else {
        Future.delayed(const Duration(milliseconds: 200), _hideSearchOverlay);
      }
    });

    _loadSession();
    _loadCatalog();
    _loadCart();
    _loadBestSellers();
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _searchOverlayEntry?.remove();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _bannerPageController.dispose();
    _desktopBannerController.dispose();
    _scrollController.dispose();
    _bestSellerScrollController.dispose();
    _bannerTimer?.cancel();
    _menuCloseTimer?.cancel();
    _activeCategoryId.dispose();
    _hoveredCategoryIndex.dispose();
    _currentBannerIndex.dispose();
    _fadeController.dispose();
    _offerBannerTimer?.cancel();
    _offerBannerScrollController.dispose();
    _bestSellerTimer?.cancel();
    for (var timer in _categoryScrollTimers.values) {
      timer.cancel();
    }
    for (var controller in _categoryScrollControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  // ==================== DATA LOADING ====================

  Future<void> _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    _baseNoImageUrl = prefs.getString('base_no_image_url') ?? _baseNoImageUrl;
    _baseProductImageUrl = prefs.getString('base_product_image_url') ?? _baseProductImageUrl;
    _baseProductVariantImageUrl = prefs.getString('base_product_variant_image_url') ?? _baseProductVariantImageUrl;
    
    final token = prefs.getString('auth_token');
    final userDataStr = prefs.getString('user_data');
    if (token != null && token.isNotEmpty && userDataStr != null && userDataStr.isNotEmpty) {
      setState(() {
        _isLoggedIn = true;
        _authToken = token;
        _userData = json.decode(userDataStr);
      });
      _refreshProfileFromServerSilent();
    }
  }

  Future<void> _refreshProfileFromServerSilent() async {
    if (_authToken == null || _userData == null) return;
    try {
      final vendorId = _userData!['id'] is int ? _userData!['id'] : int.tryParse(_userData!['id']?.toString() ?? '0') ?? 0;
      final response = await ApiService.fetchVendor(vendorId, _authToken!);
      if (response.statusCode == 200) {
        final resData = json.decode(response.body);
        final profileData = resData['data'];
        if (profileData != null) {
          final parsedProfile = Map<String, dynamic>.from(profileData);
          final addressList = parsedProfile['addresses'] ?? parsedProfile['address'];
          if (addressList != null) {
            parsedProfile['addresses'] = addressList;
            parsedProfile['address'] = addressList;
          }
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_data', json.encode(parsedProfile));
          if (mounted) setState(() => _userData = parsedProfile);
        }
      }
    } catch (e) {
      debugPrint("Silent refresh profile error: $e");
    }
  }

  Future<void> _loadCatalog() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final responses = await Future.wait([
        ApiService.fetchActiveCategories(),
        ApiService.fetchActiveSubCategories(),
        ApiService.fetchActiveBrands(),
        ApiService.fetchActiveProducts(),
        ApiService.fetchActiveBanners(token),
      ]);

      if (responses[0].statusCode == 200) {
        final catBody = json.decode(responses[0].body);
        _categories = catBody['data'] ?? [];
      }
      if (responses[1].statusCode == 200) {
        final subBody = json.decode(responses[1].body);
        _subcategories = subBody['data'] ?? [];
      }
      if (responses[2].statusCode == 200) {
        final brandBody = json.decode(responses[2].body);
        _brands = brandBody['data'] ?? [];
      }
      if (responses[3].statusCode == 200) {
        final prodBody = json.decode(responses[3].body);
        final loadedProds = prodBody['data'] ?? [];
        final imageUrls = prodBody['image_url'] ?? [];
        
        for (var item in imageUrls) {
          final imageFor = item['image_for']?.toString();
          final url = item['image_url']?.toString();
          if (imageFor != null && url != null) {
            if (imageFor == 'No Image') {
              await prefs.setString('base_no_image_url', url);
              _baseNoImageUrl = url;
            } else if (imageFor == 'Product') {
              await prefs.setString('base_product_image_url', url);
              _baseProductImageUrl = url;
            } else if (imageFor == 'Product Variant') {
              await prefs.setString('base_product_variant_image_url', url);
              _baseProductVariantImageUrl = url;
            }
          }
        }

        _allProducts = loadedProds.map((p) {
          final itemMap = Map<String, dynamic>.from(p);
          final hasVariants = (p['has_variants'] == 1 || p['has_variants'] == '1') &&
              p['variants'] != null && (p['variants'] as List).isNotEmpty;

          double pPrice = 0.0, pOriginalPrice = 0.0;
          if (hasVariants) {
            final firstVar = (p['variants'] as List).first;
            final discPrice = double.tryParse(firstVar['product_discount_price']?.toString() ?? '') ?? 0.0;
            final regPrice = double.tryParse(firstVar['product_price']?.toString() ?? '') ?? 0.0;
            if (discPrice > 0 && discPrice < regPrice) {
              pPrice = discPrice;
              pOriginalPrice = regPrice;
            } else {
              pPrice = discPrice > 0 ? discPrice : regPrice;
              pOriginalPrice = (regPrice > pPrice) ? regPrice : 0.0;
            }
          } else {
            final discPrice = double.tryParse(p['product_discount_price']?.toString() ?? '') ?? 0.0;
            final regPrice = double.tryParse(p['product_price']?.toString() ?? '') ?? 0.0;
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
      }
      if (responses[4].statusCode == 200) {
        final decoded = json.decode(responses[4].body);
        final allBanners = decoded['data'] ?? [];
        _banners = allBanners.where((b) {
          final type = b['banner_type']?.toString().toLowerCase();
          return type == null || type.isEmpty || type == 'main';
        }).toList();
        _offerBanners = allBanners.where((b) {
          final type = b['banner_type']?.toString().toLowerCase();
          return type == 'offer';
        }).toList();
        if (_banners.length > 1) _startBannerAutoScroll();
        if (_offerBanners.length > 1) _startOfferBannerAutoScroll();
      }

      _initCategoryScrolls();

      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint("Failed to load catalog: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadCart() async {
    try {
      final cartStr = await CartManager.getCartData();
      if (cartStr != null && cartStr.isNotEmpty) {
        final parsed = json.decode(cartStr);
        setState(() => _cartItems = List<Map<String, dynamic>>.from(
          parsed.map((item) => Map<String, dynamic>.from(item))
        ));
      }
    } catch (e) {
      debugPrint("Error loading cart: $e");
    }
  }

  Future<void> _loadBestSellers() async {
    setState(() => _isBestSellerLoading = true);
    try {
      final response = await ApiService.fetchBestSellerProducts();
      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        final data = body['data'] ?? [];
        final imageUrls = body['image_url'] ?? [];

        String productImgUrl = _baseProductImageUrl;
        String noImgUrl = _baseNoImageUrl;
        for (var item in imageUrls) {
          if (item['image_for'] == 'Product') productImgUrl = item['image_url'] ?? productImgUrl;
          if (item['image_for'] == 'No Image') noImgUrl = item['image_url'] ?? noImgUrl;
        }

        setState(() {
          _bestSellerProducts = data;
          _bestSellerSelectedCategoryId = -1;
          _isBestSellerLoading = false;
        });
        if (_bestSellerProducts.length > 1) _startBestSellerAutoScroll();
      } else {
        setState(() => _isBestSellerLoading = false);
      }
    } catch (e) {
      debugPrint("Error loading best sellers: $e");
      setState(() => _isBestSellerLoading = false);
    }
  }

  void _startBannerAutoScroll() {
    _bannerTimer?.cancel();
    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_banners.length < 2) return;
      if (_desktopBannerController.hasClients) {
        final nextDesktop = (_desktopBannerController.page?.toInt() ?? _kBannerLoopOffset) + 1;
        _desktopBannerController.animateToPage(
          nextDesktop,
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeInOutCubic,
        );
      }
      if (_bannerPageController.hasClients) {
        int nextPage = (_bannerPageController.page?.toInt() ?? 0) + 1;
        if (nextPage >= _banners.length) nextPage = 0;
        _bannerPageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  void _startOfferBannerAutoScroll() {
    _offerBannerTimer?.cancel();
    _offerBannerTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_offerBannersHovered) return;
      final isDesktop = MediaQuery.of(context).size.width > 850;
      final limit = isDesktop ? 3 : 1;
      if (_offerBanners.length <= limit) return;

      final controller = _offerBannerScrollController;
      if (controller.hasClients) {
        final currentScroll = controller.offset;
        final viewportWidth = controller.position.viewportDimension;
        final spacing = 16.0;
        final itemWidth = isDesktop ? (viewportWidth - (2 * spacing)) / 3 : viewportWidth;
        
        double targetScroll = currentScroll + itemWidth + spacing;
        controller.animateTo(
          targetScroll,
          duration: const Duration(milliseconds: 1200),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  void _startCategoryAutoScroll(int catId) {
    _categoryScrollTimers[catId]?.cancel();
    _categoryScrollTimers[catId] = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_categoriesHovered[catId] == true) return;
      final controller = _categoryScrollControllers[catId];
      if (controller != null && controller.hasClients) {
        final List<dynamic> catProducts = _allProducts.where((p) => p['category_id'] == catId).take(15).toList();
        if (catProducts.length <= 3) return;

        final currentScroll = controller.offset;
        double targetScroll = currentScroll + 220; // card size + spacing approx
        controller.animateTo(
          targetScroll,
          duration: const Duration(milliseconds: 1200),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  void _startBestSellerAutoScroll() {
    _bestSellerTimer?.cancel();
    _bestSellerTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_bestSellersHovered) return;
      final isDesktop = MediaQuery.of(context).size.width > 850;
      final limit = isDesktop ? 4 : 2;

      final filteredBestSellers = _bestSellerSelectedCategoryId == -1
          ? _bestSellerProducts
          : _bestSellerProducts.where((item) {
              final product = item['product'];
              return product != null && product['product_category_id'] == _bestSellerSelectedCategoryId;
            }).toList();

      if (filteredBestSellers.length <= limit) return;

      final controller = _bestSellerScrollController;
      if (controller.hasClients) {
        final currentScroll = controller.offset;
        double targetScroll = currentScroll + 250; // Scroll step
        controller.animateTo(
          targetScroll,
          duration: const Duration(milliseconds: 1200),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  void _initCategoryScrolls() {
    for (var timer in _categoryScrollTimers.values) {
      timer.cancel();
    }
    _categoryScrollTimers.clear();

    for (var controller in _categoryScrollControllers.values) {
      controller.dispose();
    }
    _categoryScrollControllers.clear();

    final frontCategories = _categories.where((cat) {
      final inFront = cat['categories_inFront'];
      return inFront == '1' || inFront == 1;
    }).toList();

    for (var cat in frontCategories) {
      final int catId = cat['id'];
      final controller = ScrollController();
      _categoryScrollControllers[catId] = controller;
      _startCategoryAutoScroll(catId);
    }
  }

  // ==================== CART OPERATIONS ====================

  Future<void> _addToCartDirect(Map<String, dynamic> product, Map<String, dynamic>? selectedVariant) async {
    try {
      final cartStr = await CartManager.getCartData();
      List<Map<String, dynamic>> currentCart = [];
      if (cartStr != null && cartStr.isNotEmpty) {
        final parsed = json.decode(cartStr);
        currentCart = List<Map<String, dynamic>>.from(
          parsed.map((item) => Map<String, dynamic>.from(item))
        );
      }

      final prodId = product['id'];
      var targetProduct = product;
      final catalogMatch = _allProducts.firstWhere(
        (p) => p['id'] == prodId,
        orElse: () => null,
      );
      if (catalogMatch != null) {
        targetProduct = Map<String, dynamic>.from(catalogMatch);
      }

      Map<String, dynamic>? resolvedVariant = selectedVariant;
      if (resolvedVariant == null && (targetProduct['has_variants'] == 1 || targetProduct['has_variants'] == '1')) {
        final List<dynamic>? variants = targetProduct['variants'];
        if (variants != null && variants.isNotEmpty) {
          resolvedVariant = Map<String, dynamic>.from(variants[0]);
        }
      }

      final discP = resolvedVariant != null
          ? (double.tryParse(resolvedVariant['product_discount_price']?.toString() ?? '') ?? 0.0)
          : (double.tryParse(targetProduct['product_discount_price']?.toString() ?? '') ?? 0.0);
      final regP = resolvedVariant != null
          ? (double.tryParse(resolvedVariant['product_price']?.toString() ?? '') ?? 0.0)
          : (double.tryParse(targetProduct['product_price']?.toString() ?? '') ?? 0.0);

      final price = (discP > 0) ? discP : (regP > 0 ? regP : double.tryParse(targetProduct['price']?.toString() ?? '') ?? 0.0);
      final originalPrice = (discP > 0 && regP > discP) ? regP : (regP > price ? regP : 0.0);

      String? productImg;
      if (resolvedVariant != null && resolvedVariant['images'] != null && (resolvedVariant['images'] as List).isNotEmpty) {
        productImg = resolvedVariant['images'][0]['product_variant_images']?.toString();
      } else if (targetProduct['images'] != null && (targetProduct['images'] as List).isNotEmpty) {
        productImg = targetProduct['images'][0]['product_images']?.toString();
      }

      String variantAttrStr = '';
      if (resolvedVariant != null) {
        final attrs = resolvedVariant['attributes'] ?? resolvedVariant['attribute_values'];
        if (attrs != null && attrs.isNotEmpty) {
          final attrTexts = <String>[];
          for (var attr in attrs) {
            final val = attr['attribute_value']?.toString();
            if (val != null && val.isNotEmpty) attrTexts.add(val);
          }
          variantAttrStr = attrTexts.join(' / ');
        }
      }

      final varId = resolvedVariant != null ? int.tryParse(resolvedVariant['id']?.toString() ?? '') : null;
      final cartMatchId = varId != null ? "${targetProduct['id']}_v$varId" : "${targetProduct['id']}";

      final existingIndex = currentCart.indexWhere((item) {
        if (item['cart_item_id'] != null) return item['cart_item_id'].toString() == cartMatchId;
        if (varId != null) return item['id'] == targetProduct['id'] && item['variant_id'] == varId;
        return item['id'] == targetProduct['id'] && item['variant_id'] == null;
      });

      if (existingIndex != -1) {
        currentCart[existingIndex]['quantity'] = (currentCart[existingIndex]['quantity'] ?? 1) + 1;
      } else {
        currentCart.add({
          "cart_item_id": cartMatchId,
          "id": targetProduct['id'],
          "variant_id": varId,
          "product_sku": resolvedVariant?['product_sku'] ?? targetProduct['product_sku'],
          "variant_attributes": variantAttrStr.isNotEmpty ? variantAttrStr : null,
          "is_variant": resolvedVariant != null,
          "name": targetProduct['product_name'] ?? targetProduct['name'] ?? 'Product',
          "price": price,
          "original_price": originalPrice,
          "product_price": regP > 0 ? regP : originalPrice,
          "desc": targetProduct['product_short_description'] ?? targetProduct['desc'] ?? '',
          "image": targetProduct['categories_name'] ?? targetProduct['image'] ?? 'Products',
          "quantity": 1,
          "product_vendor_id": targetProduct['product_vendor_id'],
          "created_by": targetProduct['created_by'],
          "vendor_id": targetProduct['vendor_id'] ?? targetProduct['created_by'],
          "product_image": productImg,
        });
      }

      await CartManager.setCartData(json.encode(currentCart));
      _loadCart();

      if (mounted) {
        ShowSnackBar.show(context, "${targetProduct['product_name'] ?? targetProduct['name'] ?? 'Product'} added to cart!");
      }
    } catch (e) {
      debugPrint("Error adding to cart: $e");
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
        _cartItems = [];
      });
      await CartManager.updateCartCount();
    } catch (e) {
      debugPrint("Error during logout: $e");
    }
  }

  // ==================== UI HELPERS ====================

  String _getCategoryImage(dynamic categoriesImage) {
    if (categoriesImage == null || categoriesImage.toString().isEmpty) {
      return 'https://agsdemo.in/singlemartapi/public/assets/images/no_image.jpg';
    }
    return 'https://agsdemo.in/singlemartapi/public/assets/images/category_images/${categoriesImage.toString()}';
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
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        await launchUrl(url, mode: LaunchMode.inAppBrowserView);
      }
    } catch (e) {
      await launchUrl(url, mode: LaunchMode.platformDefault);
    }
  }

  IconData _getCategoryIcon(String categoryName) {
    final name = categoryName.toLowerCase();
    if (name.contains('electronics') || name.contains('mobile') || name.contains('laptop') || name.contains('watch')) {
      return Icons.electrical_services;
    }
    if (name.contains('fashion') || name.contains('accessories') || name.contains('clothing')) {
      return Icons.checkroom;
    }
    if (name.contains('home') || name.contains('kitchen') || name.contains('appliance')) {
      return Icons.kitchen;
    }
    if (name.contains('beauty') || name.contains('care') || name.contains('skincare')) {
      return Icons.brush;
    }
    if (name.contains('sports') || name.contains('fitness') || name.contains('gym')) {
      return Icons.sports_soccer;
    }
    return Icons.category;
  }

  String _formatNumber(int number) {
    final str = number.toString();
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return str.replaceAllMapped(reg, (Match m) => "${m[1]},");
  }

  String _getBrandName(dynamic brandId) {
    if (brandId == null) return '';
    final id = int.tryParse(brandId.toString());
    if (id == null) return '';
    final brand = _brands.firstWhere((b) => b['id'] == id, orElse: () => null);
    return brand != null ? (brand['brand_name'] ?? brand['brands_name'] ?? '') : '';
  }

  // ==================== MEGA MENU ====================

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
    return _allProducts.where((p) => p['category_id'] == categoryId).take(5).toList();
  }

  Widget _buildMegaMenuOverlay(ThemeData theme, int activeId) {
    final catDetails = _categories.firstWhere(
      (c) => c['id'] == activeId,
      orElse: () => null,
    );
    
    final catName = catDetails != null ? (catDetails['categories_name'] ?? 'Category') : 'Category';
    final catImage = catDetails != null ? _getCategoryImage(catDetails['categories_image']) : _baseNoImageUrl;
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
            // Products Grid - 5 products
            Expanded(
              flex: 2,
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
                          Text(
                            'Featured $catName',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Expanded(
                            child: GridView.builder(
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 5,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                                childAspectRatio: 0.6,
                              ),
                              itemCount: catProducts.length,
                              itemBuilder: (context, idx) {
                                final p = catProducts[idx];
                                return _buildMegaMenuItem(p, theme);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            
            // Category Banner
            Container(
              width: 200,
              height: double.infinity,
              decoration: const BoxDecoration(
                border: Border(
                  left: BorderSide(color: Color(0xFFF1F5F9), width: 1),
                ),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.network(
                      catImage,
                      fit: BoxFit.cover,
                      cacheWidth: 300,
                      errorBuilder: (c, e, s) => Container(
                        color: theme.colorScheme.primary.withOpacity(0.08),
                        child: Icon(Icons.broken_image, size: 32, color: theme.colorScheme.primary),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withOpacity(0.6),
                            Colors.black.withOpacity(0.1),
                          ],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          catName.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Shop Now',
                          style: TextStyle(color: Colors.white70, fontSize: 10),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Text('View All', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.black87)),
                              SizedBox(width: 4),
                              Icon(Icons.arrow_forward_rounded, size: 12, color: Colors.black87),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMegaMenuItem(dynamic prod, ThemeData theme) {
    final bool hasVariants = (prod['has_variants'] == 1 || prod['has_variants'] == '1') &&
        prod['variants'] != null &&
        (prod['variants'] as List).isNotEmpty;

    String imageUrl = _baseNoImageUrl;
    if (hasVariants) {
      final firstVar = (prod['variants'] as List).first;
      final varImages = firstVar['images'];
      if (varImages != null && varImages is List && varImages.isNotEmpty) {
        final filename = varImages[0]['product_variant_images'];
        if (filename != null && filename.isNotEmpty) {
          imageUrl = '$_baseProductVariantImageUrl$filename';
        }
      }
    } else {
      final images = prod['images'];
      if (images != null && images is List && images.isNotEmpty) {
        final filename = images[0]['product_images'];
        if (filename != null && filename.isNotEmpty) {
          imageUrl = '$_baseProductImageUrl$filename';
        }
      }
    }

    final double price = prod['price'] is num
        ? (prod['price'] as num).toDouble()
        : (double.tryParse(prod['price']?.toString() ?? '0') ?? 0.0);

    return InkWell(
      onTap: () {
        _activeCategoryId.value = null;
        Navigator.pushNamed(context, '/product/${prod['id']}', arguments: prod);
      },
      borderRadius: BorderRadius.circular(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFF1F5F9), width: 0.5),
              ),
              padding: const EdgeInsets.all(4),
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                cacheWidth: 120,
                cacheHeight: 120,
                errorBuilder: (c, e, s) => const Icon(Icons.broken_image, size: 16),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            prod['name'] ?? 'Product',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 2),
          Text(
            "₹${price.toStringAsFixed(0)}",
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: theme.colorScheme.primary),
          ),
        ],
      ),
    );
  }

  // ==================== APP BAR ====================

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
              decoration: BoxDecoration(color: theme.colorScheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.shopping_bag, color: theme.colorScheme.primary, size: 24),
            ),
            const SizedBox(width: 10),
            Text('SingleMart', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 22)),
          ],
        ),
        actions: [
          if (_isLoggedIn) ...[_buildMobileProfileAvatar()] else
            TextButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginScreen()))
                  .then((_) => _loadSession()),
              icon: const Icon(Icons.login_rounded, size: 18, color: AppColors.primary),
              label: const Text('Sign In', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
            ),
          const SizedBox(width: 12),
        ],
      );
    }

    return PreferredSize(
      preferredSize: const Size.fromHeight(75),
      child: Container(
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
            _buildDesktopNavItem(icon: Icons.local_mall_outlined, label: 'Products', isActive: _currentTabIndex == 2,
              onTap: () => setState(() => _currentTabIndex = 2), theme: theme),
            ValueListenableBuilder<int>(
              valueListenable: CartManager.cartCountNotifier,
              builder: (context, count, child) => _buildDesktopNavItem(
                icon: Icons.shopping_cart_outlined, label: 'Cart', isActive: _currentTabIndex == 3,
                badgeCount: count, onTap: () => setState(() => _currentTabIndex = 3), theme: theme),
            ),
            _isLoggedIn ? _buildDesktopProfileAvatar(theme) : _buildDesktopSignInButton(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildBrandLogo(ThemeData theme) {
    return GestureDetector(
      onTap: () => setState(() => _currentTabIndex = 0),
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

    return InkWell(
      onTap: () {
        if (_isLoggedIn && _userData != null && _authToken != null) {
          Navigator.push(context, MaterialPageRoute(
            builder: (context) => ManageAddressScreen(userData: _userData!, token: _authToken!),
          )).then((_) => _loadSession());
        } else {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginScreen()))
              .then((_) => _loadSession());
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          children: [
            Container(
              width: 24, height: 16,
              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(2)),
              child: const Icon(Icons.flag_rounded, size: 14, color: Colors.orange),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Where to deliver?', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    SizedBox(
                      width: 110,
                      child: Text(displayAddress, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 10, color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
                    ),
                    Icon(Icons.keyboard_arrow_down_rounded, size: 12, color: theme.colorScheme.primary),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==================== SEARCH BAR - FIXED (No duplicate border) ====================
  Widget _buildSearchBar(ThemeData theme) {
    return CompositedTransformTarget(
      link: _searchLayerLink,
      child: Container(
        key: _searchKey,
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                onSubmitted: (_) { _searchFocusNode.unfocus(); _hideSearchOverlay(); },
                onTap: () { if (_currentTabIndex != 0) setState(() => _currentTabIndex = 0); },
                onChanged: (val) {
                  setState(() { _searchQuery = val; if (val.isNotEmpty && _currentTabIndex != 0) _currentTabIndex = 0; });
                  _searchOverlayEntry?.markNeedsBuild();
                },
                decoration: const InputDecoration(
                  hintText: 'Search for local products, stores, brands...',
                  hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                ),
                style: const TextStyle(fontSize: 13),
              ),
            ),
            if (_searchQuery.isNotEmpty)
              GestureDetector(
                onTap: () { _searchController.clear(); setState(() => _searchQuery = ''); _searchOverlayEntry?.markNeedsBuild(); },
                child: const Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Icon(Icons.clear_rounded, color: AppColors.textLight, size: 18)),
              ),
            GestureDetector(
              onTap: () { _searchFocusNode.unfocus(); _hideSearchOverlay(); },
              child: Container(
                width: 50, height: 44,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: const BorderRadius.only(topRight: Radius.circular(8), bottomRight: Radius.circular(8)),
                ),
                child: const Icon(Icons.search_rounded, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
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

  Widget _buildMobileProfileAvatar() {
    final userImage = _userData?['user_image']?.toString();
    final imageUrl = (userImage != null && userImage.isNotEmpty)
        ? "https://agsdemo.in/singlemartapi/public/assets/images/user_images/$userImage" : "";
    return GestureDetector(
      onTap: () => setState(() => _currentTabIndex = 3),
      child: Padding(
        padding: const EdgeInsets.only(right: 16.0),
        child: CircleAvatar(
          radius: 16,
          backgroundColor: AppColors.primary.withOpacity(0.08),
          backgroundImage: imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
          child: imageUrl.isEmpty ? const Icon(Icons.person, size: 20, color: AppColors.primary) : null,
        ),
      ),
    );
  }

  Widget _buildDesktopProfileAvatar(ThemeData theme) {
    final userImage = _userData?['user_image']?.toString();
    final imageUrl = (userImage != null && userImage.isNotEmpty)
        ? "https://agsdemo.in/singlemartapi/public/assets/images/user_images/$userImage" : "";
    final name = _userData?['name']?.toString() ?? 'User';
    final isActive = _currentTabIndex == 4;

    return InkWell(
      onTap: () => setState(() => _currentTabIndex = 4),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
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
            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                color: isActive ? theme.colorScheme.primary : AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopSignInButton(ThemeData theme) {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginScreen()))
          .then((_) => _loadSession()),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person_outline_rounded, size: 22, color: AppColors.textPrimary),
            const SizedBox(height: 6),
            Text('Sign In', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }

  // ==================== BANNER SLIDER ====================

  Widget _buildBannerSlider(ThemeData theme) {
    final isDesktop = MediaQuery.of(context).size.width > 850;

    if (_banners.isEmpty) {
      return Container(
        width: double.infinity,
        height: isDesktop ? 420 : 180,
        margin: EdgeInsets.symmetric(horizontal: isDesktop ? 40 : 16, vertical: isDesktop ? 24 : 12),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [theme.colorScheme.primary, theme.colorScheme.secondary]),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_isLoggedIn ? 'Welcome, ${_userData?['name']}!' : 'Grand Local Deals!',
              style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Direct neighborhood shopping with instant delivery and zero fees.',
              style: TextStyle(color: Colors.white, fontSize: 15, height: 1.4)),
          ],
        ),
      );
    }

    if (isDesktop) {
      return SizedBox(
        height: 420,
        child: Stack(
          alignment: Alignment.center,
          children: [
            PageView.builder(
              controller: _desktopBannerController,
              itemCount: 999999,
              onPageChanged: (rawIndex) => _currentBannerIndex.value = rawIndex % _banners.length,
              itemBuilder: (context, rawIndex) {
                final realIndex = rawIndex % _banners.length;
                final banner = _banners[realIndex];
                final imageUrl = _getBannerImage(banner['banner_image']);
                final link = banner['banner_link'];

                return AnimatedBuilder(
                  animation: _desktopBannerController,
                  builder: (context, child) {
                    double pageOffset = 0.0;
                    if (_desktopBannerController.position.haveDimensions) {
                      pageOffset = _desktopBannerController.page! - rawIndex;
                    }
                    final isCurrent = pageOffset.abs() < 0.5;
                    final verticalMargin = (pageOffset.abs() * 28).clamp(0.0, 28.0);
                    
                    return Container(
                      margin: EdgeInsets.symmetric(horizontal: 10, vertical: verticalMargin),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: isCurrent
                            ? [BoxShadow(color: Colors.black.withOpacity(0.20), blurRadius: 32, spreadRadius: 2, offset: const Offset(0, 12))]
                            : [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: GestureDetector(
                          onTap: () { if (link != null && link.isNotEmpty) _launchUrl(link); },
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: Image.network(imageUrl, fit: BoxFit.cover, cacheWidth: 800,
                                  semanticLabel: banner['banner_alt']?.toString() ?? 'Banner Image',
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    color: theme.colorScheme.primary.withOpacity(0.08),
                                    child: Icon(Icons.image_rounded, color: theme.colorScheme.primary, size: 64)),
                                ),
                              ),
                              if (!isCurrent)
                                Positioned.fill(
                                  child: Container(decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.25), borderRadius: BorderRadius.circular(24))),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            Positioned(
              left: 20,
              child: _buildSliderArrow(icon: Icons.chevron_left_rounded,
                onTap: () {
                  final prev = (_desktopBannerController.page?.toInt() ?? _kBannerLoopOffset) - 1;
                  _desktopBannerController.animateToPage(prev, duration: const Duration(milliseconds: 500), curve: Curves.easeOutCubic);
                }, theme: theme),
            ),
            Positioned(
              right: 20,
              child: _buildSliderArrow(icon: Icons.chevron_right_rounded,
                onTap: () {
                  final next = (_desktopBannerController.page?.toInt() ?? _kBannerLoopOffset) + 1;
                  _desktopBannerController.animateToPage(next, duration: const Duration(milliseconds: 500), curve: Curves.easeOutCubic);
                }, theme: theme),
            ),
            if (_banners.length > 1)
              Positioned(
                bottom: 14,
                left: 0, right: 0,
                child: ValueListenableBuilder<int>(
                  valueListenable: _currentBannerIndex,
                  builder: (context, currentIndex, child) => Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_banners.length, (index) {
                      final isCurrent = index == currentIndex;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: isCurrent ? 28 : 8, height: 8,
                        decoration: BoxDecoration(
                          color: isCurrent ? Colors.white : Colors.white.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                ),
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.015), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            PageView.builder(
              controller: _bannerPageController,
              itemCount: _banners.length,
              onPageChanged: (index) => _currentBannerIndex.value = index,
              itemBuilder: (context, index) {
                final banner = _banners[index];
                final imageUrl = _getBannerImage(banner['banner_image']);
                final link = banner['banner_link'];
                return GestureDetector(
                  onTap: () { if (link != null && link.isNotEmpty) _launchUrl(link); },
                  child: Image.network(imageUrl, width: double.infinity, height: 180, fit: BoxFit.cover, cacheWidth: 600,
                    semanticLabel: banner['banner_alt']?.toString() ?? 'Banner Image',
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: theme.colorScheme.primary.withOpacity(0.05),
                      child: Icon(Icons.broken_image, color: theme.colorScheme.primary, size: 48)),
                  ),
                );
              },
            ),
            if (_banners.length > 1)
              Positioned(
                bottom: 12, left: 0, right: 0,
                child: ValueListenableBuilder<int>(
                  valueListenable: _currentBannerIndex,
                  builder: (context, currentIndex, child) => Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_banners.length, (index) {
                      final isCurrent = index == currentIndex;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: isCurrent ? 12 : 8, height: 8,
                        decoration: BoxDecoration(
                          color: isCurrent ? theme.colorScheme.primary : theme.colorScheme.primary.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfferBannerSlider(ThemeData theme, bool isDesktop) {
    if (_offerBanners.isEmpty) return const SizedBox.shrink();

    final displayBanners = _offerBanners.take(10).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: isDesktop ? 40 : 20, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Save More with Offers', style: TextStyle(
                fontSize: isDesktop ? 22 : 18, fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A), letterSpacing: -0.3)),
              const SizedBox(height: 4),
              Text('Grab the best deals and cashbacks on your purchases',
                style: TextStyle(fontSize: isDesktop ? 13 : 11.5, color: const Color(0xFF475569), fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: isDesktop ? 40 : 16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final viewportWidth = constraints.maxWidth;
              final double spacing = 16.0;
              final double itemWidth = isDesktop ? (viewportWidth - (2 * spacing)) / 3 : viewportWidth;
              final double itemHeight = isDesktop ? itemWidth / 2.2 : itemWidth / 2.5;

              final limit = isDesktop ? 3 : 1;
              final shouldLoop = displayBanners.length > limit;

              return SizedBox(
                height: itemHeight,
                child: MouseRegion(
                  onEnter: (_) => _offerBannersHovered = true,
                  onExit: (_) => _offerBannersHovered = false,
                  child: ListView.builder(
                    controller: _offerBannerScrollController,
                    scrollDirection: Axis.horizontal,
                    physics: shouldLoop ? const BouncingScrollPhysics() : const NeverScrollableScrollPhysics(),
                    itemCount: shouldLoop ? 100000 : displayBanners.length,
                    itemBuilder: (context, index) {
                      final banner = displayBanners[index % displayBanners.length];
                      return Container(
                        width: itemWidth,
                        margin: EdgeInsets.only(
                          right: index == (shouldLoop ? 99999 : displayBanners.length - 1) ? 0 : spacing,
                        ),
                        child: _buildOfferCard(banner, theme, isDesktop),
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildOfferCard(dynamic banner, ThemeData theme, bool isDesktop) {
    final imageUrl = _getBannerImage(banner['banner_image']);
    final link = banner['banner_link'];
    final alt = banner['banner_alt']?.toString() ?? 'Offer Banner';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: GestureDetector(
          onTap: () { if (link != null && link.isNotEmpty) _launchUrl(link); },
          child: Image.network(
            imageUrl,
            fit: BoxFit.cover,
            semanticLabel: alt,
            errorBuilder: (context, error, stackTrace) => Container(
              color: theme.colorScheme.primary.withOpacity(0.05),
              child: Center(
                child: Icon(Icons.broken_image, color: theme.colorScheme.primary, size: isDesktop ? 40 : 28),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSliderArrow({required IconData icon, required VoidCallback onTap, required ThemeData theme}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Icon(icon, color: AppColors.textPrimary, size: 28),
      ),
    );
  }

  // ==================== BEST SELLERS SECTION ====================

  Widget _buildBestSellersSection(ThemeData theme, bool isDesktop) {
    if (_isBestSellerLoading) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 16),
        padding: const EdgeInsets.all(40),
        decoration: const BoxDecoration(color: Color(0xFFE2EDF7)),
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
      );
    }
    if (_bestSellerProducts.isEmpty) return const SizedBox.shrink();

    final categoryMap = <int, Map<String, String>>{};
    for (var item in _bestSellerProducts) {
      final product = item['product'];
      if (product != null && product['category'] != null) {
        final catId = product['category']['id'] ?? 0;
        final catName = product['category']['categories_name'] ?? '';
        final catImage = product['category']['categories_image'] ?? '';
        if (catId > 0 && catName.isNotEmpty) {
          categoryMap[catId] = {'name': catName, 'image': catImage};
        }
      }
    }

    final filteredBestSellers = _bestSellerSelectedCategoryId == -1
        ? _bestSellerProducts
        : _bestSellerProducts.where((item) {
            final product = item['product'];
            return product != null && product['product_category_id'] == _bestSellerSelectedCategoryId;
          }).toList();

    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(vertical: isDesktop ? 24 : 16),
      decoration: const BoxDecoration(color: Color(0xFFD6E4F0)),
      padding: EdgeInsets.symmetric(vertical: isDesktop ? 32 : 24, horizontal: isDesktop ? 32 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Shop By Bestsellers', style: TextStyle(
            fontSize: isDesktop ? 25 : 20, fontWeight: FontWeight.w900,
            color: const Color(0xFF0F172A), letterSpacing: -0.3)),
          const SizedBox(height: 4),
          Text('Discover dynamic bestsellers that make every purchase extra special',
            style: TextStyle(fontSize: isDesktop ? 13.5 : 12, color: const Color(0xFF475569), fontWeight: FontWeight.w500)),
          const SizedBox(height: 24),
          _buildBestSellerCategories(theme, categoryMap),
          const SizedBox(height: 24),
          _buildBestSellerProductsScroll(theme, isDesktop, filteredBestSellers),
          const SizedBox(height: 24),
          Center(
            child: InkWell(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProductsListScreen())),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('View All Products', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(width: 6),
                    Icon(Icons.chevron_right_rounded, size: 16, color: theme.colorScheme.primary),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBestSellerCategories(ThemeData theme, Map<int, Map<String, String>> categoryMap) {
    return SizedBox(
      height: 90,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildCategoryChip(theme: theme, label: 'All', imageUrl: null, isSelected: _bestSellerSelectedCategoryId == -1,
              onTap: () => setState(() => _bestSellerSelectedCategoryId = -1)),
            ...categoryMap.entries.map((entry) {
              final catId = entry.key;
              final catName = entry.value['name'] ?? '';
              final resolvedImgUrl = _getCategoryImage(entry.value['image'] ?? '');
              return _buildCategoryChip(theme: theme, label: catName, imageUrl: resolvedImgUrl,
                isSelected: _bestSellerSelectedCategoryId == catId,
                onTap: () => setState(() => _bestSellerSelectedCategoryId = catId));
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip({
    required ThemeData theme, required String label, required String? imageUrl,
    required bool isSelected, required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(right: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 75, height: 75,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: isSelected ? theme.colorScheme.primary : Colors.white.withOpacity(0.8), width: 2.0),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))],
                  ),
                  child: ClipOval(
                    child: (imageUrl != null && imageUrl.isNotEmpty)
                        ? Image.network(imageUrl, fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => Container(
                              color: Colors.white.withOpacity(0.5),
                              child: Icon(_getCategoryIcon(label), size: 20, color: Colors.grey)))
                        : Container(
                            color: Colors.white,
                            child: Icon(_getCategoryIcon(label), size: 20, color: Colors.grey)),
                  ),
                ),
                const SizedBox(width: 10),
                Text(label, style: TextStyle(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? theme.colorScheme.primary : const Color(0xFF1E293B))),
              ],
            ),
            const SizedBox(height: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 2.5, width: isSelected ? 80.0 : 0.0,
              decoration: BoxDecoration(color: theme.colorScheme.primary, borderRadius: BorderRadius.circular(2)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBestSellerProductsScroll(ThemeData theme, bool isDesktop, List<dynamic> products) {
    if (products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_bag_outlined, size: 40, color: theme.colorScheme.primary.withOpacity(0.3)),
            const SizedBox(height: 10),
            const Text('No bestsellers in this category', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
          ],
        ),
      );
    }

    return Stack(
      alignment: Alignment.centerRight,
      children: [
        SizedBox(
          height: isDesktop ? 335 : 265,
          child: MouseRegion(
            onEnter: (_) => _bestSellersHovered = true,
            onExit: (_) => _bestSellersHovered = false,
            child: ListView.builder(
              controller: _bestSellerScrollController,
              scrollDirection: Axis.horizontal,
              itemCount: products.length > (isDesktop ? 4 : 2) ? 100000 : products.length,
              physics: products.length > (isDesktop ? 4 : 2) ? const BouncingScrollPhysics() : const NeverScrollableScrollPhysics(),
              itemBuilder: (context, index) {
                final item = products[index % products.length];
                return BestSellerProductCard(
                  item: item, theme: theme, isDesktop: isDesktop,
                  productImageUrl: _baseProductImageUrl,
                  productVariantImageUrl: _baseProductVariantImageUrl,
                  noImageUrl: _baseNoImageUrl,
                  baseProductImageUrl: _baseProductImageUrl,
                  baseProductVariantImageUrl: _baseProductVariantImageUrl,
                  baseNoImageUrl: _baseNoImageUrl,
                  onTap: (productForNav) {
                    final prodId = productForNav['id'];
                    var targetProduct = productForNav;
                    final catalogMatch = _allProducts.firstWhere(
                      (p) => p['id'] == prodId,
                      orElse: () => null,
                    );
                    if (catalogMatch != null) {
                      targetProduct = Map<String, dynamic>.from(catalogMatch);
                      targetProduct['total_sold'] = productForNav['total_sold'];
                      if (productForNav['selected_variant_id'] != null) {
                        targetProduct['selected_variant_id'] = productForNav['selected_variant_id'];
                      }
                    }
                    Navigator.push(context, MaterialPageRoute(
                      builder: (context) => ProductDetailScreen(product: targetProduct),
                    )).then((_) { CartManager.updateCartCount(); _loadCart(); });
                  },
                  onAddToCart: (product, selectedVariant) => _addToCartDirect(product, selectedVariant),
                );
              },
            ),
          ),
        ),
        Positioned(
          right: 4,
          child: GestureDetector(
            onTap: () {
              if (_bestSellerScrollController.hasClients) {
                final maxScroll = _bestSellerScrollController.position.maxScrollExtent;
                final target = (_bestSellerScrollController.offset + 250).clamp(0.0, maxScroll);
                _bestSellerScrollController.animateTo(target,
                  duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
              }
            },
            child: Container(
              width: 36, height: 36,
              decoration: const BoxDecoration(
                color: Colors.white, shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, spreadRadius: 1, offset: Offset(0, 2))],
              ),
              child: const Icon(Icons.chevron_right_rounded, color: Color(0xFF1E293B), size: 24),
            ),
          ),
        ),
      ],
    );
  }

  // ==================== SEARCH OVERLAY - FIXED (High Z-index, appears above bottom nav) ====================

  void _showSearchOverlay() {
    if (_searchOverlayEntry != null) return;
    
    double overlayWidth = 550;
    if (_searchKey.currentContext != null) {
      final renderBox = _searchKey.currentContext!.findRenderObject() as RenderBox?;
      if (renderBox != null) overlayWidth = renderBox.size.width;
    }
    
    _searchOverlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: overlayWidth,
        child: CompositedTransformFollower(
          link: _searchLayerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 48),
          child: Material(
            elevation: 20, // ✅ FIX: High elevation to appear above bottom nav
            borderRadius: BorderRadius.circular(14),
            color: Colors.white,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                constraints: const BoxConstraints(maxHeight: 350),
                decoration: const BoxDecoration(
                  color: Colors.white,
                ),
                child: _buildSearchDropdownContent(),
              ),
            ),
          ),
        ),
      ),
    );
    
    // ✅ FIX: Insert with high priority to appear above everything
    Overlay.of(context).insert(_searchOverlayEntry!);
  }

  void _hideSearchOverlay() {
    _searchOverlayEntry?.remove();
    _searchOverlayEntry = null;
  }

  String _getProductDisplayPrice(Map<String, dynamic> product) {
    if (product.containsKey('price') && product['price'] != null) {
      final val = double.tryParse(product['price'].toString()) ?? 0.0;
      if (val > 0) return val.toStringAsFixed(0);
    }
    final hasVar = (product['has_variants'] == 1 || product['has_variants'] == '1') &&
        product['variants'] != null && (product['variants'] as List).isNotEmpty;
    double pPrice = 0.0;
    if (hasVar) {
      final firstVar = (product['variants'] as List).first;
      final discPrice = double.tryParse(firstVar['product_discount_price']?.toString() ?? '') ?? 0.0;
      final regPrice = double.tryParse(firstVar['product_price']?.toString() ?? '') ?? 0.0;
      pPrice = discPrice > 0 ? discPrice : regPrice;
    }
    if (pPrice <= 0) {
      final discPrice = double.tryParse(product['product_discount_price']?.toString() ?? '') ?? 0.0;
      final regPrice = double.tryParse(product['product_price']?.toString() ?? '') ?? 0.0;
      pPrice = discPrice > 0 ? discPrice : (regPrice > 0 ? regPrice : double.tryParse(product['price']?.toString() ?? '') ?? 0.0);
    }
    return pPrice.toStringAsFixed(0);
  }

  String _getProductImage(Map<String, dynamic> product) {
    final hasVar = (product['has_variants'] == 1 || product['has_variants'] == '1') &&
        product['variants'] != null && (product['variants'] as List).isNotEmpty;
    if (hasVar) {
      final firstVar = (product['variants'] as List).first;
      final varImages = firstVar['images'];
      if (varImages != null && varImages is List && varImages.isNotEmpty) {
        final filename = varImages[0]['product_variant_images'];
        if (filename != null && filename.isNotEmpty) {
          return '$_baseProductVariantImageUrl$filename';
        }
      }
    }
    final images = product['images'];
    if (images != null && images is List && images.isNotEmpty) {
      final filename = images[0]['product_images'];
      if (filename != null && filename.isNotEmpty) {
        return '$_baseProductImageUrl$filename';
      }
    }
    return _baseNoImageUrl;
  }

  Widget _buildSearchDropdownContent() {
    if (_searchQuery.isNotEmpty) {
      final results = _allProducts.where((p) {
        final name = (p['product_name'] ?? p['name'] ?? '').toString().toLowerCase();
        return name.contains(_searchQuery.toLowerCase());
      }).toList();

      if (results.isEmpty) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.search_off_rounded, size: 32, color: Color(0xFF94A3B8)),
                ),
                const SizedBox(height: 12),
                const Text('No products found', style: TextStyle(color: Color(0xFF64748B), fontSize: 14)),
                const Text('Try searching with different keywords', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
              ],
            ),
          ),
        );
      }

      return ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: results.length,
        itemBuilder: (context, index) {
          final product = results[index];
          final name = product['product_name'] ?? product['name'] ?? 'Product';
          final price = _getProductDisplayPrice(product);
          final image = _getProductImage(product);
          
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(image, width: 44, height: 44, fit: BoxFit.cover,
                  errorBuilder: (c, e, s) => Container(
                    width: 44, height: 44,
                    color: const Color(0xFFF1F5F9),
                    child: const Icon(Icons.shopping_bag_outlined, size: 20, color: Color(0xFF94A3B8)),
                  ),
                ),
              ),
              title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
              subtitle: Text('₹$price',
                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
              onTap: () {
                _hideSearchOverlay();
                _searchFocusNode.unfocus();
                Navigator.push(context, MaterialPageRoute(
                  builder: (context) => ProductDetailScreen(product: product),
                ));
              },
            ),
          );
        },
      );
    }

    // Empty state - show trending categories and recommended products
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Trending Categories', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
          const SizedBox(height: 12),
          SizedBox(
            height: 70,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _categories.isNotEmpty
                  ? _categories.take(6).map<Widget>((cat) {
                      final name = cat['categories_name']?.toString() ?? 'Category';
                      final image = _getCategoryImage(cat['categories_image']);
                      return _buildSearchCategoryItem(name, image);
                    }).toList()
                  : [
                      _buildSearchCategoryItem('Cakes', 'https://agsdemo.in/singlemartapi/public/assets/images/no_image.jpg'),
                      _buildSearchCategoryItem('Bottles', 'https://agsdemo.in/singlemartapi/public/assets/images/no_image.jpg'),
                      _buildSearchCategoryItem('Accessories', 'https://agsdemo.in/singlemartapi/public/assets/images/no_image.jpg'),
                    ],
            ),
          ),
          const Divider(height: 24, thickness: 0.5, color: Color(0xFFE2E8F0)),
          const Text('Recommended Products', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
          const SizedBox(height: 10),
          SizedBox(
            height: 110,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _bestSellerProducts.take(5).map<Widget>((item) {
                final product = item['product'];
                if (product == null) return const SizedBox();
                final name = product['product_name'] ?? 'Product';
                final image = _getProductImage(product);
                final price = _getProductDisplayPrice(product);
                return _buildSearchProductItem(name, image, price, product);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchCategoryItem(String label, String imgUrl) {
    return GestureDetector(
      onTap: () {
        _searchController.text = label;
        _searchQuery = label;
        _searchFocusNode.requestFocus();
        setState(() {});
        _searchOverlayEntry?.markNeedsBuild();
      },
      child: Padding(
        padding: const EdgeInsets.only(right: 14),
        child: Column(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: ClipOval(
                child: Image.network(imgUrl, width: 44, height: 44, fit: BoxFit.cover,
                  errorBuilder: (c, e, s) => const Icon(Icons.category, size: 20, color: Color(0xFF94A3B8)),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF475569), fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchProductItem(String label, String imgUrl, String price, Map<String, dynamic> product) {
    return GestureDetector(
      onTap: () {
        _hideSearchOverlay();
        _searchFocusNode.unfocus();
        Navigator.push(context, MaterialPageRoute(
          builder: (context) => ProductDetailScreen(product: product),
        ));
      },
      child: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 80, height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: const Color(0xFFF1F5F9),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(imgUrl, width: 80, height: 60, fit: BoxFit.cover,
                  errorBuilder: (c, e, s) => const Icon(Icons.shopping_bag_outlined, size: 20, color: Color(0xFF94A3B8)),
                ),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 80,
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, color: Color(0xFF1E293B), fontWeight: FontWeight.w600)),
            ),
            Text('₹$price', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
          ],
        ),
      ),
    );
  }

  // ==================== MAIN BUILD ====================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 850;

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
        onStartShopping: () => setState(() => _currentTabIndex = 0),
      );
    } else {
      activeBody = ProfileScreen(
        isLoggedIn: _isLoggedIn,
        userData: _userData,
        token: _authToken,
        onLogout: _logout,
        onLoginSuccess: _loadSession,
        onRefreshProfile: _refreshProfileFromServerSilent,
      );
    }

    return PopScope(
      canPop: !_isSearchFocused && _searchQuery.isEmpty,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _searchController.clear();
        _searchFocusNode.unfocus();
        setState(() { _searchQuery = ''; _isSearchFocused = false; });
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFAFBFD),
        appBar: _buildAppBar(context, isDesktop, theme),
        body: _isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 60, height: 60,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const CircularProgressIndicator(strokeWidth: 3),
                    ),
                    const SizedBox(height: 20),
                    const Text('Loading...', style: TextStyle(fontSize: 14, color: AppColors.textLight)),
                  ],
                ),
              )
            : activeBody,
        bottomNavigationBar: isDesktop ? null : _buildMobileBottomNav(theme),
      ),
    );
  }

  // ==================== MOBILE BOTTOM NAV - FIXED (No SizedBox height constraint) ====================
  Widget _buildMobileBottomNav(ThemeData theme) {
    return BottomNavigationBar(
      currentIndex: _currentTabIndex,
      onTap: (index) => setState(() => _currentTabIndex = index),
      backgroundColor: Colors.white,
      elevation: 8,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.textLight,
      selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 10),
      iconSize: 22,
      items: [
        const BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home_rounded), label: 'Home'),
        const BottomNavigationBarItem(icon: Icon(Icons.grid_view_outlined), activeIcon: Icon(Icons.grid_view_rounded), label: 'Categories'),
        const BottomNavigationBarItem(icon: Icon(Icons.local_mall_outlined), activeIcon: Icon(Icons.local_mall_rounded), label: 'Products'),
        BottomNavigationBarItem(
          icon: ValueListenableBuilder<int>(
            valueListenable: CartManager.cartCountNotifier,
            builder: (context, count, child) => Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.shopping_cart_outlined),
                if (count > 0)
                  Positioned(
                    top: -4, right: -6,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                      constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                      child: Text('$count', style: const TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                    ),
                  ),
              ],
            ),
          ),
          activeIcon: ValueListenableBuilder<int>(
            valueListenable: CartManager.cartCountNotifier,
            builder: (context, count, child) => Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.shopping_cart_rounded),
                if (count > 0)
                  Positioned(
                    top: -4, right: -6,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                      constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                      child: Text('$count', style: const TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                    ),
                  ),
              ],
            ),
          ),
          label: 'Cart',
        ),
        const BottomNavigationBarItem(icon: Icon(Icons.person_outline_rounded), activeIcon: Icon(Icons.person_rounded), label: 'Profile'),
      ],
    );
  }

  // ==================== DASHBOARD BODY ====================

  Widget _buildDashboardBody(ThemeData theme, bool isDesktop) {
    if (isDesktop) return _buildDesktopDashboardBody(theme);

    final filteredProducts = _allProducts.where((p) {
      final matchesSearch = _searchQuery.isEmpty ||
          p['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p['desc'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesSearch;
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadCatalog,
      child: SingleChildScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: double.infinity),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_searchQuery.isEmpty && !_isSearchFocused)
                      RepaintBoundary(child: _buildBannerSlider(theme)),
                    _buildMobileSearchBar(theme),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SizeTransition(sizeFactor: animation, axisAlignment: -1.0, child: child),
                      ),
                      child: (_searchQuery.isNotEmpty || _isSearchFocused)
                          ? KeyedSubtree(
                              key: const ValueKey('suggestions_view'),
                              child: RepaintBoundary(child: _buildSearchSuggestionsList(theme, filteredProducts)),
                            )
                          : Column(
                              key: const ValueKey('default_view'),
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                RepaintBoundary(child: _buildBestSellersSection(theme, false)),
                                _buildCategorySection(theme),
                                _buildOfferBannerSlider(theme, false),
                                RepaintBoundary(child: _buildProductGrid(theme, filteredProducts)),
                              ],
                            ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  // ==================== MOBILE SEARCH BAR - FIXED (No duplicate border) ====================
  Widget _buildMobileSearchBar(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        onTap: () => _scrollController.animateTo(0.0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut),
        onChanged: (val) => setState(() => _searchQuery = val),
        decoration: InputDecoration(
          hintText: 'Search products...',
          prefixIcon: (_isSearchFocused || _searchQuery.isNotEmpty)
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
                  onPressed: () {
                    _searchController.clear();
                    _searchFocusNode.unfocus();
                    setState(() { _searchQuery = ''; _isSearchFocused = false; });
                  },
                )
              : const Icon(Icons.search, color: AppColors.textLight),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: AppColors.textLight),
                  onPressed: () { _searchController.clear(); setState(() => _searchQuery = ''); },
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          // ✅ FIX: Only enabledBorder + focusedBorder - NO duplicate border
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14), 
            borderSide: const BorderSide(color: AppColors.border)
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
          ),
          // ⚠️ NO 'border' property here - that causes duplicate rectangle!
        ),
      ),
    );
  }

  Widget _buildCategorySection(ThemeData theme) {
    if (_categories.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Categories', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (context) => CategoriesListScreen(categories: _categories))),
                child: Text('View All', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
              ),
            ],
          ),
        ),
        RepaintBoundary(
          child: SizedBox(
            height: 110,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final imageUrl = _getCategoryImage(cat['categories_image']);
                return GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (context) => ProductsListScreen(
                      categoryId: cat['id'],
                      subcategoryName: cat['categories_name'] ?? 'Category',
                    ),
                  )),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(3),
                          child: ClipOval(
                            child: Image.network(imageUrl, width: 54, height: 54, fit: BoxFit.cover,
                              cacheWidth: 120, cacheHeight: 120,
                              errorBuilder: (context, error, stackTrace) => Container(
                                width: 54, height: 54,
                                color: theme.colorScheme.primary.withOpacity(0.05),
                                child: Icon(_getCategoryIcon(cat['categories_name'] ?? ''),
                                  color: theme.colorScheme.primary, size: 24),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: 80,
                          child: Text(cat['categories_name'] ?? 'Category', textAlign: TextAlign.center,
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProductGrid(ThemeData theme, List<dynamic> products) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Featured Products', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProductsListScreen())),
                child: Text('View All', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
              ),
            ],
          ),
        ),
        products.isEmpty
            ? _buildEmptyProductState()
            : RepaintBoundary(
                child: GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.72,
                  ),
                  itemCount: products.length,
                  itemBuilder: (context, index) => _buildProductCard(products[index], theme),
                ),
              ),
      ],
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
              decoration: BoxDecoration(color: AppColors.border.withOpacity(0.3), shape: BoxShape.circle),
              child: const Icon(Icons.search_off_rounded, size: 48, color: AppColors.textLight),
            ),
            const SizedBox(height: 16),
            const Text('No product found', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 16)),
            const SizedBox(height: 6),
            const Text('Try searching for something else.', style: TextStyle(color: AppColors.textLight, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  // ==================== DESKTOP DASHBOARD ====================

  Widget _buildDesktopDashboardBody(ThemeData theme) {
    return RefreshIndicator(
      onRefresh: _loadCatalog,
      child: SingleChildScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Mega Menu Row
            _buildDesktopCategoryMenuRow(theme),
            
            // Mega Menu + Content Stack
            Stack(
              clipBehavior: Clip.none,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Horizontal Category Scroll
                    _buildDesktopCircularCategories(theme),
                    
                    RepaintBoundary(child: _buildBannerSlider(theme)),
                    const SizedBox(height: 24),
                    
                    // Best Sellers Section
                    RepaintBoundary(child: _buildBestSellersSection(theme, true)),
                    const SizedBox(height: 24),
                    
                    RepaintBoundary(child: _buildDesktopCategorySections(theme)),
                    const SizedBox(height: 48),
                  ],
                ),
                
                // Mega Menu Overlay
                Positioned(
                  top: 0,
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
            
            _buildDesktopBrandsSection(theme),
            _buildDesktopFooter(theme),
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
              final String catName = cat['categories_name'] ?? 'Category';

              return MouseRegion(
                onEnter: (_) {
                  _cancelMenuCloseTimer();
                  _activeCategoryId.value = catId;
                  _hoveredCategoryIndex.value = index;
                },
                onExit: (_) => _startMenuCloseTimer(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: InkWell(
                    onTap: () {
                      _activeCategoryId.value = null;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProductsListScreen(
                            categoryId: catId,
                            subcategoryName: catName,
                          ),
                        ),
                      );
                    },
                    child: ValueListenableBuilder<int?>(
                      valueListenable: _hoveredCategoryIndex,
                      builder: (context, hoveredIndex, child) {
                        final bool isHovered = hoveredIndex == index;
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              catName,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isHovered ? FontWeight.bold : FontWeight.w600,
                                color: isHovered ? theme.colorScheme.primary : AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 14,
                              color: isHovered ? theme.colorScheme.primary : AppColors.textLight,
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopCircularCategories(ThemeData theme) {
    if (_categories.isEmpty) return const SizedBox.shrink();
    
    return RepaintBoundary(
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_categories.length, (index) {
                final cat = _categories[index];
                final int id = cat['id'];
                final String imageUrl = _getCategoryImage(cat['categories_image']);
                final String name = cat['categories_name'] ?? 'Category';
       
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProductsListScreen(
                            categoryId: id,
                            subcategoryName: name,
                          ),
                        ),
                      );
                    },
                    child: Column(
                      children: [
                        Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFF8FAFC),
                            border: Border.all(
                              color: theme.colorScheme.secondary.withOpacity(0.3),
                              width: 2.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(4),
                          child: ClipOval(
                            child: Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              cacheWidth: 150,
                              cacheHeight: 150,
                              errorBuilder: (c, e, s) => Icon(
                                _getCategoryIcon(name),
                                color: theme.colorScheme.primary,
                                size: 40,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopCategorySections(ThemeData theme) {
    if (_categories.isEmpty) return const SizedBox.shrink();

    final frontCategories = _categories.where((cat) {
      final inFront = cat['categories_inFront'];
      return inFront == '1' || inFront == 1;
    }).toList();

    if (frontCategories.isEmpty) return const SizedBox.shrink();

    final List<Widget> children = [];
    int visibleCount = 0;

    for (int idx = 0; idx < frontCategories.length; idx++) {
      final cat = frontCategories[idx];
      final int catId = cat['id'];
      final String catName = cat['categories_name'] ?? 'Category';
      final String catImage = _getCategoryImage(cat['categories_image']);
      
      final List<dynamic> catProducts = _allProducts.where((p) => p['category_id'] == catId).take(15).toList();
      if (catProducts.isEmpty) continue;

      visibleCount++;

      children.add(
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border, width: 1),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 16, offset: const Offset(0, 4))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(width: 4, height: 20,
                          decoration: BoxDecoration(color: theme.colorScheme.primary, borderRadius: BorderRadius.circular(2))),
                        const SizedBox(width: 10),
                        Text(catName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      ],
                    ),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(
                        builder: (context) => ProductsListScreen(categoryId: catId, subcategoryName: catName))),
                      icon: Icon(Icons.arrow_forward_rounded, size: 14, color: theme.colorScheme.primary),
                      label: Text('View All', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: theme.colorScheme.primary, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildCategoryBanner(theme, catName, catImage),
                    const SizedBox(width: 20),
                    Expanded(
                      child: SizedBox(
                        height: 270,
                        child: MouseRegion(
                          onEnter: (_) => _categoriesHovered[catId] = true,
                          onExit: (_) => _categoriesHovered[catId] = false,
                          child: GridView.builder(
                            controller: _categoryScrollControllers[catId],
                            physics: catProducts.length > 3 ? const BouncingScrollPhysics() : const NeverScrollableScrollPhysics(),
                            scrollDirection: Axis.horizontal,
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 1,
                              mainAxisSpacing: 16,
                              childAspectRatio: 1.22,
                            ),
                            itemCount: catProducts.length > 3 ? 100000 : catProducts.length,
                            itemBuilder: (context, index) {
                              final prod = catProducts[index % catProducts.length];
                              return BestSellerProductCard(
                                item: {"product": prod},
                                theme: theme,
                                isDesktop: true,
                                showBestsellerBadge: false,
                                showVariants: false,
                                productImageUrl: _baseProductImageUrl,
                                productVariantImageUrl: _baseProductVariantImageUrl,
                                noImageUrl: _baseNoImageUrl,
                                baseProductImageUrl: _baseProductImageUrl,
                                baseProductVariantImageUrl: _baseProductVariantImageUrl,
                                baseNoImageUrl: _baseNoImageUrl,
                                onTap: (productForNav) {
                                  Navigator.push(context, MaterialPageRoute(
                                    builder: (context) => ProductDetailScreen(product: productForNav),
                                  )).then((_) { CartManager.updateCartCount(); _loadCart(); });
                                },
                                onAddToCart: (product, selectedVariant) => _addToCartDirect(product, selectedVariant),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

      if (visibleCount == 2) {
        children.add(RepaintBoundary(child: _buildOfferBannerSlider(theme, true)));
      }
    }

    if (visibleCount == 1) {
      children.add(RepaintBoundary(child: _buildOfferBannerSlider(theme, true)));
    }

    return Column(
      children: children,
    );
  }

  Widget _buildCategoryBanner(ThemeData theme, String catName, String catImage) {
    return Container(
      width: 250,
      height: 380,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.network(catImage, fit: BoxFit.cover, cacheWidth: 350,
                errorBuilder: (c, e, s) => Container(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  child: Icon(Icons.broken_image, size: 48, color: theme.colorScheme.primary)),
              ),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(catName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  const Text('Special Deals', style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== BRANDS SECTION ====================

  Widget _buildDesktopBrandsSection(ThemeData theme) {
    if (_brands.isEmpty) return const SizedBox.shrink();
    const baseBrandImageUrl = 'https://agsdemo.in/singlemartapi/public/assets/images/brand_images/';

    return Container(
      width: double.infinity,
      color: const Color(0xFFF8F9FF),
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Row(
              children: [
                Container(width: 4, height: 24,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [theme.colorScheme.primary, theme.colorScheme.secondary]),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                const Text('Shop by Brands', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => setState(() => _currentTabIndex = 1),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                  label: const Text('View All'),
                  style: TextButton.styleFrom(foregroundColor: theme.colorScheme.primary, textStyle: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 36),
          SizedBox(
            height: 150,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 32),
              itemCount: _brands.length,
              itemBuilder: (context, index) {
                final brand = _brands[index];
                final name = brand['brands_name'] ?? brand['brand_name'] ?? 'Brand';
                final imgFile = brand['brands_image'] ?? brand['brand_image'];
                final imgUrl = (imgFile != null && imgFile.isNotEmpty) ? '$baseBrandImageUrl$imgFile' : '';

                return MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () {},
                    child: Container(
                      width: 120,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Container(
                            width: 90, height: 90,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: theme.colorScheme.primary.withOpacity(0.08), blurRadius: 16, offset: const Offset(0, 6))],
                            ),
                            padding: const EdgeInsets.all(18),
                            child: imgUrl.isNotEmpty
                                ? Image.network(imgUrl, fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => _buildBrandInitialAvatar(name, theme))
                                : _buildBrandInitialAvatar(name, theme),
                          ),
                          const SizedBox(height: 14),
                          Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                            maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandInitialAvatar(String name, ThemeData theme) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'B';
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [theme.colorScheme.primary.withOpacity(0.12), theme.colorScheme.secondary.withOpacity(0.12)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(initial, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: theme.colorScheme.primary)),
      ),
    );
  }

  // ==================== SEARCH SUGGESTIONS ====================

  Widget _buildSearchSuggestionsList(ThemeData theme, List<dynamic> matchedProducts) {
    final isQueryEmpty = _searchQuery.isEmpty;

    if (isQueryEmpty) {
      final recommendedProducts = _allProducts.take(10).toList();
      if (recommendedProducts.isEmpty) return const SizedBox.shrink();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Text('Recommended for You', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary))),
          SizedBox(
            height: 185,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: recommendedProducts.length,
              itemBuilder: (context, index) => _buildRecommendedProductCard(recommendedProducts[index], theme),
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
                decoration: BoxDecoration(color: AppColors.border.withOpacity(0.3), shape: BoxShape.circle),
                child: const Icon(Icons.search_off_rounded, size: 48, color: AppColors.textLight),
              ),
              const SizedBox(height: 16),
              const Text('No matching products found', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 16)),
              const SizedBox(height: 6),
              const Text('Try searching for something else.', style: TextStyle(color: AppColors.textLight, fontSize: 13)),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(padding: EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Text('Search Results', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textLight))),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: matchedProducts.length,
          itemBuilder: (context, index) {
            final prod = matchedProducts[index];
            final imageUrl = _getProductImage(prod);
            return Container(
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border, width: 0.8))),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(imageUrl, width: 36, height: 36, fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 36, height: 36,
                      color: theme.colorScheme.primary.withOpacity(0.05),
                      child: Icon(_getCategoryIcon(prod['image'] ?? ''), color: theme.colorScheme.primary, size: 20)),
                  ),
                ),
                title: _buildHighlightedText(prod['name'] ?? 'Product Name', _searchQuery,
                  const TextStyle(fontSize: 13.0, color: AppColors.textLight, fontWeight: FontWeight.normal),
                  const TextStyle(fontSize: 13.0, color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 2.0),
                  child: Text("₹${(prod['price'] is num ? prod['price'] : double.tryParse(prod['price']?.toString() ?? '0') ?? 0.0).toStringAsFixed(2)}",
                    style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary, fontSize: 12)),
                ),
                trailing: const Icon(Icons.call_made_rounded, color: AppColors.textMuted, size: 16),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (context) => ProductDetailScreen(product: prod),
                  )).then((_) { CartManager.updateCartCount(); _loadCart(); });
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildRecommendedProductCard(dynamic prod, ThemeData theme) {
    final imageUrl = _getProductImage(prod);
    final price = prod['price'] is num ? (prod['price'] as num).toDouble() : double.tryParse(prod['price']?.toString() ?? '0') ?? 0.0;

    return Container(
      width: 130,
      margin: const EdgeInsets.only(right: 12, bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1.0),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 3))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(context, MaterialPageRoute(
              builder: (context) => ProductDetailScreen(product: prod),
            )).then((_) { CartManager.updateCartCount(); _loadCart(); });
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(color: theme.colorScheme.primary.withOpacity(0.05)),
                  child: Image.network(imageUrl, fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Center(
                      child: Icon(_getCategoryIcon(prod['image'] ?? ''), color: theme.colorScheme.primary, size: 32)),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(prod['name'] ?? 'Product Name', maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    const SizedBox(height: 4),
                    Text("₹${price.toStringAsFixed(2)}", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: theme.colorScheme.primary)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHighlightedText(String text, String query, TextStyle baseStyle, TextStyle highlightStyle) {
    if (query.isEmpty) {
      return Text(text, style: baseStyle, maxLines: 1, overflow: TextOverflow.ellipsis);
    }
    final textLower = text.toLowerCase();
    final queryLower = query.toLowerCase();
    final startIndex = textLower.indexOf(queryLower);
    if (startIndex == -1) {
      return Text(text, style: baseStyle, maxLines: 1, overflow: TextOverflow.ellipsis);
    }
    final endIndex = startIndex + query.length;

    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: baseStyle,
        children: [
          if (startIndex > 0) TextSpan(text: text.substring(0, startIndex)),
          TextSpan(text: text.substring(startIndex, endIndex), style: highlightStyle),
          if (endIndex < text.length) TextSpan(text: text.substring(endIndex)),
        ],
      ),
    );
  }

  // ==================== PRODUCT CARD ====================

  Widget _buildProductCard(Map<String, dynamic> product, ThemeData theme) {
    final imageUrl = _getProductImage(product);
    final price = product['price'] is num ? (product['price'] as num).toDouble() : double.tryParse(product['price']?.toString() ?? '0') ?? 0.0;
    final originalPrice = product['original_price'] is num ? (product['original_price'] as num).toDouble() : null;
    final hasDiscount = originalPrice != null && originalPrice > price;
    final brandName = _getBrandName(product['brand_id']);
    final prodName = product['name'] ?? 'Product Name';

    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(
          builder: (context) => ProductDetailScreen(product: product),
        )).then((_) { CartManager.updateCartCount(); _loadCart(); });
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Image.network(imageUrl, fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: theme.colorScheme.primary.withOpacity(0.05),
                            child: Icon(_getCategoryIcon(product['image'] ?? ''), size: 40, color: theme.colorScheme.primary)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: RichText(
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                style: const TextStyle(fontSize: 13.0, height: 1.2),
                children: [
                  if (brandName.isNotEmpty)
                    TextSpan(text: '$brandName ', style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                  TextSpan(text: prodName, style: const TextStyle(fontWeight: FontWeight.w500, color: AppColors.textLight)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                if (hasDiscount) ...[
                  Text(_formatNumber(originalPrice.round()), style: const TextStyle(fontSize: 12, color: AppColors.textLight, decoration: TextDecoration.lineThrough)),
                  const SizedBox(width: 6),
                ],
                Text("₹${_formatNumber(price.round())}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
              ],
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  // ==================== FOOTER ====================

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
                            decoration: InputDecoration(hintText: 'Enter your email address', hintStyle: TextStyle(fontSize: 13, color: Colors.grey)),
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
                      _buildFooterLink('Home', () => setState(() => _currentTabIndex = 0)),
                      _buildFooterLink('All Categories', () => setState(() => _currentTabIndex = 1)),
                      _buildFooterLink('Featured Products', () => setState(() => _currentTabIndex = 2)),
                      _buildFooterLink('My Cart', () => setState(() => _currentTabIndex = 3)),
                      _buildFooterLink('My Profile', () {
                        if (_isLoggedIn) {
                          setState(() => _currentTabIndex = 4);
                        } else {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginScreen()))
                              .then((_) => _loadSession());
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

  Widget _buildSocialIcon(IconData icon, String url) {
    return InkWell(
      onTap: () => _launchUrl(url),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}

// ==================== BEST SELLER PRODUCT CARD ====================

class BestSellerProductCard extends StatefulWidget {
  final Map<String, dynamic> item;
  final ThemeData theme;
  final bool isDesktop;
  final String productImageUrl;
  final String productVariantImageUrl;
  final String noImageUrl;
  final String baseProductImageUrl;
  final String baseProductVariantImageUrl;
  final String baseNoImageUrl;
  final Function(Map<String, dynamic> productForNav) onTap;
  final Future<void> Function(Map<String, dynamic> product, Map<String, dynamic>? selectedVariant) onAddToCart;
  final bool showBestsellerBadge;
  final bool showVariants;

  const BestSellerProductCard({
    super.key,
    required this.item,
    required this.theme,
    required this.isDesktop,
    required this.productImageUrl,
    required this.productVariantImageUrl,
    required this.noImageUrl,
    required this.baseProductImageUrl,
    required this.baseProductVariantImageUrl,
    required this.baseNoImageUrl,
    required this.onTap,
    required this.onAddToCart,
    this.showBestsellerBadge = true,
    this.showVariants = true,
  });

  @override
  State<BestSellerProductCard> createState() => _BestSellerProductCardState();
}

class _BestSellerProductCardState extends State<BestSellerProductCard> {
  bool _isHovered = false;
  int _currentImageIndex = 0;
  Timer? _imageCycleTimer;
  int _selectedVariantIndex = 0;
  List<String> _imageUrls = [];

  String _formatNumber(int number) {
    final str = number.toString();
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return str.replaceAllMapped(reg, (Match m) => "${m[1]},");
  }

  @override
  void initState() {
    super.initState();
    _updateImageUrls();
  }

  @override
  void didUpdateWidget(covariant BestSellerProductCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateImageUrls();
  }

  @override
  void dispose() {
    _imageCycleTimer?.cancel();
    super.dispose();
  }

  void _updateImageUrls() {
    final product = widget.item['product'];
    if (product == null) { _imageUrls = [widget.baseNoImageUrl]; return; }

    final urls = <String>[];
    
    final rootVariant = widget.item['variant'];
    final variants = product['variants'];
    final hasVar = (product['has_variants'] == 1 || product['has_variants'] == '1') &&
        ((variants != null && variants is List && variants.isNotEmpty) || rootVariant != null);

    Map<String, dynamic>? activeVar;
    if (rootVariant != null) {
      activeVar = Map<String, dynamic>.from(rootVariant);
    } else if (variants != null && variants is List && variants.isNotEmpty && _selectedVariantIndex < variants.length) {
      activeVar = Map<String, dynamic>.from(variants[_selectedVariantIndex]);
    }

    if (activeVar != null) {
      final varImages = activeVar['images'];
      if (varImages is List && varImages.isNotEmpty) {
        final baseVarUrl = widget.productVariantImageUrl.isNotEmpty ? widget.productVariantImageUrl : widget.baseProductVariantImageUrl;
        for (var img in varImages) {
          final filename = img['product_variant_images'];
          if (filename != null && filename.isNotEmpty) urls.add('$baseVarUrl$filename');
        }
      }
    }

    final prodImages = product['images'];
    if (prodImages is List && prodImages.isNotEmpty) {
      final baseUrl = widget.productImageUrl.isNotEmpty ? widget.productImageUrl : widget.baseProductImageUrl;
      for (var img in prodImages) {
        final filename = img['product_images'];
        if (filename != null && filename.isNotEmpty) urls.add('$baseUrl$filename');
      }
    }

    if (urls.isEmpty) urls.add(widget.noImageUrl.isNotEmpty ? widget.noImageUrl : widget.baseNoImageUrl);
    _imageUrls = urls;
    if (_currentImageIndex >= _imageUrls.length) _currentImageIndex = 0;
  }

  void _startImageCycling() {
    _imageCycleTimer?.cancel();
    if (_imageUrls.length > 1) {
      _imageCycleTimer = Timer.periodic(const Duration(milliseconds: 1200), (timer) {
        if (mounted) setState(() => _currentImageIndex = (_currentImageIndex + 1) % _imageUrls.length);
      });
    }
  }

  void _stopImageCycling() {
    _imageCycleTimer?.cancel();
    if (mounted) setState(() => _currentImageIndex = 0);
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.item['product'];
    if (product == null) return const SizedBox.shrink();

    final name = product['product_name'] ?? 'Product';
    final shortDesc = product['product_short_description'] ?? '';
    final totalSold = widget.item['total_sold']?.toString() ?? '0';

    final rootVariant = widget.item['variant'];
    final variants = product['variants'];
    final hasVar = (product['has_variants'] == 1 || product['has_variants'] == '1') &&
        ((variants != null && variants is List && variants.isNotEmpty) || rootVariant != null);

    dynamic activePriceSource = product;
    Map<String, dynamic>? selectedVar;
    if (rootVariant != null) {
      selectedVar = Map<String, dynamic>.from(rootVariant);
      activePriceSource = selectedVar;
    } else if (variants != null && variants is List && variants.isNotEmpty && _selectedVariantIndex < variants.length) {
      selectedVar = Map<String, dynamic>.from(variants[_selectedVariantIndex]);
      activePriceSource = selectedVar;
    }

    final originalPrice = double.tryParse(activePriceSource['product_price']?.toString() ?? '0') ?? 0.0;
    final discountPrice = double.tryParse(activePriceSource['product_discount_price']?.toString() ?? '0') ?? 0.0;
    final displayPrice = (discountPrice > 0 && discountPrice < originalPrice) ? discountPrice : originalPrice;
    final hasDiscount = discountPrice > 0 && discountPrice < originalPrice;
    final discountPercent = hasDiscount ? (((originalPrice - discountPrice) / originalPrice) * 100).round() : 0;

    final categoryName = product['category']?['categories_name'] ?? '';
    final subCategoryName = product['categories_subs_name'] ?? product['sub_category']?['categories_subs_name'] ?? '';
    final displayCategory = categoryName.isNotEmpty && subCategoryName.isNotEmpty
        ? '$categoryName • $subCategoryName'
        : (categoryName.isNotEmpty ? categoryName : (subCategoryName.isNotEmpty ? subCategoryName : 'General'));
    final cardWidth = widget.isDesktop ? 220.0 : 170.0;

    final productForNav = Map<String, dynamic>.from(product);
    productForNav['name'] = name;
    productForNav['desc'] = shortDesc;
    productForNav['price'] = displayPrice;
    productForNav['original_price'] = hasDiscount ? originalPrice : 0.0;
    productForNav['category_id'] = product['product_category_id'];
    productForNav['subcategory_id'] = product['product_sub_category_id'];
    productForNav['brand_id'] = product['product_brand_id'];
    productForNav['product_vendor_id'] = product['product_vendor_id'];
    if (selectedVar != null) {
      productForNav['selected_variant_id'] = selectedVar['id'];
    }

    final currentImgUrl = _imageUrls[_currentImageIndex];

    return MouseRegion(
      onEnter: (_) { setState(() => _isHovered = true); _startImageCycling(); },
      onExit: (_) { setState(() => _isHovered = false); _stopImageCycling(); },
      child: Container(
        width: cardWidth,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 12,
              child: ClipRRect(
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: GestureDetector(
                        onTap: () => widget.onTap(productForNav),
                        child: Image.network(currentImgUrl, fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => Container(
                            color: Colors.grey.shade100,
                            child: Icon(Icons.broken_image_rounded, size: 36, color: Colors.grey.shade400)),
                        ),
                      ),
                    ),
                    if (widget.showBestsellerBadge)
                      Positioned(
                        left: 8, top: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(color: const Color(0xFF7C3AED), borderRadius: BorderRadius.circular(4)),
                          child: const Text('Bestseller', style: TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    if (_isHovered && _imageUrls.length > 1)
                      Positioned(
                        bottom: 8, left: 0, right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(_imageUrls.length, (dotIdx) {
                            final isActive = dotIdx == _currentImageIndex;
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              width: isActive ? 6 : 4, height: isActive ? 6 : 4,
                              decoration: BoxDecoration(
                                color: isActive ? Colors.white : Colors.white.withOpacity(0.5),
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                    GestureDetector(
                      onTap: () => widget.onTap(productForNav),
                      child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (hasVar && widget.showVariants && rootVariant == null)
                          Text('${variants?.length ?? 0} Variants', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: widget.theme.colorScheme.primary))
                        else
                          Text(displayCategory, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                        if (widget.showBestsellerBadge)
                          Text('$totalSold sold', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.grey.shade500)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (shortDesc.isNotEmpty && !(hasVar && widget.showVariants && rootVariant == null)) ...[
                      Text(shortDesc, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 9.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                    ],
                    if (rootVariant != null) ...[
                      _buildStaticAttributeChips(rootVariant['attribute_values'] ?? []),
                      const SizedBox(height: 2),
                    ] else if (hasVar && widget.showVariants && variants != null) ...[
                      _buildVariantChipsRow(variants),
                      const SizedBox(height: 2),
                    ],
                    const SizedBox(height: 2),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 150),
                      child: (_isHovered && widget.isDesktop)
                          ? Row(
                              key: const ValueKey('hover_buttons'),
                              children: [
                                Expanded(
                                  child: SizedBox(
                                    height: 30,
                                    child: ElevatedButton(
                                      onPressed: () => widget.onAddToCart(product, selectedVar),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: widget.theme.colorScheme.primary,
                                        padding: EdgeInsets.zero,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                        elevation: 1,
                                      ),
                                      child: const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.shopping_cart_outlined, size: 12, color: Colors.white),
                                          SizedBox(width: 4),
                                          Text('ADD TO CART', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.white)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                SizedBox(
                                  width: 40, height: 30,
                                  child: OutlinedButton(
                                    onPressed: () => widget.onTap(productForNav),
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(color: widget.theme.colorScheme.primary, width: 1.5),
                                      padding: EdgeInsets.zero,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                    ),
                                    child: Icon(Icons.visibility_outlined, size: 14, color: widget.theme.colorScheme.primary),
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              key: const ValueKey('pricing_row'),
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text('₹${_formatNumber(displayPrice.round())}',
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                                if (hasDiscount) ...[
                                  const SizedBox(width: 4),
                                  Text('₹${_formatNumber(originalPrice.round())}',
                                    style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), decoration: TextDecoration.lineThrough)),
                                  const SizedBox(width: 4),
                                  Text('$discountPercent% OFF',
                                    style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                                ],
                                const Spacer(),
                                if (!widget.isDesktop)
                                  GestureDetector(
                                    onTap: () => widget.onAddToCart(product, selectedVar),
                                    child: Container(
                                      padding: const EdgeInsets.all(5),
                                      decoration: BoxDecoration(
                                        color: widget.theme.colorScheme.primary,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Icon(Icons.add_shopping_cart_rounded, size: 14, color: Colors.white),
                                    ),
                                  ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ],
        ),
      ),
    );
  }

  Widget _buildVariantChipsRow(List<dynamic> list) {
    return SizedBox(
      height: 20,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: list.length,
        itemBuilder: (context, idx) {
          final v = list[idx];
          final attrs = v['attributes'];
          String label = 'V${idx + 1}';
          if (attrs != null && attrs.isNotEmpty) {
            label = attrs[0]['attribute_value']?.toString() ?? label;
          }
          final isSelected = _selectedVariantIndex == idx;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedVariantIndex = idx;
                _updateImageUrls();
              });
            },
            child: Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? widget.theme.colorScheme.primary.withOpacity(0.12) : Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: isSelected ? widget.theme.colorScheme.primary : Colors.grey.shade300, width: 1),
              ),
              child: Center(
                child: Text(label, style: TextStyle(
                  fontSize: 9,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? widget.theme.colorScheme.primary : const Color(0xFF475569),
                )),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStaticAttributeChips(List<dynamic> list) {
    if (list.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 20,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: list.length,
        itemBuilder: (context, idx) {
          final attr = list[idx];
          final String label = attr['attribute_value']?.toString() ?? '';
          if (label.isEmpty) return const SizedBox.shrink();
          return Container(
            margin: const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
            ),
            child: Center(
              child: Text(label, style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: Color(0xFF475569),
              )),
            ),
          );
        },
      ),
    );
  }
}