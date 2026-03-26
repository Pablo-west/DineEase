import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

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
    _vendorsStream = FirebaseFirestore.instance
        .collection('vendors')
        .orderBy('name')
        .snapshots();
    _foodsStream = FirebaseFirestore.instance.collection('foods').snapshots();
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
            for (final food in foodDocs) {
              final data = food.data();
              final vendorId = data['vendorId']?.toString() ?? '';
              if (vendorId.isEmpty) {
                continue;
              }
              foodCounts[vendorId] = (foodCounts[vendorId] ?? 0) + 1;
            }

            return ValueListenableBuilder<String>(
              valueListenable: widget.searchQuery,
              builder: (context, query, _) {
                final normalizedQuery = query.trim().toLowerCase();
                final filtered = vendorDocs.where((doc) {
                  if (normalizedQuery.isEmpty) {
                    return true;
                  }
                  final data = doc.data();
                  final pool = [
                    data['name'],
                    data['description'],
                    data['phone'],
                    data['email'],
                    data['address'],
                  ].join(' ').toLowerCase();
                  return pool.contains(normalizedQuery);
                }).toList();

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
                            'Vendors',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          _CountPill(count: filtered.length, label: 'vendors'),
                          _CountPill(
                            count: foodDocs.length,
                            label: 'foods assigned',
                          ),
                          FilledButton.icon(
                            onPressed: () async {
                              await showDialog(
                                context: context,
                                builder: (context) => const VendorFormDialog(),
                              );
                            },
                            icon: const Icon(Icons.storefront_outlined),
                            label: const Text('Add Vendor'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Expanded(
                        child: filtered.isEmpty
                            ? Center(
                                child: Text(
                                  'No vendors found.',
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                              )
                            : GridView.builder(
                                gridDelegate:
                                    const SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 340,
                                  mainAxisExtent: 380,
                                  crossAxisSpacing: 14,
                                  mainAxisSpacing: 14,
                                ),
                                itemCount: filtered.length,
                                itemBuilder: (context, index) {
                                  final doc = filtered[index];
                                  final vendorFoodCount =
                                      foodCounts[doc.id] ?? 0;
                                  return _VendorCard(
                                    doc: doc,
                                    foodCount: vendorFoodCount,
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
                    decoration: const InputDecoration(
                      labelText: 'Description',
                    ),
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
  const _VendorCard({required this.doc, required this.foodCount});

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final int foodCount;

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
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.black12),
        ),
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
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
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
                physics: const BouncingScrollPhysics(),
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
        style: Theme.of(context)
            .textTheme
            .labelMedium
            ?.copyWith(color: Theme.of(context).colorScheme.primary),
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
        children: [
          const Row(
            children: [
              SkeletonBox(width: 150, height: 28),
              SizedBox(width: 12),
              SkeletonBox(width: 90, height: 28),
              SizedBox(width: 12),
              SkeletonBox(width: 120, height: 28),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 360,
                mainAxisExtent: 380,
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
