import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'admin_ui.dart';
import 'loading_skeleton.dart';

class AuditLogsPage extends StatefulWidget {
  const AuditLogsPage({super.key, required this.searchQuery});

  final ValueListenable<String> searchQuery;

  @override
  State<AuditLogsPage> createState() => _AuditLogsPageState();
}

class _AuditLogsPageState extends State<AuditLogsPage> {
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _logsStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _usersStream;

  @override
  void initState() {
    super.initState();
    _logsStream = FirebaseFirestore.instance
        .collection('audit_logs')
        .orderBy('timestamp', descending: true)
        .snapshots();
    _usersStream = FirebaseFirestore.instance.collection('users').snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _logsStream,
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
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _usersStream,
          builder: (context, usersSnapshot) {
            final userDocs = usersSnapshot.data?.docs ?? [];
            final usersById = <String, Map<String, dynamic>>{
              for (final doc in userDocs) doc.id: doc.data(),
            };

            return ValueListenableBuilder<String>(
              valueListenable: widget.searchQuery,
              builder: (context, query, _) {
                final normalized = query.trim().toLowerCase();
                final entries = docs
                    .map((doc) => _AuditLogEntry.fromDoc(
                          doc,
                          user: usersById[doc.data()['target']?.toString()],
                        ))
                    .where((entry) => entry.matches(normalized))
                    .toList()
                  ..sort((a, b) => b.sortKey.compareTo(a.sortKey));

                final now = DateTime.now();
                final todayStart = DateTime(now.year, now.month, now.day);
                final recent24h = now.subtract(const Duration(hours: 24));
                final todayCount = entries
                    .where((entry) => entry.timestamp.isAfter(todayStart))
                    .length;
                final recentCount = entries
                    .where((entry) => entry.timestamp.isAfter(recent24h))
                    .length;
                final criticalCount =
                    entries.where((entry) => entry.isCritical).length;
                final actors = <String, int>{};
                final actions = <String, int>{};
                for (final entry in entries) {
                  actors[entry.by] = (actors[entry.by] ?? 0) + 1;
                  actions[entry.actionLabel] =
                      (actions[entry.actionLabel] ?? 0) + 1;
                }

                final topActors = actors.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value));
                final topActions = actions.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value));

                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AdminPageIntro(
                        icon: Icons.fact_check_outlined,
                        title: 'Audit Logs',
                        subtitle:
                            'Follow who changed what, when it happened, and which actions are driving the most noise.',
                        badges: [
                          AdminBadge(
                            icon: Icons.receipt_long_outlined,
                            label: '${entries.length} logs',
                          ),
                          AdminBadge(
                            icon: Icons.schedule_outlined,
                            label: '$recentCount in 24h',
                          ),
                          AdminBadge(
                            icon: Icons.warning_amber_rounded,
                            label: '$criticalCount critical',
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final wide = constraints.maxWidth >= 980;
                          final tiles = [
                            _MetricTile(
                              title: 'Logs',
                              value: '${entries.length}',
                              icon: Icons.receipt_long_outlined,
                            ),
                            _MetricTile(
                              title: 'Today',
                              value: '$todayCount',
                              icon: Icons.today_outlined,
                            ),
                            _MetricTile(
                              title: '24h',
                              value: '$recentCount',
                              icon: Icons.access_time_outlined,
                            ),
                            _MetricTile(
                              title: 'Critical',
                              value: '$criticalCount',
                              icon: Icons.error_outline,
                            ),
                          ];

                          final row = wide
                              ? Row(
                                  children: [
                                    for (var i = 0; i < tiles.length; i++) ...[
                                      Expanded(child: tiles[i]),
                                      if (i != tiles.length - 1)
                                        const SizedBox(width: 12),
                                    ],
                                  ],
                                )
                              : SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      for (var i = 0; i < tiles.length; i++) ...[
                                        SizedBox(width: 210, child: tiles[i]),
                                        if (i != tiles.length - 1)
                                          const SizedBox(width: 12),
                                      ],
                                    ],
                                  ),
                                );

