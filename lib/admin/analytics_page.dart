// ignore_for_file: avoid_types_as_parameter_names, prefer_const_literals_to_create_immutables, prefer_const_constructors

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'admin_ui.dart';
import 'loading_skeleton.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _ordersStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _foodsStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _vendorsStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _usersStream;

  String _range = '30d';

  @override
  void initState() {
    super.initState();
    final firestore = FirebaseFirestore.instance;
    _ordersStream = firestore.collection('orders').snapshots();
    _foodsStream = firestore.collection('foods').snapshots();
    _vendorsStream = firestore.collection('vendors').snapshots();
    _usersStream = firestore.collection('users').snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _ordersStream,
      builder: (context, ordersSnap) {
        if (ordersSnap.connectionState == ConnectionState.waiting) {
          return const _AnalyticsSkeleton();
        }
        if (ordersSnap.hasError) {
          return FirestoreErrorPanel(
            title: 'Analytics cannot load orders.',
            error: ordersSnap.error,
          );
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _foodsStream,
          builder: (context, foodsSnap) {
            if (foodsSnap.connectionState == ConnectionState.waiting) {
              return const _AnalyticsSkeleton();
            }
            if (foodsSnap.hasError) {
              return FirestoreErrorPanel(
                title: 'Analytics cannot load foods.',
                error: foodsSnap.error,
              );
            }

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _vendorsStream,
              builder: (context, vendorsSnap) {
                if (vendorsSnap.connectionState == ConnectionState.waiting) {
                  return const _AnalyticsSkeleton();
                }
                if (vendorsSnap.hasError) {
                  return FirestoreErrorPanel(
                    title: 'Analytics cannot load vendors.',
                    error: vendorsSnap.error,
                  );
                }

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _usersStream,
                  builder: (context, usersSnap) {
                    if (usersSnap.connectionState == ConnectionState.waiting) {
                      return const _AnalyticsSkeleton();
                    }

                    final orders = ordersSnap.data?.docs ?? [];
                    final foods = foodsSnap.data?.docs ?? [];
                    final vendors = vendorsSnap.data?.docs ?? [];
                    final users = usersSnap.data?.docs ?? [];
                    final filteredOrders = _applyRangeFilter(orders, _range);

                    final totalOrders = filteredOrders.length;
                    final revenue = filteredOrders.fold<double>(0, (sum, doc) {
                      return sum + _orderTotal(doc.data());
                    });
                    final avgOrder =
                        totalOrders == 0 ? 0 : revenue / totalOrders;
                    final delivered = filteredOrders.where((doc) {
                      return _normalizeStage(doc.data()['stage']?.toString()) ==
                          'delivered';
                    }).length;
                    final pending = totalOrders - delivered;
                    final completion = totalOrders == 0
                        ? 0.0
                        : (delivered / totalOrders) * 100;
                    final latestOrder = _latestOrder(filteredOrders);
                    final activeFoods = foods.where((doc) {
                      return doc.data()['isActive'] != false;
                    }).length;
                    final activeVendors = vendors.where((doc) {
                      return doc.data()['isActive'] != false;
                    }).length;

                    final vendorMap = <String, String>{
                      for (final doc in vendors)
                        doc.id: _clean(doc.data()['name']).isNotEmpty
                            ? _clean(doc.data()['name'])
                            : doc.id,
                    };

                    final stageCounts = <String, int>{
                      'placed': 0,
                      'preparing': 0,
                      'in kitchen': 0,
                      'delivered': 0,
                    };
                    final paymentCounts = <String, int>{};
                    final dailyRevenue = <DateTime, double>{};
                    final foodCounts = <String, int>{};
                    final vendorLoad = <String, _VendorRow>{};

                    for (final vendor in vendors) {
                      final data = vendor.data();
                      final name = _clean(data['name']).isNotEmpty
                          ? _clean(data['name'])
                          : vendor.id;
                      vendorLoad[name.toLowerCase()] = _VendorRow(
                        name: name,
                        count: 0,
                        latest: null,
                        active: data['isActive'] != false,
                      );
                    }

                    for (final doc in filteredOrders) {
                      final data = doc.data();
                      final stage = _normalizeStage(data['stage']?.toString());
                      if (stage != null && stageCounts.containsKey(stage)) {
                        stageCounts[stage] = stageCounts[stage]! + 1;
                      }

                      final total = _orderTotal(data);
                      final date = _orderDate(data);
                      if (date != null) {
                        final bucket =
                            DateTime(date.year, date.month, date.day);
                        dailyRevenue[bucket] =
                            (dailyRevenue[bucket] ?? 0) + total;
                      }

                      final payment = _paymentLabel(data);
                      paymentCounts[payment] =
                          (paymentCounts[payment] ?? 0) + 1;

                      for (final name in _orderItems(data)) {
                        foodCounts[name] = (foodCounts[name] ?? 0) + 1;
                      }

                      for (final vendorName in _vendorNames(data, vendorMap)) {
                        final key = vendorName.toLowerCase();
                        final row = vendorLoad[key];
                        if (row == null) {
                          vendorLoad[key] = _VendorRow(
                            name: vendorName,
                            count: 1,
                            latest: date,
                            active: true,
                          );
                          continue;
                        }
                        row.count += 1;
                        if (date != null &&
                            (row.latest == null || date.isAfter(row.latest!))) {
                          row.latest = date;
                        }
                      }
                    }

                    final revenueTrend = dailyRevenue.entries.toList()
                      ..sort((a, b) => a.key.compareTo(b.key));
                    final topPayments = paymentCounts.entries.toList()
                      ..sort((a, b) => b.value.compareTo(a.value));
                    final topFoods = foodCounts.entries.toList()
                      ..sort((a, b) => b.value.compareTo(a.value));
                    final topVendors = vendorLoad.values.toList()
                      ..sort((a, b) => b.count.compareTo(a.count));

                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1360),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final wide = constraints.maxWidth >= 1120;

                              final hero = AdminPageIntro(
                                icon: Icons.insights_outlined,
                                title: 'Analytics Dashboard',
                                subtitle:
                                    'A richer view of revenue, fulfillment, and vendor performance.',
                                trailing: SegmentedButton<String>(
                                  segments: const [
                                    ButtonSegment(
                                        value: 'today', label: Text('Today')),
                                    ButtonSegment(
                                        value: '7d', label: Text('7d')),
                                    ButtonSegment(
                                        value: '30d', label: Text('30d')),
                                    ButtonSegment(
                                        value: 'all', label: Text('All')),
                                  ],
                                  selected: {_range},
                                  onSelectionChanged: (selection) {
                                    setState(() => _range = selection.first);
                                  },
                                ),
                                badges: [
                                  AdminBadge(
                                    icon: Icons.receipt_long_outlined,
                                    label: '$totalOrders orders in view',
                                  ),
                                  AdminBadge(
                                    icon: Icons.payments_outlined,
                                    label:
                                        'GHS ${revenue.toStringAsFixed(2)} revenue',
                                  ),
                                  AdminBadge(
                                    icon: Icons.schedule_outlined,
                                    label: latestOrder == null
                                        ? 'No recent orders'
                                        : _formatDate(latestOrder),
                                  ),
                                  AdminBadge(
                                    icon: Icons.people_outline,
                                    label: '${users.length} users',
                                  ),
                                ],
                              );

                              final metrics = Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  _MetricCard(
                                      title: 'Orders',
                                      value: totalOrders.toString(),
                                      icon: Icons.receipt_long),
                                  _MetricCard(
                                      title: 'Revenue',
                                      value:
                                          'GHS ${revenue.toStringAsFixed(2)}',
                                      icon: Icons.payments),
                                  _MetricCard(
                                      title: 'Avg Order',
                                      value:
                                          'GHS ${avgOrder.toStringAsFixed(2)}',
                                      icon: Icons.show_chart),
                                  _MetricCard(
                                      title: 'Delivered',
                                      value: delivered.toString(),
                                      icon: Icons.check_circle_outline),
                                  _MetricCard(
                                      title: 'Pending',
                                      value: pending.toString(),
                                      icon: Icons.hourglass_bottom_outlined),
                                  _MetricCard(
                                      title: 'Foods',
                                      value: activeFoods.toString(),
                                      icon: Icons.restaurant_menu),
                                  _MetricCard(
                                      title: 'Vendors',
                                      value: activeVendors.toString(),
                                      icon: Icons.storefront_outlined),
                                  _MetricCard(
                                      title: 'Completion',
                                      value:
                                          '${completion.toStringAsFixed(1)}%',
                                      icon: Icons.track_changes_outlined),
                                ],
                              );
                              final revenueCard = AdminSectionCard(
                                title: 'Revenue Trend',
                                subtitle:
                                    'Daily revenue for the selected range.',
                                child: revenueTrend.isEmpty
                                    ? const Text(
                                        'No revenue data in this range.')
                                    : _TrendBars(entries: revenueTrend),
                              );

                              final stageCard = AdminSectionCard(
                                title: 'Order Stage Breakdown',
                                subtitle:
                                    'See where orders are concentrated in the funnel.',
                                child:
                                    _StageBreakdown(stageCounts: stageCounts),
                              );

                              final vendorCard = AdminSectionCard(
                                title: 'Vendor Load',
                                subtitle:
                                    'Which vendors are handling the most work right now.',
                                child: topVendors.isEmpty
                                    ? const Text('No vendor activity yet.')
                                    : Column(
                                        children: topVendors.take(7).map((row) {
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 10),
                                            child: _RankRow(
                                              title: row.name,
                                              subtitle: row.latest == null
                                                  ? 'No orders'
                                                  : _formatDate(row.latest!),
                                              value: '${row.count} orders',
                                              active: row.active,
                                            ),
                                          );
                                        }).toList(),
                                      ),
                              );

                              final paymentCard = AdminSectionCard(
                                title: 'Payment Mix',
                                subtitle:
                                    'Which payment methods are used most often.',
                                child: topPayments.isEmpty
                                    ? const Text('No payment data available.')
                                    : Column(
                                        children:
                                            topPayments.take(6).map((entry) {
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 10),
                                            child: _BarRow(
                                              label: entry.key,
                                              value: entry.value,
                                              total: totalOrders == 0
                                                  ? 1
                                                  : totalOrders,
                                              color: Colors.teal,
                                            ),
                                          );
                                        }).toList(),
                                      ),
                              );

                              final foodCard = AdminSectionCard(
                                title: 'Top Menu Items',
                                subtitle:
                                    'Items most frequently seen in recent orders.',
                                child: topFoods.isEmpty
                                    ? const Text('No menu item activity yet.')
                                    : Column(
                                        children: topFoods.take(7).map((entry) {
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 10),
                                            child: _BarRow(
                                              label: entry.key,
                                              value: entry.value,
                                              total: totalOrders == 0
                                                  ? 1
                                                  : totalOrders,
                                              color: Colors.deepPurple,
                                            ),
                                          );
                                        }).toList(),
                                      ),
                              );

                              final catalogCard = AdminSectionCard(
                                title: 'Catalog Health',
                                subtitle:
                                    'A quick count of the active menu catalog.',
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _RankRow(
                                      title: 'Foods collection',
                                      subtitle: 'Total food documents',
                                      value: foods.length.toString(),
                                      active: true,
                                    ),
                                    const SizedBox(height: 10),
                                    _RankRow(
                                      title: 'Active foods',
                                      subtitle: 'Currently available items',
                                      value: activeFoods.toString(),
                                      active: true,
                                    ),
                                  ],
                                ),
                              );

                              final left = Column(
                                children: [
                                  revenueCard,
                                  const SizedBox(height: 14),
                                  stageCard,
                                  const SizedBox(height: 14),
                                  vendorCard,
                                ],
                              );
                              final right = Column(
                                children: [
                                  paymentCard,
                                  const SizedBox(height: 14),
                                  foodCard,
                                  const SizedBox(height: 14),
                                  catalogCard,
                                ],
                              );

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  hero,
                                  const SizedBox(height: 14),
                                  metrics,
                                  const SizedBox(height: 14),
                                  if (wide)
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(flex: 2, child: left),
                                        const SizedBox(width: 14),
                                        SizedBox(width: 390, child: right),
                                      ],
                                    )
                                  else ...[
                                    left,
                                    const SizedBox(height: 14),
                                    right,
                                  ],
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

