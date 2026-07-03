import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/payment_service.dart';

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  @override
  void initState() {
    super.initState();
    final pc = Get.find<PaymentController>();
    pc.fetchSubscriptionStatus();
    pc.fetchPaymentHistory();
  }

  Widget _buildStatusBadge(String status) {
    Color bgColor;
    Color textColor;
    String label;

    switch (status.toLowerCase()) {
      case 'active':
      case 'completed':
      case 'paid':
        bgColor = Colors.green.shade50;
        textColor = Colors.green.shade700;
        label = 'Active';
        break;
      case 'created':
        bgColor = Colors.blue.shade50;
        textColor = Colors.blue.shade700;
        label = 'Pending';
        break;
      case 'expired':
      case 'past_due':
        bgColor = Colors.red.shade50;
        textColor = Colors.red.shade700;
        label = 'Expired';
        break;
      case 'failed':
        bgColor = Colors.red.shade50;
        textColor = Colors.red.shade700;
        label = 'Failed';
        break;
      default:
        bgColor = Colors.grey.shade100;
        textColor = Colors.grey.shade700;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pc = Get.find<PaymentController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Billing'),
        backgroundColor: const Color(0xFF152A4A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Obx(() {
              if (pc.isLoadingSubscription.value) {
                return const Center(child: CircularProgressIndicator());
              }

              final sub = pc.subscriptionStatus.value;
              if (sub == null) {
                return const SizedBox.shrink();
              }

              final plan = sub['plan'] is Map ? sub['plan'] as Map : <String, dynamic>{};
              final planName = plan['name']?.toString() ?? 'Free';
              final status = sub['subscription_status']?.toString() ?? 'active';
              final validUntil = sub['subscription_valid_until']?.toString() ?? '';
              final remainingDays = sub['remaining_days'];

              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF152A4A), Color(0xFF1E3A5F)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF152A4A).withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Subscription',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white70,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          planName,
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        _buildStatusBadge(status),
                      ],
                    ),
                    if (validUntil.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Valid until: ${_formatDate(validUntil)}',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.white60,
                        ),
                      ),
                    ],
                    if (remainingDays != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '$remainingDays days remaining',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.white60,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),
            const SizedBox(height: 24),
            Text(
              'Payment History',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 12),
            Obx(() {
              if (pc.isLoadingHistory.value) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              if (pc.paymentHistory.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text(
                          'No payment history',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: pc.paymentHistory.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final payment = pc.paymentHistory[index];
                  final amount = payment['amount']?.toString() ?? '0';
                  final currency = payment['currency']?.toString() ?? '\u20B9';
                  final status = payment['status']?.toString() ?? '';
                  final date = payment['createdAt']?.toString() ?? '';
                  final planName = payment['planName']?.toString() ?? '';

                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF152A4A).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.receipt,
                            size: 20,
                            color: Color(0xFF152A4A),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                planName.isNotEmpty ? planName : 'Payment',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF1E293B),
                                ),
                              ),
                              if (date.isNotEmpty)
                                Text(
                                  _formatDate(date),
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Text(
                          '$currency ${_formatAmount(amount)}',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF152A4A),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (status.isNotEmpty) _buildStatusBadge(status),
                      ],
                    ),
                  );
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat('dd MMM yyyy').format(dt);
    } catch (_) {
      return dateStr;
    }
  }

  String _formatAmount(String amount) {
    try {
      final val = double.parse(amount);
      return val.toStringAsFixed(2);
    } catch (_) {
      return amount;
    }
  }
}