                          return row;
                        },
                      ),
                      const SizedBox(height: 14),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final wide = constraints.maxWidth >= 1120;
                          final leftColumn = AdminSectionCard(
                            title: 'Activity Timeline',
                            subtitle:
                                'Recent entries ordered by time, with the full detail payload visible.',
                            child: entries.isEmpty
                                ? const AdminEmptyState(
                                    icon: Icons.history_toggle_off,
                                    title: 'No audit logs found',
                                    message:
                                        'New administrative actions will appear here automatically.',
                                  )
                                : Column(
                                    children: entries.take(12).map((entry) {
                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 10),
                                        child: _TimelineRow(entry: entry),
                                      );
                                    }).toList(),
                                  ),
                          );

                          final rightColumn = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AdminSectionCard(
                                title: 'Action Breakdown',
                                subtitle: 'Which actions are happening the most.',
                                child: topActions.isEmpty
                                    ? const Text('No action data yet.')
                                    : Column(
                                        children: topActions.take(6).map((entry) {
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 10),
                                            child: _BarRow(
                                              label: entry.key,
                                              value: entry.value,
                                              total: entries.isEmpty
                                                  ? 0
                                                  : entries.length,
                                              color: _actionColor(entry.key),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                              ),
                              const SizedBox(height: 14),
                              AdminSectionCard(
                                title: 'Top Actors',
                                subtitle: 'Who is making the most changes.',
                                child: topActors.isEmpty
                                    ? const Text('No actor data yet.')
                                    : Column(
                                        children: topActors.take(6).map((entry) {
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 10),
                                            child: _ActorRow(
                                              actor: entry.key,
                                              count: entry.value,
                                            ),
                                          );
                                        }).toList(),
                                      ),
                              ),
                              const SizedBox(height: 14),
                              AdminSectionCard(
                                title: 'Quick Filters',
                                subtitle:
                                    'A few common slices of the audit trail.',
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _FilterChip(
                                      icon: Icons.delete_outline,
                                      label: 'Deletes',
                                      color: Colors.redAccent,
                                      value: entries
                                          .where((entry) => entry.actionLabel
                                              .contains('delete'))
                                          .length
                                          .toString(),
                                    ),
                                    _FilterChip(
                                      icon: Icons.edit_outlined,
                                      label: 'Updates',
                                      color: Colors.blue,
                                      value: entries
                                          .where((entry) =>
                                              entry.actionLabel
                                                  .contains('update') ||
                                              entry.actionLabel
                                                  .contains('change'))
                                          .length
                                          .toString(),
                                    ),
                                    _FilterChip(
                                      icon: Icons.person_outline,
                                      label: 'Actors',
                                      color: Colors.green,
                                      value: actors.length.toString(),
                                    ),
                                    _FilterChip(
                                      icon: Icons.search_outlined,
                                      label: 'Searchable',
                                      color: Colors.deepPurple,
                                      value: normalized.isEmpty
                                          ? 'All'
                                          : 'Filtered',
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );

                          if (wide) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 2, child: leftColumn),
                                const SizedBox(width: 14),
                                SizedBox(width: 360, child: rightColumn),
                              ],
                            );
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              leftColumn,
                              const SizedBox(height: 14),
                              rightColumn,
                            ],
                          );
                        },
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

class _AuditLogEntry {
  const _AuditLogEntry({
    required this.action,
    required this.target,
    required this.details,
    required this.by,
    required this.timestamp,
    required this.searchPool,
    required this.targetLabel,
  });

  final String action;
  final String target;
  final String details;
  final String by;
  final DateTime timestamp;
  final String searchPool;
  final String targetLabel;

  factory _AuditLogEntry.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    {Map<String, dynamic>? user}) {
    final data = doc.data();
    final timestamp =
        _toDateTime(data['timestamp']) ?? DateTime.fromMillisecondsSinceEpoch(0);
    final action = _cleanText(data['action']);
    final target = _cleanText(data['target']);
    final details = _cleanText(data['details']);
    final by = _cleanText(data['by']).isEmpty ? 'unknown' : _cleanText(data['by']);
    final targetLabel = _resolveTargetLabel(action: action, target: target, user: user);

    return _AuditLogEntry(
      action: action,
      target: target,
      details: details,
      by: by,
      timestamp: timestamp,
      searchPool: [
        action,
        target,
        details,
        by,
        targetLabel,
        _formatDate(timestamp),
      ].join(' ').toLowerCase(),
      targetLabel: targetLabel,
    );
  }

  DateTime get sortKey => timestamp;

  String get actionLabel => _prettyAction(action);

  bool get isCritical {
    final normalized = action.toLowerCase();
    return normalized.contains('delete') ||
        normalized.contains('role_changed') ||
        normalized.contains('role change') ||
        normalized.contains('permission') ||
        normalized.contains('admin');
  }

  bool get isRoleChange {
    final normalized = action.toLowerCase();
    return normalized.contains('role_changed') ||
        normalized.contains('role change') ||
        normalized.contains('role');
  }

  bool matches(String normalizedQuery) {
    if (normalizedQuery.isEmpty) {
      return true;
    }
    return searchPool.contains(normalizedQuery);
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
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
      width: 190,
      child: Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.45)),
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
                maxLines: 1,
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

