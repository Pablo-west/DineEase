import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'admin_ui.dart';
import 'loading_skeleton.dart';

class FinancePage extends StatefulWidget {
  const FinancePage({super.key, required this.searchQuery});

  final ValueListenable<String> searchQuery;

  @override
  State<FinancePage> createState() => _FinancePageState();
}

class _FinancePageState extends State<FinancePage> {
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _ordersStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _recordsStream;

  @override
  void initState() {
    super.initState();
    _ordersStream = FirebaseFirestore.instance.collection('orders').snapshots();
    _recordsStream = FirebaseFirestore.instance
        .collection('reconciliations')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> _createRecord(BuildContext context, double monthRevenue) async {
    final notesController = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('New Reconciliation Record'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Month amount: ${_money(monthRevenue)}'),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Notes'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Create'),
            ),
          ],
        );
      },
    );

    if (saved != true) {
      notesController.dispose();
      return;
    }

    final now = DateTime.now();
    await FirebaseFirestore.instance.collection('reconciliations').add({
      'period': '${now.year}-${now.month.toString().padLeft(2, '0')}',
      'amount': monthRevenue,
      'notes': notesController.text.trim(),
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
    });
    notesController.dispose();
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
      stream: _ordersStream,
      builder: (context, ordersSnap) {
        if (ordersSnap.connectionState == ConnectionState.waiting) {
          return const _FinanceSkeleton();
        }
        if (ordersSnap.hasError) {
          return FirestoreErrorPanel(
            title: 'Finance cannot load orders.',
            error: ordersSnap.error,
          );
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _recordsStream,
          builder: (context, recordsSnap) {
            if (recordsSnap.connectionState == ConnectionState.waiting) {
              return const _FinanceSkeleton();
            }
            if (recordsSnap.hasError) {
              return FirestoreErrorPanel(
                title: 'Reconciliation records cannot be loaded.',
                error: recordsSnap.error,
              );
            }

            final orderDocs = ordersSnap.data?.docs ?? [];
            final recordDocs = recordsSnap.data?.docs ?? [];

            return ValueListenableBuilder<String>(
              valueListenable: widget.searchQuery,
              builder: (context, query, _) {
                final normalized = query.trim().toLowerCase();
                final orders = orderDocs
                    .map(_FinanceOrder.fromDoc)
                    .where((item) => item.matches(normalized))
                    .toList()
                  ..sort((a, b) => b.sortKey.compareTo(a.sortKey));
                final records = recordDocs
                    .map(_FinanceRecord.fromDoc)
                    .where((item) => item.matches(normalized))
                    .toList()
                  ..sort((a, b) => b.sortKey.compareTo(a.sortKey));

                final now = DateTime.now();
                final monthStart = DateTime(now.year, now.month, 1);
                final todayStart = DateTime(now.year, now.month, now.day);
                final todayEnd = todayStart.add(const Duration(days: 1));

                double todayRevenue = 0;
                double monthRevenue = 0;
                double totalRevenue = 0;
                int pendingOrders = 0;
                int deliveredOrders = 0;
                final paymentTotals = <String, double>{};
                final stageCounts = <String, int>{};

                for (final order in orders) {
                  totalRevenue += order.total;
                  if (order.stage == 'delivered') {
                    deliveredOrders += 1;
                  } else {
                    pendingOrders += 1;
                  }
                  final placedAt = order.placedAt;
                  if (placedAt != null) {
                    if (!placedAt.isBefore(todayStart) &&
                        placedAt.isBefore(todayEnd)) {
                      todayRevenue += order.total;
                    }
                    if (!placedAt.isBefore(monthStart)) {
                      monthRevenue += order.total;
                    }
                  }
                  paymentTotals[order.paymentMethod] =
                      (paymentTotals[order.paymentMethod] ?? 0) + order.total;
                  stageCounts[order.stage] = (stageCounts[order.stage] ?? 0) + 1;
                }

                final avgOrder =
                    orders.isEmpty ? 0.0 : totalRevenue / orders.length;
                final reconciledAmount =
                    records.fold<double>(0, (total, item) => total + item.amount);
                final openRecords =
                    records.where((item) => item.status == 'open').length;
                final unreconciled = (monthRevenue - reconciledAmount)
                    .clamp(0.0, double.infinity)
                    .toDouble();

                final paymentBars = paymentTotals.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value));
                final stageBars = stageCounts.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value));

                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AdminPageIntro(
                        icon: Icons.account_balance_wallet_outlined,
                        title: 'Finance Hub',
                        subtitle:
                            'A fuller command center for revenue, reconciliation, payment mix, and order health.',
                        badges: [
                          AdminBadge(
                            icon: Icons.today_outlined,
                            label: 'Today ${_money(todayRevenue)}',
                          ),
                          AdminBadge(
                            icon: Icons.calendar_month_outlined,
                            label: 'Month ${_money(monthRevenue)}',
                          ),
                          AdminBadge(
                            icon: Icons.rule_folder_outlined,
                            label: '$openRecords open records',
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _MetricTile(
                            title: 'Today Revenue',
                            value: _money(todayRevenue),
                            icon: Icons.today_outlined,
                          ),
                          _MetricTile(
                            title: 'Month Revenue',
                            value: _money(monthRevenue),
                            icon: Icons.calendar_month_outlined,
                          ),
                          _MetricTile(
                            title: 'Average Order',
                            value: _money(avgOrder),
                            icon: Icons.analytics_outlined,
                          ),
                          _MetricTile(
                            title: 'Pending Orders',
                            value: '$pendingOrders',
                            icon: Icons.hourglass_bottom_outlined,
                          ),
                          _MetricTile(
                            title: 'Delivered Orders',
                            value: '$deliveredOrders',
                            icon: Icons.local_shipping_outlined,
                          ),
                          _MetricTile(
                            title: 'Unreconciled',
                            value: _money(unreconciled),
                            icon: Icons.warning_amber_rounded,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final wide = constraints.maxWidth >= 1120;

                          final left = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AdminSectionCard(
                                title: 'Payment Method Breakdown',
                                subtitle: 'See where revenue is landing.',
                                child: paymentBars.isEmpty
                                    ? const Text('No payment data yet.')
                                    : Column(
                                        children: paymentBars.map((entry) {
                                          return _BarItem(
                                            label: _prettyPaymentMethod(
                                              entry.key,
                                            ),
                                            valueLabel: _money(entry.value),
                                            value: entry.value,
                                            total: totalRevenue,
                                            color: _paymentColor(entry.key),
                                          );
                                        }).toList(),
                                      ),
                              ),
                              const SizedBox(height: 14),
                              AdminSectionCard(
                                title: 'Order Health',
                                subtitle: 'Revenue flow by stage.',
                                child: stageBars.isEmpty
                                    ? const Text('No stage data yet.')
                                    : Column(
                                        children: stageBars.map((entry) {
                                          return _BarItem(
                                            label: _stageLabel(entry.key),
                                            valueLabel: '${entry.value} orders',
                                            value: entry.value.toDouble(),
                                            total: orders.isEmpty
                                                ? 0.0
                                                : orders.length.toDouble(),
                                            color: _stageColor(entry.key),
                                          );
                                        }).toList(),
                                      ),
                              ),
                            ],
                          );

                          final right = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AdminSectionCard(
                                title: 'Reconciliation',
                                subtitle:
                                    'Open records, closed records, and monthly gap.',
                                action: FilledButton.icon(
                                  onPressed: () =>
                                      _createRecord(context, monthRevenue),
                                  icon: const Icon(Icons.add),
                                  label: const Text('New Record'),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        _Pill(
                                          label: '$openRecords open',
                                          color: Colors.orange,
                                        ),
                                        _Pill(
                                          label:
                                              'Reconciled ${_money(reconciledAmount)}',
                                          color: Colors.green,
                                        ),
                                        _Pill(
                                          label:
                                              'Gap ${_money(unreconciled)}',
                                          color: Colors.redAccent,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    if (records.isEmpty)
                                      const AdminEmptyState(
                                        icon: Icons.rule_folder_outlined,
                                        title: 'No reconciliation records',
                                        message:
                                            'Create the first record to track monthly settlement.',
                                      )
                                    else
                                      Column(
                                        children: records.take(5).map((record) {
                                          return Padding(
                                            padding:
                                                const EdgeInsets.only(bottom: 10),
                                            child: _RecordTile(record: record),
                                          );
                                        }).toList(),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),
                              AdminSectionCard(
                                title: 'Recent Orders',
                                subtitle:
                                    'The latest transactions that shape your numbers.',
                                child: orders.isEmpty
                                    ? AdminEmptyState(
                                        icon: Icons.receipt_long_outlined,
                                        title: normalized.isEmpty
                                            ? 'No orders yet'
                                            : 'No matches found',
                                        message: normalized.isEmpty
                                            ? 'Orders will appear here once transactions begin.'
                                            : 'Try another search term for finance records.',
                                      )
                                    : Column(
                                        children: orders.take(6).map((order) {
                                          return Padding(
                                            padding:
                                                const EdgeInsets.only(bottom: 10),
                                            child: _OrderTile(order: order),
                                          );
                                        }).toList(),
                                      ),
                              ),
                            ],
                          );

                          if (!wide) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                left,
                                const SizedBox(height: 14),
                                right,
                              ],
                            );
                          }

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: left),
                              const SizedBox(width: 14),
                              Expanded(child: right),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
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
          SkeletonBox(height: 180),
          SizedBox(height: 14),
          SkeletonBox(height: 220),
        ],
      ),
    );
  }
}

