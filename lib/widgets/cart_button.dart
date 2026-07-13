import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/cart_screen.dart';
import '../theme.dart';

class CartManager {
  static final ValueNotifier<int> cartCountNotifier = ValueNotifier<int>(0);

  /// Synchronize the globally visible cart count badge with local SharedPreferences data
  static Future<void> updateCartCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? cartStr = prefs.getString('cart_data');
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
