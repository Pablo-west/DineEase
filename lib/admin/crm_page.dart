import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'loading_skeleton.dart';

class CrmPage extends StatelessWidget {
  const CrmPage({super.key, required this.searchQuery});

  final ValueListenable<String> searchQuery;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('orders').snapshots(),
      builder: (context, ordersSnap) {
        if (ordersSnap.connectionState == ConnectionState.waiting) {
          return const _CrmSkeleton();
        }
        if (ordersSnap.hasError) {
          return _CrmPermissionDenied(error: ordersSnap.error);
        }
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('users').snapshots(),
          builder: (context, usersSnap) {
            if (usersSnap.connectionState == ConnectionState.waiting) {
              return const _CrmSkeleton();
            }
            if (usersSnap.hasError) {
              return _CrmPermissionDenied(error: usersSnap.error);
            }
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('customers')
                  .snapshots(),
              builder: (context, customerSnap) {
                if (customerSnap.connectionState == ConnectionState.waiting) {
                  return const _CrmSkeleton();
                }
                if (customerSnap.hasError) {
                  return _CrmPermissionDenied(error: customerSnap.error);
                }

                final orderDocs = ordersSnap.data?.docs ?? [];
                final userDocs = usersSnap.data?.docs ?? [];
                final customerDocs = customerSnap.data?.docs ?? [];
                final customers = _buildCustomers(
                  orderDocs: orderDocs,
                  userDocs: userDocs,
                  customerDocs: customerDocs,
                );

                return ValueListenableBuilder<String>(
                  valueListenable: searchQuery,
                  builder: (context, query, _) {
                    final normalized = query.trim().toLowerCase();
                    final filtered = customers.where((customer) {
                      if (normalized.isEmpty) {
                        return true;
                      }
                      return customer.searchPool.contains(normalized);
                    }).toList();
                    final totalOrders = filtered.fold<int>(
                      0,
                      (total, customer) => total + customer.orders,
                    );
                    final totalSpend = filtered.fold<double>(
                      0,
                      (total, customer) => total + customer.spend,
                    );
                    final vipCount = filtered
                        .where((customer) => customer.segment == 'VIP')
                        .length;
                    final colorScheme = Theme.of(context).colorScheme;

                    return Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                      child: Column(
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  colorScheme.primary.withValues(alpha: 0.14),
                                  colorScheme.tertiary.withValues(alpha: 0.08),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color:
                                    colorScheme.primary.withValues(alpha: 0.15),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.people_alt_outlined,
                                  color: colorScheme.primary,
                                  size: 26,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Customer CRM',
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineSmall
                                            ?.copyWith(
                                                fontWeight: FontWeight.w700),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        'Track customers, spending, and note history in one place.',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium,
                                      ),
                                    ],
                                  ),
                                ),
                                _Badge(text: '${filtered.length} customers'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _StatTile(
                                  icon: Icons.receipt_long_outlined,
                                  label: 'Orders',
                                  value: '$totalOrders',
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _StatTile(
                                  icon: Icons.payments_outlined,
                                  label: 'Revenue',
                                  value: 'GHS ${totalSpend.toStringAsFixed(2)}',
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _StatTile(
                                  icon: Icons.workspace_premium_outlined,
                                  label: 'VIPs',
                                  value: '$vipCount',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: filtered.isEmpty
                                ? const Center(
                                    child: Text('No customers found.'))
                                : LayoutBuilder(
                                    builder: (context, constraints) {
                                      final width = constraints.maxWidth;
                                      var columns = 1;
                                      if (width >= 1200) {
                                        columns = 4;
                                      } else if (width >= 900) {
                                        columns = 3;
                                      } else if (width >= 620) {
                                        columns = 2;
                                      }
                                      final childAspectRatio = switch (columns) {
                                        4 => 1.45,
                                        3 => 1.55,
                                        2 => 1.8,
                                        _ => 2.2,
                                      };

                                      return GridView.builder(
                                        itemCount: filtered.length,
                                        gridDelegate:
                                            SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: columns,
                                          crossAxisSpacing: 10,
                                          mainAxisSpacing: 10,
                                          childAspectRatio: childAspectRatio,
                                        ),
                                        itemBuilder: (context, index) {
                                          final customer = filtered[index];
                                          return _CustomerCard(
                                            customer: customer,
                                            onOpenNotes: () => _openNotesDialog(
                                              context,
                                              customer,
                                            ),
                                          );
                                        },
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
      },
    );
  }

  Future<void> _openNotesDialog(
    BuildContext context,
    _CustomerItem customer,
  ) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return _CustomerNotesDialog(
          customer: customer,
          onCreate: (message) => _createNote(customer, message),
          onEdit: (noteId, message) => _updateNote(
            customer: customer,
            noteId: noteId,
            message: message,
          ),
          onDelete: (noteId) => _deleteNote(customer: customer, noteId: noteId),
        );
      },
    );
  }

  Future<void> _createNote(_CustomerItem customer, String message) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final customerRef =
        FirebaseFirestore.instance.collection('customers').doc(customer.id);
    await customerRef.set({
      'name': customer.name,
      'phone': customer.phone,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await customerRef.collection('notes').add({
      'message': trimmed,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _syncLatestCustomerNote(customer);
  }

  Future<void> _updateNote({
    required _CustomerItem customer,
    required String noteId,
    required String message,
  }) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      return;
    }
    await FirebaseFirestore.instance
        .collection('customers')
        .doc(customer.id)
        .collection('notes')
        .doc(noteId)
        .set({
      'message': trimmed,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await _syncLatestCustomerNote(customer);
  }

  Future<void> _deleteNote({
    required _CustomerItem customer,
    required String noteId,
  }) async {
    await FirebaseFirestore.instance
        .collection('customers')
        .doc(customer.id)
        .collection('notes')
        .doc(noteId)
        .delete();
    await _syncLatestCustomerNote(customer);
  }

  Future<void> _syncLatestCustomerNote(_CustomerItem customer) async {
    final customerRef =
        FirebaseFirestore.instance.collection('customers').doc(customer.id);
    final notesSnap = await customerRef
        .collection('notes')
        .orderBy('updatedAt', descending: true)
        .get();
    final latest = notesSnap.docs.isEmpty
        ? ''
        : (notesSnap.docs.first.data()['message'] ?? '').toString();
    await customerRef.set({
      'name': customer.name,
      'phone': customer.phone,
      'note': latest,
      'notesCount': notesSnap.size,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

bool _isStaffRole(String role) {
  const staffRoles = {
    'admin',
    'chef',
    'cashier',
    'waiter',
    'delivery rider',
    'delivery_rider',
  };
  return staffRoles.contains(role.toLowerCase().trim());
}

List<_CustomerItem> _buildCustomers({
  required List<QueryDocumentSnapshot<Map<String, dynamic>>> orderDocs,
  required List<QueryDocumentSnapshot<Map<String, dynamic>>> userDocs,
  required List<QueryDocumentSnapshot<Map<String, dynamic>>> customerDocs,
}) {
  final mapped = <String, _CustomerItem>{};

  // Start from registered app users (stored in users collection).
  for (final doc in userDocs) {
    final data = doc.data();
    final role = data['role']?.toString() ?? '';
    if (_isStaffRole(role)) {
      continue;
    }
    final name = data['name']?.toString().trim();
    final email = data['email']?.toString().trim() ?? '';
    final phone = data['phone']?.toString().trim() ?? '';
    mapped[doc.id] = _CustomerItem(
      id: doc.id,
      name: name?.isNotEmpty == true
          ? name!
          : (email.isNotEmpty ? email : 'Unknown'),
      phone: phone.isNotEmpty ? phone : 'No phone',
      spend: 0,
      orders: 0,
      note: '',
      notesCount: 0,
    );
  }

  // Merge order activity.
  for (final doc in orderDocs) {
    final data = doc.data();
    final userId = data['userId']?.toString().trim();
    final user = _asStringMap(data['user']);
    final orderName = user['name']?.toString().trim();
    final orderPhone = user['phone']?.toString().trim() ?? '';
    final totals = _asStringMap(data['totals']);
    final totalRaw = totals['total'];
    final total = totalRaw is num ? totalRaw.toDouble() : 0.0;

    final key = (userId != null && userId.isNotEmpty)
        ? userId
        : orderPhone.isNotEmpty
            ? orderPhone
            : (orderName?.isNotEmpty == true ? orderName! : 'unknown');

    final current = mapped[key];
    if (current == null) {
      mapped[key] = _CustomerItem(
        id: key.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_'),
        name: orderName?.isNotEmpty == true ? orderName! : 'Unknown',
        phone: orderPhone.isNotEmpty ? orderPhone : 'No phone',
        spend: total,
        orders: 1,
        note: '',
        notesCount: 0,
      );
    } else {
      mapped[key] = current.copyWith(
        spend: current.spend + total,
        orders: current.orders + 1,
        phone: current.phone == 'No phone' && orderPhone.isNotEmpty
            ? orderPhone
            : current.phone,
        name: current.name == 'Unknown' && (orderName?.isNotEmpty == true)
            ? orderName!
            : current.name,
      );
    }
  }

  // Overlay CRM notes.
  for (final doc in customerDocs) {
    final data = doc.data();
    final existing = mapped[doc.id];
    if (existing != null) {
      mapped[doc.id] = existing.copyWith(
        note: data['note']?.toString() ?? '',
        notesCount: _toInt(data['notesCount']),
      );
      continue;
    }
    mapped[doc.id] = _CustomerItem(
      id: doc.id,
      name: data['name']?.toString().trim() ?? 'Unknown',
      phone: data['phone']?.toString().trim() ?? 'No phone',
      spend: 0,
      orders: 0,
      note: data['note']?.toString() ?? '',
      notesCount: _toInt(data['notesCount']),
    );
  }

  final list = mapped.values.toList()
    ..sort((a, b) => b.spend.compareTo(a.spend));
  return list;
}

class _CustomerItem {
  const _CustomerItem({
    required this.id,
    required this.name,
    required this.phone,
    required this.spend,
    required this.orders,
    required this.note,
    required this.notesCount,
  });

  final String id;
  final String name;
  final String phone;
  final double spend;
  final int orders;
  final String note;
  final int notesCount;

  String get segment {
    if (spend >= 500) {
      return 'VIP';
    }
    if (spend >= 200) {
      return 'Returning';
    }
    return 'New';
  }

  String get searchPool =>
      '$name $phone $note ${segment.toLowerCase()}'.toLowerCase();

  _CustomerItem copyWith({
    double? spend,
    int? orders,
    String? note,
    String? phone,
    String? name,
    int? notesCount,
  }) {
    return _CustomerItem(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      spend: spend ?? this.spend,
      orders: orders ?? this.orders,
      note: note ?? this.note,
      notesCount: notesCount ?? this.notesCount,
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, this.tone});

  final String text;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final color = tone ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({
    required this.customer,
    required this.onOpenNotes,
  });

  final _CustomerItem customer;
  final VoidCallback onOpenNotes;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final initial = customer.name.trim().isEmpty
        ? '?'
        : customer.name.trim().substring(0, 1).toUpperCase();

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: colorScheme.primary.withValues(alpha: 0.13),
              child: Text(
                initial,
                style: TextStyle(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          customer.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ),
                      Card(
                        elevation: 2,
                        child: IconButton(
                          tooltip: 'Notes',
                          onPressed: onOpenNotes,
                          visualDensity: VisualDensity.compact,
                          constraints:
                              const BoxConstraints(minWidth: 34, minHeight: 34),
                          icon: const Icon(Icons.edit_note_outlined, size: 19),
                        ),
                      ),
                      const SizedBox(width: 4),
                      _Badge(
                        text: customer.segment,
                        tone: customer.segment == 'VIP'
                            ? Colors.green
                            : Colors.blueGrey,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _InfoChip(
                        icon: Icons.phone_outlined,
                        label: customer.phone,
                      ),
                      _InfoChip(
                        icon: Icons.receipt_long_outlined,
                        label: '${customer.orders} orders',
                      ),
                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('customers')
                            .doc(customer.id)
                            .collection('notes')
                            .snapshots(),
                        builder: (context, notesSnap) {
                          final notesCount =
                              notesSnap.data?.size ?? customer.notesCount;
                          return _InfoChip(
                            icon: Icons.sticky_note_2_outlined,
                            label: '$notesCount notes',
                          );
                        },
                      ),
                      _InfoChip(
                        icon: Icons.payments_outlined,
                        label: 'GHS ${customer.spend.toStringAsFixed(2)}',
                      ),
                    ],
                  ),
                  if (customer.note.trim().isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Card(
                      elevation: 0,
                      color: Colors.black.withValues(alpha: 0.1),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 8.0, horizontal: 10),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 14,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                'Latest: ${customer.note.trim()}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                        color: colorScheme.onSurfaceVariant),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _CrmSkeleton extends StatelessWidget {
  const _CrmSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(20),
      child: Column(
        children: [
          SkeletonBox(height: 32),
          SizedBox(height: 12),
          SkeletonBox(height: 86),
          SizedBox(height: 10),
          SkeletonBox(height: 86),
          SizedBox(height: 10),
          SkeletonBox(height: 86),
        ],
      ),
    );
  }
}

class _CrmPermissionDenied extends StatelessWidget {
  const _CrmPermissionDenied({required this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    final message = error?.toString() ?? 'unknown';
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CRM cannot load due to Firestore permissions.',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Grant read/write access for admin/chef roles on users, orders, customers and customers/{id}/notes.',
                ),
                const SizedBox(height: 8),
                Text(
                  'Error: $message',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CustomerNotesDialog extends StatefulWidget {
  const _CustomerNotesDialog({
    required this.customer,
    required this.onCreate,
    required this.onEdit,
    required this.onDelete,
  });

  final _CustomerItem customer;
  final Future<void> Function(String message) onCreate;
  final Future<void> Function(String noteId, String message) onEdit;
  final Future<void> Function(String noteId) onDelete;

  @override
  State<_CustomerNotesDialog> createState() => _CustomerNotesDialogState();
}

class _CustomerNotesDialogState extends State<_CustomerNotesDialog> {
  final _createController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _createController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notesStream = FirebaseFirestore.instance
        .collection('customers')
        .doc(widget.customer.id)
        .collection('notes')
        .orderBy('updatedAt', descending: true)
        .snapshots();

    return AlertDialog(
      title: Text('Notes: ${widget.customer.name}'),
      content: SizedBox(
        width: 560,
        height: 460,
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _createController,
                    minLines: 1,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Add note',
                      hintText: 'Enter note message',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _submitting
                      ? null
                      : () async {
                          final text = _createController.text.trim();
                          if (text.isEmpty) {
                            return;
                          }
                          setState(() => _submitting = true);
                          try {
                            await widget.onCreate(text);
                            _createController.clear();
                          } catch (e) {
                            if (!mounted) {
                              return;
                            }
                            _showFirestoreActionError(this.context, e);
                          } finally {
                            if (mounted) {
                              setState(() => _submitting = false);
                            }
                          }
                        },
                  icon: _submitting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_comment_outlined, size: 18),
                  label: Text(_submitting ? 'Adding...' : 'Add Note'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: notesStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        'Unable to load notes due to Firestore permissions.\n${snapshot.error}',
                      ),
                    );
                  }
                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return const Center(
                      child: Text('No notes yet for this customer.'),
                    );
                  }
                  return ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data();
                      final message = (data['message'] ?? '').toString();
                      final updatedAt =
                          _toDateTime(data['updatedAt'])?.toLocal();
                      final dateLabel = updatedAt == null
                          ? 'Unknown date'
                          : '${updatedAt.year}-${updatedAt.month.toString().padLeft(2, '0')}-${updatedAt.day.toString().padLeft(2, '0')} ${updatedAt.hour.toString().padLeft(2, '0')}:${updatedAt.minute.toString().padLeft(2, '0')}';
                      return Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.black12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              message,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    dateLabel,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(color: Colors.black54),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Edit note',
                                  onPressed: () async {
                                    final updated = await _showEditDialog(
                                      context: context,
                                      initial: message,
                                    );
                                    if (updated == null) {
                                      return;
                                    }
                                    try {
                                      await widget.onEdit(doc.id, updated);
                                    } catch (e) {
                                      if (!mounted) {
                                        return;
                                      }
                                      _showFirestoreActionError(
                                          this.context, e);
                                    }
                                  },
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                                IconButton(
                                  tooltip: 'Delete note',
                                  onPressed: () async {
                                    final confirmed = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Delete note'),
                                        content: const Text(
                                          'Are you sure you want to delete this note?',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(
                                              context,
                                              false,
                                            ),
                                            child: const Text('Cancel'),
                                          ),
                                          FilledButton(
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                            child: const Text('Delete'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirmed == true) {
                                      try {
                                        await widget.onDelete(doc.id);
                                      } catch (e) {
                                        if (!mounted) {
                                          return;
                                        }
                                        _showFirestoreActionError(
                                            this.context, e);
                                      }
                                    }
                                  },
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Future<String?> _showEditDialog({
    required BuildContext context,
    required String initial,
  }) async {
    final controller = TextEditingController(text: initial);
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit note'),
          content: TextField(
            controller: controller,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Note',
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
    final value = controller.text.trim();
    controller.dispose();
    if (saved != true || value.isEmpty) {
      return null;
    }
    return value;
  }
}

void _showFirestoreActionError(BuildContext context, Object error) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) {
    return;
  }
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text('Firestore request failed: $error')),
    );
}

DateTime? _toDateTime(Object? value) {
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

Map<String, dynamic> _asStringMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, val) => MapEntry(key.toString(), val));
  }
  return const <String, dynamic>{};
}

int _toInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
