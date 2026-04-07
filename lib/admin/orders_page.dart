// ignore_for_file: deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'loading_skeleton.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key, required this.searchQuery});

  final ValueListenable<String> searchQuery;

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  static const stages = ['placed', 'preparing', 'inKitchen', 'delivered'];
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _vendorsStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _ordersStream;
  String _stageFilter = 'all';
  String _vendorFilter = 'all';
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    _vendorsStream = FirebaseFirestore.instance.collection('vendors').snapshots();
    _ordersStream = FirebaseFirestore.instance
        .collection('orders')
        .orderBy('placedAt', descending: true)
        .snapshots();
  }

  void _clearFilters() {
    setState(() {
      _stageFilter = 'all';
      _vendorFilter = 'all';
      _dateRange = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _vendorsStream,
      builder: (context, vendorsSnapshot) {
        if (vendorsSnapshot.connectionState == ConnectionState.waiting) {
          return const _OrdersPageSkeleton();
        }
        if (vendorsSnapshot.hasError) {
          return FirestoreErrorPanel(
            title: 'Vendors cannot be loaded for orders.',
            error: vendorsSnapshot.error,
          );
        }
        final vendorDocs = vendorsSnapshot.data?.docs ?? [];
        final vendorMap = <String, String>{
          for (final doc in vendorDocs)
            doc.id: (doc.data()['name']?.toString() ?? 'Vendor').trim(),
        };
        final vendorOptions = <_VendorOption>[
          for (final doc in vendorDocs) _VendorOption.fromDoc(doc),
        ]..sort();

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _ordersStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const _OrdersPageSkeleton();
            }
            if (snapshot.hasError) {
              return FirestoreErrorPanel(
                title: 'Orders cannot be loaded.',
                error: snapshot.error,
              );
            }
            final docs = snapshot.data?.docs ?? [];
            return ValueListenableBuilder<String>(
              valueListenable: widget.searchQuery,
              builder: (context, query, _) {
                final normalizedQuery = query.trim().toLowerCase();
                final baseFiltered = docs.where((doc) {
                  final data = doc.data();
                  if (_dateRange != null) {
                    final orderDate = _resolveOrderDate(data);
                    if (orderDate == null) {
                      return false;
                    }
                    final start = DateTime(
                      _dateRange!.start.year,
                      _dateRange!.start.month,
                      _dateRange!.start.day,
                    );
                    final endExclusive = DateTime(
                      _dateRange!.end.year,
                      _dateRange!.end.month,
                      _dateRange!.end.day + 1,
                    );
                    if (orderDate.isBefore(start) ||
                        !orderDate.isBefore(endExclusive)) {
                      return false;
                    }
                  }
                  if (normalizedQuery.isEmpty) {
                    return true;
                  }
                  return _orderSearchPool(data, vendorMap)
                      .contains(normalizedQuery);
                }).toList();

                final filtered = baseFiltered.where((doc) {
                  final data = doc.data();
                  if (_stageFilter != 'all') {
                    final stage = _normalizeOrderStage(
                      data['stage']?.toString(),
                    );
                    if (stage != _stageFilter) {
                      return false;
                    }
                  }
                  if (_vendorFilter != 'all') {
                    final vendorIds = _resolveVendorIds(data);
                    if (!vendorIds.contains(_vendorFilter)) {
                      final selectedVendorName =
                          vendorMap[_vendorFilter]?.toLowerCase() ?? '';
                      final vendorNames = _resolveVendorNames(data, vendorMap)
                          .map((name) => name.toLowerCase())
                          .toSet();
                      if (selectedVendorName.isEmpty ||
                          !vendorNames.contains(selectedVendorName)) {
                        return false;
                      }
                    }
                  }
                  return true;
                }).toList();

                final totalAmount = filtered.fold<double>(0.0, (acc, doc) {
                  final totals = (doc.data()['totals'] as Map?) ?? {};
                  return acc + _readAmount(totals['total']);
                });

                final stageCounts = <String, int>{for (var s in stages) s: 0};
                for (final doc in baseFiltered) {
                  final data = doc.data();
                  final stage = _normalizeOrderStage(data['stage']?.toString());
                  if (stageCounts.containsKey(stage)) {
                    stageCounts[stage] = stageCounts[stage]! + 1;
                  }
                }

                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.surface,
                        Theme.of(context)
                            .colorScheme
                            .surface
                            .withValues(alpha: 0.85),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      final isCompact = width < 720;
                      final isMedium = width >= 720 && width < 1180;
                      final pagePadding = EdgeInsets.fromLTRB(
                        isCompact ? 14 : 20,
                        isCompact ? 14 : 18,
                        isCompact ? 14 : 20,
                        isCompact ? 14 : 16,
                      );
                      final gridMaxCrossAxisExtent = isCompact
                          ? 320.0
                          : isMedium
                              ? 340.0
                              : 380.0;
                      final gridChildAspectRatio = isCompact
                          ? 1.12
                          : isMedium
                              ? 1.02
                              : 0.98;
                      final summaryHeader = _SummaryHeader(
                        totalOrders: filtered.length,
                        totalAmount: totalAmount,
                        allCount: baseFiltered.length,
                        stageCounts: stageCounts,
                        currentStage: _stageFilter,
                        vendorOptions: vendorOptions,
                        currentVendor: _vendorFilter,
                        dateRangeLabel: _dateRange == null
                            ? ''
                            : '${_formatCompactDate(_dateRange!.start)} - ${_formatCompactDate(_dateRange!.end)}',
                        onStageSelect: (stage) =>
                            setState(() => _stageFilter = stage),
                        onVendorSelect: (vendor) =>
                            setState(() => _vendorFilter = vendor),
                        onClearFilters: _clearFilters,
                      );
                      final dateRangeCard = Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.black12),
                        ),
                        child: _DateRangeFilter(
                          selected: _dateRange,
                          onPick: () async {
                            final picked = await showDateRangePicker(
                              context: context,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                              initialDateRange: _dateRange,
                              helpText: 'Filter orders by date range',
                            );
                            if (picked == null || !mounted) {
                              return;
                            }
                            setState(() => _dateRange = picked);
                          },
                          onClear: () => setState(() => _dateRange = null),
                        ),
                      );

                      return Padding(
                        padding: pagePadding,
                        child: CustomScrollView(
                          slivers: [
                            SliverToBoxAdapter(
                              child: summaryHeader,
                            ),
                            const SliverToBoxAdapter(
                              child: SizedBox(height: 10),
                            ),
                            SliverToBoxAdapter(
                              child: dateRangeCard,
                            ),
                            const SliverToBoxAdapter(
                              child: SizedBox(height: 12),
                            ),
                            if (filtered.isEmpty)
                              SliverFillRemaining(
                                hasScrollBody: false,
                                child: Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 22,
                                      vertical: 16,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: Colors.black12),
                                    ),
                                    child: Text(
                                      'No orders match your filters.',
                                      style:
                                          Theme.of(context).textTheme.bodyLarge,
                                    ),
                                  ),
                                ),
                              )
                            else
                              SliverPadding(
                                padding: const EdgeInsets.only(bottom: 16),
                                sliver: SliverGrid(
                                  gridDelegate:
                                      SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent:
                                        gridMaxCrossAxisExtent,
                                    childAspectRatio: gridChildAspectRatio,
                                    crossAxisSpacing: isCompact ? 10 : 14,
                                    mainAxisSpacing: isCompact ? 10 : 14,
                                  ),
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) {
                                      final doc = filtered[index];
                                      return RepaintBoundary(
                                        child: _OrderCard(
                                          key: ValueKey(doc.id),
                                          doc: doc,
                                          vendorMap: vendorMap,
                                        ),
                                      );
                                    },
                                    childCount: filtered.length,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
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

DateTime? _resolveOrderDate(Map<String, dynamic> data) {
  final placedAt = data['placedAt'];
  if (placedAt is Timestamp) {
    return placedAt.toDate();
  }
  if (placedAt is DateTime) {
    return placedAt;
  }
  if (placedAt is String) {
    final parsed = DateTime.tryParse(placedAt);
    if (parsed != null) {
      return parsed;
    }
  }
  final timestamp = data['timestamp'];
  if (timestamp is Timestamp) {
    return timestamp.toDate();
  }
  if (timestamp is String) {
    return DateTime.tryParse(timestamp);
  }
  return null;
}

String _normalizeOrderStage(String? stage) {
  switch ((stage ?? '').trim().toLowerCase()) {
    case 'placed':
      return 'placed';
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
  switch (_normalizeOrderStage(stage)) {
    case 'preparing':
      return 'Preparing';
    case 'inKitchen':
      return 'In Kitchen';
    case 'delivered':
      return 'Delivered';
    case 'placed':
    default:
      return 'Placed';
  }
}

String _formatCompactDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

String _orderSearchPool(
  Map<String, dynamic> data,
  Map<String, String> vendorMap,
) {
  final user = (data['user'] as Map?) ?? const {};
  final payment = (data['payment'] as Map?) ?? const {};
  final delivery = (data['delivery'] as Map?) ?? const {};
  final items = (data['items'] as List?) ?? const [];
  final itemNames = items
      .whereType<Map>()
      .map((item) => (item['title'] ?? '').toString())
      .where((title) => title.isNotEmpty)
      .join(' ');
  final vendorNames = _resolveVendorNames(data, vendorMap).join(' ');
  final destination = delivery['type']?.toString() == 'table'
      ? 'Table ${delivery['tableNumber']?.toString() ?? ''}'
      : delivery['address']?.toString() ?? '';

  return [
    data['orderNumber']?.toString() ?? '',
    data['orderId']?.toString() ?? '',
    user['name']?.toString() ?? '',
    user['phone']?.toString() ?? '',
    payment['method']?.toString() ?? '',
    data['stage']?.toString() ?? '',
    _stageLabel(data['stage']?.toString() ?? ''),
    destination,
    itemNames,
    vendorNames,
  ].join(' ').toLowerCase();
}

double _readAmount(dynamic value) {
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

String _formatAmount(num value) {
  return value.toStringAsFixed(2);
}

List<String> _resolveVendorNames(
  Map<String, dynamic> data,
  Map<String, String> vendorMap,
) {
  final vendors = <String>{};

  void addVendorName(String raw) {
    final name = raw.trim();
    if (name.isNotEmpty) {
      vendors.add(name);
    }
  }

  void addVendorId(String raw) {
    final id = raw.trim();
    if (id.isEmpty) {
      return;
    }
    final resolved = vendorMap[id];
    if (resolved != null && resolved.isNotEmpty) {
      vendors.add(resolved);
    }
  }

  addVendorName((data['vendorName'] ?? '').toString());
  addVendorId((data['vendorId'] ?? '').toString());

  final vendorNames = (data['vendorNames'] as List?) ?? const [];
  for (final vendor in vendorNames) {
    addVendorName(vendor?.toString() ?? '');
  }

  final vendorIds = (data['vendorIds'] as List?) ?? const [];
  for (final vendor in vendorIds) {
    addVendorId(vendor?.toString() ?? '');
  }

  final items = (data['items'] as List?) ?? const [];
  for (final item in items) {
    final map = (item as Map?) ?? const {};
    addVendorName((map['vendorName'] ?? '').toString());
    addVendorId((map['vendorId'] ?? '').toString());
  }

  if (vendors.isEmpty) {
    vendors.add('Unassigned vendor');
  }
  return vendors.toList(growable: false);
}

List<String> _resolveVendorIds(Map<String, dynamic> data) {
  final ids = <String>{};

  void addVendorId(String raw) {
    final value = raw.trim();
    if (value.isNotEmpty) {
      ids.add(value);
    }
  }

  addVendorId((data['vendorId'] ?? '').toString());

  final vendorIds = (data['vendorIds'] as List?) ?? const [];
  for (final vendor in vendorIds) {
    addVendorId(vendor?.toString() ?? '');
  }

  final items = (data['items'] as List?) ?? const [];
  for (final item in items) {
    final map = (item as Map?) ?? const {};
    addVendorId((map['vendorId'] ?? '').toString());
  }

  return ids.toList(growable: false);
}

String _vendorNameForId(String id, List<_VendorOption> vendorOptions) {
  for (final vendor in vendorOptions) {
    if (vendor.id == id) {
      return vendor.name;
    }
  }
  return 'Selected vendor';
}

void _showSnack(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) {
    return;
  }
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

class _OrdersPageSkeleton extends StatelessWidget {
  const _OrdersPageSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      child: Column(
        children: [
          const Row(
            children: [
              Expanded(child: SkeletonBox(height: 92)),
              SizedBox(width: 12),
              Expanded(child: SkeletonBox(height: 92)),
              SizedBox(width: 12),
              Expanded(child: SkeletonBox(height: 92)),
            ],
          ),
          const SizedBox(height: 10),
          const SkeletonBox(height: 56),
          const SizedBox(height: 10),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 360,
                childAspectRatio: 1.2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
              ),
              itemCount: 8,
              itemBuilder: (_, __) => const SkeletonBox(height: 260),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryHeader extends StatefulWidget {
  const _SummaryHeader({
    required this.totalOrders,
    required this.totalAmount,
    required this.allCount,
    required this.stageCounts,
    required this.currentStage,
    required this.vendorOptions,
    required this.currentVendor,
    required this.dateRangeLabel,
    required this.onStageSelect,
    required this.onVendorSelect,
    required this.onClearFilters,
  });

  final int totalOrders;
  final double totalAmount;
  final int allCount;
  final Map<String, int> stageCounts;
  final String currentStage;
  final List<_VendorOption> vendorOptions;
  final String currentVendor;
  final String dateRangeLabel;
  final ValueChanged<String> onStageSelect;
  final ValueChanged<String> onVendorSelect;
  final VoidCallback onClearFilters;

  @override
  State<_SummaryHeader> createState() => _SummaryHeaderState();
}

class _SummaryHeaderState extends State<_SummaryHeader> {
  bool _collapsed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dropdownTextStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: scheme.onSurface,
        );
    final activeFilters = <Widget>[
      if (widget.currentStage != 'all')
        _FilterChip(
          icon: Icons.layers_outlined,
          label: _stageLabel(widget.currentStage),
          color: _stageColor(widget.currentStage),
        ),
      if (widget.currentVendor != 'all')
        _FilterChip(
          icon: Icons.storefront_outlined,
          label: _vendorNameForId(widget.currentVendor, widget.vendorOptions),
          color: scheme.primary,
        ),
      if (widget.dateRangeLabel.isNotEmpty)
        _FilterChip(
          icon: Icons.date_range_outlined,
          label: widget.dateRangeLabel,
          color: scheme.tertiary,
        ),
      if (widget.currentStage == 'all' &&
          widget.currentVendor == 'all' &&
          widget.dateRangeLabel.isEmpty &&
          widget.allCount > 0 &&
          widget.totalOrders > 0)
        _FilterChip(
          icon: Icons.done_all,
          label: 'No active filters',
          color: scheme.secondary,
        ),
    ];

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.45)),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            colors: [
              scheme.primary.withValues(alpha: 0.05),
              Colors.white,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, headerConstraints) {
                final stacked = headerConstraints.maxWidth < 620;
                final titleBlock = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order Operations',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Track fulfillment, switch stages, and filter by vendor or date without losing context.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.black54,
                          ),
                    ),
                  ],
                );
                final clearButton = FilledButton.tonalIcon(
                  onPressed: widget.onClearFilters,
                  icon: const Icon(Icons.filter_alt_off_outlined),
                  label: const Text('Clear all'),
                );
                final collapseButton = IconButton.filledTonal(
                  tooltip: _collapsed ? 'Expand controls' : 'Collapse controls',
                  onPressed: () => setState(() => _collapsed = !_collapsed),
                  icon: Icon(
                    _collapsed
                        ? Icons.unfold_more_outlined
                        : Icons.unfold_less_outlined,
                  ),
                );

                if (stacked) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      titleBlock,
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          clearButton,
                          collapseButton,
                        ],
                      ),
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: titleBlock),
                    const SizedBox(width: 12),
                    clearButton,
                    const SizedBox(width: 8),
                    collapseButton,
                  ],
                );
              },
            ),
            if (activeFilters.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: activeFilters),
            ],
            const SizedBox(height: 14),
            if (_collapsed)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.black12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.visibility_off_outlined, color: scheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Controls collapsed. Expand to change stage, vendor, or date filters.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => setState(() => _collapsed = false),
                      icon: const Icon(Icons.unfold_more_outlined),
                      label: const Text('Expand'),
                    ),
                  ],
                ),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 900;
                  final statsWidgets = [
                    SizedBox(
                      width: 180,
                      child: _StatCard(
                        title: 'Total Orders',
                        value: widget.totalOrders.toString(),
                        icon: Icons.receipt_long,
                      ),
                    ),
                    SizedBox(
                      width: 180,
                      child: _StatCard(
                        title: 'Total Amount',
                        value: 'GHS ${widget.totalAmount.toStringAsFixed(2)}',
                        icon: Icons.payments,
                      ),
                    ),
                  ];

                  final filterPanel = _SectionCard(
                    title: 'Filters',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                          ChoiceChip(
                            label: Text('All: ${widget.allCount}'),
                            selected: widget.currentStage == 'all',
                            selectedColor:
                                  scheme.primary.withValues(alpha: 0.14),
                              onSelected: (_) =>
                                  widget.onStageSelect('all'),
                            ),
                            ...widget.stageCounts.entries.map((entry) {
                              final active = widget.currentStage == entry.key;
                              return ChoiceChip(
                                label: Text(
                                  '${_stageLabel(entry.key)}: ${entry.value}',
                                ),
                                selected: active,
                                selectedColor: _stageColor(entry.key)
                                    .withValues(alpha: 0.22),
                                labelStyle: TextStyle(
                                  color: _stageColor(entry.key),
                                  fontWeight: FontWeight.w700,
                                ),
                                onSelected: (_) => widget.onStageSelect(entry.key),
                              );
                            }),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _QueueSummaryCard(
                              title: 'Placed',
                              value: widget.stageCounts['placed'] ?? 0,
                              icon: Icons.schedule_outlined,
                              color: _stageColor('placed'),
                            ),
                            _QueueSummaryCard(
                              title: 'Preparing',
                              value: widget.stageCounts['preparing'] ?? 0,
                              icon: Icons.local_fire_department_outlined,
                              color: _stageColor('preparing'),
                            ),
                            _QueueSummaryCard(
                              title: 'In Kitchen',
                              value: widget.stageCounts['inKitchen'] ?? 0,
                              icon: Icons.kitchen_outlined,
                              color: _stageColor('inKitchen'),
                            ),
                            _QueueSummaryCard(
                              title: 'Delivered',
                              value: widget.stageCounts['delivered'] ?? 0,
                              icon: Icons.verified_outlined,
                              color: _stageColor('delivered'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: widget.vendorOptions.any(
                                  (vendor) => vendor.id == widget.currentVendor)
                              ? widget.currentVendor
                              : 'all',
                          isExpanded: true,
                          menuMaxHeight: 420,
                          dropdownColor: Colors.white,
                          style: dropdownTextStyle,
                          iconEnabledColor: scheme.onSurface,
                          decoration: const InputDecoration(
                            labelText: 'Vendor orders list',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                          selectedItemBuilder: (context) => [
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text('All vendors'),
                            ),
                            ...widget.vendorOptions.map(
                              (vendor) => Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  vendor.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                          items: [
                            const DropdownMenuItem(
                              value: 'all',
                              child: Text('All vendors'),
                            ),
                            ...widget.vendorOptions.map(
                              (vendor) => DropdownMenuItem(
                                value: vendor.id,
                                child: Text(
                                  vendor.label,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              widget.onVendorSelect(value);
                            }
                          },
                        ),
                      ],
                    ),
                  );

                  if (wide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: statsWidgets,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(flex: 2, child: filterPanel),
                      ],
                    );
                  }

                  return Column(
                    children: [
                      Wrap(spacing: 12, runSpacing: 12, children: statsWidgets),
                      const SizedBox(height: 12),
                      filterPanel,
                    ],
                  );
                },
              ),
          ],
        ),
      ),
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
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 180,
      child: Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.black12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: scheme.primary),
              ),
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

