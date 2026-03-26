import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'admin_ui.dart';
import 'loading_skeleton.dart';

class AuditLogsPage extends StatelessWidget {
  const AuditLogsPage({super.key, required this.searchQuery});

  final ValueListenable<String> searchQuery;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('audit_logs')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _AuditSkeleton();
        }
        if (snapshot.hasError) {
          return FirestoreErrorPanel(
            title: 'Audit logs cannot be loaded.',
            error: snapshot.error,
          );
        }
        final docs = snapshot.data?.docs ?? [];
        return ValueListenableBuilder<String>(
          valueListenable: searchQuery,
          builder: (context, query, _) {
            final normalized = query.trim().toLowerCase();
            final filtered = docs.where((doc) {
              if (normalized.isEmpty) {
                return true;
              }
              final data = doc.data();
              final pool = [
                data['action']?.toString() ?? '',
                data['target']?.toString() ?? '',
                data['details']?.toString() ?? '',
                data['by']?.toString() ?? '',
              ].join(' ').toLowerCase();
              return pool.contains(normalized);
            }).toList();

            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  AdminPageIntro(
                    icon: Icons.fact_check_outlined,
                    title: 'Audit Logs',
                    subtitle:
                        'Review critical admin activity with a cleaner, easier-to-scan trail.',
                    badges: [
                      AdminBadge(
                        icon: Icons.receipt_long,
                        label: '${filtered.length} logs',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: filtered.isEmpty
                        ? const AdminEmptyState(
                            icon: Icons.history_toggle_off,
                            title: 'No audit logs found',
                            message:
                                'New administrative actions will appear here automatically.',
                          )
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final data = filtered[index].data();
                              final ts = data['timestamp'];
                              DateTime? date;
                              if (ts is Timestamp) {
                                date = ts.toDate();
                              }
                              return Card(
                                child: ListTile(
                                  leading: const Icon(Icons.fact_check_outlined),
                                  title: Text(
                                    data['action']?.toString() ?? 'unknown_action',
                                  ),
                                  subtitle: Text(
                                    '${data['details']?.toString() ?? ''}\nby ${data['by']?.toString() ?? 'unknown'}',
                                  ),
                                  isThreeLine: true,
                                  trailing: Text(
                                    date == null
                                        ? '-'
                                        : '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
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

class _AuditSkeleton extends StatelessWidget {
  const _AuditSkeleton();

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
