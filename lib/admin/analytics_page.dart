import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'loading_skeleton.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  String _range = '30d';

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('orders').snapshots(),
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
          stream: FirebaseFirestore.instance.collection('foods').snapshots(),
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
              stream: FirebaseFirestore.instance.collection('users').snapshots(),
              builder: (context, usersSnap) {
                if (usersSnap.connectionState == ConnectionState.waiting) {
                  return const _AnalyticsSkeleton();
                }
                final usersReadFailed = usersSnap.hasError;

                final orders = ordersSnap.data?.docs ?? [];
                final foods = foodsSnap.data?.docs ?? [];
                final users = usersSnap.data?.docs ?? [];
                final usersCount = usersSnap.data?.size ?? users.length;
                final filteredOrders = _applyRangeFilter(orders, _range);

                final totalRevenue = filteredOrders.fold<double>(0, (acc, doc) {
                  final totals = doc.data()['totals'] as Map?;
                  final total = totals?['total'];
                  if (total is num) {
                    return acc + total.toDouble();
                  }
                  return acc;
                });

                final delivered = filteredOrders.where((doc) {
                  return doc.data()['stage']?.toString() == 'delivered';
                }).length;

                final avgValue = filteredOrders.isEmpty
                    ? 0
                    : totalRevenue / filteredOrders.length;

                final stageCounts = <String, int>{
                  'placed': 0,
                  'preparing': 0,
                  'inKitchen': 0,
                  'delivered': 0,
                };
                final foodCounts = <String, int>{};
                for (final doc in filteredOrders) {
                  final data = doc.data();
                  final stage = data['stage']?.toString();
                  if (stage != null && stageCounts.containsKey(stage)) {
                    stageCounts[stage] = stageCounts[stage]! + 1;
                  }
                  final items = (data['items'] as List?) ?? const [];
                  for (final item in items) {
                    final map = (item as Map?) ?? const {};
                    final title = map['title']?.toString() ?? 'Item';
                    final qty = int.tryParse(
                          map['quantity']?.toString() ?? '1',
                        ) ??
                        1;
                    foodCounts[title] = (foodCounts[title] ?? 0) + qty;
                  }
                }
                final topFoods = foodCounts.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value));

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Analytics Dashboard',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const Spacer(),
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(value: 'today', label: Text('Today')),
                              ButtonSegment(value: '7d', label: Text('7d')),
                              ButtonSegment(value: '30d', label: Text('30d')),
                              ButtonSegment(value: 'all', label: Text('All')),
                            ],
                            selected: {_range},
                            onSelectionChanged: (selection) {
                              setState(() => _range = selection.first);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _MetricCard(
                            title: 'Orders',
                            value: filteredOrders.length.toString(),
                            icon: Icons.receipt_long,
                          ),
                          _MetricCard(
                            title: 'Revenue',
                            value: 'GHS ${totalRevenue.toStringAsFixed(2)}',
                            icon: Icons.payments,
                          ),
                          _MetricCard(
                            title: 'Avg Order',
                            value: 'GHS ${avgValue.toStringAsFixed(2)}',
                            icon: Icons.show_chart,
                          ),
                          _MetricCard(
                            title: 'Delivered',
                            value: delivered.toString(),
                            icon: Icons.check_circle_outline,
                          ),
                          _MetricCard(
                            title: 'Foods',
                            value: foods.length.toString(),
                            icon: Icons.restaurant_menu,
                          ),
                          _MetricCard(
                            title: 'Staff/Users',
                            value: usersReadFailed
                                ? 'N/A'
                                : usersCount.toString(),
                            icon: Icons.group_outlined,
                          ),
                        ],
                      ),
                      if (usersReadFailed) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Could not read users collection. Check Firestore rules/collection path.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.error,
                              ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Order Stage Breakdown',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 12),
                              _OrderStageBreakdown(stageCounts: stageCounts),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Top Ordered Foods',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 10),
                              if (topFoods.isEmpty)
                                const Text('No food order activity yet.')
                              else
                                ...topFoods.take(8).map((entry) {
                                  return ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    leading: const Icon(Icons.star_border),
                                    title: Text(entry.key),
                                    trailing: Text('${entry.value} orders'),
                                  );
                                }),
                            ],
                          ),
                        ),
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

List<QueryDocumentSnapshot<Map<String, dynamic>>> _applyRangeFilter(
  List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  String range,
) {
  if (range == 'all') {
    return docs;
  }

  final now = DateTime.now();
  if (range == 'today') {
    final startOfToday = DateTime(now.year, now.month, now.day);
    final startOfTomorrow = startOfToday.add(const Duration(days: 1));
    return docs.where((doc) {
      final data = doc.data();
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
        return false;
      }
      return !date.isBefore(startOfToday) && date.isBefore(startOfTomorrow);
    }).toList();
  }

  final days = range == '7d' ? 7 : 30;
  final start = now.subtract(Duration(days: days));
  return docs.where((doc) {
    final data = doc.data();
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
      return false;
    }
    return !date.isBefore(start);
  }).toList();
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
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: scheme.primary),
              const SizedBox(height: 10),
              Text(title, style: Theme.of(context).textTheme.labelMedium),
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

class _AnalyticsSkeleton extends StatelessWidget {
  const _AnalyticsSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(20),
      child: Column(
        children: [
          SkeletonBox(height: 34),
          SizedBox(height: 14),
          SkeletonBox(height: 120),
          SizedBox(height: 14),
          SkeletonBox(height: 180),
          SizedBox(height: 14),
          SkeletonBox(height: 220),
        ],
      ),
    );
  }
}

class _OrderStageBreakdown extends StatelessWidget {
  const _OrderStageBreakdown({required this.stageCounts});

  final Map<String, int> stageCounts;

  static const _colors = {
    'placed': Color(0xff8e44ad),
    'preparing': Color(0xfff39c12),
    'inKitchen': Color(0xff2980b9),
    'delivered': Color(0xff27ae60),
  };

  @override
  Widget build(BuildContext context) {
    final total = stageCounts.values.fold<int>(0, (acc, v) => acc + v);
    final entries = stageCounts.entries.toList();

    if (total == 0) {
      return const Text('No stage data available for selected range.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 16,
            child: Row(
              children: entries.map((entry) {
                final value = entry.value;
                final ratio = total == 0 ? 0.0 : value / total;
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
            final value = entry.value;
            final percent = (value / total) * 100;
            return _StageStatTile(
              label: entry.key,
              value: value,
              percent: percent,
              color: color,
            );
          }).toList(),
        ),
        const SizedBox(height: 6),
        Text(
          'Total orders in range: $total',
          style: Theme.of(context).textTheme.labelMedium,
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
        borderRadius: BorderRadius.circular(12),
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$value orders',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            '${percent.toStringAsFixed(1)}%',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
