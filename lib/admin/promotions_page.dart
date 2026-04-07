import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dine_ease/admin/admin_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'loading_skeleton.dart';

class PromotionsPage extends StatefulWidget {
  const PromotionsPage({super.key, required this.searchQuery});

  final ValueListenable<String> searchQuery;

  @override
  State<PromotionsPage> createState() => _PromotionsPageState();
}

class _PromotionsPageState extends State<PromotionsPage> {
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _promotionsStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _pricingStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _announcementsStream;

  @override
  void initState() {
    super.initState();
    final firestore = FirebaseFirestore.instance;
    _promotionsStream = firestore.collection('promotions').snapshots();
    _pricingStream = firestore.collection('pricing_rules').snapshots();
    _announcementsStream = firestore.collection('announcements').snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _promotionsStream,
      builder: (context, promotionsSnap) {
        if (promotionsSnap.connectionState == ConnectionState.waiting) {
          return const _PromoSkeleton();
        }
        if (promotionsSnap.hasError) {
          return FirestoreErrorPanel(
            title: 'Promotions cannot be loaded.',
            error: promotionsSnap.error,
          );
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _pricingStream,
          builder: (context, pricingSnap) {
            if (pricingSnap.connectionState == ConnectionState.waiting) {
              return const _PromoSkeleton();
            }
            if (pricingSnap.hasError) {
              return FirestoreErrorPanel(
                title: 'Pricing rules cannot be loaded.',
                error: pricingSnap.error,
              );
            }

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _announcementsStream,
              builder: (context, announcementsSnap) {
                if (announcementsSnap.connectionState ==
                    ConnectionState.waiting) {
                  return const _PromoSkeleton();
                }
                if (announcementsSnap.hasError) {
                  return FirestoreErrorPanel(
                    title: 'Announcements cannot be loaded.',
                    error: announcementsSnap.error,
                  );
                }

                final promotions = promotionsSnap.data?.docs ?? [];
                final pricingRules = pricingSnap.data?.docs ?? [];
                final announcements = announcementsSnap.data?.docs ?? [];
                final activePromotions = promotions
                    .where((doc) => doc.data()['active'] == true)
                    .length;
                final activeRules = pricingRules
                    .where((doc) => doc.data()['active'] == true)
                    .length;
                final activeAnnouncements = announcements
                    .where((doc) => doc.data()['active'] == true)
                    .length;
                final liveCount =
                    activePromotions + activeRules + activeAnnouncements;

                return LayoutBuilder(
                  builder: (context, pageConstraints) {
                    return DefaultTabController(
                      length: 3,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: pageConstraints.maxHeight,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AdminPageIntro(
                                icon: Icons.campaign_outlined,
                                title: 'Promotions Studio',
                                subtitle:
                                    'Launch offers, price rules, and announcements from one coordinated workspace.',
                                trailing: FilledButton.icon(
                                  onPressed: () => _showQuickCreate(context),
                                  icon: const Icon(Icons.add_chart_outlined),
                                  label: const Text('Studio Tips'),
                                ),
                                badges: [
                                  AdminBadge(
                                    icon: Icons.local_fire_department_outlined,
                                    label: '$liveCount live items',
                                  ),
                                  AdminBadge(
                                    icon: Icons.campaign_outlined,
                                    label: '${promotions.length} promotions',
                                  ),
                                  AdminBadge(
                                    icon: Icons.notifications_active_outlined,
                                    label:
                                        '${announcements.length} announcements',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  _StudioMetricCard(
                                    title: 'Promotions',
                                    value: promotions.length.toString(),
                                    subtitle: '$activePromotions active',
                                    icon: Icons.campaign_outlined,
                                  ),
                                  _StudioMetricCard(
                                    title: 'Pricing Rules',
                                    value: pricingRules.length.toString(),
                                    subtitle: '$activeRules active',
                                    icon: Icons.price_change_outlined,
                                  ),
                                  _StudioMetricCard(
                                    title: 'Announcements',
                                    value: announcements.length.toString(),
                                    subtitle: '$activeAnnouncements active',
                                    icon: Icons.announcement_outlined,
                                  ),
                                  _StudioMetricCard(
                                    title: 'Live Coverage',
                                    value: '$liveCount',
                                    subtitle: 'Across all tabs',
                                    icon: Icons.insights_outlined,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              AdminSectionCard(
                                title: 'Studio Navigation',
                                subtitle:
                                    'Switch between your promotion assets, pricing logic, and broadcasts.',
                                padding:
                                    const EdgeInsets.fromLTRB(16, 16, 16, 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const TabBar(
                                      isScrollable: true,
                                      tabs: [
                                        Tab(text: 'Promotions'),
                                        Tab(text: 'Pricing Rules'),
                                        Tab(text: 'Announcements'),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      height: 620,
                                      child: TabBarView(
                                        children: [
                                          _PromotionsTab(
                                              searchQuery: widget.searchQuery),
                                          _PricingRulesTab(
                                              searchQuery: widget.searchQuery),
                                          _AnnouncementsTab(
                                              searchQuery: widget.searchQuery),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
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

  void _showQuickCreate(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Promotions Studio'),
          content: const Text(
            'Use the tabs below to create or edit promotions, pricing rules, and announcements. The header is designed as an overview and control surface.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}

class _StudioMetricCard extends StatelessWidget {
  const _StudioMetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 240,
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, size: 18, color: scheme.primary),
                  ),
                  const Spacer(),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PromotionsTab extends StatelessWidget {
  const _PromotionsTab({required this.searchQuery});

  final ValueListenable<String> searchQuery;

  @override
  Widget build(BuildContext context) {
    return _PromotionsManager(searchQuery: searchQuery);
  }
}

class _PricingRulesTab extends StatelessWidget {
  const _PricingRulesTab({required this.searchQuery});

  final ValueListenable<String> searchQuery;

  @override
  Widget build(BuildContext context) {
    return _CollectionManager(
      searchQuery: searchQuery,
      title: 'Pricing Rules',
      collection: 'pricing_rules',
      fields: const ['title', 'description', 'value'],
    );
  }
}

class _AnnouncementsTab extends StatelessWidget {
  const _AnnouncementsTab({required this.searchQuery});

  final ValueListenable<String> searchQuery;

  @override
  Widget build(BuildContext context) {
    return _CollectionManager(
      searchQuery: searchQuery,
      title: 'Announcements (Ads)',
      collection: 'announcements',
      fields: const ['title', 'description'],
    );
  }
}

class _PromotionsManager extends StatelessWidget {
  const _PromotionsManager({required this.searchQuery});

  final ValueListenable<String> searchQuery;

  bool _isValidWebUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme) {
      return false;
    }
    final isHttp = uri.scheme == 'http' || uri.scheme == 'https';
    if (!isHttp || uri.host.isEmpty) {
      return false;
    }
    return true;
  }

  bool _isValidTargetUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme) {
      return false;
    }
    final isHttp = uri.scheme == 'http' || uri.scheme == 'https';
    if (isHttp && uri.host.isEmpty) {
      return false;
    }
    return true;
  }

  Future<_PromotionFormData?> _showPromotionDialog(
    BuildContext context, {
    Map<String, dynamic>? initialData,
  }) async {
    final titleController = TextEditingController(
      text: initialData?['title']?.toString() ?? '',
    );
    final descriptionController = TextEditingController(
      text: initialData?['description']?.toString() ?? '',
    );
    final imageController = TextEditingController(
      text: initialData?['image']?.toString() ?? '',
    );
    final urlController = TextEditingController(
      text: initialData?['url']?.toString() ?? '',
    );
    var active = initialData?['active'] != false;
    var showTitleError = false;
    var showDescriptionError = false;
    String? imageUrlErrorText;
    var showTargetUrlError = false;

    final result = await showDialog<_PromotionFormData>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final imageUrl = imageController.text.trim();
            return AlertDialog(
              title: Text(
                  initialData == null ? 'Add Promotion' : 'Edit Promotion'),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: titleController,
                        onChanged: (value) {
                          if (showTitleError && value.trim().isNotEmpty) {
                            setState(() => showTitleError = false);
                          }
                        },
                        decoration: InputDecoration(
                          labelText: 'Promo title',
                          errorText:
                              showTitleError ? 'Title is required' : null,
                          suffixIcon: showTitleError
                              ? const Icon(Icons.error_outline)
                              : null,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: descriptionController,
                        maxLines: 3,
                        onChanged: (value) {
                          if (showDescriptionError && value.trim().isNotEmpty) {
                            setState(() => showDescriptionError = false);
                          }
                        },
                        decoration: InputDecoration(
                          labelText: 'Description',
                          errorText: showDescriptionError
                              ? 'Description is required'
                              : null,
                          suffixIcon: showDescriptionError
                              ? const Icon(Icons.error_outline)
                              : null,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: imageController,
                        onChanged: (value) {
                          final trimmed = value.trim();
                          final valid =
                              trimmed.isNotEmpty && _isValidWebUrl(trimmed);
                          if (imageUrlErrorText != null && valid) {
                            setState(() => imageUrlErrorText = null);
                            return;
                          }
                          setState(() {});
                        },
                        decoration: InputDecoration(
                          labelText: 'Image URL',
                          hintText: 'https://example.com/image.jpg',
                          errorText: imageUrlErrorText,
                          suffixIcon: imageUrlErrorText != null
                              ? const Icon(Icons.error_outline)
                              : null,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: urlController,
                        onChanged: (value) {
                          if (!showTargetUrlError) {
                            return;
                          }
                          final trimmed = value.trim();
                          if (trimmed.isEmpty || _isValidTargetUrl(trimmed)) {
                            setState(() => showTargetUrlError = false);
                          }
                        },
                        decoration: InputDecoration(
                          labelText: 'Target URL',
                          hintText: 'https://example.com/deal',
                          errorText: showTargetUrlError
                              ? 'Enter a valid URL (e.g. https://example.com)'
                              : null,
                          suffixIcon: showTargetUrlError
                              ? const Icon(Icons.error_outline)
                              : null,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: active,
                        onChanged: (value) => setState(() => active = value),
                        title: const Text('Active'),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Image preview',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          height: 160,
                          width: double.infinity,
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          child: imageUrl.isEmpty
                              ? const Center(
                                  child: Text('No image URL'),
                                )
                              : Image.network(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) {
                                    return const Center(
                                      child: Text('Could not load image'),
                                    );
                                  },
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final title = titleController.text.trim();
                    final description = descriptionController.text.trim();
                    final imageUrl = imageController.text.trim();
                    final targetUrl = urlController.text.trim();
                    final titleInvalid = title.isEmpty;
                    final descriptionInvalid = description.isEmpty;
                    final imageMissing = imageUrl.isEmpty;
                    final imageInvalid =
                        imageUrl.isNotEmpty && !_isValidWebUrl(imageUrl);
                    final targetInvalid =
                        targetUrl.isNotEmpty && !_isValidTargetUrl(targetUrl);

                    if (titleInvalid ||
                        descriptionInvalid ||
                        imageMissing ||
                        imageInvalid ||
                        targetInvalid) {
                      setState(() {
                        showTitleError = titleInvalid;
                        showDescriptionError = descriptionInvalid;
                        imageUrlErrorText = imageMissing
                            ? 'Image URL is required'
                            : imageInvalid
                                ? 'Enter a valid image URL (http/https)'
                                : null;
                        showTargetUrlError = targetInvalid;
                      });
                      return;
                    }
                    Navigator.pop(
                      context,
                      _PromotionFormData(
                        title: title,
                        description: description,
                        image: imageUrl,
                        url: targetUrl,
                        active: active,
                      ),
                    );
                  },
                  child: Text(initialData == null ? 'Create' : 'Update'),
                ),
              ],
            );
          },
        );
      },
    );

    titleController.dispose();
    descriptionController.dispose();
    imageController.dispose();
    urlController.dispose();
    return result;
  }

  Future<void> _createPromotion(BuildContext context) async {
    final data = await _showPromotionDialog(context);
    if (data == null) {
      return;
    }

    await FirebaseFirestore.instance.collection('promotions').add({
      'title': data.title,
      'description': data.description,
      'image': data.image,
      'url': data.url,
      'active': data.active,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Promotion created')),
    );
  }

  Future<void> _editPromotion(
    BuildContext context,
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = await _showPromotionDialog(context, initialData: doc.data());
    if (data == null) {
      return;
    }

    await doc.reference.set({
      'title': data.title,
      'description': data.description,
      'image': data.image,
      'url': data.url,
      'active': data.active,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Promotion updated')),
    );
  }

  Future<void> _deletePromotion(
    BuildContext context,
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete promotion'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    await doc.reference.delete();
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Promotion deleted')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('promotions').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _PromoSkeleton();
        }
        if (snapshot.hasError) {
          return FirestoreErrorPanel(
            title: 'Promotions cannot be loaded.',
            error: snapshot.error,
          );
        }

        final docs = snapshot.data?.docs ?? [];
        return ValueListenableBuilder<String>(
          valueListenable: searchQuery,
          builder: (context, query, _) {
            final normalizedQuery = query.trim().toLowerCase();
            final filtered = docs.where((doc) {
              if (normalizedQuery.isEmpty) {
                return true;
              }
              final data = doc.data();
              final pool = [
                data['title']?.toString() ?? '',
                data['description']?.toString() ?? '',
                data['image']?.toString() ?? '',
                data['url']?.toString() ?? '',
                data['active'] == true ? 'active' : 'inactive',
                doc.id,
              ].join(' ').toLowerCase();
              return pool.contains(normalizedQuery);
            }).toList();

            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        'Promotions',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: () => _createPromotion(context),
                        icon: const Icon(Icons.add),
                        label: const Text('Add'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Text(
                              normalizedQuery.isEmpty
                                  ? 'No promotions yet.'
                                  : 'No promotions match "$query".',
                            ),
                          )
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final doc = filtered[index];
                              final data = doc.data();
                              final imageUrl = data['image']?.toString() ?? '';
                              final url = data['url']?.toString() ?? '';

                              return Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          width: 96,
                                          height: 96,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .surfaceContainerHighest,
                                          child: imageUrl.isEmpty
                                              ? const Icon(Icons.image_outlined)
                                              : Image.network(
                                                  imageUrl,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) {
                                                    return const Icon(
                                                      Icons
                                                          .broken_image_outlined,
                                                    );
                                                  },
                                                ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              data['title']?.toString() ??
                                                  'Untitled',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleMedium,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              data['description']?.toString() ??
                                                  '',
                                              maxLines: 3,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (url.isNotEmpty) ...[
                                              const SizedBox(height: 6),
                                              Text(
                                                url,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall
                                                    ?.copyWith(
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .primary,
                                                    ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Column(
                                        children: [
                                          Switch(
                                            value: data['active'] == true,
                                            onChanged: (value) async {
                                              await doc.reference.set({
                                                'active': value,
                                                'updatedAt': FieldValue
                                                    .serverTimestamp(),
                                              }, SetOptions(merge: true));
                                            },
                                          ),
                                          IconButton(
                                            tooltip: 'Edit',
                                            onPressed: () =>
                                                _editPromotion(context, doc),
                                            icon:
                                                const Icon(Icons.edit_outlined),
                                          ),
                                          IconButton(
                                            tooltip: 'Delete',
                                            onPressed: () =>
                                                _deletePromotion(context, doc),
                                            icon: const Icon(
                                                Icons.delete_outline),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
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
  }
}

class _PromotionFormData {
  const _PromotionFormData({
    required this.title,
    required this.description,
    required this.image,
    required this.url,
    required this.active,
  });

  final String title;
  final String description;
  final String image;
  final String url;
  final bool active;
}

class _CollectionManager extends StatelessWidget {
  const _CollectionManager({
    required this.searchQuery,
    required this.title,
    required this.collection,
    required this.fields,
  });

  final ValueListenable<String> searchQuery;
  final String title;
  final String collection;
  final List<String> fields;

  Future<void> _showCreateDialog(BuildContext context) async {
    final controllers = <String, TextEditingController>{
      for (final field in fields) field: TextEditingController(),
    };
    bool active = true;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Add $title'),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ...fields.map(
                        (field) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: TextField(
                            controller: controllers[field],
                            keyboardType:
                                field.toLowerCase().contains('percent')
                                    ? TextInputType.number
                                    : TextInputType.text,
                            decoration: InputDecoration(
                              labelText: field,
                            ),
                          ),
                        ),
                      ),
                      SwitchListTile(
                        value: active,
                        onChanged: (value) => setState(() => active = value),
                        title: const Text('Active'),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved != true) {
      for (final controller in controllers.values) {
        controller.dispose();
      }
      return;
    }

    final payload = <String, dynamic>{
      for (final field in fields) field: controllers[field]!.text.trim(),
      'active': active,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    };
    await FirebaseFirestore.instance.collection(collection).add(payload);
    for (final controller in controllers.values) {
      controller.dispose();
    }
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$title saved')));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection(collection).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _PromoSkeleton();
        }
        if (snapshot.hasError) {
          return FirestoreErrorPanel(
            title: '$title cannot be loaded.',
            error: snapshot.error,
          );
        }
        final docs = snapshot.data?.docs ?? [];

        return ValueListenableBuilder<String>(
          valueListenable: searchQuery,
          builder: (context, query, _) {
            final normalizedQuery = query.trim().toLowerCase();
            final filtered = docs.where((doc) {
              if (normalizedQuery.isEmpty) {
                return true;
              }
              final data = doc.data();
              final pool = [
                for (final field in fields) data[field]?.toString() ?? '',
                data['active'] == true ? 'active' : 'inactive',
                doc.id,
              ].join(' ').toLowerCase();
              return pool.contains(normalizedQuery);
            }).toList();

            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(title,
                          style: Theme.of(context).textTheme.headlineSmall),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: () => _showCreateDialog(context),
                        icon: const Icon(Icons.add),
                        label: const Text('Add'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Text(
                              normalizedQuery.isEmpty
                                  ? 'No $title entries yet.'
                                  : 'No $title entries match "$query".',
                            ),
                          )
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final doc = filtered[index];
                              final data = doc.data();
                              return Card(
                                child: ListTile(
                                  title: Text(
                                      data['title']?.toString() ?? 'Untitled'),
                                  subtitle: Text(
                                    data['description']?.toString() ?? '',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: Switch(
                                    value: data['active'] == true,
                                    onChanged: (value) async {
                                      await doc.reference.set({
                                        'active': value,
                                        'updatedAt':
                                            FieldValue.serverTimestamp(),
                                      }, SetOptions(merge: true));
                                    },
                                  ),
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
  }
}

class _PromoSkeleton extends StatelessWidget {
  const _PromoSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(20),
      child: Column(
        children: [
          SkeletonBox(height: 32),
          SizedBox(height: 12),
          SkeletonBox(height: 78),
          SizedBox(height: 10),
          SkeletonBox(height: 78),
          SizedBox(height: 10),
          SkeletonBox(height: 78),
        ],
      ),
    );
  }
}