String _money(double value) => 'GHS ${value.toStringAsFixed(2)}';

class _FinanceOrder {
  const _FinanceOrder({
    required this.orderNumber,
    required this.total,
    required this.paymentMethod,
    required this.stage,
    required this.userName,
    required this.userPhone,
    required this.destination,
    required this.vendorNames,
    required this.placedAt,
    required this.sortKey,
    required this.searchPool,
  });

  final String orderNumber;
  final double total;
  final String paymentMethod;
  final String stage;
  final String userName;
  final String userPhone;
  final String destination;
  final List<String> vendorNames;
  final DateTime? placedAt;
  final DateTime sortKey;
  final String searchPool;

  factory _FinanceOrder.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final user = _map(data['user']);
    final payment = _map(data['payment']);
    final delivery = _map(data['delivery']);
    final totals = _map(data['totals']);
    final orderNumber = data['orderNumber']?.toString().trim().isNotEmpty == true
        ? data['orderNumber'].toString().trim()
        : doc.id;
    final placedAt = _date(data['placedAt']) ?? _date(data['timestamp']);
    final total = _amount(totals['total']);
    final paymentMethod = _paymentMethod(payment['method']?.toString());
    final stage = _normalizeStage(data['stage']?.toString());
    final userName = user['name']?.toString().trim() ?? '';
    final userPhone = user['phone']?.toString().trim() ?? '';
    final destination = _destination(delivery);
    final vendors = _vendors(data);
    final pool = [
      orderNumber,
      doc.id,
      userName,
      userPhone,
      paymentMethod,
      stage,
      _stageLabel(stage),
      destination,
      vendors.join(' '),
      _formatOrderPool(data['items']),
      _money(total),
    ].join(' ').toLowerCase();

