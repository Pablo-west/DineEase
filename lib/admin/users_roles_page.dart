import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'admin_ui.dart';
import 'loading_skeleton.dart';

const List<String> _roles = [
  'admin',
  'chef',
  'cashier',
  'waiter',
  'delivery rider',
];

const String _protectedRoleUid = 'J5GKrWrL7pSq0tWADtOUx18r6Al2';

String _normalizeRole(String? role) {
  final value = (role ?? '').trim().toLowerCase();
  if (value == 'delivery_rider') {
    return 'delivery rider';
  }
  return value;
}

String _roleLabel(String role) {
  final words = role.split(RegExp(r'[\s_]+')).where((part) => part.isNotEmpty);
  return words
      .map((part) => part[0].toUpperCase() + part.substring(1))
      .join(' ');
}

String _shortUid(String uid) {
  if (uid.length <= 12) {
    return uid;
  }
  return '${uid.substring(0, 6)}...${uid.substring(uid.length - 4)}';
}

bool _isProtectedUser(String uid) => uid == _protectedRoleUid;

Color _roleTint(ColorScheme scheme, String role) {
  switch (_normalizeRole(role)) {
    case 'admin':
      return scheme.error;
    case 'chef':
      return const Color(0xff8e44ad);
    case 'cashier':
      return const Color(0xff1565c0);
    case 'waiter':
      return const Color(0xff2e7d32);
    case 'delivery rider':
      return const Color(0xffef6c00);
    default:
      return scheme.primary;
  }
}

enum _UserSortField {
  name,
  email,
  role,
  phone,
  uid,
}

class UsersRolesPage extends StatefulWidget {
  const UsersRolesPage({super.key, required this.searchQuery});

  final ValueListenable<String> searchQuery;

  @override
  State<UsersRolesPage> createState() => _UsersRolesPageState();
}