class _DateRangeFilter extends StatelessWidget {
  const _DateRangeFilter({
    required this.selected,
    required this.onPick,
    required this.onClear,
  });

  final DateTimeRange? selected;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasRange = selected != null;
    final label = hasRange
        ? '${_fmt(selected!.start)} - ${_fmt(selected!.end)}'
        : 'All dates';

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          'Date Range',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w700,
              ),
        ),
        OutlinedButton.icon(
          onPressed: onPick,
          icon: const Icon(Icons.date_range),
          label: const Text('Pick Date Range'),
        ),
        Chip(
          avatar: const Icon(Icons.calendar_today, size: 16),
          label: Text(label),
        ),
        if (hasRange)
          TextButton(
            onPressed: onClear,
            child: const Text('Clear'),
          ),
      ],
    );
  }

  String _fmt(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}

class _OrderCard extends StatefulWidget {
  const _OrderCard({
    super.key,
    required this.doc,
    required this.vendorMap,
  });

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final Map<String, String> vendorMap;

  @override
  State<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<_OrderCard> {
  bool _updating = false;
  late String _selectedStage;

  @override
  void initState() {
    super.initState();
    _selectedStage = _normalizeOrderStage(widget.doc.data()['stage']?.toString());
  }

  @override
  void didUpdateWidget(covariant _OrderCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final incomingStage =
        _normalizeOrderStage(widget.doc.data()['stage']?.toString());
    if (!_updating && incomingStage != _selectedStage) {
      _selectedStage = incomingStage;
    }
  }

  Future<void> _updateOrderAndCreateNotice({
    required String newStage,
    required Map<String, dynamic> data,
    required List items,
    required String orderNumber,
  }) async {
    await widget.doc.reference.update({
      'stage': newStage,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final userMap = (data['user'] as Map?) ?? const {};
    final userId =
        (data['userId'] ?? userMap['id'] ?? userMap['uid'] ?? '').toString();
    if (userId.isEmpty) return;

    final foodNames = items
        .whereType<Map>()
        .map((item) => (item['title'] ?? '').toString())
        .where((title) => title.isNotEmpty)
        .toSet()
        .toList(growable: false);

    final resolvedOrderNumber =
        orderNumber.isEmpty ? widget.doc.id : orderNumber;
    final message =
        'Order #$resolvedOrderNumber is now ${_stageLabel(newStage)}.';

    try {
      await FirebaseFirestore.instance.collection('notices').add({
        'userId': userId,
        'title': 'Order Status Updated',
        'message': message,
        'orderId': widget.doc.id,
        'orderNumber': resolvedOrderNumber,
        'foodNames': foodNames,
        'stage': newStage,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // The order update should still succeed even if a notice cannot be stored.
    }
  }

  String _normalizedStage(String? stage) {
    return _normalizeOrderStage(stage);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dropdownTextStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: scheme.onSurface,
        );
    final data = widget.doc.data();
    final user = (data['user'] as Map?) ?? {};
    final payment = (data['payment'] as Map?) ?? {};
    final delivery = (data['delivery'] as Map?) ?? {};
    final totals = (data['totals'] as Map?) ?? {};
    final items = (data['items'] as List?) ?? [];
    final stage = _normalizedStage(data['stage']?.toString());
    final orderNumber = data['orderNumber']?.toString() ?? widget.doc.id;
    final deliveryType = delivery['type']?.toString() ?? '';
    final tableNumber = delivery['tableNumber']?.toString() ?? '';
    final address = delivery['address']?.toString() ?? '';
    final deliveryDestination = deliveryType == 'table'
        ? 'Table ${tableNumber.isEmpty ? '-' : tableNumber}'
        : (address.isEmpty ? 'Doorstep' : address);
    final vendorNames = _resolveVendorNames(data, widget.vendorMap);

    final itemPreview = items.take(2).toList();
    final remaining = items.length - itemPreview.length;

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.55)),
          gradient: LinearGradient(
            colors: [
              scheme.primary.withValues(alpha: 0.03),
              Colors.white,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Order #$orderNumber',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _stageColor(stage).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _stageLabel(stage),
                      style: TextStyle(
                        color: _stageColor(stage),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 150,
                    child: Builder(
                      builder: (context) {
                        return DropdownButtonFormField<String>(
                          key: ValueKey(
                            'order-stage-${widget.doc.id}-$_selectedStage',
                          ),
                          initialValue: _selectedStage,
                          dropdownColor: Colors.white,
                          style: dropdownTextStyle,
                          iconEnabledColor: scheme.onSurface,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Stage',
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          items: _OrderPageStages.stages
                              .map(
                                (s) => DropdownMenuItem(
                                  value: s,
                                  child: Text(_stageLabel(s)),
                                ),
                              )
                              .toList(),
                          onChanged: _updating
                              ? null
                              : (value) async {
                                  if (value == null || value == _selectedStage) {
                                    return;
                                  }

                                  final previousStage = _selectedStage;
                                  setState(() {
                                    _selectedStage = value;
                                    _updating = true;
                                  });

                                  try {
                                    await _updateOrderAndCreateNotice(
                                      newStage: value,
                                      data: data,
                                      items: items,
                                      orderNumber: orderNumber,
                                    );
                                    if (!context.mounted) {
                                      return;
                                    }
                                    _showSnack(
                                      context,
                                      'Order updated to ${_stageLabel(value)}',
                                    );
                                  } catch (error) {
                                    if (!mounted) {
                                      return;
                                    }
                                    setState(
                                      () => _selectedStage = previousStage,
                                    );
                                    _showSnack(
                                      context,
                                      'Failed to update order: $error',
                                    );
                                  } finally {
                                    if (mounted) {
                                      setState(() => _updating = false);
                                    }
                                  }
                                },
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ...vendorNames.map(
                    (vendor) => _InfoPill(
                      icon: Icons.storefront_outlined,
                      text: 'Vendor: $vendor',
                    ),
                  ),
                  _InfoPill(
                    icon: Icons.person_outline,
                    text:
                        '${user['name'] ?? 'Unknown'} - ${user['phone'] ?? ''}',
                  ),
                  _InfoPill(
                    icon: Icons.payment,
                    text: 'Payment: ${payment['method'] ?? 'unknown'}',
                  ),
                  _InfoPill(
                    icon: Icons.place_outlined,
                    text: 'Destination: $deliveryDestination',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Items',
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(color: Colors.black54),
              ),
              const SizedBox(height: 4),
              Column(
                children: itemPreview.map<Widget>((item) {
                  final map = (item as Map?) ?? {};
                  final title = map['title']?.toString() ?? 'Item';
                  final qty = map['quantity']?.toString() ?? '1';
                  final vendorName = map['vendorName']?.toString() ?? '';
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            vendorName.isEmpty ? title : '$title | $vendorName',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text('x$qty'),
                      ],
                    ),
                  );
                }).toList(),
              ),
              if (remaining > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    '+$remaining more',
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: Colors.black54),
                  ),
                ),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, constraints) {
                  final stacked = constraints.maxWidth < 240;
                  final totalText = Text(
                    'Total: GHS ${_formatAmount(_readAmount(totals['total']))}',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  );
                  final stageBadge = Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _stageColor(stage).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _stageLabel(stage),
                      style: TextStyle(
                        color: _stageColor(stage),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );

                  if (stacked) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        totalText,
                        const SizedBox(height: 8),
                        stageBadge,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: totalText),
                      const SizedBox(width: 8),
                      stageBadge,
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.black54),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.45)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text(
        label,
        overflow: TextOverflow.ellipsis,
      ),
      backgroundColor: color.withValues(alpha: 0.08),
      side: BorderSide(color: color.withValues(alpha: 0.15)),
      labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _QueueSummaryCard extends StatelessWidget {
  const _QueueSummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final int value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 132,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value.toString(),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                Text(
                  title,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.black54,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VendorOption implements Comparable<_VendorOption> {
  const _VendorOption({
    required this.id,
    required this.name,
    required this.phone,
    required this.address,
    required this.isActive,
  });

  final String id;
  final String name;
  final String phone;
  final String address;
  final bool isActive;

  factory _VendorOption.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return _VendorOption(
      id: doc.id,
      name: (data['name']?.toString().trim().isNotEmpty ?? false)
          ? data['name'].toString().trim()
          : doc.id,
      phone: data['phone']?.toString().trim() ?? '',
      address: data['address']?.toString().trim() ?? '',
      isActive: data['isActive'] != false,
    );
  }

  String get label {
    final details = <String>[
      if (phone.isNotEmpty) phone,
      if (address.isNotEmpty) address,
      if (!isActive) 'Inactive',
    ];
    if (details.isEmpty) {
      return name;
    }
    return '$name - ${details.join(' - ')}';
  }

  @override
  int compareTo(_VendorOption other) {
    final activeCompare = (other.isActive ? 1 : 0).compareTo(isActive ? 1 : 0);
    if (activeCompare != 0) {
      return activeCompare;
    }
    final nameCompare = name.toLowerCase().compareTo(other.name.toLowerCase());
    if (nameCompare != 0) {
      return nameCompare;
    }
    return id.compareTo(other.id);
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