    return _FinanceOrder(
      orderNumber: orderNumber,
      total: total,
      paymentMethod: paymentMethod,
      stage: stage,
      userName: userName.isNotEmpty ? userName : 'Unknown',
      userPhone: userPhone.isNotEmpty ? userPhone : 'No phone',
      destination: destination,
      vendorNames: vendors,
      placedAt: placedAt,
      sortKey: placedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
      searchPool: pool,
    );
  }

  bool matches(String query) {
    if (query.isEmpty) {
      return true;
    }
    return searchPool.contains(query);
  }
}

class _FinanceRecord {
  const _FinanceRecord({
    required this.period,
    required this.amount,
    required this.notes,
    required this.status,
    required this.createdAt,
    required this.sortKey,
    required this.searchPool,
  });

  final String period;
  final double amount;
  final String notes;
  final String status;
  final DateTime? createdAt;
  final DateTime sortKey;
  final String searchPool;

  factory _FinanceRecord.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final period = data['period']?.toString().trim().isNotEmpty == true
        ? data['period'].toString().trim()
        : doc.id;
    final amount = _amount(data['amount']);
    final notes = data['notes']?.toString().trim() ?? '';
    final status = (data['status']?.toString().trim().isNotEmpty == true
            ? data['status'].toString().trim()
            : 'open')
        .toLowerCase();
    final createdAt = _date(data['createdAt']) ?? _date(data['updatedAt']);
    final pool = [period, doc.id, notes, status, _money(amount)]
        .join(' ')
        .toLowerCase();