class _BarRow extends StatelessWidget {
  const _BarRow({
    required this.label,
    required this.value,
    required this.total,
    required this.color,
  });

  final String label;
  final int value;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ratio = total <= 0 ? 0.0 : (value / total).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              value.toString(),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Colors.black54,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 8,
            backgroundColor: color.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _ActorRow extends StatelessWidget {
  const _ActorRow({
    required this.actor,
    required this.count,
  });

  final String actor;
  final int count;

  @override
  Widget build(BuildContext context) {
    final initial = actor.trim().isEmpty
        ? '?'
        : actor.trim().substring(0, 1).toUpperCase();

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.deepPurple.withValues(alpha: 0.12),
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.deepPurple,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              actor,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          const SizedBox(width: 8),
          _SmallPill(text: '$count'),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.entry});

  final _AuditLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final color = _actionColor(entry.action);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 11,
                height: 11,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.actionLabel,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'by ${entry.by}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _SmallPill(text: _formatDate(entry.timestamp)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SmallPill(
                text: entry.isRoleChange
                    ? (entry.targetLabel.isEmpty
                        ? 'User updated'
                        : entry.targetLabel)
                    : (entry.target.isEmpty ? 'No target' : entry.target),
              ),
              _SmallPill(text: entry.by),
              if (entry.isCritical)
                const _SmallPill(text: 'Critical', color: Colors.redAccent),
            ],
          ),
          if (entry.details.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              entry.details,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          if (entry.isRoleChange && entry.targetLabel.isNotEmpty) ...[
            const SizedBox(height: 10),
            _UserDetailCard(label: 'User', value: entry.targetLabel),
          ],
        ],
      ),
    );
  }
}

class _UserDetailCard extends StatelessWidget {
  const _UserDetailCard({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
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
    required this.value,
  });

  final IconData icon;
  final String label;
  final Color color;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            '$label: $value',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _SmallPill extends StatelessWidget {
  const _SmallPill({
    required this.text,
    this.color,
  });

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tone = color ?? Colors.black54;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: tone,
              fontWeight: FontWeight.w700,
            ),
      ),
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
          SkeletonBox(height: 110),
          SizedBox(height: 14),
          SkeletonBox(height: 180),
          SizedBox(height: 14),
          SkeletonBox(height: 220),
        ],
      ),
    );
  }
}

String _cleanText(Object? value) => value?.toString().trim() ?? '';

String _prettyAction(String action) {
  final normalized = action.trim();
  if (normalized.isEmpty) {
    return 'Unknown action';
  }
  final words = normalized
      .replaceAll(RegExp(r'[_-]+'), ' ')
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty);
  return words.map((word) {
    final lower = word.toLowerCase();
    return lower[0].toUpperCase() + lower.substring(1);
  }).join(' ');
}

Color _actionColor(String action) {
  final normalized = action.toLowerCase();
  if (normalized.contains('delete')) {
    return Colors.redAccent;
  }
  if (normalized.contains('role')) {
    return Colors.deepPurple;
  }
  if (normalized.contains('create')) {
    return Colors.green;
  }
  if (normalized.contains('update') || normalized.contains('change')) {
    return Colors.blue;
  }
  if (normalized.contains('login') || normalized.contains('auth')) {
    return Colors.orange;
  }
  return Colors.teal;
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

String _formatDate(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '${value.year}-$month-$day $hour:$minute';
}

String _resolveTargetLabel({
  required String action,
  required String target,
  Map<String, dynamic>? user,
}) {
  final normalized = action.toLowerCase();
  if (!normalized.contains('role')) {
    return '';
  }

  if (user == null) {
    return target.isEmpty ? 'Unknown user' : 'User record not loaded';
  }

  final name = _cleanText(user['name']);
  final email = _cleanText(user['email']);
  final phone = _cleanText(user['phone']);
  final parts = <String>[];
  if (name.isNotEmpty) {
    parts.add(name);
  }
  if (email.isNotEmpty) {
    parts.add(email);
  }
  if (phone.isNotEmpty) {
    parts.add(phone);
  }
  if (parts.isEmpty) {
    return target.isEmpty ? 'Unknown user' : 'User record loaded';
  }
  return parts.join(' • ');
}
