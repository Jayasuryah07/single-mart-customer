import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'https://agsdemo.in/singlemartapi/public/api';

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
    required String deviceId,
    required String password,
  }) async {
    final uri = Uri.parse('$baseUrl/login');
    return await http.post(
      uri,
      body: {
        'mobile': mobile,
        'device_id': deviceId,
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
}