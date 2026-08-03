import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'screens/ecommerce_home_screen.dart';
import 'screens/product_detail_screen.dart';
import 'screens/order_history_screen.dart';

class AppRouter {
  static bool isInitialized = false;
  static String? pendingRoute;

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    final String routeName = settings.name ?? '/';
    
    // 1. If not initialized, divert all deep links to splash screen and queue them
    if (!isInitialized && routeName != '/') {
      pendingRoute = routeName;
      return MaterialPageRoute(
        settings: settings,
        builder: (context) => const SplashScreen(),
      );
    }

    // 2. Capture slash-nested order paths (e.g. /order/ORD/2025-26/22)
    if (routeName.startsWith('/order/') || routeName.startsWith('/orders/')) {
      final prefix = routeName.startsWith('/order/') ? '/order/' : '/orders/';
      final String orderRef = routeName.substring(prefix.length);
      if (orderRef.isNotEmpty) {
        return MaterialPageRoute(
          settings: settings,
          builder: (context) => OrderHistoryScreen(
            token: null,
            orderId: orderRef,
          ),
        );
      }
    }

    final uri = Uri.parse(routeName);
    final segments = uri.pathSegments;

    // 2. Main route dispatch
    if (segments.isEmpty || routeName == '/') {
      return MaterialPageRoute(
        settings: settings,
        builder: (context) => const SplashScreen(),
      );
    }

    if (segments.length == 1) {
      final tab = segments[0];
      if (tab == 'home') {
        return MaterialPageRoute(
          settings: settings,
          builder: (context) => const ECommerceHomeScreen(initialTabIndex: 0),
        );
      }
      if (tab == 'products') {
        return MaterialPageRoute(
          settings: settings,
          builder: (context) => const ECommerceHomeScreen(initialTabIndex: 2),
        );
      }
      if (tab == 'cart') {
        return MaterialPageRoute(
          settings: settings,
          builder: (context) => const ECommerceHomeScreen(initialTabIndex: 3),
        );
      }
      if (tab == 'profile') {
        return MaterialPageRoute(
          settings: settings,
          builder: (context) => const ECommerceHomeScreen(initialTabIndex: 4),
        );
      }
      if (tab == 'orders') {
        final String? token = settings.arguments as String?;
        return MaterialPageRoute(
          settings: settings,
          builder: (context) => OrderHistoryScreen(token: token),
        );
      }
    }

    if (segments.length == 2) {
      final type = segments[0];
      final param = segments[1];

      if (type == 'product') {
        final id = int.tryParse(param);
        if (id != null) {
          final Map<String, dynamic>? argProduct = settings.arguments as Map<String, dynamic>?;
          return MaterialPageRoute(
            settings: settings,
            builder: (context) => ProductDetailScreen(
              product: argProduct,
              productId: id,
            ),
          );
        }
      }

      if (type == 'order') {
        return MaterialPageRoute(
          settings: settings,
          builder: (context) => OrderHistoryScreen(
            token: null,
            orderId: param,
          ),
        );
      }
    }

    // Default fallback to Home
    return MaterialPageRoute(
      settings: settings,
      builder: (context) => const ECommerceHomeScreen(initialTabIndex: 0),
    );
  }
}
