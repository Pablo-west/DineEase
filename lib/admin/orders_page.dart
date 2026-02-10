import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key, required this.searchQuery});

  final ValueListenable<String> searchQuery;

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  static const stages = ['placed', 'preparing', 'inKitchen', 'delivered'];
  String _stageFilter = 'all';

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .orderBy('placedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data?.docs ?? [];
        return ValueListenableBuilder<String>(
          valueListenable: widget.searchQuery,
          builder: (context, query, _) {
            final filtered = docs.where((doc) {
              final data = doc.data();
              final stage = data['stage']?.toString() ?? '';
              if (_stageFilter != 'all' && stage != _stageFilter) {
                return false;
              }
              if (query.trim().isEmpty) {
                return true;
              }
              final lower = query.toLowerCase();
              final orderNumber = data['orderNumber']?.toString() ?? '';
              final user = (data['user'] as Map?) ?? {};
              final payment = (data['payment'] as Map?) ?? {};
              final searchPool = [
                orderNumber,
                user['name']?.toString() ?? '',
                user['phone']?.toString() ?? '',
                payment['method']?.toString() ?? '',
              ].join(' ').toLowerCase();
              return searchPool.contains(lower);
            }).toList();

            final totalAmount = filtered.fold<double>(0.0, (acc, doc) {
              final totals = (doc.data()['totals'] as Map?) ?? {};
              final total = totals['total'];
              if (total is num) {
                return acc + total.toDouble();
              }
              return acc;
            });

            final stageCounts = <String, int>{for (var s in stages) s: 0};
            for (final doc in filtered) {
              final stage = doc.data()['stage']?.toString();
              if (stage != null && stageCounts.containsKey(stage)) {
                stageCounts[stage] = stageCounts[stage]! + 1;
              }
            }

            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _SummaryHeader(
                    totalOrders: filtered.length,
                    totalAmount: totalAmount,
                    stageCounts: stageCounts,
                  ),
                  const SizedBox(height: 16),
                  _StageFilter(
                    current: _stageFilter,
                    onSelect: (value) => setState(() => _stageFilter = value),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Text(
                              'No orders match your filters.',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          )
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final doc = filtered[index];
                              return _OrderCard(doc: doc);
                            },
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
}

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({
    required this.totalOrders,
    required this.totalAmount,
    required this.stageCounts,
  });

  final int totalOrders;
  final double totalAmount;
  final Map<String, int> stageCounts;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _StatCard(
          title: 'Total Orders',
          value: totalOrders.toString(),
          icon: Icons.receipt_long,
        ),
        _StatCard(
          title: 'Total Amount',
          value: '\$${totalAmount.toStringAsFixed(2)}',
          icon: Icons.payments,
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 260, maxWidth: 520),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                children: stageCounts.entries.map((entry) {
                  return Chip(
                    label: Text('${entry.key}: ${entry.value}'),
                    backgroundColor:
                        _stageColor(entry.key).withValues(alpha: 0.15),
                    labelStyle: TextStyle(
                      color: _stageColor(entry.key),
                      fontWeight: FontWeight.w600,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
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
      width: 180,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20),
              const SizedBox(height: 10),
              Text(
                title,
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(color: Colors.black54),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StageFilter extends StatelessWidget {
  const _StageFilter({
    required this.current,
    required this.onSelect,
  });

  final String current;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    const filters = ['all', 'placed', 'preparing', 'inKitchen', 'delivered'];
    return Row(
      children: filters.map((stage) {
        final active = stage == current;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(stage),
            selected: active,
            selectedColor: _stageColor(stage).withValues(alpha: 0.18),
            onSelected: (_) => onSelect(stage),
          ),
        );
      }).toList(),
    );
  }
}

class _OrderCard extends StatefulWidget {
  const _OrderCard({required this.doc});

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;

  @override
  State<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<_OrderCard> {
  bool _updating = false;

  @override
  Widget build(BuildContext context) {
    final data = widget.doc.data();
    final user = (data['user'] as Map?) ?? {};
    final payment = (data['payment'] as Map?) ?? {};
    final totals = (data['totals'] as Map?) ?? {};
    final items = (data['items'] as List?) ?? [];
    final stage = data['stage']?.toString() ?? 'placed';
    final orderNumber = data['orderNumber']?.toString() ?? widget.doc.id;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Order #$orderNumber',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(width: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _stageColor(stage).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    stage,
                    style: TextStyle(
                      color: _stageColor(stage),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: 160,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: stage,
                        isDense: true,
                        items: _OrderPageStages.stages
                            .map(
                              (s) => DropdownMenuItem(
                                value: s,
                                child: Text(s),
                              ),
                            )
                            .toList(),
                        onChanged: _updating
                            ? null
                            : (value) async {
                                if (value == null || value == stage) {
                                  return;
                                }
                                setState(() => _updating = true);
                                try {
                                  await widget.doc.reference
                                      .update({'stage': value});
                                  Fluttertoast.showToast(
                                    msg: 'Order updated to $value',
                                    gravity: ToastGravity.BOTTOM,
                                  );
                                } catch (_) {
                                  Fluttertoast.showToast(
                                    msg: 'Failed to update order',
                                    gravity: ToastGravity.BOTTOM,
                                  );
                                } finally {
                                  if (mounted) {
                                    setState(() => _updating = false);
                                  }
                                }
                              },
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _InfoRow(
                  icon: Icons.person_outline,
                  text: '${user['name'] ?? 'Unknown'} - ${user['phone'] ?? ''}',
                ),
                _InfoRow(
                  icon: Icons.payment,
                  text: 'Payment: ${payment['method'] ?? 'unknown'}',
                ),
                _InfoRow(
                  icon: Icons.payments,
                  text:
                      'Total: \$${(totals['total'] ?? 0).toString()}',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Items',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 6),
            Column(
              children: items.map<Widget>((item) {
                final map = (item as Map?) ?? {};
                final title = map['title']?.toString() ?? 'Item';
                final qty = map['quantity']?.toString() ?? '1';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Expanded(child: Text(title)),
                      Text('x$qty'),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: Colors.black54),
        const SizedBox(width: 6),
        Text(text),
      ],
    );
  }
}

class _OrderPageStages {
  static const stages = ['placed', 'preparing', 'inKitchen', 'delivered'];
}

Color _stageColor(String stage) {
  switch (stage) {
    case 'preparing':
      return const Color(0xfff39c12);
    case 'inKitchen':
      return const Color(0xff2980b9);
    case 'delivered':
      return const Color(0xff27ae60);
    case 'placed':
    default:
      return const Color(0xff8e44ad);
  }
}
