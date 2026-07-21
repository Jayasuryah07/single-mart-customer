import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'https://agsdemo.in/singlemartapi/public/api';

  /// Helper to generate a UUID v4 string
  static String _generateUuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));

    // Set version to 4 (0100)
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    // Set variant to IETF (10xx)
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }

  /// Get or Create persistent Device ID stored in SharedPreferences (UUID v4)
  static Future<String> getOrCreateDeviceId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? deviceId = prefs.getString('device_id');

      if (deviceId == null || deviceId.isEmpty) {
        deviceId = _generateUuidV4();
        await prefs.setString('device_id', deviceId);
      }

      return deviceId;
    } catch (e) {
      debugPrint('Error getting or creating device ID: $e');
      return _generateUuidV4();
    }
  }

  /// Helper method for backward compatibility
  static Future<String> getDeviceId() async {
    return await getOrCreateDeviceId();
  }

  /// 1. Check App Status and Maintenance Mode
  static Future<http.Response> checkStatus() async {
    final uri = Uri.parse('$baseUrl/app-check-status');
    return await http.get(uri).timeout(const Duration(seconds: 10));
  }

  /// 2. Check Mobile (Send OTP)
  static Future<http.Response> checkMobile(String mobile) async {
    final uri = Uri.parse('$baseUrl/check-mobile');
    return await http.post(
      uri,
      body: {
        'mobile': mobile,
      },
    ).timeout(const Duration(seconds: 10));
  }

  /// 3. Login User
  static Future<http.Response> login({
    required String mobile,
    required String password,
    String? deviceId,
  }) async {
    final String resolvedDeviceId = (deviceId != null && deviceId.isNotEmpty)
        ? deviceId
        : await getDeviceId();

    final uri = Uri.parse('$baseUrl/login');
    return await http.post(
      uri,
      body: {
        'mobile': mobile,
        'device_id': resolvedDeviceId,
        'password': password,
      },
    ).timeout(const Duration(seconds: 10));
  }

  /// 4. Register User with Multipart/Form-Data (for image upload)
  static Future<http.MultipartRequest> createMultipartRequest({
    required String endpoint,
    String? token,
  }) async {
    final uri = Uri.parse('$baseUrl/$endpoint');
    final request = http.MultipartRequest('POST', uri);
    
    request.headers['Accept'] = 'application/json';
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    
    return request;
  }

  /// 5. Register User (JSON - without image)
  static Future<http.Response> registerUser({
    required Map<String, dynamic> payload,
    String? token,
  }) async {
    final uri = Uri.parse('$baseUrl/createvendor');
    final Map<String, String> headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return await http.post(
      uri,
      headers: headers,
      body: json.encode(payload),
    ).timeout(const Duration(seconds: 15));
  }

  /// 6. Register User with Multipart (with image)
  static Future<http.Response> registerUserWithImage({
    required Map<String, String> fields,
    required File? imageFile,
    String? token,
  }) async {
    final uri = Uri.parse('$baseUrl/createvendor');
    final request = http.MultipartRequest('POST', uri);
    
    // Add headers
    request.headers['Accept'] = 'application/json';
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    
    // Add all text fields
    fields.forEach((key, value) {
      request.fields[key] = value;
    });
    
    // Add image file if exists
    if (imageFile != null && await imageFile.exists()) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'user_image',
          imageFile.path,
        ),
      );
    }
    
    final streamedResponse = await request.send();
    return await http.Response.fromStream(streamedResponse);
  }

  /// 7. Fetch States List
  static Future<http.Response> fetchStates() async {
    final uri = Uri.parse('$baseUrl/fetchState');
    return await http.get(uri).timeout(const Duration(seconds: 10));
  }

  /// 8. Logout User
  static Future<http.Response> logout(String token) async {
    final uri = Uri.parse('$baseUrl/app-logout');
    return await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    ).timeout(const Duration(seconds: 8));
  }

  /// 9. Fetch Active Categories
  static Future<http.Response> fetchActiveCategories() async {
    final uri = Uri.parse('$baseUrl/activeCategories');
    return await http.get(uri).timeout(const Duration(seconds: 10));
  }

  /// 10. Fetch Active Subcategories
  static Future<http.Response> fetchActiveSubCategories() async {
    final uri = Uri.parse('$baseUrl/activeSubCategories');
    return await http.get(uri).timeout(const Duration(seconds: 10));
  }

  /// 11. Fetch Active Brands
  static Future<http.Response> fetchActiveBrands() async {
    final uri = Uri.parse('$baseUrl/activeBrands');
    return await http.get(uri).timeout(const Duration(seconds: 10));
  }

  /// 12. Fetch Active Products
  static Future<http.Response> fetchActiveProducts() async {
    final uri = Uri.parse('$baseUrl/activeProducts');
    return await http.get(uri).timeout(const Duration(seconds: 10));
  }

  /// 13. Fetch Active Banners
  static Future<http.Response> fetchActiveBanners(String? token) async {
    final uri = Uri.parse('$baseUrl/activeBanners');
    final Map<String, String> headers = {};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return await http.get(uri, headers: headers).timeout(const Duration(seconds: 10));
  }

  /// 14. Update Vendor Profile or Address
  static Future<http.Response> updateVendor(int vendorId, Map<String, dynamic> body, String token) async {
    final uri = Uri.parse('$baseUrl/vendor/$vendorId');
    return await http.put(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: json.encode(body),
    ).timeout(const Duration(seconds: 10));
  }

  /// 15. Fetch Vendor Profile Details
  static Future<http.Response> fetchVendor(int vendorId, String token) async {
    final uri = Uri.parse('$baseUrl/vendor/$vendorId');
    return await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    ).timeout(const Duration(seconds: 10));
  }

  /// 16. Update Vendor Profile with Multipart (with image)
  static Future<http.Response> updateVendorWithImage({
    required int vendorId,
    required Map<String, String> fields,
    required File? imageFile,
    required String token,
  }) async {
    final uri = Uri.parse('$baseUrl/vendor/$vendorId');
    
    // Spoof PUT using POST method for Laravel multipart file compatibility
    final request = http.MultipartRequest('POST', uri);
    
    // Add headers
    request.headers['Accept'] = 'application/json';
    request.headers['Authorization'] = 'Bearer $token';
    
    // Spoofing PUT method
    request.fields['_method'] = 'PUT';
    
    // Add all text fields
    fields.forEach((key, value) {
      request.fields[key] = value;
    });
    
    // Add image file if exists
    if (imageFile != null && await imageFile.exists()) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'user_image',
          imageFile.path,
        ),
      );
    }
    
    final streamedResponse = await request.send();
    return await http.Response.fromStream(streamedResponse);
  }

  /// 17. Delete Address
  static Future<http.Response> deleteAddress(int addressId, String token) async {
    final uri = Uri.parse('$baseUrl/delete-address/$addressId');
    return await http.delete(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    ).timeout(const Duration(seconds: 10));
  }

  /// 18. Create Order
  static Future<http.Response> createOrder({
    required String address,
    required String remarks,
    required List<Map<String, dynamic>> cartItems,
    required Map<int, String> utrByVendor,
    required Map<int, File?> screenshotFileByVendor,
    required String token,
  }) async {
    final uri = Uri.parse('$baseUrl/order');
    final request = http.MultipartRequest('POST', uri);

    request.headers['Authorization'] = 'Bearer $token';
    request.headers['Accept'] = 'application/json';

    request.fields['order_address'] = address;
    request.fields['order_remarks'] = remarks;

    for (int i = 0; i < cartItems.length; i++) {
      final item = cartItems[i];
      final vIdRaw = item['product_vendor_id'] ?? item['vendor_id'] ?? item['created_by'] ?? 0;
      final int vId = vIdRaw is int ? vIdRaw : int.tryParse(vIdRaw.toString()) ?? 0;

      final dynamic rawVarId = item['order_product_variant_id'] ?? item['variant_id'] ?? item['product_variant_id'];
      final String variantIdStr = (rawVarId != null && rawVarId.toString().isNotEmpty && rawVarId.toString() != 'null')
          ? rawVarId.toString()
          : '';

      request.fields['subs[$i][order_product_id]'] = item['id'].toString();
      request.fields['subs[$i][order_product_variant_id]'] = variantIdStr;
      request.fields['subs[$i][order_quantity]'] = item['quantity'].toString();
      request.fields['subs[$i][order_payment_utr_no]'] = utrByVendor[vId] ?? '';

      final File? screenshotFile = screenshotFileByVendor[vId];
      if (screenshotFile != null && await screenshotFile.exists()) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'subs[$i][order_payment_screenshot]',
            screenshotFile.path,
          ),
        );
      }
    }

    // DEBUG: Print all request fields before sending
    print("===== REQUEST FIELDS =====");
    request.fields.forEach((key, value) {
      print("$key : $value");
    });
    print("===== END REQUEST FIELDS =====");

    final streamedRes = await request.send().timeout(const Duration(seconds: 35));
    return await http.Response.fromStream(streamedRes);
  }

  /// 19. Fetch Order History
  static Future<http.Response> fetchOrders(String token) async {
    final uri = Uri.parse('$baseUrl/order');
    return await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    ).timeout(const Duration(seconds: 15));
  }

  /// 20. Post Product Review
  static Future<http.Response> postProductReview({
    required String productId,
    required String productRating,
    required String productReview,
    required String token,
  }) async {
    final uri = Uri.parse('$baseUrl/product-review');
    return await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({
        'product_id': productId,
        'product_rating': productRating,
        'product_review': productReview,
      }),
    ).timeout(const Duration(seconds: 10));
  }
}