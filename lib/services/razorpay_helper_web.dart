import 'dart:js';

class RazorpayHelper {
  static void openCheckout({
    required String key,
    required int amount,
    required String currency,
    required String orderId,
    required String name,
    String? description,
    Map<String, String>? prefill,
    required void Function(Map<String, dynamic> response) onSuccess,
    required void Function(String? error) onError,
    void Function()? onDismiss,
  }) {
    final options = JsObject.jsify({
      'key': key,
      'amount': amount,
      'currency': currency,
      'name': name,
      'order_id': orderId,
      if (description != null) 'description': description,
      if (prefill != null) 'prefill': JsObject.jsify(prefill),
      'modal': JsObject.jsify({}),
    });

    options['handler'] = JsFunction.withThis((_, response) {
      if (response is JsObject) {
        onSuccess({
          'razorpay_payment_id': response['razorpay_payment_id'],
          'razorpay_order_id': response['razorpay_order_id'],
          'razorpay_signature': response['razorpay_signature'],
        });
      }
    });

    options['modal']!['ondismiss'] = JsFunction.withThis((_) {
      onDismiss?.call();
    });

    final razorpayCtor = context['Razorpay'];
    if (razorpayCtor == null) {
      onError('Razorpay SDK not loaded');
      return;
    }

    try {
      final instance = JsObject(razorpayCtor as JsFunction, [options]);
      instance.callMethod('open', []);
    } catch (e) {
      onError(e.toString());
    }
  }
}
