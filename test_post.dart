import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final uri = Uri.parse('https://agsdemo.in/singlemartapi/public/api/vendor');
  try {
    final payload = {
      "name": "Test User",
      "owner_name": null,
      "mobile": "9999999999",
      "email": "test@example.com",
      "gender": "Male",
      "dob": "1995-01-01",
      "user_type": "1",
      "user_position": "User",
      "user_image": null,
      "upi_id": null,
      "qr_code": null,
      "business_document": null,
      "gst_number": null,
      "pan_number": null,
      "is_verified": "1",
      "addresses": [
        {
          "address_line_1": "Test Address",
          "city": "Bangalore",
          "state": "Karnataka",
          "country": "India",
          "pincode": "560001",
          "address_type": "Home",
          "is_default": "1"
        }
      ]
    };

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: json.encode(payload),
    );

    print('Status Code: ${response.statusCode}');
    print('Body: ${response.body}');
  } catch (e) {
    print('Error: $e');
  }
}
