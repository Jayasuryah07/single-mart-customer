import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/cart_screen.dart';
import '../theme.dart';

class CartManager {
  static final ValueNotifier<int> cartCountNotifier = ValueNotifier<int>(0);

  /// Dynamically computes a unique storage key based on the logged-in user's profile ID
  static Future<String> getCartKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? userStr = prefs.getString('user_data');
      if (userStr != null && userStr.isNotEmpty) {
        final Map<String, dynamic> userData = json.decode(userStr);
        final String userId = userData['id']?.toString() ?? '';
        if (userId.isNotEmpty) {
          return 'cart_user_$userId';
        }
      }
    } catch (_) {}
    return 'cart_guest';
  }

  /// Retrieve cart data using the active user-scoped key
  static Future<String?> getCartData() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await getCartKey();
    return prefs.getString(key);
  }

  /// Save cart data using the active user-scoped key and refresh global count badges
  static Future<void> setCartData(String data) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await getCartKey();
    await prefs.setString(key, data);
    await updateCartCount();
  }

  /// Clear the current user-scoped cart
  static Future<void> clearCart() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await getCartKey();
    await prefs.remove(key);
    await updateCartCount();
  }

  /// Migrates guest cart items to the logged-in user's cart on successful login
  static Future<void> migrateGuestCartToUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? guestCartStr = prefs.getString('cart_guest');
      if (guestCartStr != null && guestCartStr.isNotEmpty) {
        final List<dynamic> guestItems = json.decode(guestCartStr);
        if (guestItems.isNotEmpty) {
          final String userKey = await getCartKey();
          if (userKey != 'cart_guest') {
            final String? userCartStr = prefs.getString(userKey);
            List<dynamic> userItems = [];
            if (userCartStr != null && userCartStr.isNotEmpty) {
              userItems = json.decode(userCartStr);
            }
            
            for (var gItem in guestItems) {
              final int existingIndex = userItems.indexWhere((uItem) =>
                  uItem['id'] == gItem['id'] &&
                  uItem['variant_id'] == gItem['variant_id']);
              if (existingIndex != -1) {
                userItems[existingIndex]['quantity'] =
                    (userItems[existingIndex]['quantity'] ?? 1) +
                        (gItem['quantity'] ?? 1);
              } else {
                userItems.add(gItem);
              }
            }
            
            await prefs.setString(userKey, json.encode(userItems));
            await prefs.remove('cart_guest'); // Clear guest cart
          }
        }
      }
      await updateCartCount();
    } catch (_) {}
  }

  /// Synchronize the globally visible cart count badge with local SharedPreferences data
  static Future<void> updateCartCount() async {
    try {
      final cartStr = await getCartData();
      if (cartStr != null && cartStr.isNotEmpty) {
        final List<dynamic> parsed = json.decode(cartStr);
        int totalQuantity = 0;
        for (var item in parsed) {
          final int qty = item['quantity'] is int 
              ? item['quantity'] 
              : int.tryParse(item['quantity']?.toString() ?? '1') ?? 1;
          totalQuantity += qty;
        }
        cartCountNotifier.value = totalQuantity;
      } else {
        cartCountNotifier.value = 0;
      }
    } catch (e) {
      cartCountNotifier.value = 0;
    }
  }
}

class CartButton extends StatefulWidget {
  final Color? color;
  const CartButton({super.key, this.color});

  @override
  State<CartButton> createState() => _CartButtonState();
}

class _CartButtonState extends State<CartButton> {
  @override
  void initState() {
    super.initState();
    CartManager.updateCartCount();
  }

  @override
  Widget build(BuildContext context) {
    final buttonColor = widget.color ?? AppColors.textPrimary;

    return ValueListenableBuilder<int>(
      valueListenable: CartManager.cartCountNotifier,
      builder: (context, count, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: Icon(Icons.shopping_cart_outlined, color: buttonColor),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CartScreen()),
                ).then((_) {
                  // Reload count when coming back
                  CartManager.updateCartCount();
                });
              },
            ),
            if (count > 0)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Center(
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        fontSize: 9,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
