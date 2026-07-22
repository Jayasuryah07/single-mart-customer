import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final baseUrl = 'https://agsdemo.in/singlemartapi/public/api';
  final ts = DateTime.now().millisecondsSinceEpoch.toString();
  final mobile = '98${ts.substring(ts.length - 8)}';
  final email = 'testuser$ts@example.com';

  print('Registering mobile: $mobile');

  final regUri = Uri.parse('$baseUrl/createvendor');
  final regReq = http.MultipartRequest('POST', regUri);
  regReq.headers['Accept'] = 'application/json';
  regReq.fields['name'] = 'Test User';
  regReq.fields['owner_name'] = 'Test User';
  regReq.fields['mobile'] = mobile;
  regReq.fields['email'] = email;
  regReq.fields['gender'] = 'Male';
  regReq.fields['dob'] = '1995-01-01';
  regReq.fields['user_type'] = '1';
  regReq.fields['user_position'] = 'User';
  regReq.fields['is_verified'] = '1';
  regReq.fields['upi_id'] = '';
  regReq.fields['qr_code'] = '';
  regReq.fields['business_document'] = '';
  regReq.fields['gst_number'] = '';
  regReq.fields['pan_number'] = '';
  regReq.fields['user_image'] = '';
  regReq.fields['addresses[0][address_line_1]'] = 'Street 1';
  regReq.fields['addresses[0][address_line_2]'] = '';
  regReq.fields['addresses[0][landmark]'] = '';
  regReq.fields['addresses[0][city]'] = 'Bangalore';
  regReq.fields['addresses[0][district]'] = 'Bangalore';
  regReq.fields['addresses[0][state]'] = 'Karnataka';
  regReq.fields['addresses[0][country]'] = 'India';
  regReq.fields['addresses[0][pincode]'] = '560001';
  regReq.fields['addresses[0][address_type]'] = 'Home';
  regReq.fields['addresses[0][is_default]'] = '1';

  final regStream = await regReq.send();
  final regRes = await http.Response.fromStream(regStream);
  print('Register status: ${regRes.statusCode}');
  print('Register body: ${regRes.body}');

  final checkRes = await http.post(
    Uri.parse('$baseUrl/check-mobile'),
    body: {'mobile': mobile},
  );
  print('checkMobile body: ${checkRes.body}');
  final checkData = json.decode(checkRes.body);
  final pass = checkData['data']?.toString() ?? '123456';

  final loginRes = await http.post(
    Uri.parse('$baseUrl/login'),
    body: {
      'mobile': mobile,
      'device_id': 'test_device',
      'password': pass,
    },
  );
  print('Login status: ${loginRes.statusCode}');
  print('Login body: ${loginRes.body}');

  final loginData = json.decode(loginRes.body);
  final token = loginData['data']?['token']?.toString();
  print('Token: $token');

  if (token != null) {
    final orderUri = Uri.parse('$baseUrl/order');

    print('\n--- 1. Testing with string order_product_variant_id "3" ---');
    final orderReq1 = http.MultipartRequest('POST', orderUri);
    orderReq1.headers['Authorization'] = 'Bearer $token';
    orderReq1.headers['Accept'] = 'application/json';
    orderReq1.fields['order_address'] = '123 Test Street';
    orderReq1.fields['order_remarks'] = 'Test Remark';

    orderReq1.fields['subs[0][order_product_id]'] = '11';
    orderReq1.fields['subs[0][order_product_variant_id]'] = '3';
    orderReq1.fields['subs[0][order_quantity]'] = '1';
    orderReq1.fields['subs[0][order_payment_utr_no]'] = '1234456789012';

    final orderStream1 = await orderReq1.send();
    final orderRes1 = await http.Response.fromStream(orderStream1);
    print('Order 1 Status: ${orderRes1.statusCode}');
    print('Order 1 Body: ${orderRes1.body}');
  }
}