class _VendorRow {
  _VendorRow({
    required this.name,
    required this.count,
    required this.latest,
    required this.active,
  });

  final String name;
  int count;
  DateTime? latest;
  final bool active;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
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
      width: 170,
      child: Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side:
              BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.45)),
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
                child: Icon(icon, size: 18, color: scheme.primary),
              ),
              const SizedBox(height: 10),
              Text(title, style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 4),
              Text(
                value,
                maxLines: 2,
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

class _BarRow extends StatelessWidget {
  const _BarRow({
    required this.label,
    required this.value,
    required this.total,
    required this.color,
  });

  final String label;
  final int value;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ratio = total <= 0 ? 0.0 : (value / total).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
                width: 10,
                height: 10,
                decoration:
                    BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              value.toString(),
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
            value: ratio,
            minHeight: 8,
            backgroundColor: color.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _SmallPill extends StatelessWidget {
  const _SmallPill({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.active,
  });

  final String title;
  final String subtitle;
  final String value;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor:
                (active ? Colors.green : Colors.grey).withValues(alpha: 0.12),
            child: Text(
              title.isEmpty ? '?' : title[0].toUpperCase(),
              style: TextStyle(
                color: active ? Colors.green : Colors.grey,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _SmallPill(label: value, color: active ? Colors.green : Colors.grey),
        ],
      ),
    );
  }
}

