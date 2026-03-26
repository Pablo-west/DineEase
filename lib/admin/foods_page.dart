import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'loading_skeleton.dart';
import 'vendors_page.dart';

class FoodsPage extends StatefulWidget {
  const FoodsPage({super.key, required this.searchQuery});

  final ValueListenable<String> searchQuery;

  @override
  State<FoodsPage> createState() => _FoodsPageState();
}

class _FoodsPageState extends State<FoodsPage> {
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _foodsStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _categoriesStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _vendorsStream;

  @override
  void initState() {
    super.initState();
    _foodsStream = FirebaseFirestore.instance
        .collection('foods')
        .orderBy('title')
        .snapshots();
    _categoriesStream =
        FirebaseFirestore.instance.collection('food_categories').snapshots();
    _vendorsStream =
        FirebaseFirestore.instance.collection('vendors').orderBy('name').snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _vendorsStream,
      builder: (context, vendorsSnapshot) {
        if (vendorsSnapshot.connectionState == ConnectionState.waiting) {
          return const _FoodsPageSkeleton();
        }
        if (vendorsSnapshot.hasError) {
          return FirestoreErrorPanel(
            title: 'Vendors cannot be loaded.',
            error: vendorsSnapshot.error,
          );
        }
        final vendorDocs = vendorsSnapshot.data?.docs ?? [];
        final vendorMap = {
          for (final doc in vendorDocs)
            doc.id: (doc.data()['name']?.toString() ?? 'Vendor').trim(),
        };

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _foodsStream,
          builder: (context, foodsSnapshot) {
            if (foodsSnapshot.connectionState == ConnectionState.waiting) {
              return const _FoodsPageSkeleton();
            }
            if (foodsSnapshot.hasError) {
              return FirestoreErrorPanel(
                title: 'Foods cannot be loaded.',
                error: foodsSnapshot.error,
              );
            }
            final docs = foodsSnapshot.data?.docs ?? [];
            return ValueListenableBuilder<String>(
              valueListenable: widget.searchQuery,
              builder: (context, query, _) {
                final normalizedQuery = query.trim().toLowerCase();
                final filtered = docs.where((doc) {
                  final data = doc.data();
                  final title = data['title']?.toString() ?? '';
                  final category = data['category']?.toString() ?? '';
                  final vendorName = _resolveVendorName(data, vendorMap);
                  if (normalizedQuery.isEmpty) {
                    return true;
                  }
                  return ('$title $category $vendorName')
                      .toLowerCase()
                      .contains(normalizedQuery);
                }).toList();

                final vendorCounts = <String, int>{};
                for (final doc in filtered) {
                  final vendorName = _resolveVendorName(doc.data(), vendorMap);
                  vendorCounts[vendorName] = (vendorCounts[vendorName] ?? 0) + 1;
                }

                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Wrap(
                        spacing: 12,
                        runSpacing: 10,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Foods',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          _CountPill(count: filtered.length, label: 'foods'),
                          _CountPill(count: vendorDocs.length, label: 'vendors'),
                          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                            stream: _categoriesStream,
                            builder: (context, snapshot) {
                              final docs = snapshot.data?.docs ?? [];
                              final unique = <String>{};
                              for (final doc in docs) {
                                final data = doc.data();
                                final name = (data['name'] ?? data['label'] ?? '')
                                    .toString()
                                    .trim();
                                if (name.isNotEmpty) {
                                  unique.add(name.toLowerCase());
                                }
                              }
                              return _CountPill(
                                count: unique.length,
                                label: 'categories',
                              );
                            },
                          ),
                          FilledButton.icon(
                            onPressed: () async {
                              await showDialog(
                                context: context,
                                builder: (context) => const FoodFormDialog(),
                              );
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Add Food'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () async {
                              await showDialog(
                                context: context,
                                builder: (context) => const VendorFormDialog(),
                              );
                            },
                            icon: const Icon(Icons.storefront_outlined),
                            label: const Text('Add Vendor'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () async {
                              await showDialog(
                                context: context,
                                builder: (context) =>
                                    const _CategoryManagerDialog(),
                              );
                            },
                            icon: const Icon(Icons.category_outlined),
                            label: const Text('Add / Modify Categories'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _FoodHintBar(
                        total: filtered.length,
                        vendorCounts: vendorCounts,
                      ),
                      Expanded(
                        child: filtered.isEmpty
                            ? Center(
                                child: Text(
                                  'No foods found.',
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                              )
                            : GridView.builder(
                                gridDelegate:
                                    const SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 300,
                                  childAspectRatio: 0.9,
                                  crossAxisSpacing: 14,
                                  mainAxisSpacing: 14,
                                ),
                                itemCount: filtered.length,
                                itemBuilder: (context, index) {
                                  final doc = filtered[index];
                                  return _FoodCard(
                                    doc: doc,
                                    vendorName: _resolveVendorName(
                                      doc.data(),
                                      vendorMap,
                                    ),
                                  );
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
      },
    );
  }

  String _resolveVendorName(
    Map<String, dynamic> data,
    Map<String, String> vendorMap,
  ) {
    final vendorId = data['vendorId']?.toString() ?? '';
    if (vendorId.isNotEmpty && vendorMap.containsKey(vendorId)) {
      return vendorMap[vendorId]!;
    }
    final vendorName = (data['vendorName'] ?? '').toString().trim();
    return vendorName.isEmpty ? 'Unassigned vendor' : vendorName;
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

class _FoodCard extends StatelessWidget {
  const _FoodCard({required this.doc, required this.vendorName});

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final String vendorName;

  @override
  Widget build(BuildContext context) {
    final data = doc.data();
    final imageUrl = (data['imageUrl']?.toString() ?? '').trim();
    final title = data['title']?.toString() ?? 'Food';
    final category = data['category']?.toString() ?? '';
    final price = data['price']?.toString() ?? '';
    final rating = (data['rating'] as num?)?.toDouble() ?? 0;
    final calories = data['calories']?.toString() ?? '';
    final time = data['time']?.toString() ?? '';

    return Card(
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.black12),
          color: Colors.white,
        ),
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(18),
                ),
                child: AspectRatio(
                  aspectRatio: 16 / 10,
                  child: Container(
                    color: Colors.grey.shade100,
                    child: imageUrl.isEmpty
                        ? const Icon(Icons.image_not_supported)
                        : Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            filterQuality: FilterQuality.low,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.broken_image),
                          ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _CategoryChip(label: category),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _MetaChip(
                      icon: Icons.storefront_outlined,
                      label: vendorName,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _MetaChip(
                          icon: Icons.star,
                          label: rating == 0
                              ? 'Unrated'
                              : rating.toStringAsFixed(1),
                        ),
                        if (calories.isNotEmpty)
                          _MetaChip(
                            icon: Icons.local_fire_department,
                            label: '$calories kcal',
                          ),
                        if (time.isNotEmpty)
                          _MetaChip(
                            icon: Icons.schedule,
                            label: time,
                          ),
                        // _MetaChip(
                        //   icon: Icons.delivery_dining,
                        //   label: destinationDelivery.isEmpty
                        //       ? 'Destination delivery'
                        //       : destinationDelivery,
                        // ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          'GHS $price',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Edit',
                          icon: const Icon(Icons.edit),
                          onPressed: () async {
                            await showDialog(
                              context: context,
                              builder: (context) => FoodFormDialog(
                                docId: doc.id,
                                existing: data,
                              ),
                            );
                          },
                        ),
                        IconButton(
                          tooltip: 'Delete',
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.redAccent),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Delete food?'),
                                content:
                                    const Text('This action cannot be undone.'),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              await doc.reference.delete();
                              if (!context.mounted) {
                                return;
                              }
                              _showSnack(context, 'Food deleted');
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.count, this.label = 'items'});

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
        style: Theme.of(context)
            .textTheme
            .labelMedium
            ?.copyWith(color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}

class _FoodsPageSkeleton extends StatelessWidget {
  const _FoodsPageSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Row(
            children: [
              SkeletonBox(width: 150, height: 28),
              SizedBox(width: 12),
              SkeletonBox(width: 90, height: 28),
              SizedBox(width: 12),
              SkeletonBox(width: 110, height: 28),
            ],
          ),
          const SizedBox(height: 14),
          const SkeletonBox(height: 48),
          const SizedBox(height: 14),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 300,
                childAspectRatio: 1.12,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
              ),
              itemCount: 8,
              itemBuilder: (_, __) => const SkeletonBox(height: 280),
            ),
          ),
        ],
      ),
    );
  }
}

class _FoodHintBar extends StatelessWidget {
  const _FoodHintBar({required this.total, required this.vendorCounts});

  final int total;
  final Map<String, int> vendorCounts;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              vendorCounts.isEmpty
                  ? 'Tip: Add vendors first, then assign every food to the right vendor.'
                  : 'Tip: Use "Create & Add Another" to build each vendor menu quickly.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Text(
            'Vendors: ${vendorCounts.length} | Foods: $total',
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label.isEmpty ? 'Uncategorized' : label,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: Theme.of(context).colorScheme.secondary),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.black54),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

class _CategoryManagerDialog extends StatefulWidget {
  const _CategoryManagerDialog();

