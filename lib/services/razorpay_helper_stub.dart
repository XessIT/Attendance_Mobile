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
    throw UnsupportedError('RazorpayHelper is only available on web');
  }
}