class _TrendBars extends StatelessWidget {
  const _TrendBars({required this.entries});

  final List<MapEntry<DateTime, double>> entries;

  @override
  Widget build(BuildContext context) {
    final maxValue = entries
        .map((entry) => entry.value)
        .fold<double>(0, (a, b) => a > b ? a : b);
    return Column(
      children: entries.map((entry) {
        final ratio = maxValue <= 0 ? 0.0 : entry.value / maxValue;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _formatTrendDate(entry.key),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'GHS ${entry.value.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 10,
                  backgroundColor: Colors.deepPurple.withValues(alpha: 0.10),
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Colors.deepPurple),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _StageBreakdown extends StatelessWidget {
  const _StageBreakdown({required this.stageCounts});

  final Map<String, int> stageCounts;

  static const _colors = {
    'placed': Color(0xff8e44ad),
    'preparing': Color(0xfff39c12),
    'in kitchen': Color(0xff2980b9),
    'delivered': Color(0xff27ae60),
  };

  @override
  Widget build(BuildContext context) {
    final total = stageCounts.values.fold<int>(0, (acc, v) => acc + v);
    if (total == 0) {
      return const Text('No stage data available for selected range.');
    }

    final entries = stageCounts.entries.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 16,
            child: Row(
              children: entries.map((entry) {
                final ratio = entry.value / total;
                return Expanded(
                  flex: (ratio * 1000).round().clamp(1, 1000),
                  child: Container(color: _colors[entry.key] ?? Colors.grey),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: entries.map((entry) {
            final color = _colors[entry.key] ?? Colors.grey;
            final percent = (entry.value / total) * 100;
            return _StageStatTile(
              label: entry.key,
              value: entry.value,
              percent: percent,
              color: color,
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _StageStatTile extends StatelessWidget {
  const _StageStatTile({
    required this.label,
    required this.value,
    required this.percent,
    required this.color,
  });

  final String label;
  final int value;
  final double percent;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 170,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 6),
          Text(
            '$value orders',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          Text(
            '${percent.toStringAsFixed(1)}%',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _AnalyticsSkeleton extends StatelessWidget {
  const _AnalyticsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.all(20),
      children: [
        SkeletonBox(height: 120),
        SizedBox(height: 14),
        SkeletonBox(height: 120),
        SizedBox(height: 14),
        SkeletonBox(height: 220),
        SizedBox(height: 14),
        SkeletonBox(height: 220),
      ],
    );
  }
}

List<QueryDocumentSnapshot<Map<String, dynamic>>> _applyRangeFilter(
  List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  String range,
) {
  if (range == 'all') return docs;
  final now = DateTime.now();
  if (range == 'today') {
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    return docs.where((doc) {
      final date = _orderDate(doc.data());
      return date != null && !date.isBefore(start) && date.isBefore(end);
    }).toList();
  }
  final days = range == '7d' ? 7 : 30;
  final start = now.subtract(Duration(days: days));
  return docs.where((doc) {
    final date = _orderDate(doc.data());
    return date != null && !date.isBefore(start);
  }).toList();
}

double _orderTotal(Map<String, dynamic> data) {
  final totals = data['totals'];
  if (totals is Map) {
    final total = totals['total'];
    if (total is num) return total.toDouble();
  }
  final direct = data['total'];
  if (direct is num) return direct.toDouble();
  return 0;
}

DateTime? _orderDate(Map<String, dynamic> data) {
  final value = data['placedAt'];
  if (value is Timestamp) return value.toDate();
  if (value is String) return DateTime.tryParse(value);
  if (value is DateTime) return value;
  return null;
}

DateTime? _latestOrder(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
  DateTime? latest;
  for (final doc in docs) {
    final date = _orderDate(doc.data());
    if (date == null) continue;
    if (latest == null || date.isAfter(latest)) latest = date;
  }
  return latest;
}

String? _normalizeStage(String? stage) {
  switch ((stage ?? '').trim().toLowerCase()) {
    case 'placed':
      return 'placed';
    case 'preparing':
    case 'preaparing':
      return 'preparing';
    case 'inkitchen':
    case 'in kitchen':
      return 'in kitchen';
    case 'delivered':
      return 'delivered';
    default:
      return null;
  }
}

List<String> _vendorNames(
  Map<String, dynamic> data,
  Map<String, String> vendorMap,
) {
  final names = <String>{};
  void addName(String raw) {
    final value = raw.trim();
    if (value.isNotEmpty) names.add(value);
  }

  void addId(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return;
    final resolved = vendorMap[value];
    if (resolved != null && resolved.isNotEmpty) names.add(resolved);
  }

  addName((data['vendorName'] ?? '').toString());
  addId((data['vendorId'] ?? '').toString());
  final vendorNames = (data['vendorNames'] as List?) ?? const [];
  for (final vendor in vendorNames) {
    addName(vendor?.toString() ?? '');
  }
  final vendorIds = (data['vendorIds'] as List?) ?? const [];
  for (final vendor in vendorIds) {
    addId(vendor?.toString() ?? '');
  }
  final items = (data['items'] as List?) ?? const [];
  for (final item in items) {
    final map = (item as Map?) ?? const {};
    addName((map['vendorName'] ?? '').toString());
    addId((map['vendorId'] ?? '').toString());
  }
  if (names.isEmpty) names.add('Unassigned vendor');
  return names.toList(growable: false);
}

List<String> _orderItems(Map<String, dynamic> data) {
  final names = <String>{};
  void add(Object? value) {
    final cleaned = _clean(value);
    if (cleaned.isNotEmpty) names.add(cleaned);
  }

  final items = data['items'];
  if (items is List) {
    for (final item in items) {
      if (item is Map) {
        add(item['name']);
        add(item['title']);
        add(item['foodName']);
        add(item['itemName']);
      } else {
        add(item);
      }
    }
  }
  add(data['foodName']);
  add(data['itemName']);
  add(data['productName']);
  return names.toList(growable: false);
}

String _paymentLabel(Map<String, dynamic> data) {
  final candidates = [
    data['paymentMethod'],
    data['paymentType'],
    data['payment'],
    data['method'],
  ];
  for (final candidate in candidates) {
    final value = _clean(candidate);
    if (value.isNotEmpty) return _pretty(value);
  }
  return 'Unknown';
}

String _pretty(String value) {
  return value
      .replaceAll(RegExp(r'[_-]+'), ' ')
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .map((part) {
    final lower = part.toLowerCase();
    return lower[0].toUpperCase() + lower.substring(1);
  }).join(' ');
}

String _clean(Object? value) => value?.toString().trim() ?? '';

String _formatDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '${date.year}-$month-$day $hour:$minute';
}

String _formatTrendDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$month/$day';
}
