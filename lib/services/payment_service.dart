import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/auth_utils.dart';
import 'razorpay_helper_stub.dart'
    if (dart.library.js) 'razorpay_helper_web.dart';

class PaymentController extends GetxController {
  static const String _baseUrl = 'https://nodeface.agniplay.com/api';

  final Dio _dio = Dio(BaseOptions(
    baseUrl: _baseUrl,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
    headers: {'Accept': 'application/json', 'Content-Type': 'application/json'},
  ));

  Razorpay? _mobileRazorpay;

  var isProcessingPayment = false.obs;
  var paymentHistory = <Map<String, dynamic>>[].obs;
  var subscriptionStatus = Rx<Map<String, dynamic>?>(null);
  var isLoadingHistory = false.obs;
  var isLoadingSubscription = false.obs;
  var isLoadingPlans = false.obs;
  var plans = <Map<String, dynamic>>[].obs;
  var currentPlan = Rx<Map<String, dynamic>?>(null);
  var billingConfig = Rx<Map<String, dynamic>?>(null);
  var usage = Rx<Map<String, dynamic>?>(null);

  int? _pendingCompanyId;
  dynamic _pendingPlanId;
  bool _paymentHandled = false;

  @override
  void onInit() {
    super.onInit();
    if (!kIsWeb) {
      _mobileRazorpay = Razorpay();
      _mobileRazorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, _mobileHandleSuccess);
      _mobileRazorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, _mobileHandleError);
      _mobileRazorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, _mobileHandleExternalWallet);
    }
  }

  @override
  void onClose() {
    _mobileRazorpay?.clear();
    super.onClose();
  }

  Future<Map<String, String>> _getAuthHeaders() async {
    final token = await AuthUtils.getToken();
    return {'Authorization': 'Bearer $token'};
  }

  Future<int> _getCompanyId() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getInt('company_id');
    if (stored != null && stored > 0) return stored;

    final token = await AuthUtils.getToken();
    if (token == null) return 0;

    try {
      final parts = token.split('.');
      if (parts.length != 3) return 0;
      String payload = parts[1];
      while (payload.length % 4 != 0) { payload += '='; }
      final decoded = utf8.decode(base64Url.decode(payload));
      final map = json.decode(decoded) as Map<String, dynamic>;
      final companyId = map['companyId'] ?? map['companyID'] ?? map['company_id'];
      if (companyId != null) {
        final id = companyId is int ? companyId : int.tryParse(companyId.toString());
        if (id != null && id > 0) {
          await prefs.setInt('company_id', id);
          return id;
        }
      }
    } catch (_) {}

    return 0;
  }

  Future<void> createAndOpenCheckout(dynamic planId) async {
    if (isProcessingPayment.value) return;

    isProcessingPayment(true);
    _paymentHandled = false;

    try {
      final companyId = await _getCompanyId();
      _pendingCompanyId = companyId;
      _pendingPlanId = planId;

      final headers = await _getAuthHeaders();
      final response = await _dio.post(
        '/subscription/create-order',
        data: {'company_id': companyId, 'plan_id': planId},
        options: Options(headers: headers),
      );

      if (response.statusCode != 200 || response.data['success'] != true) {
        throw Exception(response.data?['error'] ?? response.data?['message'] ?? 'Failed to create order');
      }

      final data = response.data['data'] ?? response.data;
      final orderId = data['order_id'] ?? data['id'];
      final amount = data['amount'];
      final currency = data['currency'] ?? 'INR';
      final keyId = data['key'] ?? data['key_id'];

      if (orderId == null || amount == null || keyId == null) {
        throw Exception('Invalid order response from server');
      }

      final amountPaise = amount is int ? amount : (double.tryParse(amount.toString()) ?? 0).toInt();

      await Future.delayed(Duration.zero);

      if (kIsWeb) {
        RazorpayHelper.openCheckout(
          key: keyId,
          amount: amountPaise,
          currency: currency,
          orderId: orderId,
          name: 'InstaMarQ',
          description: data['plan_name']?.toString(),
          onSuccess: _webHandleSuccess,
          onError: (error) {
            _paymentHandled = true;
            isProcessingPayment(false);
            _pendingCompanyId = null;
            _pendingPlanId = null;
            Get.snackbar('Payment Failed', error ?? 'Payment was cancelled',
                snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red.shade600, colorText: Colors.white);
          },
          onDismiss: () {
            if (!_paymentHandled) {
              isProcessingPayment(false);
              _pendingCompanyId = null;
              _pendingPlanId = null;
            }
          },
        );
      } else {
        _mobileRazorpay!.open({
          'key': keyId,
          'amount': amountPaise,
          'currency': currency,
          'name': 'InstaMarQ',
          'description': 'Plan Upgrade',
          'order_id': orderId,
          'prefill': {'contact': '', 'email': ''},
          'theme': {'color': '#152A4A'},
        });
      }
    } catch (e) {
      isProcessingPayment(false);
      _pendingCompanyId = null;
      _pendingPlanId = null;
      Get.snackbar('Error', e.toString().replaceAll('Exception: ', ''),
          snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red.shade600, colorText: Colors.white);
    }
  }

  void _webHandleSuccess(Map<String, dynamic> response) {
    _paymentHandled = true;
    _verifyPayment(
      orderId: response['razorpay_order_id'],
      paymentId: response['razorpay_payment_id'],
      signature: response['razorpay_signature'],
    );
  }

  void _mobileHandleSuccess(PaymentSuccessResponse response) {
    _paymentHandled = true;
    _verifyPayment(
      orderId: response.orderId,
      paymentId: response.paymentId,
      signature: response.signature,
    );
  }

  void _mobileHandleError(PaymentFailureResponse response) {
    debugPrint('[PAYMENT] Error: code=${response.code} message=${response.message}');
    isProcessingPayment(false);
    Get.snackbar('Payment Failed', response.message ?? 'An error occurred',
        snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red.shade600, colorText: Colors.white);
  }

  void _mobileHandleExternalWallet(ExternalWalletResponse response) {
    isProcessingPayment(false);
    Get.snackbar('External Wallet', '${response.walletName} is not supported',
        snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.orange.shade600, colorText: Colors.white);
  }

  Future<void> _verifyPayment({
    String? orderId,
    String? paymentId,
    String? signature,
  }) async {
    try {
      final companyId = _pendingCompanyId ?? await _getCompanyId();
      final planId = _pendingPlanId;

      final headers = await _getAuthHeaders();
      final verifyResponse = await _dio.post(
        '/subscription/verify',
        data: {
          'company_id': companyId,
          'razorpay_order_id': orderId,
          'razorpay_payment_id': paymentId,
          'razorpay_signature': signature,
          'plan_id': planId,
        },
        options: Options(headers: headers),
      );

      if (verifyResponse.data['success'] == true) {
        Get.snackbar('Payment Successful', 'Your plan has been upgraded successfully',
            snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.green.shade600, colorText: Colors.white);
        await fetchPlans();
        await fetchSubscriptionStatus();
      } else {
        throw Exception(verifyResponse.data?['error'] ?? 'Verification failed');
      }
    } catch (e) {
      Get.snackbar('Verification Error', 'Payment was completed but verification failed. Please contact support.',
          snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.orange.shade600, colorText: Colors.white);
    } finally {
      isProcessingPayment(false);
      _pendingCompanyId = null;
      _pendingPlanId = null;
    }
  }

  Future<void> fetchPlans() async {
    isLoadingPlans(true);
    try {
      final headers = await _getAuthHeaders();
      final response = await _dio.get('/my-pricing', options: Options(headers: headers));

      if (response.data['success'] == true) {
        final data = response.data['data'];
        if (data['plans'] is List) plans.value = List<Map<String, dynamic>>.from(data['plans']);
        if (data['currentPlan'] is Map) currentPlan.value = Map<String, dynamic>.from(data['currentPlan']);
        if (data['config'] is Map) billingConfig.value = Map<String, dynamic>.from(data['config']);
        if (data['usage'] is Map) usage.value = Map<String, dynamic>.from(data['usage']);
      }
    } catch (e) {
      debugPrint('Error fetching plans: $e');
    } finally {
      isLoadingPlans(false);
    }
  }

  Future<void> fetchPaymentHistory() async {
    isLoadingHistory(true);
    try {
      final headers = await _getAuthHeaders();
      final response = await _dio.get('/payment/history', options: Options(headers: headers));

      if (response.data['success'] == true) {
        final data = response.data['data'];
        if (data is List) paymentHistory.value = List<Map<String, dynamic>>.from(data);
      }
    } catch (e) {
      debugPrint('Error fetching payment history: $e');
    } finally {
      isLoadingHistory(false);
    }
  }

  Future<void> fetchSubscriptionStatus() async {
    isLoadingSubscription(true);
    try {
      final headers = await _getAuthHeaders();
      final response = await _dio.get('/payment/subscription-status', options: Options(headers: headers));

      if (response.data['success'] == true) {
        final data = response.data['data'];
        subscriptionStatus.value = data is Map<String, dynamic> ? data : null;
      }
    } catch (e) {
      debugPrint('Error fetching subscription status: $e');
    } finally {
      isLoadingSubscription(false);
    }
  }
}