class _UsersRolesPageState extends State<UsersRolesPage> {
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _usersStream;
  String _roleFilter = 'all';
  bool _introExpanded = true;
  _UserSortField _sortField = _UserSortField.name;
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    _usersStream = FirebaseFirestore.instance.collection('users').snapshots();
  }

  Future<void> _writeAudit({
    required String action,
    required String target,
    required String details,
  }) async {
    await FirebaseFirestore.instance.collection('audit_logs').add({
      'action': action,
      'target': target,
      'details': details,
      'by': FirebaseAuth.instance.currentUser?.email ?? 'unknown',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  void _setIntroExpanded(bool value) {
    setState(() => _introExpanded = value);
  }

  void _sortBy(_UserSortField field) {
    setState(() {
      if (_sortField == field) {
        _sortAscending = !_sortAscending;
      } else {
        _sortField = field;
        _sortAscending = true;
      }
    });
  }

  int _compareText(String left, String right) {
    return left.toLowerCase().compareTo(right.toLowerCase());
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _sortUsers(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final sorted = [...docs];
    sorted.sort((a, b) {
      final aData = a.data();
      final bData = b.data();
      int comparison;
      switch (_sortField) {
        case _UserSortField.email:
          comparison = _compareText(
            aData['email']?.toString().trim() ?? '',
            bData['email']?.toString().trim() ?? '',
          );
          break;
        case _UserSortField.role:
          comparison = _compareText(
            _normalizeRole(aData['role']?.toString()),
            _normalizeRole(bData['role']?.toString()),
          );
          break;
        case _UserSortField.phone:
          comparison = _compareText(
            aData['phone']?.toString().trim() ?? '',
            bData['phone']?.toString().trim() ?? '',
          );
          break;
        case _UserSortField.uid:
          comparison = _compareText(a.id, b.id);
          break;
        case _UserSortField.name:
          comparison = _compareText(
            aData['name']?.toString().trim() ?? '',
            bData['name']?.toString().trim() ?? '',
          );
          if (comparison == 0) {
            comparison = _compareText(a.id, b.id);
          }
          break;
      }
      return _sortAscending ? comparison : -comparison;
    });
    return sorted;
  }

  void _showSnack(String message) {
    if (!mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _updateRole(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    String role,
  ) async {
    final normalizedRole = _normalizeRole(role);
    if (!_roles.contains(normalizedRole)) {
      _showSnack('Invalid role selected');
      return false;
    }
    if (doc.id == _protectedRoleUid) {
      _showSnack('Role is locked for this UID');
      return false;
    }
    try {
      await doc.reference.set({
        'role': normalizedRole,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await _writeAudit(
        action: 'role_changed',
        target: doc.id,
        details: 'Role changed to $normalizedRole',
      );
      _showSnack('Updated role to ${_roleLabel(normalizedRole)}');
      return true;
    } catch (_) {
      _showSnack('Could not update role right now');
      return false;
    }
  }

  Future<void> _createUser() async {
    final generatedUid =
        FirebaseFirestore.instance.collection('users').doc().id;
    final uidController = TextEditingController(text: generatedUid);
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    String role = 'waiter';
    String? uidError;

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Create User'),
              content: SizedBox(
                width: 460,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: uidController,
                      onChanged: (value) {
                        final normalizedUid = value.trim();
                        setDialogState(() {
                          uidError = normalizedUid == _protectedRoleUid
                              ? 'This UID is reserved for the protected account.'
                              : null;
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'UID (auto-generated by default)',
                        errorText: uidError,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Name'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: emailController,
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: phoneController,
                      decoration: const InputDecoration(labelText: 'Phone'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: role,
                      dropdownColor: Colors.white,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                      iconEnabledColor: Theme.of(context).colorScheme.onSurface,
                      items: _roles
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(_roleLabel(value)),
                            ),
                          )
                          .toList(),
                      decoration: const InputDecoration(labelText: 'Role'),
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setDialogState(() => role = value);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: uidError != null
                      ? null
                      : () => Navigator.pop(context, true),
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );

    if (!mounted) {
      uidController.dispose();
      nameController.dispose();
      emailController.dispose();
      phoneController.dispose();
      return;
    }

    if (shouldSave != true) {
      uidController.dispose();
      nameController.dispose();
      emailController.dispose();
      phoneController.dispose();
      return;
    }

    final uidInput = uidController.text.trim();
    final uid = uidInput.isEmpty ? generatedUid : uidInput;
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final phone = phoneController.text.trim();
    final roleToSave =
        _roles.contains(_normalizeRole(role)) ? _normalizeRole(role) : 'waiter';

    try {
      if (uid == _protectedRoleUid) {
        _showSnack('This UID is reserved and cannot be used.');
        return;
      }

      final existingUser = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (existingUser.exists) {
        _showSnack('A user with this UID already exists. Use Edit instead.');
        return;
      }

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'name': name,
        'email': email,
        'phone': phone,
        'role': roleToSave,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await _writeAudit(
        action: 'user_created',
        target: uid,
        details: 'Created user with role $roleToSave',
      );
      _showSnack('User created: $uid');
    } catch (_) {
      _showSnack('Could not create user right now');
    } finally {
      uidController.dispose();
      nameController.dispose();
      emailController.dispose();
      phoneController.dispose();
    }
  }

  Future<void> _editUser(
      QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final data = doc.data();
    final roleLocked = _isProtectedUser(doc.id);
    final nameController = TextEditingController(
      text: data['name']?.toString() ?? '',
    );
    final emailController = TextEditingController(
      text: data['email']?.toString() ?? '',
    );
    final phoneController = TextEditingController(
      text: data['phone']?.toString() ?? '',
    );
    String role = data['role']?.toString().toLowerCase() ?? 'waiter';
    if (!_roles.contains(role)) {
      role = 'waiter';
    }

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit User'),
              content: SizedBox(
                width: 460,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Name'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: emailController,
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: phoneController,
                      decoration: const InputDecoration(labelText: 'Phone'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: role,
                      dropdownColor: Colors.white,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                      iconEnabledColor: Theme.of(context).colorScheme.onSurface,
                      items: _roles
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(_roleLabel(value)),
                            ),
                          )
                          .toList(),
                      decoration: const InputDecoration(labelText: 'Role'),
                      onChanged: roleLocked
                          ? null
                          : (value) {
                              if (value == null) {
                                return;
                              }
                              setDialogState(() => role = value);
                            },
                    ),
                    if (roleLocked)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Role is locked for this UID.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                  ],
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

    if (!mounted) {
      nameController.dispose();
      emailController.dispose();
      phoneController.dispose();
      return;
    }

    if (shouldSave != true) {
      nameController.dispose();
      emailController.dispose();
      phoneController.dispose();
      return;
    }

    final roleToSave =
        roleLocked ? _normalizeRole(data['role']?.toString()) : role;
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final phone = phoneController.text.trim();

    try {
      await doc.reference.set({
        'name': name,
        'email': email,
        'phone': phone,
        'role': roleToSave,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await _writeAudit(
        action: 'user_updated',
        target: doc.id,
        details: 'Updated user profile and role to $roleToSave',
      );
      _showSnack('User updated');
    } catch (_) {
      _showSnack('Could not update user right now');
    } finally {
      nameController.dispose();
      emailController.dispose();
      phoneController.dispose();
    }
  }

  Future<void> _deleteUser(
      QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    if (_isProtectedUser(doc.id)) {
      _showSnack('This account is protected and cannot be deleted.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete user?'),
          content: Text('Delete user document "${doc.id}"?'),
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
        );
      },
    );

    if (!mounted) {
      return;
    }

    if (confirmed != true) {
      return;
    }
    try {
      await doc.reference.delete();
      await _writeAudit(
        action: 'user_deleted',
        target: doc.id,
        details: 'Deleted user document',
      );
      _showSnack('User deleted');
    } catch (_) {
      _showSnack('Could not delete user right now');
    }
  }

  Widget _buildDesktopTable(
    BuildContext context,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final adminCount = docs
        .where((doc) => _normalizeRole(doc.data()['role']?.toString()) == 'admin')
        .length;
    final protectedCount = docs.where((doc) => _isProtectedUser(doc.id)).length;

    DataColumn sortColumn(
      String label,
      _UserSortField field, {
      Widget? icon,
    }) {
      final selected = _sortField == field;
      return DataColumn(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              icon,
              const SizedBox(width: 8),
            ],
            Text(label),
            const SizedBox(width: 6),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              child: Icon(
                selected
                    ? (_sortAscending
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded)
                    : Icons.unfold_more_rounded,
                key: ValueKey('${field.name}-${selected ? _sortAscending : 0}'),
                size: 16,
                color: selected ? scheme.primary : Colors.black38,
              ),
            ),
          ],
        ),
        onSort: (_, __) => _sortBy(field),
      );
    }

    DataCell textCell(String text) {
      return DataCell(
        Text(
          text.isEmpty ? '—' : text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );
    }

    Widget statPill({
      required IconData icon,
      required String label,
      required Color color,
    }) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.14)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      );
    }

    final rows = docs.map((doc) {
      final data = doc.data();
      final name = data['name']?.toString().trim() ?? '';
      final email = data['email']?.toString().trim() ?? '';
      final phone = data['phone']?.toString().trim() ?? '';
      final role = _normalizeRole(data['role']?.toString());
      final roleLocked = _isProtectedUser(doc.id);
      final accent = _roleTint(scheme, role);

      return DataRow(
        color: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.selected)) {
            return scheme.primary.withValues(alpha: 0.08);
          }
          return null;
        }),
        cells: [
          DataCell(
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: accent.withValues(alpha: 0.12),
                  child: Text(
                    (name.isNotEmpty ? name : 'U')[0].toUpperCase(),
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 220),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name.isEmpty ? 'Unnamed User' : name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _shortUid(doc.id),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Colors.black54,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          textCell(email),
          textCell(phone),
          DataCell(
            SizedBox(
              width: 190,
              child: _buildRoleField(
                context: context,
                uid: doc.id,
                role: role,
                locked: roleLocked,
                onChanged: (value) async {
                  if (value == null || value == role) {
                    return false;
                  }
                  return _updateRole(doc, value);
                },
              ),
            ),
          ),
          DataCell(
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                _shortUid(doc.id),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ),
          DataCell(
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                IconButton.outlined(
                  tooltip: 'Edit user',
                  onPressed: () => _editUser(doc),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                ),
                IconButton.outlined(
                  tooltip: roleLocked ? 'Protected account' : 'Delete user',
                  onPressed: roleLocked ? null : () => _deleteUser(doc),
                  icon: Icon(
                    roleLocked ? Icons.lock_outline : Icons.delete_outline,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final tableMinWidth = constraints.maxWidth < 1180 ? 1180.0 : constraints.maxWidth;

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white,
                scheme.primary.withValues(alpha: 0.03),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.45)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'User Directory',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Sort by header, edit roles inline, and manage accounts from one wide workspace.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.end,
                    children: [
                      statPill(
                        icon: Icons.groups_outlined,
                        label: '${docs.length} users',
                        color: scheme.primary,
                      ),
                      statPill(
                        icon: Icons.shield_outlined,
                        label: '$adminCount admins',
                        color: scheme.error,
                      ),
                      statPill(
                        icon: Icons.lock_outline,
                        label: '$protectedCount protected',
                        color: const Color(0xffc58b00),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: tableMinWidth),
                    child: DataTable(
                      showCheckboxColumn: false,
                      sortColumnIndex: switch (_sortField) {
                        _UserSortField.name => 0,
                        _UserSortField.email => 1,
                        _UserSortField.phone => 2,
                        _UserSortField.role => 3,
                        _UserSortField.uid => 4,
                      },
                      sortAscending: _sortAscending,
                      headingRowColor: WidgetStatePropertyAll(
                        scheme.primary.withValues(alpha: 0.08),
                      ),
                      dataRowColor: WidgetStateProperty.resolveWith<Color?>(
                        (states) {
                          if (states.contains(WidgetState.hovered)) {
                            return scheme.primary.withValues(alpha: 0.04);
                          }
                          return null;
                        },
                      ),
                      horizontalMargin: 20,
                      columnSpacing: 28,
                      headingRowHeight: 56,
                      dataRowMinHeight: 72,
                      dataRowMaxHeight: 84,
                      dividerThickness: 0.6,
                      columns: [
                        sortColumn(
                          'Name',
                          _UserSortField.name,
                          icon: const Icon(Icons.badge_outlined, size: 16),
                        ),
                        sortColumn(
                          'Email',
                          _UserSortField.email,
                          icon: const Icon(Icons.email_outlined, size: 16),
                        ),
                        sortColumn(
                          'Phone',
                          _UserSortField.phone,
                          icon: const Icon(Icons.call_outlined, size: 16),
                        ),
                        sortColumn(
                          'Role',
                          _UserSortField.role,
                          icon: const Icon(Icons.shield_outlined, size: 16),
                        ),
                        sortColumn(
                          'UID',
                          _UserSortField.uid,
                          icon: const Icon(Icons.fingerprint, size: 16),
                        ),
                        const DataColumn(label: Text('Actions')),
                      ],
                      rows: rows,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRoleField({
    required BuildContext context,
    required String uid,
    required String role,
    required bool locked,
    required Future<bool> Function(String?) onChanged,
  }) {
    return _RoleDropdownField(
      uid: uid,
      role: role,
      locked: locked,
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _usersStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _UsersSkeleton();
        }
        if (snapshot.hasError) {
          return FirestoreErrorPanel(
            title: 'Users and roles cannot be loaded.',
            error: snapshot.error,
          );
        }
        final docs = snapshot.data?.docs ?? [];
        return ValueListenableBuilder<String>(
          valueListenable: widget.searchQuery,
          builder: (context, query, _) {
            final normalizedQuery = query.trim().toLowerCase();
            final filtered = docs.where((doc) {
              final data = doc.data();
              final role = _normalizeRole(data['role']?.toString());
              if (_roleFilter != 'all' && role != _roleFilter) {
                return false;
              }
              if (normalizedQuery.isEmpty) {
                return true;
              }
              final pool = [
                data['name']?.toString() ?? '',
                data['email']?.toString() ?? '',
                data['phone']?.toString() ?? '',
                data['role']?.toString() ?? '',
                doc.id,
              ].join(' ').toLowerCase();
              return pool.contains(normalizedQuery);
            }).toList();
            final visibleDocs = _sortUsers(filtered);

            final roleCounts = <String, int>{
              for (final role in _roles) role: 0
            };
            for (final doc in docs) {
              final role = _normalizeRole(doc.data()['role']?.toString());
              if (roleCounts.containsKey(role)) {
                roleCounts[role] = roleCounts[role]! + 1;
              }
            }
            final protectedExists = docs.any((doc) => _isProtectedUser(doc.id));

            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  AnimatedCrossFade(
                    duration: const Duration(milliseconds: 240),
                    firstCurve: Curves.easeInOut,
                    secondCurve: Curves.easeInOut,
                    sizeCurve: Curves.easeInOut,
                    crossFadeState: _introExpanded
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    firstChild: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.black12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 18,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(
                                    alpha: 0.12,
                                  ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              Icons.manage_accounts_outlined,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Users & Roles',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Collapsed mode keeps the directory front and center.',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: _createUser,
                            icon: const Icon(Icons.person_add_alt_1),
                            label: const Text('Add User'),
                          ),
                          const SizedBox(width: 8),
                          IconButton.outlined(
                            onPressed: () => _setIntroExpanded(true),
                            icon: const Icon(Icons.expand_more),
                            tooltip: 'Expand intro',
                          ),
                        ],
                      ),
                    ),
                    secondChild: AdminPageIntro(
                      icon: Icons.manage_accounts_outlined,
                      title: 'Users & Roles',
                      subtitle:
                          'Assign access, keep accounts accurate, and manage staff from one focused control surface.',
                      badges: [
                        AdminBadge(
                          icon: Icons.groups_outlined,
                          label: '${docs.length} users',
                        ),
                        AdminBadge(
                          icon: Icons.shield_outlined,
                          label: '${roleCounts['admin'] ?? 0} admins',
                        ),
                        AdminBadge(
                          icon: Icons.lock_outline,
                          label: protectedExists
                              ? 'Protected account'
                              : 'No protected account',
                        ),
                      ],
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FilledButton.icon(
                            onPressed: _createUser,
                            icon: const Icon(Icons.person_add_alt_1),
                            label: const Text('Add User'),
                          ),
                          const SizedBox(width: 8),
                          IconButton.outlined(
                            onPressed: () => _setIntroExpanded(false),
                            icon: const Icon(Icons.expand_less),
                            tooltip: 'Collapse intro',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      ChoiceChip(
                        selected: _roleFilter == 'all',
                        label: const Text('All roles'),
                        onSelected: (_) => setState(() => _roleFilter = 'all'),
                      ),
                      for (final role in _roles)
                        ChoiceChip(
                          selected: _roleFilter == role,
                          label: Text(
                            '${_roleLabel(role)} (${roleCounts[role] ?? 0})',
                          ),
                          onSelected: (_) => setState(() => _roleFilter = role),
                        ),
                      TextButton.icon(
                        onPressed: () => setState(() => _roleFilter = 'all'),
                        icon: const Icon(Icons.tune_outlined),
                        label: const Text('Reset filter'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: MediaQuery.of(context).size.width >= 1120
                        ? _buildDesktopTable(context, visibleDocs)
                        : visibleDocs.isEmpty
                            ? const Center(child: Text('No users found.'))
                            : GridView.builder(
                                gridDelegate:
                                    const SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 520,
                                  mainAxisSpacing: 12,
                                  crossAxisSpacing: 12,
                                  mainAxisExtent: 340,
                                ),
                                itemCount: visibleDocs.length,
                                itemBuilder: (context, index) {
                                  final doc = visibleDocs[index];
                                  final data = doc.data();
                                  final name = data['name']?.toString().trim();
                                  final email =
                                      data['email']?.toString().trim();
                                  final phone =
                                      data['phone']?.toString().trim();
                                  final role = _normalizeRole(
                                    data['role']?.toString(),
                                  );
                                  final roleLocked = _isProtectedUser(doc.id);
                                  final accent = _roleTint(
                                    Theme.of(context).colorScheme,
                                    role,
                                  );
                                  final displayName = name?.isNotEmpty == true
                                      ? name!
                                      : 'Unnamed User';
                                  final displayEmail = email?.isNotEmpty == true
                                      ? email!
                                      : 'No email';
                                  final displayPhone = phone?.isNotEmpty == true
                                      ? phone!
                                      : 'No phone';
                                  return Card(
                                    elevation: 0,
                                    color: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                      side: BorderSide(
                                        color: accent.withValues(alpha: 0.12),
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              CircleAvatar(
                                                backgroundColor: accent
                                                    .withValues(alpha: 0.12),
                                                child: Text(
                                                  displayName[0].toUpperCase(),
                                                  style: TextStyle(
                                                    color: accent,
                                                    fontWeight: FontWeight.w800,
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
                                                      displayName,
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .titleMedium
                                                          ?.copyWith(
                                                            fontWeight:
                                                                FontWeight.w800,
                                                          ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      displayEmail,
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodySmall,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              if (roleLocked)
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 10,
                                                    vertical: 6,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.amber
                                                        .withValues(
                                                            alpha: 0.16),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            999),
                                                  ),
                                                  child: const Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.lock_outline,
                                                          size: 14),
                                                      SizedBox(width: 6),
                                                      Text('Protected'),
                                                    ],
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          _UserMeta(
                                            label: 'Phone',
                                            value: displayPhone,
                                          ),
                                          const SizedBox(height: 8),
                                          _UserMeta(
                                            label: 'UID',
                                            value: _shortUid(doc.id),
                                          ),
                                          const SizedBox(height: 10),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            crossAxisAlignment:
                                                WrapCrossAlignment.center,
                                            children: [
                                              SizedBox(
                                                width: 180,
                                                child: _buildRoleField(
                                                  context: context,
                                                  uid: doc.id,
                                                  role: role,
                                                  locked: roleLocked,
                                                  onChanged: (value) async {
                                                    if (value == null ||
                                                        value == role) {
                                                      return false;
                                                    }
                                                    return _updateRole(
                                                      doc,
                                                      value,
                                                    );
                                                  },
                                                ),
                                              ),
                                              OutlinedButton.icon(
                                                onPressed: () => _editUser(doc),
                                                icon: const Icon(
                                                    Icons.edit_outlined),
                                                label: const Text('Edit'),
                                              ),
                                              const SizedBox(width: 8),
                                              OutlinedButton.icon(
                                                onPressed: roleLocked
                                                    ? null
                                                    : () => _deleteUser(doc),
                                                icon: const Icon(
                                                  Icons.delete_outline,
                                                ),
                                                label: Text(
                                                  roleLocked
                                                      ? 'Protected'
                                                      : 'Delete',
                                                ),
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

class _UserMeta extends StatelessWidget {
  const _UserMeta({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
      ),
      child: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

class _RoleDropdownField extends StatefulWidget {
  const _RoleDropdownField({
    required this.uid,
    required this.role,
    required this.locked,
    required this.onChanged,
  });

  final String uid;
  final String role;
  final bool locked;
  final Future<bool> Function(String?) onChanged;

  @override
  State<_RoleDropdownField> createState() => _RoleDropdownFieldState();
}

class _RoleDropdownFieldState extends State<_RoleDropdownField> {
  late String _selectedRole;
  bool _updating = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _selectedRole = _roles.contains(widget.role) ? widget.role : 'waiter';
  }

  @override
  void didUpdateWidget(covariant _RoleDropdownField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.role != widget.role) {
      _selectedRole = _roles.contains(widget.role) ? widget.role : 'waiter';
      _updating = false;
      _errorText = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dropdownTextStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w600,
        );

    return DropdownButtonFormField<String>(
      key: ValueKey('user-role-${widget.uid}'),
      initialValue: _selectedRole,
      isExpanded: true,
      menuMaxHeight: 320,
      dropdownColor: Colors.white,
      style: dropdownTextStyle,
      iconEnabledColor: scheme.onSurface,
      decoration: InputDecoration(
        labelText: 'Role',
        hintText: 'Select role',
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        suffixIcon: _updating
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : null,
        errorText: _errorText,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: widget.locked
                ? Colors.black12
                : scheme.primary.withValues(alpha: 0.18),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: scheme.primary,
            width: 1.4,
          ),
        ),
      ),
      selectedItemBuilder: (context) => _roles
          .map(
            (value) => Align(
              alignment: Alignment.centerLeft,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Text(
                  _roleLabel(value),
                  key: ValueKey(value),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _roleTint(scheme, value),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          )
          .toList(),
      items: _roles
          .map(
            (value) => DropdownMenuItem<String>(
              value: value,
              child: Text(
                _roleLabel(value),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _roleTint(scheme, value),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          )
          .toList(),
      onChanged: widget.locked || _updating
          ? null
          : (value) async {
              if (value == null || value == _selectedRole) {
                return;
              }

              if (value == 'admin') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) {
                    return AlertDialog(
                      title: const Text('Confirm Admin Role'),
                      content: const Text(
                        'Are you sure you want to assign the Admin role to this user?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(dialogContext, true),
                          child: const Text('Yes, assign'),
                        ),
                      ],
                    );
                  },
                );
                if (!mounted) {
                  return;
                }
                if (confirm != true) {
                  return;
                }
              }

              final previousRole = _selectedRole;
              setState(() {
                _selectedRole = value;
                _updating = true;
                _errorText = null;
              });

              final success = await widget.onChanged(value);
              if (!mounted) {
                return;
              }
              setState(() {
                if (!success) {
                  _selectedRole = previousRole;
                  _errorText = 'Update failed';
                } else {
                  _errorText = null;
                }
                _updating = false;
              });
            },
    );
  }
}

class _UsersSkeleton extends StatelessWidget {
  const _UsersSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(20),
      child: Column(
        children: [
          SkeletonBox(height: 32),
          SizedBox(height: 12),
          SkeletonBox(height: 90),
          SizedBox(height: 10),
          SkeletonBox(height: 90),
          SizedBox(height: 10),
          SkeletonBox(height: 90),
        ],
      ),
    );
  }
}
