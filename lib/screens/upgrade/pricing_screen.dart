import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/payment_service.dart';

class PricingScreen extends StatefulWidget {
  const PricingScreen({super.key});

  @override
  State<PricingScreen> createState() => _PricingScreenState();
}

class _PricingScreenState extends State<PricingScreen> {
  @override
  void initState() {
    super.initState();
    final pc = Get.find<PaymentController>();
    pc.fetchPlans();
  }

  int? _getCurrentPlanId() {
    final pc = Get.find<PaymentController>();
    final cp = pc.currentPlan.value;
    if (cp == null) return null;
    return cp['id'] is int ? cp['id'] : int.tryParse(cp['id'].toString());
  }

  void _showPlanDetails(BuildContext context, Map<String, dynamic> plan, bool isCurrentPlan, PaymentController pc) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final planId = plan['id'] is int ? plan['id'] : int.tryParse(plan['id'].toString());
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    plan['name']?.toString() ?? 'Plan Details',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  if (plan['description']?.toString().isNotEmpty == true) ...[
                    const SizedBox(height: 8),
                    Text(
                      plan['description'].toString(),
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    '\u20B9${plan['pricePerUser']} /user/mo',
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF152A4A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildDetailChip('${_formatPlanLimit(plan['maxEmployees'])} employees'),
                      _buildDetailChip('${_formatPlanLimit(plan['maxBranches'])} branches'),
                    ],
                  ),
                  if (plan['features'] is Map) ...[
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 12),
                    Text(
                      'Features',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...(plan['features'] as Map<String, dynamic>).entries.map((e) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Text(e.value.toString() == '✅' ? '✅' : (e.value.toString() == '❌' ? '❌' : '•')),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              e.value.toString() == '✅' || e.value.toString() == '❌'
                                  ? e.key.replaceAll('_', ' ')
                                  : '${e.key.replaceAll('_', ' ')}: ${e.value}',
                              style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF64748B)),
                            ),
                          ),
                        ],
                      ),
                    )),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: isCurrentPlan
                        ? OutlinedButton(
                            onPressed: null,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text('Current Plan', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
                          )
                        : ElevatedButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              pc.createAndOpenCheckout(planId);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF152A4A),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text('Upgrade', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _formatPlanLimit(dynamic limit) {
    if (limit == null) return 'N/A';
    if (limit is int && limit == -1) return 'Unlimited';
    return limit.toString();
  }

  Widget _buildDetailChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF152A4A).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: const Color(0xFF152A4A))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pc = Get.find<PaymentController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose a Plan'),
        backgroundColor: const Color(0xFF152A4A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Obx(() {
        if (pc.isLoadingPlans.value) {
          return const Center(child: CircularProgressIndicator());
        }

        if (pc.plans.isEmpty) {
          return Center(
            child: Text(
              'No plans available',
              style: GoogleFonts.poppins(color: Colors.grey.shade500),
            ),
          );
        }

        final currentPlanId = _getCurrentPlanId();

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: pc.plans.length,
          itemBuilder: (context, index) {
            final plan = pc.plans[index];
            final planId = plan['id'] is int ? plan['id'] : int.tryParse(plan['id'].toString());
            final isCurrentPlan = planId != null && planId == currentPlanId;
            final name = plan['name']?.toString() ?? 'Plan';
            final price = plan['pricePerUser']?.toString() ?? '0';
            final description = plan['description']?.toString() ?? '';
            final features = plan['features'] is Map ? plan['features'] as Map<String, dynamic> : <String, dynamic>{};
            final maxEmployees = plan['maxEmployees'];
            final maxBranches = plan['maxBranches'];
            final sortOrder = plan['sortOrder'] is int ? plan['sortOrder'] : 999;

            final color = sortOrder == 3
                ? const Color(0xFFD4A843)
                : (sortOrder == 2 ? const Color(0xFF152A4A) : const Color(0xFF64748B));

            return _PlanCard(
              name: name,
              price: price,
              description: description,
              features: features,
              maxEmployees: maxEmployees,
              maxBranches: maxBranches,
              color: color,
              isCurrentPlan: isCurrentPlan,
              onTap: () => _showPlanDetails(context, plan, isCurrentPlan, pc),
              onUpgrade: () => pc.createAndOpenCheckout(planId),
              isProcessing: pc.isProcessingPayment.value,
              isPremium: sortOrder == 3,
            );
          },
        );
      }),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String name;
  final String price;
  final String description;
  final Map<String, dynamic> features;
  final dynamic maxEmployees;
  final dynamic maxBranches;
  final Color color;
  final bool isCurrentPlan;
  final VoidCallback? onTap;
  final VoidCallback onUpgrade;
  final bool isProcessing;
  final bool isPremium;

  const _PlanCard({
    required this.name,
    required this.price,
    required this.description,
    required this.features,
    required this.maxEmployees,
    required this.maxBranches,
    required this.color,
    required this.isCurrentPlan,
    this.onTap,
    required this.onUpgrade,
    required this.isProcessing,
    required this.isPremium,
  });

  String _formatLimit(dynamic limit) {
    if (limit == null) return 'N/A';
    if (limit is int && limit == -1) return 'Unlimited';
    return limit.toString();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: isPremium
            ? const LinearGradient(
                colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isPremium ? null : Colors.white,
        border: Border.all(
          color: isCurrentPlan ? color : Colors.grey.shade200,
          width: isCurrentPlan ? 2 : 1,
        ),
        boxShadow: [
          if (isPremium)
            BoxShadow(
              color: const Color(0xFFD4A843).withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            )
          else
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  name,
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: isPremium ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
                if (isCurrentPlan)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'ACTIVE',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: color,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
              ],
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                description,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: isPremium ? Colors.grey.shade400 : Colors.grey.shade500,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\u20B9$price',
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: isPremium ? const Color(0xFFD4A843) : const Color(0xFF152A4A),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 5, left: 4),
                  child: Text(
                    '/user/mo',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: isPremium ? Colors.grey.shade400 : Colors.grey.shade500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildChip('${_formatLimit(maxEmployees)} employees', isPremium),
                const SizedBox(width: 8),
                _buildChip('${_formatLimit(maxBranches)} branches', isPremium),
              ],
            ),
            if (features.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 12),
              ...features.entries.map((entry) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.value.toString() == '✅' ? '✅' : (entry.value.toString() == '❌' ? '❌' : '•'),
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            entry.value.toString() == '✅' || entry.value.toString() == '❌'
                                ? entry.key.replaceAll('_', ' ')
                                : '${entry.key.replaceAll('_', ' ')}: ${entry.value}',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: isPremium ? Colors.grey.shade300 : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: isCurrentPlan
                  ? OutlinedButton(
                      onPressed: null,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(color: color.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        'Current Plan',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: color.withValues(alpha: 0.5),
                        ),
                      ),
                    )
                  : ElevatedButton(
                      onPressed: isProcessing ? null : onUpgrade,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: isPremium ? const Color(0xFF1A1A2E) : Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: isProcessing
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              'Upgrade',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildChip(String label, bool isPremium) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isPremium ? Colors.white.withValues(alpha: 0.1) : const Color(0xFF152A4A).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: isPremium ? Colors.white70 : const Color(0xFF152A4A),
        ),
      ),
    );
  }
}
