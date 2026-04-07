// ignore_for_file: unused_element

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'admin_ui.dart';
import 'loading_skeleton.dart';

class VendorsPage extends StatefulWidget {
  const VendorsPage({super.key, required this.searchQuery});

  final ValueListenable<String> searchQuery;

  @override
  State<VendorsPage> createState() => _VendorsPageState();
}

class _VendorsPageState extends State<VendorsPage> {
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _vendorsStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _foodsStream;

  @override
  void initState() {
    super.initState();
    final firestore = FirebaseFirestore.instance;
    _vendorsStream =
        firestore.collection('vendors').orderBy('name').snapshots();
    _foodsStream = firestore.collection('foods').snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _vendorsStream,
      builder: (context, vendorsSnapshot) {
        if (vendorsSnapshot.connectionState == ConnectionState.waiting) {
          return const _VendorsPageSkeleton();
        }
        if (vendorsSnapshot.hasError) {
          return FirestoreErrorPanel(
            title: 'Vendors cannot be loaded.',
            error: vendorsSnapshot.error,
          );
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _foodsStream,
          builder: (context, foodsSnapshot) {
            if (foodsSnapshot.connectionState == ConnectionState.waiting) {
              return const _VendorsPageSkeleton();
            }
            if (foodsSnapshot.hasError) {
              return FirestoreErrorPanel(
                title: 'Vendor foods cannot be loaded.',
                error: foodsSnapshot.error,
              );
            }

            final vendorDocs = vendorsSnapshot.data?.docs ?? [];
            final foodDocs = foodsSnapshot.data?.docs ?? [];
            final foodCounts = <String, int>{};
            final vendorFoodNames = <String, List<String>>{};

            for (final food in foodDocs) {
              final data = food.data();
              final vendorId = data['vendorId']?.toString().trim() ?? '';
              if (vendorId.isEmpty) {
                continue;
              }
              foodCounts[vendorId] = (foodCounts[vendorId] ?? 0) + 1;
              final foodName = _clean(data['name']).isNotEmpty
                  ? _clean(data['name'])
                  : _clean(data['title']);
              if (foodName.isNotEmpty) {
                vendorFoodNames
                    .putIfAbsent(vendorId, () => <String>[])
                    .add(foodName);
              }
            }

            return ValueListenableBuilder<String>(
              valueListenable: widget.searchQuery,
              builder: (context, query, _) {
                final normalizedQuery = query.trim().toLowerCase();
                final vendors = vendorDocs.where((doc) {
                  if (normalizedQuery.isEmpty) {
                    return true;
                  }
                  final data = doc.data();
                  final pool = [
                    doc.id,
                    data['name'],
                    data['description'],
                    data['phone'],
                    data['email'],
                    data['address'],
                    data['slug'],
                    foodCounts[doc.id]?.toString(),
                  ].join(' ').toLowerCase();
                  return pool.contains(normalizedQuery);
                }).toList()
                  ..sort((a, b) {
                    final aName = _clean(a.data()['name']).toLowerCase();
                    final bName = _clean(b.data()['name']).toLowerCase();
                    return aName.compareTo(bName);
                  });

                final totalVendors = vendorDocs.length;
                final activeVendors = vendorDocs
                    .where((doc) => doc.data()['isActive'] != false)
                    .length;
                final inactiveVendors = totalVendors - activeVendors;
                final vendorsWithMenus = vendorDocs
                    .where((doc) => (foodCounts[doc.id] ?? 0) > 0)
                    .length;
                final totalFoods = foodDocs.length;
                final avgFoodsPerVendor =
                    totalVendors == 0 ? 0 : totalFoods / totalVendors;

                final topVendorRows = vendorDocs
                    .map((doc) => _VendorSummaryRow.fromDoc(
                          doc,
                          foodCount: foodCounts[doc.id] ?? 0,
                          sampleFoods: vendorFoodNames[doc.id] ?? const [],
                        ))
                    .toList()
                  ..sort((a, b) => b.foodCount.compareTo(a.foodCount));

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1400),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final wide = constraints.maxWidth >= 1120;

                          final hero = AdminPageIntro(
                            icon: Icons.storefront_outlined,
                            title: 'Vendor Operations',
                            subtitle:
                                'Manage suppliers, spot menu coverage gaps, and keep vendor records healthy.',
                            trailing: FilledButton.icon(
                              onPressed: () async {
                                await showDialog(
                                  context: context,
                                  builder: (context) =>
                                      const VendorFormDialog(),
                                );
                              },
                              icon: const Icon(Icons.add_business_outlined),
                              label: const Text('Add Vendor'),
                            ),
                            badges: [
                              AdminBadge(
                                icon: Icons.storefront_outlined,
                                label: '$totalVendors vendors',
                              ),
                              AdminBadge(
                                icon: Icons.check_circle_outline,
                                label: '$activeVendors active',
                              ),
                              AdminBadge(
                                icon: Icons.restaurant_menu,
                                label: '$totalFoods menu items',
                              ),
                            ],
                          );

                          final metrics = Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _MetricCard(
                                  title: 'Vendors',
                                  value: totalVendors.toString(),
                                  icon: Icons.storefront_outlined),
                              _MetricCard(
                                  title: 'Active',
                                  value: activeVendors.toString(),
                                  icon: Icons.verified_outlined),
                              _MetricCard(
                                  title: 'Inactive',
                                  value: inactiveVendors.toString(),
                                  icon: Icons.pause_circle_outline),
                              _MetricCard(
                                  title: 'Foods',
                                  value: totalFoods.toString(),
                                  icon: Icons.restaurant_menu),
                              _MetricCard(
                                  title: 'Coverage',
                                  value: '$vendorsWithMenus vendors',
                                  icon: Icons.grid_view_outlined),
                              _MetricCard(
                                  title: 'Avg Foods/Vendor',
                                  value: avgFoodsPerVendor.toStringAsFixed(1),
                                  icon: Icons.analytics_outlined),
                            ],
                          );

                          // final coverageCard = AdminSectionCard(
                          //   title: 'Menu Coverage',
                          //   subtitle:
                          //       'Which vendors own the biggest share of your catalog.',
                          //   child: topVendorRows.isEmpty
                          //       ? const Text('No vendor coverage data yet.')
                          //       : Column(
                          //           children: topVendorRows.take(8).map((row) {
                          //             return Padding(
                          //               padding:
                          //                   const EdgeInsets.only(bottom: 10),
                          //               child: _CoverageRow(row: row),
                          //             );
                          //           }).toList(),
                          //         ),
                          // );

                          final healthCard = AdminSectionCard(
                            title: 'Vendor Health',
                            subtitle:
                                'A quick operational read on the vendor catalog.',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                LinearProgressIndicator(
                                  value: totalVendors == 0
                                      ? 0
                                      : activeVendors / totalVendors,
                                  minHeight: 12,
                                  backgroundColor: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withValues(alpha: 0.12),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  '$activeVendors of $totalVendors vendors are active',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Keep vendor profiles complete so foods and orders stay easy to route.',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          );

                          final directoryCard = AdminSectionCard(
                            title: 'Vendor Directory',
                            subtitle:
                                'Browse vendor profiles, contact details, and assignment depth.',
                            child: vendors.isEmpty
                                ? const AdminEmptyState(
                                    icon: Icons.storefront_outlined,
                                    title: 'No vendors yet',
                                    message:
                                        'Add your first vendor to start building a supplier directory.',
                                  )
                                : GridView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    gridDelegate:
                                        SliverGridDelegateWithMaxCrossAxisExtent(
                                      maxCrossAxisExtent: wide ? 380 : 460,
                                      mainAxisSpacing: 14,
                                      crossAxisSpacing: 14,
                                      mainAxisExtent: 360,
                                    ),
                                    itemCount: vendors.length,
                                    itemBuilder: (context, index) {
                                      final doc = vendors[index];
                                      return _VendorCard(
                                        doc: doc,
                                        foodCount: foodCounts[doc.id] ?? 0,
                                        sampleFoods:
                                            vendorFoodNames[doc.id] ?? const [],
                                      );
                                    },
                                  ),
                          );

                          final layout = wide
                              ? Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: Column(
                                        children: [
                                          // coverageCard,
                                          const SizedBox(height: 14),
                                          directoryCard,
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    SizedBox(
                                      width: 380,
                                      child: Column(
                                        children: [
                                          healthCard,
                                          const SizedBox(height: 14),
                                          AdminSectionCard(
                                            title: 'Top Vendor Depth',
                                            subtitle:
                                                'Fast view of vendors with the largest menus.',
                                            child: topVendorRows.isEmpty
                                                ? const Text(
                                                    'No vendor data yet.')
                                                : Column(
                                                    children: topVendorRows
                                                        .take(6)
                                                        .map((row) {
                                                      return Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .only(
                                                                bottom: 10),
                                                        child: _CoverageRow(
                                                            row: row),
                                                      );
                                                    }).toList(),
                                                  ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // coverageCard,
                                    const SizedBox(height: 14),
                                    healthCard,
                                    const SizedBox(height: 14),
                                    directoryCard,
                                  ],
                                );

                          final emptySearch =
                              normalizedQuery.isNotEmpty && vendors.isEmpty;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              hero,
                              const SizedBox(height: 14),
                              metrics,
                              if (emptySearch) ...[
                                const SizedBox(height: 14),
                                const AdminEmptyState(
                                  icon: Icons.search_off_outlined,
                                  title: 'No vendors match your search',
                                  message:
                                      'Try a different name, contact detail, or address to find the vendor you want.',
                                ),
                              ] else ...[
                                const SizedBox(height: 14),
                                layout,
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
  }
}

class VendorFormDialog extends StatefulWidget {
  const VendorFormDialog({super.key, this.docId, this.existing});

  final String? docId;
  final Map<String, dynamic>? existing;

  @override
  State<VendorFormDialog> createState() => _VendorFormDialogState();
}

class _VendorFormDialogState extends State<VendorFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    final data = widget.existing;
    if (data != null) {
      _nameController.text = data['name']?.toString() ?? '';
      _descriptionController.text = data['description']?.toString() ?? '';
      _imageUrlController.text = data['imageUrl']?.toString() ?? '';
      _phoneController.text = data['phone']?.toString() ?? '';
      _emailController.text = data['email']?.toString() ?? '';
      _addressController.text = data['address']?.toString() ?? '';
      _isActive = data['isActive'] != false;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _imageUrlController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final name = _nameController.text.trim();
    final payload = {
      'name': name,
      'description': _descriptionController.text.trim(),
      'imageUrl': _imageUrlController.text.trim(),
      'phone': _phoneController.text.trim(),
      'email': _emailController.text.trim(),
      'address': _addressController.text.trim(),
      'isActive': _isActive,
      'slug': _slugify(name),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      final vendors = FirebaseFirestore.instance.collection('vendors');
      if (widget.docId == null) {
        await vendors.add({
          ...payload,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        await vendors.doc(widget.docId).update(payload);
      }
      if (!mounted) {
        return;
      }
      Navigator.pop(context);
      Navigator.pop(context);
      _showSnack(
        context,
        widget.docId == null ? 'Vendor created' : 'Vendor updated',
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      Navigator.pop(context);
      _showSnack(context, 'Failed to save vendor');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.docId != null;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEditing ? 'Edit Vendor' : 'Add Vendor',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Create a vendor profile so foods and orders can be routed correctly.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Vendor name'),
                    validator: _requiredField,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(labelText: 'Description'),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _imageUrlController,
                    decoration: const InputDecoration(
                      labelText: 'Image URL',
                      hintText: 'https://example.com/vendor.jpg',
                    ),
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _phoneController,
                          decoration: const InputDecoration(labelText: 'Phone'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _emailController,
                          decoration: const InputDecoration(labelText: 'Email'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _addressController,
                    decoration: const InputDecoration(labelText: 'Address'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Vendor is active'),
                    value: _isActive,
                    onChanged: (value) => setState(() => _isActive = value),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _save,
                        child: Text(isEditing ? 'Update' : 'Create'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? _requiredField(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Required';
    }
    return null;
  }
}

class _VendorCard extends StatelessWidget {
  const _VendorCard({
    required this.doc,
    required this.foodCount,
    required this.sampleFoods,
  });

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final int foodCount;
  final List<String> sampleFoods;

  @override
  Widget build(BuildContext context) {
    final data = doc.data();
    final name = data['name']?.toString() ?? 'Vendor';
    final description = data['description']?.toString() ?? '';
    final imageUrl = data['imageUrl']?.toString() ?? '';
    final phone = data['phone']?.toString() ?? '';
    final email = data['email']?.toString() ?? '';
    final address = data['address']?.toString() ?? '';
    final isActive = data['isActive'] != false;

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: isActive
              ? const Color(0xff27ae60).withValues(alpha: 0.14)
              : Colors.black12,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                height: 104,
                width: double.infinity,
                color: Colors.black.withValues(alpha: 0.05),
                child: imageUrl.isEmpty
                    ? _VendorImageFallback(name: name)
                    : Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _VendorImageFallback(name: name),
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) {
                            return child;
                          }
                          return const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          );
                        },
                      ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isActive
                        ? const Color(0xff27ae60).withValues(alpha: 0.12)
                        : Colors.grey.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isActive ? 'Active' : 'Inactive',
                    style: TextStyle(
                      color: isActive ? const Color(0xff27ae60) : Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (description.isNotEmpty)
                      Text(
                        description,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    if (description.isNotEmpty) const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _InfoPill(
                          icon: Icons.restaurant_menu,
                          text: '$foodCount foods',
                        ),
                        if (phone.isNotEmpty)
                          _InfoPill(icon: Icons.call_outlined, text: phone),
                        if (email.isNotEmpty)
                          _InfoPill(icon: Icons.email_outlined, text: email),
                        if (address.isNotEmpty)
                          _InfoPill(
                            icon: Icons.location_on_outlined,
                            text: address,
                          ),
                      ],
                    ),
                    if (sampleFoods.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Sample foods',
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: sampleFoods.take(3).map((food) {
                          return _SmallPill(
                            label: food,
                            color: Colors.deepPurple,
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: 'Edit vendor',
                  onPressed: () async {
                    await showDialog(
                      context: context,
                      builder: (context) => VendorFormDialog(
                        docId: doc.id,
                        existing: data,
                      ),
                    );
                  },
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: 'Delete vendor',
                  onPressed: () async {
                    final foods = await FirebaseFirestore.instance
                        .collection('foods')
                        .where('vendorId', isEqualTo: doc.id)
                        .limit(1)
                        .get();
                    if (!context.mounted) {
                      return;
                    }
                    if (foods.docs.isNotEmpty) {
                      _showSnack(
                        context,
                        'Move or delete this vendor\'s foods before deleting the vendor.',
                      );
                      return;
                    }
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete vendor?'),
                        content: Text('Delete "$name"? This cannot be undone.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (confirm != true) {
                      return;
                    }
                    await doc.reference.delete();
                    if (!context.mounted) {
                      return;
                    }
                    _showSnack(context, 'Vendor deleted');
                  },
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
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

class _CoverageRow extends StatelessWidget {
  const _CoverageRow({required this.row});

  final _VendorSummaryRow row;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  row.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              const SizedBox(width: 8),
              _SmallPill(label: '${row.foodCount} foods', color: Colors.blue),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: row.ratio,
            minHeight: 10,
            backgroundColor: Colors.blue.withValues(alpha: 0.12),
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
          ),
          const SizedBox(height: 8),
          Text(
            row.sampleFoods.isEmpty
                ? 'No sample menu items'
                : 'Examples: ${row.sampleFoods.take(2).join(', ')}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _VendorSummaryRow {
  _VendorSummaryRow({
    required this.name,
    required this.foodCount,
    required this.sampleFoods,
  });

  final String name;
  final int foodCount;
  final List<String> sampleFoods;

  double get ratio =>
      foodCount == 0 ? 0 : (foodCount / 10).clamp(0, 1).toDouble();

  factory _VendorSummaryRow.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc, {
    required int foodCount,
    required List<String> sampleFoods,
  }) {
    final data = doc.data();
    return _VendorSummaryRow(
      name: _clean(data['name']).isNotEmpty ? _clean(data['name']) : doc.id,
      foodCount: foodCount,
      sampleFoods: sampleFoods,
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

class _VendorImageFallback extends StatelessWidget {
  const _VendorImageFallback({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xfff4d03f), Color(0xfff39c12)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.storefront_outlined,
              size: 34,
              color: Colors.white,
            ),
            const SizedBox(height: 8),
            Text(
              initials.isEmpty ? 'VN' : initials,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.count, required this.label});

  final int count;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$count $label',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}

class _VendorsPageSkeleton extends StatelessWidget {
  const _VendorsPageSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonBox(height: 120),
          const SizedBox(height: 14),
          const SkeletonBox(height: 80),
          const SizedBox(height: 14),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 360,
                mainAxisExtent: 360,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
              ),
              itemCount: 6,
              itemBuilder: (_, __) => const SkeletonBox(height: 220),
            ),
          ),
        ],
      ),
    );
  }
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

String _slugify(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
}

String _clean(Object? value) => value?.toString().trim() ?? '';
