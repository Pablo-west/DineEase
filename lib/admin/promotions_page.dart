import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'loading_skeleton.dart';

class PromotionsPage extends StatelessWidget {
  const PromotionsPage({super.key, required this.searchQuery});

  final ValueListenable<String> searchQuery;

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 3,
      child: Column(
        children: [
          SizedBox(height: 8),
          TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Promotions'),
              Tab(text: 'Pricing Rules'),
              Tab(text: 'Announcements'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _PromotionsTab(),
                _PricingRulesTab(),
                _AnnouncementsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PromotionsTab extends StatelessWidget {
  const _PromotionsTab();

  @override
  Widget build(BuildContext context) {
    return const _CollectionManager(
      title: 'Promotions',
      collection: 'promotions',
      fields: ['title', 'description', 'discountPercent'],
    );
  }
}

class _PricingRulesTab extends StatelessWidget {
  const _PricingRulesTab();

  @override
  Widget build(BuildContext context) {
    return const _CollectionManager(
      title: 'Pricing Rules',
      collection: 'pricing_rules',
      fields: ['title', 'description', 'value'],
    );
  }
}

class _AnnouncementsTab extends StatelessWidget {
  const _AnnouncementsTab();

  @override
  Widget build(BuildContext context) {
    return const _CollectionManager(
      title: 'Announcements (Ads)',
      collection: 'announcements',
      fields: ['title', 'description'],
    );
  }
}

class _CollectionManager extends StatelessWidget {
  const _CollectionManager({
    required this.title,
    required this.collection,
    required this.fields,
  });

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
                            keyboardType: field.toLowerCase().contains('percent')
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
      for (final field in fields)
        field: controllers[field]!.text.trim(),
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

        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                children: [
                  Text(title, style: Theme.of(context).textTheme.headlineSmall),
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
                child: docs.isEmpty
                    ? Center(
                        child: Text('No $title entries yet.'),
                      )
                    : ListView.builder(
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final data = doc.data();
                          return Card(
                            child: ListTile(
                              title: Text(data['title']?.toString() ?? 'Untitled'),
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
                                    'updatedAt': FieldValue.serverTimestamp(),
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