  @override
  State<_CategoryManagerDialog> createState() => _CategoryManagerDialogState();
}

class _CategoryManagerDialogState extends State<_CategoryManagerDialog> {
  final _newCategoryController = TextEditingController();
  final _categoriesCollection =
      FirebaseFirestore.instance.collection('food_categories');

  @override
  void dispose() {
    _newCategoryController.dispose();
    super.dispose();
  }

  String _categoryKey(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  Future<void> _createCategory() async {
    final label = _newCategoryController.text.trim();
    if (label.isEmpty) {
      return;
    }
    final key = _categoryKey(label);
    if (key.isEmpty) {
      return;
    }
    await _categoriesCollection.doc(key).set(
      {
        'name': label,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    _newCategoryController.clear();
  }

  Future<void> _renameCategory({
    required String oldLabel,
    required String categoryDocId,
  }) async {
    final controller = TextEditingController(text: oldLabel);
    final renamed = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Category'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Category name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (renamed == null || renamed.isEmpty) {
      return;
    }
    final from = oldLabel.trim();
    final to = renamed.trim();
    if (from.toLowerCase() == to.toLowerCase()) {
      return;
    }

    final newKey = _categoryKey(to);
    await _categoriesCollection.doc(newKey).set(
      {
        'name': to,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    if (categoryDocId != newKey) {
      await _categoriesCollection.doc(categoryDocId).delete();
    }

    final foodsSnapshot = await FirebaseFirestore.instance
        .collection('foods')
        .where('category', isEqualTo: from)
        .get();
    if (foodsSnapshot.docs.isNotEmpty) {
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in foodsSnapshot.docs) {
        batch.update(doc.reference, {'category': to});
      }
      await batch.commit();
    }
  }

  Future<void> _confirmDeleteCategory({
    required String categoryDocId,
    required String label,
  }) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete category?'),
        content: Text(
          'Delete "$label"? Foods using this category will be set to Uncategorized.',
        ),
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

    await _categoriesCollection.doc(categoryDocId).delete();
    final foodsSnapshot = await FirebaseFirestore.instance
        .collection('foods')
        .where('category', isEqualTo: label)
        .get();
    if (foodsSnapshot.docs.isNotEmpty) {
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in foodsSnapshot.docs) {
        batch.update(doc.reference, {'category': ''});
      }
      await batch.commit();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 720),
        child: Padding(
          padding: EdgeInsets.only(
            left: 22,
            right: 22,
            top: 18,
            bottom: MediaQuery.of(context).viewInsets.bottom + 18,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Manage Categories',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Create, rename, or remove menu categories.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.black54,
                    ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _newCategoryController,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: 'New category',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onSubmitted: (_) => _createCategory(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: _createCategory,
                    icon: const Icon(Icons.add),
                    label: const Text('Create'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _categoriesCollection.snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Text(
                          'Failed to load categories: ${snapshot.error}',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: Colors.redAccent),
                        ),
                      );
                    }
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs = snapshot.data?.docs ?? [];
                    final categories = docs
                        .map((doc) {
                          final data = doc.data();
                          final name = (data['name'] ?? data['label'] ?? '')
                              .toString()
                              .trim();
                          if (name.isEmpty) {
                            return null;
                          }
                          return _CategoryEntry(id: doc.id, name: name);
                        })
                        .whereType<_CategoryEntry>()
                        .toList()
                      ..sort((a, b) =>
                          a.name.toLowerCase().compareTo(b.name.toLowerCase()));

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.03),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.black12),
                          ),
                          child: Row(
                            children: [
                              Text(
                                'Existing Categories',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const Spacer(),
                              Text(
                                '${categories.length}',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (docs.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              'No categories yet. Add one to get started.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          )
                        else
                          Expanded(
                            child: ListView.separated(
                              itemCount: categories.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final category = categories[index];
                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 4,
                                  ),
                                  title: Text(category.name),
                                  subtitle: const Text(
                                    'Edit to rename or delete this category',
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        onPressed: () => _renameCategory(
                                          categoryDocId: category.id,
                                          oldLabel: category.name,
                                        ),
                                        icon: const Icon(Icons.edit_outlined),
                                      ),
                                      IconButton(
                                        onPressed: () => _confirmDeleteCategory(
                                          categoryDocId: category.id,
                                          label: category.name,
                                        ),
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          color: Colors.redAccent,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryEntry {
  const _CategoryEntry({required this.id, required this.name});

  final String id;
  final String name;
}

class FoodFormDialog extends StatefulWidget {
  const FoodFormDialog({super.key, this.docId, this.existing});

  final String? docId;
  final Map<String, dynamic>? existing;

  @override
  State<FoodFormDialog> createState() => _FoodFormDialogState();
}

class _FoodFormDialogState extends State<FoodFormDialog> {
  static const String _popularFoodType = 'popularFood';
  static const String _deliciousFoodType = 'deliciousFoods';

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _subtitleController = TextEditingController();
  final _categoryController = TextEditingController();
  final _vendorController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _ratingController = ValueNotifier<double>(4);
  final _caloriesController = TextEditingController();
  final _timeController = TextEditingController();
  Duration _duration = const Duration(minutes: 20);
  List<String> _categoryOptions = [];
  List<_VendorOption> _vendorOptions = [];
  bool _loadingCategories = true;
  bool _loadingVendors = true;
  final _ingredientsController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _foodType = <String>{};

  @override
  void initState() {
    super.initState();
    final data = widget.existing;
    if (data != null) {
      _titleController.text = data['title']?.toString() ?? '';
      _subtitleController.text = data['subtitle']?.toString() ?? '';
      _categoryController.text = data['category']?.toString() ?? '';
      _vendorController.text = data['vendorId']?.toString() ?? '';
      _descriptionController.text = data['description']?.toString() ?? '';
      _priceController.text = data['price']?.toString() ?? '';
      _ratingController.value = (data['rating'] as num?)?.toDouble() ?? 4;
      _caloriesController.text = data['calories']?.toString() ?? '';
      _timeController.text = data['time']?.toString() ?? '';
      _duration = _parseDuration(_timeController.text) ?? _duration;
      _ingredientsController.text =
          (data['ingredients'] as List?)?.join(', ') ?? '';
      _imageUrlController.text = data['imageUrl']?.toString() ?? '';
      final types = (data['foodType'] as List?)?.cast<String>() ?? [];
      _foodType.addAll(
        types.map(_normalizeFoodType).where((type) => type.isNotEmpty),
      );
    }
    _loadCategoryOptions();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    _categoryController.dispose();
    _vendorController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _ratingController.dispose();
    _caloriesController.dispose();
    _timeController.dispose();
    _ingredientsController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  Future<void> _save({required bool stayOpen}) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final ingredients = _ingredientsController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final payload = {
      'title': _titleController.text.trim(),
      'subtitle': _subtitleController.text.trim(),
      'category': _categoryController.text.trim(),
      'vendorId': _vendorController.text.trim(),
      'vendorName': _selectedVendorName,
      'description': _descriptionController.text.trim(),
      'price': double.parse(_priceController.text.trim()),
      'rating': _ratingController.value,
      'calories': double.parse(_caloriesController.text.trim()),
      'time': _formatDuration(_duration),
      'ingredients': ingredients,
      'foodType': _foodType.toList(),
      'imageUrl': _imageUrlController.text.trim(),
    };

    try {
      final foods = FirebaseFirestore.instance.collection('foods');
      if (widget.docId == null) {
        await foods.add(payload);
      } else {
        await foods.doc(widget.docId).update(payload);
      }
      if (mounted) {
        Navigator.pop(context);
        if (stayOpen && widget.docId == null) {
          _resetForm();
        } else {
          Navigator.pop(context);
        }
        _showSnack(
            context, widget.docId == null ? 'Food created' : 'Food updated');
      }
    } catch (_) {
      if (mounted) {
        Navigator.pop(context);
        _showSnack(context, 'Failed to save food');
      }
    }
  }

  Future<void> _loadCategoryOptions() async {
    try {
      final foodsSnapshot =
          await FirebaseFirestore.instance.collection('foods').get();
      final categorySnapshot =
          await FirebaseFirestore.instance.collection('food_categories').get();
      final vendorSnapshot =
          await FirebaseFirestore.instance.collection('vendors').get();
      final normalized = <String, String>{};
      for (final doc in foodsSnapshot.docs) {
        final raw = doc.data()['category']?.toString() ?? '';
        final cleaned = raw.trim();
        if (cleaned.isEmpty) {
          continue;
        }
        normalized.putIfAbsent(cleaned.toLowerCase(), () => cleaned);
      }
      for (final doc in categorySnapshot.docs) {
        final raw = doc.data()['name']?.toString() ?? '';
        final cleaned = raw.trim();
        if (cleaned.isEmpty) {
          continue;
        }
        normalized.putIfAbsent(cleaned.toLowerCase(), () => cleaned);
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _categoryOptions = normalized.values.toList()..sort();
        _vendorOptions = vendorSnapshot.docs
            .map(
              (doc) => _VendorOption(
                id: doc.id,
                name: (doc.data()['name'] ?? 'Vendor').toString().trim(),
                isActive: doc.data()['isActive'] != false,
              ),
            )
            .where((vendor) => vendor.name.isNotEmpty)
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
        _loadingCategories = false;
        _loadingVendors = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingCategories = false;
        _loadingVendors = false;
      });
    }
  }

  String get _selectedVendorName {
    final currentVendorId = _vendorController.text.trim();
    for (final vendor in _vendorOptions) {
      if (vendor.id == currentVendorId) {
        return vendor.name;
      }
    }
    return (widget.existing?['vendorName'] ?? '').toString().trim();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.docId != null;
    final scheme = Theme.of(context).colorScheme;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 840),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEditing ? 'Edit Food' : 'Add Food',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isEditing
                        ? 'Update this food item.'
                        : 'Create a new food item for the menu.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final twoColumns = constraints.maxWidth > 720;
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: twoColumns ? 3 : 1,
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _titleController,
                                        decoration: const InputDecoration(
                                          labelText: 'Title',
                                        ),
                                        validator: _requiredField,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _subtitleController,
                                        decoration: const InputDecoration(
                                          labelText: 'Subtitle',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Builder(
                                        builder: (context) {
                                          final selectedVendorId =
                                              _vendorController.text.trim().isEmpty
                                                  ? null
                                                  : _vendorController.text.trim();
                                          return DropdownButtonFormField<String>(
                                            key: ValueKey(
                                              'vendor-$selectedVendorId-${_vendorOptions.length}',
                                            ),
                                            initialValue: selectedVendorId,
                                            decoration: InputDecoration(
                                              labelText: 'Vendor',
                                              helperText: _loadingVendors
                                                  ? 'Loading vendors...'
                                                  : null,
                                            ),
                                            items: _vendorOptions
                                                .map(
                                                  (vendor) => DropdownMenuItem(
                                                    value: vendor.id,
                                                    child: Text(
                                                      vendor.isActive
                                                          ? vendor.name
                                                          : '${vendor.name} (inactive)',
                                                    ),
                                                  ),
                                                )
                                                .toList(),
                                            onChanged: (value) {
                                              setState(() {
                                                _vendorController.text =
                                                    value ?? '';
                                              });
                                            },
                                            validator: (value) {
                                              if (value == null ||
                                                  value.trim().isEmpty) {
                                                return 'Required';
                                              }
                                              return null;
                                            },
                                          );
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Builder(
                                        builder: (context) {
                                          final normalized = <String, String>{};
                                          for (final raw in _categoryOptions) {
                                            final cleaned = raw.trim();
                                            if (cleaned.isEmpty) {
                                              continue;
                                            }
                                            normalized[cleaned.toLowerCase()] =
                                                cleaned;
                                          }

                                          final currentCategoryRaw =
                                              _categoryController.text;
                                          final currentCategory =
                                              currentCategoryRaw.trim();
                                          if (currentCategory.isNotEmpty) {
                                            normalized[currentCategory
                                                    .toLowerCase()] =
                                                currentCategory;
                                          }

                                          final optionList = normalized.values
                                              .toList()
                                            ..sort();
                                          final selected =
                                              currentCategory.isEmpty
                                                  ? null
                                                  : normalized[currentCategory
                                                      .toLowerCase()];

                                          return DropdownButtonFormField<
                                              String>(
                                            key: ValueKey(
                                              'category-$selected-${optionList.length}',
                                            ),
                                            initialValue: selected,
                                            decoration: InputDecoration(
                                              labelText: 'Category',
                                              helperText: _loadingCategories
                                                  ? 'Loading categories...'
                                                  : null,
                                            ),
                                            items: optionList
                                                .map(
                                                  (cat) => DropdownMenuItem(
                                                    value: cat,
                                                    child: Text(cat),
                                                  ),
                                                )
                                                .toList(),
                                            onChanged: (value) {
                                              setState(() {
                                                _categoryController.text =
                                                    value ?? '';
                                              });
                                            },
                                            validator: (value) {
                                              if (value == null ||
                                                  value.isEmpty) {
                                                return 'Required';
                                              }
                                              return null;
                                            },
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _timeController,
                                        readOnly: true,
                                        decoration: const InputDecoration(
                                          labelText: 'Prep time',
                                          suffixIcon: Icon(Icons.schedule),
                                        ),
                                        onTap: _pickDuration,
                                        validator: (value) {
                                          if (value == null ||
                                              value.trim().isEmpty) {
                                            return 'Required';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _descriptionController,
                                  decoration: const InputDecoration(
                                    labelText: 'Description',
                                  ),
                                  maxLines: 4,
                                  validator: _requiredField,
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _priceController,
                                        decoration: const InputDecoration(
                                          labelText: 'Price (GHS)',
                                        ),
                                        keyboardType: TextInputType.number,
                                        validator: _numberRequired,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _caloriesController,
                                        decoration: const InputDecoration(
                                          labelText: 'Calories',
                                        ),
                                        keyboardType: TextInputType.number,
                                        validator: _numberRequired,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                ValueListenableBuilder<double>(
                                  valueListenable: _ratingController,
                                  builder: (context, value, _) {
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Rating: ${value.toStringAsFixed(1)}',
                                        ),
                                        Slider(
                                          min: 1,
                                          max: 5,
                                          divisions: 8,
                                          label: value.toStringAsFixed(1),
                                          value: value,
                                          onChanged: (v) =>
                                              _ratingController.value = v,
                                        ),
                                      ],
                                    );
                                  },
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  maxLines: 3,
                                  controller: _ingredientsController,
                                  decoration: const InputDecoration(
                                    labelText: 'Ingredients (comma separated)',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _imageUrlController,
                                  decoration: const InputDecoration(
                                    labelText: 'Image URL',
                                  ),
                                  validator: _requiredField,
                                  onChanged: (_) => setState(() {}),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    FilterChip(
                                      label: const Text('Popular Food'),
                                      selected:
                                          _foodType.contains(_popularFoodType),
                                      showCheckmark: true,
                                      checkmarkColor:
                                          Theme.of(context).colorScheme.primary,
                                      selectedColor: Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withValues(alpha: 0.16),
                                      onSelected: (value) => setState(() {
                                        value
                                            ? _foodType.add(_popularFoodType)
                                            : _foodType
                                                .remove(_popularFoodType);
                                      }),
                                    ),
                                    FilterChip(
                                      label: const Text('Delicious Foods'),
                                      selected: _foodType
                                          .contains(_deliciousFoodType),
                                      showCheckmark: true,
                                      checkmarkColor: Theme.of(context)
                                          .colorScheme
                                          .secondary,
                                      selectedColor: Theme.of(context)
                                          .colorScheme
                                          .secondary
                                          .withValues(alpha: 0.16),
                                      onSelected: (value) => setState(() {
                                        value
                                            ? _foodType.add(_deliciousFoodType)
                                            : _foodType
                                                .remove(_deliciousFoodType);
                                      }),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (twoColumns) const SizedBox(width: 18),
                          Expanded(
                            child: Column(
                              children: [
                                Container(
                                  height: 200,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: _imageUrlController.text.trim().isEmpty
                                      ? const Center(
                                          child: Text('Image preview'),
                                        )
                                      : ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          child: Image.network(
                                            _imageUrlController.text.trim(),
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                const Center(
                                              child: Text(
                                                'Invalid image URL',
                                              ),
                                            ),
                                          ),
                                        ),
                                ),
                                const SizedBox(height: 16),
                                FilledButton(
                                  onPressed: () => _save(stayOpen: false),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: scheme.primary,
                                  ),
                                  child: Text(isEditing ? 'Update' : 'Create'),
                                ),
                                if (!isEditing) ...[
                                  const SizedBox(height: 8),
                                  OutlinedButton.icon(
                                    onPressed: () => _save(stayOpen: true),
                                    icon: Icon(
                                      Icons.add_task,
                                      color: scheme.secondary,
                                    ),
                                    label: Text(
                                      'Create & Add Another',
                                      style: TextStyle(color: scheme.secondary),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(color: scheme.secondary),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      backgroundColor: scheme.secondary
                                          .withValues(alpha: 0.06),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Cancel'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
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

  String? _numberRequired(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Required';
    }
    final parsed = double.tryParse(value.trim());
    if (parsed == null) {
      return 'Enter a number';
    }
    return null;
  }

  Future<void> _pickDuration() async {
    final selected = await showDialog<int>(
      context: context,
      builder: (context) {
        final current = _duration.inMinutes.clamp(5, 120);
        int tempValue = current;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return AlertDialog(
              title: const Text('Select prep time'),
              content: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$tempValue min',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    Slider(
                      min: 5,
                      max: 120,
                      divisions: 115,
                      label: '$tempValue min',
                      value: tempValue.toDouble(),
                      onChanged: (value) {
                        setSheetState(() => tempValue = value.round());
                      },
                    ),
                    Text(
                      'Range: 5 to 120 minutes',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, tempValue),
                  child: const Text('Use time'),
                ),
              ],
            );
          },
        );
      },
    );
    if (selected == null) {
      return;
    }
    _duration = Duration(minutes: selected);
    _timeController.text = _formatDuration(_duration);
    setState(() {});
  }

  String _formatDuration(Duration duration) {
    final totalMinutes = duration.inMinutes;
    return '$totalMinutes min';
  }

  Duration? _parseDuration(String input) {
    final cleaned = input.trim();
    if (cleaned.isEmpty) {
      return null;
    }
    final hoursMatch = RegExp(r'(\d+)h').firstMatch(cleaned);
    final minutesMatch = RegExp(r'(\d+)\s*m').firstMatch(cleaned);
    if (hoursMatch == null && minutesMatch == null) {
      final onlyMinutes = int.tryParse(cleaned.replaceAll(RegExp(r'\D'), ''));
      if (onlyMinutes != null) {
        return Duration(minutes: onlyMinutes);
      }
      return null;
    }
    final hours = int.tryParse(hoursMatch?.group(1) ?? '0') ?? 0;
    final minutes = int.tryParse(minutesMatch?.group(1) ?? '0') ?? 0;
    return Duration(hours: hours, minutes: minutes);
  }

  String _normalizeFoodType(String raw) {
    final normalized =
        raw.trim().toLowerCase().replaceAll(RegExp(r'[\s_-]+'), '');
    if (normalized == 'popularfood') {
      return _popularFoodType;
    }
    if (normalized == 'deliciousfoods' || normalized == 'deliciousfood') {
      return _deliciousFoodType;
    }
    return raw.trim();
  }

  void _resetForm() {
    _titleController.clear();
    _subtitleController.clear();
    _categoryController.clear();
    _vendorController.clear();
    _descriptionController.clear();
    _priceController.clear();
    _caloriesController.clear();
    _timeController.clear();
    _duration = const Duration(minutes: 20);
    _ingredientsController.clear();
    _imageUrlController.clear();
    _ratingController.value = 4;
    _foodType.clear();
    setState(() {});
  }
}

class _VendorOption {
  const _VendorOption({
    required this.id,
    required this.name,
    required this.isActive,
  });

  final String id;
  final String name;
  final bool isActive;
}
