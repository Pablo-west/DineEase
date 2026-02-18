import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'loading_skeleton.dart';

class FinancePage extends StatelessWidget {
  const FinancePage({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('orders').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _FinanceSkeleton();
        }
        if (snapshot.hasError) {
          return FirestoreErrorPanel(
            title: 'Finance cannot load orders.',
            error: snapshot.error,
          );
        }
        final orders = snapshot.data?.docs ?? [];
        final now = DateTime.now();

        double todayRevenue = 0;
        double monthRevenue = 0;
        final paymentBreakdown = <String, double>{};
        int pendingReconcile = 0;

        for (final doc in orders) {
          final data = doc.data();
          final totals = (data['totals'] as Map?) ?? const {};
          final totalRaw = totals['total'];
          final total = totalRaw is num ? totalRaw.toDouble() : 0.0;
          final payment = (data['payment'] as Map?) ?? const {};
          final method = payment['method']?.toString() ?? 'unknown';
          paymentBreakdown[method] = (paymentBreakdown[method] ?? 0) + total;

          final stage = data['stage']?.toString() ?? '';
          if (stage != 'delivered') {
            pendingReconcile += 1;
          }

          final placedAt = data['placedAt'];
          DateTime? date;
          if (placedAt is Timestamp) {
            date = placedAt.toDate();
          } else if (placedAt is String) {
            date = DateTime.tryParse(placedAt);
          } else if (placedAt is DateTime) {
            date = placedAt;
          }
          if (date == null) {
            continue;
          }
          if (date.year == now.year && date.month == now.month) {
            monthRevenue += total;
            if (date.day == now.day) {
              todayRevenue += total;
            }
          }
        }

        final sortedMethods = paymentBreakdown.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Finance & Reconciliation',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _FinanceMetric(
                    title: 'Today Revenue',
                    value: 'GHS ${todayRevenue.toStringAsFixed(2)}',
                    icon: Icons.today,
                  ),
                  _FinanceMetric(
                    title: 'Month Revenue',
                    value: 'GHS ${monthRevenue.toStringAsFixed(2)}',
                    icon: Icons.calendar_month,
                  ),
                  _FinanceMetric(
                    title: 'Pending Reconcile',
                    value: pendingReconcile.toString(),
                    icon: Icons.warning_amber_rounded,
                  ),
                  _FinanceMetric(
                    title: 'Total Orders',
                    value: orders.length.toString(),
                    icon: Icons.receipt_long,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Payment Method Breakdown',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      if (sortedMethods.isEmpty)
                        const Text('No payment data yet.')
                      else
                        ...sortedMethods.map((entry) {
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(entry.key),
                            trailing: Text(
                              'GHS ${entry.value.toStringAsFixed(2)}',
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _ReconciliationSection(monthRevenue: monthRevenue),
            ],
          ),
        );
      },
    );
  }
}

class _ReconciliationSection extends StatelessWidget {
  const _ReconciliationSection({required this.monthRevenue});

  final double monthRevenue;

  Future<void> _createRecord(BuildContext context) async {
    final noteController = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Create Reconciliation Record'),
          content: TextField(
            controller: noteController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Notes'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
    if (saved != true) {
      noteController.dispose();
      return;
    }

    final now = DateTime.now();
    await FirebaseFirestore.instance.collection('reconciliations').add({
      'period': '${now.year}-${now.month.toString().padLeft(2, '0')}',
      'amount': monthRevenue,
      'notes': noteController.text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'open',
    });
    noteController.dispose();
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reconciliation record created')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('reconciliations')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SkeletonBox(height: 220);
        }
        if (snapshot.hasError) {
          return FirestoreErrorPanel(
            title: 'Reconciliation records cannot be loaded.',
            error: snapshot.error,
          );
        }
        final docs = snapshot.data?.docs ?? [];

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Reconciliation Records',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: () => _createRecord(context),
                      icon: const Icon(Icons.add),
                      label: const Text('New Record'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (docs.isEmpty)
                  const Text('No reconciliation records yet.')
                else
                  ...docs.map((doc) {
                    final data = doc.data();
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(data['period']?.toString() ?? 'Unknown'),
                      subtitle: Text(data['notes']?.toString() ?? ''),
                      trailing: Text(
                        'GHS ${(data['amount'] ?? 0).toString()}',
                      ),
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FinanceMetric extends StatelessWidget {
  const _FinanceMetric({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon),
              const SizedBox(height: 8),
              Text(title),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FinanceSkeleton extends StatelessWidget {
  const _FinanceSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(20),
      child: Column(
        children: [
          SkeletonBox(height: 32),
          SizedBox(height: 12),
          SkeletonBox(height: 110),
          SizedBox(height: 14),
          SkeletonBox(height: 220),
          SizedBox(height: 14),
          SkeletonBox(height: 220),
        ],
      ),
    );
  }
}
