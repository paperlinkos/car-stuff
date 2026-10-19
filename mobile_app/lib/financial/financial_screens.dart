import 'package:flutter/material.dart';
import 'financial_models.dart';
import 'financial_repository.dart';

String formatMoneyNgn(int value) =>
    '₦${value.toString().replaceAllMapped(RegExp(r'(?=(\d{3})+(?!\d))'), (m) => ',')}';

String formatFinancialDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

class CustomerPaymentsScreen extends StatelessWidget {
  const CustomerPaymentsScreen({super.key, required this.customerId});
  final String customerId;

  @override
  Widget build(BuildContext context) {
    final repo = FinancialRepository();
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8F9),
      appBar: AppBar(
        title: const Text('Payments & Invoices',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: const Color(0xFFFEF3C7),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: const Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Color(0xFF92400E)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'PROTOTYPE FINANCIAL MODE · NO REAL MONEY CHARGED',
                    style: TextStyle(
                      color: Color(0xFF92400E),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<PaymentRecord>>(
              stream: repo.watchPaymentsForCustomer(customerId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Could not load payment records.'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = snapshot.data!;
                if (items.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long_outlined,
                              size: 56, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          const Text('No Payment History',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text(
                            'Verified receipts, security deposits, and refunds will appear here once an accepted booking is paid.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Colors.grey.shade600, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _CustomerPaymentCard(payment: item);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerPaymentCard extends StatelessWidget {
  const _CustomerPaymentCard({required this.payment});
  final PaymentRecord payment;

  @override
  Widget build(BuildContext context) {
    final isSuccess = payment.status == 'successful';
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                formatMoneyNgn(payment.amountNgn),
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF13382C),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isSuccess
                      ? const Color(0xFFE9F5ED)
                      : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  payment.status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isSuccess
                        ? const Color(0xFF13382C)
                        : const Color(0xFF991B1B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Ref: ${payment.reference}',
            style: const TextStyle(
              fontSize: 12,
              fontFamily: 'monospace',
              color: Color(0xFF6B7280),
            ),
          ),
          if (payment.paidAt != null)
            Text(
              'Date: ${formatFinancialDate(payment.paidAt!)}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            ),
          const Divider(height: 20, color: Color(0xFFF3F4F6)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Rental Charge:',
                  style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
              Text(formatMoneyNgn(payment.grossRentalNgn),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
          if (payment.depositNgn > 0) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Security Deposit (Held):',
                    style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                Text(formatMoneyNgn(payment.depositNgn),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class OwnerFinancialWorkspaceScreen extends StatefulWidget {
  const OwnerFinancialWorkspaceScreen({super.key, required this.ownerId});
  final String ownerId;

  @override
  State<OwnerFinancialWorkspaceScreen> createState() =>
      _OwnerFinancialWorkspaceScreenState();
}

class _OwnerFinancialWorkspaceScreenState
    extends State<OwnerFinancialWorkspaceScreen> {
  final repo = FinancialRepository();
  OwnerBalanceSummary? _summary;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    setState(() => _loading = true);
    final summary = await repo.getOwnerBalances(widget.ownerId);
    if (mounted) {
      setState(() {
        _summary = summary;
        _loading = false;
      });
    }
  }

  void _showPayoutRequestSheet() {
    final available = _summary?.availableForPayoutNgn ?? 0;
    final controller = TextEditingController(text: available > 0 ? '$available' : '10000');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Request Payout (Sandbox)',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Available balance for settlement: ${formatMoneyNgn(available)}',
              style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Amount (NGN)',
                prefixText: '₦ ',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Note: Minimum payout is ₦5,000. Funds will be placed on hold until administrative review.',
              style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final nav = Navigator.of(context);
                final amount = int.tryParse(controller.text) ?? 0;
                if (amount < 5000) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Minimum payout is ₦5,000.')),
                  );
                  return;
                }
                if (amount > available) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                          'Amount exceeds available balance (${formatMoneyNgn(available)}).'),
                    ),
                  );
                  return;
                }
                nav.pop();
                try {
                  await repo.requestPayout(amountNgn: amount);
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                          'Payout request for ${formatMoneyNgn(amount)} submitted (Sandbox).'),
                    ),
                  );
                  if (mounted) {
                    _loadBalance();
                  }
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Payout request failed: $e')),
                  );
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF13382C),
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Submit Payout Request'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary ?? OwnerBalanceSummary.prototypeDefault;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8F9),
      appBar: AppBar(
        title: const Text('Financial Workspace',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadBalance,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF13382C), Color(0xFF1A4738)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'AVAILABLE FOR PAYOUT',
                      style: TextStyle(
                        color: Color(0xFF86EFAC),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.6,
                      ),
                    ),
                    Text(
                      'VERIFIED LEDGER',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  _loading ? 'Calculating…' : formatMoneyNgn(summary.availableForPayoutNgn),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _balanceMiniStat('Pending Review', summary.pendingPayoutNgn),
                    Container(width: 1, height: 30, color: Colors.white24),
                    _balanceMiniStat('Total Paid Out', summary.paidOutNgn),
                  ],
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: summary.availableForPayoutNgn >= 5000
                      ? _showPayoutRequestSheet
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.18),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Request Payout (Sandbox)'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('Payout History & Settlement Queue',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          StreamBuilder<List<PayoutRecord>>(
            stream: repo.watchPayouts(widget.ownerId),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Text('Could not load payout history.');
              }
              final payouts = snapshot.data ?? [];
              if (payouts.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: const Center(
                    child: Text('No payout requests yet.',
                        style: TextStyle(color: Color(0xFF6B7280))),
                  ),
                );
              }

              return Column(
                children: payouts.map((p) => _PayoutTile(payout: p)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _balanceMiniStat(String label, int amount) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white60, fontSize: 11)),
          const SizedBox(height: 2),
          Text(
            formatMoneyNgn(amount),
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _PayoutTile extends StatelessWidget {
  const _PayoutTile({required this.payout});
  final PayoutRecord payout;

  @override
  Widget build(BuildContext context) {
    Color badgeColor = const Color(0xFFFEF3C7);
    Color textColor = const Color(0xFF92400E);
    if (payout.status == 'completed' || payout.status == 'approved') {
      badgeColor = const Color(0xFFE9F5ED);
      textColor = const Color(0xFF13382C);
    } else if (payout.status == 'rejected' || payout.status == 'failed') {
      badgeColor = const Color(0xFFFEF2F2);
      textColor = const Color(0xFF991B1B);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(formatMoneyNgn(payout.amountNgn),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 3),
              Text(formatFinancialDate(payout.requestedAt),
                  style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              payout.status.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