    return _FinanceRecord(
      period: period,
      amount: amount,
      notes: notes,
      status: status,
      createdAt: createdAt,
      sortKey: createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
      searchPool: pool,
    );
  }

  bool matches(String query) {
    if (query.isEmpty) {
      return true;
    }
    return searchPool.contains(query);
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 190,
      child: Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.45)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: scheme.primary, size: 18),
              ),
              const SizedBox(height: 10),
              Text(title, style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 4),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _BarItem extends StatelessWidget {
  const _BarItem({
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.total,
    required this.color,
  });

  final String label;
  final String valueLabel;
  final double value;
  final double total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ratio = total <= 0 ? 0.0 : (value / total).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                valueLabel,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Colors.black54,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: ratio,
              backgroundColor: color.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  const _OrderTile({required this.order});

  final _FinanceOrder order;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Order #${order.orderNumber}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              _Pill(label: _stageLabel(order.stage), color: _stageColor(order.stage)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${order.userName}  •  ${order.userPhone}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _TinyTag(icon: Icons.payments_outlined, label: order.paymentMethod),
              _TinyTag(icon: Icons.place_outlined, label: order.destination),
              _TinyTag(
                icon: Icons.storefront_outlined,
                label: order.vendorNames.isEmpty
                    ? 'No vendor'
                    : order.vendorNames.take(2).join(', '),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  order.placedAt == null
                      ? 'Date unavailable'
                      : _formatDate(order.placedAt!),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.black54,
                      ),
                ),
              ),
              Text(
                _money(order.total),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: scheme.primary,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({required this.record});

  final _FinanceRecord record;

  @override
  Widget build(BuildContext context) {
    final color = record.status == 'closed'
        ? Colors.green
        : record.status == 'pending'
            ? Colors.orange
            : Colors.redAccent;

    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black12),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  record.period,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              _Pill(label: record.status.toUpperCase(), color: color),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            record.notes.isEmpty ? 'No notes provided' : record.notes,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  record.createdAt == null
                      ? 'Date unavailable'
                      : _formatDate(record.createdAt!),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.black54,
                      ),
                ),
              ),
              Text(
                _money(record.amount),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TinyTag extends StatelessWidget {
  const _TinyTag({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.black54),
          const SizedBox(width: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

String _prettyPaymentMethod(String method) {
  switch (method) {
    case 'mobile money':
      return 'Mobile Money';
    case 'cash':
      return 'Cash';
    case 'card':
      return 'Card';
    case 'unknown':
      return 'Unknown';
    default:
      return method[0].toUpperCase() + method.substring(1);
  }
}

String _paymentMethod(String? method) {
  final normalized = (method ?? '').trim().toLowerCase();
  switch (normalized) {
    case 'momo':
      return 'mobile money';
    case 'mobile money':
      return 'mobile money';
    case 'cash':
      return 'cash';
    case 'card':
      return 'card';
    default:
      return normalized.isEmpty ? 'unknown' : normalized;
  }
}

String _normalizeStage(String? stage) {
  switch ((stage ?? '').trim().toLowerCase()) {
    case 'preparing':
    case 'preaparing':
      return 'preparing';
    case 'inkitchen':
    case 'in kitchen':
      return 'inKitchen';
    case 'delivered':
      return 'delivered';
    default:
      return 'placed';
  }
}

String _stageLabel(String stage) {
  switch (_normalizeStage(stage)) {
    case 'preparing':
      return 'Preparing';
    case 'inKitchen':
      return 'In Kitchen';
    case 'delivered':
      return 'Delivered';
    default:
      return 'Placed';
  }
}

Color _stageColor(String stage) {
  switch (_normalizeStage(stage)) {
    case 'preparing':
      return const Color(0xfff39c12);
    case 'inKitchen':
      return const Color(0xff2980b9);
    case 'delivered':
      return const Color(0xff27ae60);
    default:
      return const Color(0xff8e44ad);
  }
}

Color _paymentColor(String method) {
  switch (_paymentMethod(method)) {
    case 'mobile money':
      return const Color(0xff2e7d32);
    case 'cash':
      return const Color(0xffef6c00);
    case 'card':
      return const Color(0xff1565c0);
    default:
      return const Color(0xff6c5ce7);
  }
}

String _destination(Map<String, dynamic> delivery) {
  final type = delivery['type']?.toString() ?? '';
  final table = delivery['tableNumber']?.toString() ?? '';
  final address = delivery['address']?.toString() ?? '';
  if (type == 'table') {
    return 'Table ${table.isEmpty ? '-' : table}';
  }
  return address.isEmpty ? 'Doorstep' : address;
}

List<String> _vendors(Map<String, dynamic> data) {
  final values = <String>{};
  void add(String raw) {
    final value = raw.trim();
    if (value.isNotEmpty) {
      values.add(value);
    }
  }

  add((data['vendorName'] ?? '').toString());
  final vendorNames = (data['vendorNames'] as List?) ?? const [];
  for (final item in vendorNames) {
    add(item?.toString() ?? '');
  }
  add((data['vendorId'] ?? '').toString());
  final vendorIds = (data['vendorIds'] as List?) ?? const [];
  for (final item in vendorIds) {
    add(item?.toString() ?? '');
  }
  final items = (data['items'] as List?) ?? const [];
  for (final item in items) {
    final map = _map(item);
    add((map['vendorName'] ?? '').toString());
    add((map['vendorId'] ?? '').toString());
  }

  if (values.isEmpty) {
    values.add('Unassigned vendor');
  }
  return values.toList(growable: false);
}

String _formatOrderPool(Object? itemsValue) {
  final items = (itemsValue as List?) ?? const [];
  return items
      .whereType<Map>()
      .map((item) => (item['title'] ?? '').toString())
      .where((title) => title.isNotEmpty)
      .join(' ');
}

DateTime? _date(Object? value) {
  if (value is Timestamp) {
    return value.toDate();
  }
  if (value is DateTime) {
    return value;
  }
  if (value is String) {
    return DateTime.tryParse(value);
  }
  return null;
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, val) => MapEntry(key.toString(), val));
  }
  return const <String, dynamic>{};
}

double _amount(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  final raw = value?.toString().trim() ?? '';
  if (raw.isEmpty) {
    return 0;
  }
  final sanitized = raw.replaceAll(RegExp(r'[^0-9,\.\-]'), '');
  if (sanitized.isEmpty) {
    return 0;
  }
  final normalized = sanitized.contains('.') && sanitized.contains(',')
      ? sanitized.replaceAll(',', '')
      : sanitized.replaceAll(',', '.');
  return double.tryParse(normalized) ?? 0;
}

String _formatDate(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '${value.year}-$month-$day $hour:$minute';
}
