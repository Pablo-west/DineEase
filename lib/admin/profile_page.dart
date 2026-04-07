import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'admin_ui.dart';
import 'loading_skeleton.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _profileStream;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _initializedFromSnapshot = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    _profileStream = FirebaseFirestore.instance
        .collection('users')
        .doc(user?.uid ?? '')
        .snapshots();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _save(String uid, String role, String email) async {
    if (!_formKey.currentState!.validate() || _saving) {
      return;
    }

    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'role': role,
        'email': email,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (!mounted) {
        return;
      }
      _showSnack('Profile updated');
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showSnack('Failed to update profile');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _showSnack(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      return;
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  double _profileCompleteness(String name, String phone, String email) {
    final fields = [name.trim(), phone.trim(), email.trim()];
    final filled = fields.where((value) => value.isNotEmpty).length;
    return filled / fields.length;
  }

  String _formatDate(dynamic value) {
    if (value is Timestamp) {
      final date = value.toDate();
      final month = date.month.toString().padLeft(2, '0');
      final day = date.day.toString().padLeft(2, '0');
      return '${date.year}-$month-$day';
    }
    if (value is DateTime) {
      final month = value.month.toString().padLeft(2, '0');
      final day = value.day.toString().padLeft(2, '0');
      return '${value.year}-$month-$day';
    }
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return 'Unknown';
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Not signed in.'));
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _profileStream,
      builder: (context, profileSnap) {
        if (profileSnap.connectionState == ConnectionState.waiting) {
          return const _ProfilePageSkeleton();
        }
        if (profileSnap.hasError) {
          return FirestoreErrorPanel(
            title: 'Profile cannot be loaded.',
            error: profileSnap.error,
          );
        }

        final data = profileSnap.data?.data() ?? {};
        final role = data['role']?.toString() ?? 'unknown';
        final name = data['name']?.toString() ?? '';
        final phone = data['phone']?.toString() ?? '';
        final email = user.email ?? 'No email';

        if (!_initializedFromSnapshot) {
          _nameController.text = name;
          _phoneController.text = phone;
          _initializedFromSnapshot = true;
        }

        final completeness = _profileCompleteness(name, phone, email);
        final metadata = user.metadata;
        // final scheme = Theme.of(context).colorScheme;

        final hero = AdminPageIntro(
          icon: Icons.account_circle_outlined,
          title: name.isEmpty ? 'Admin Profile' : name,
          subtitle:
              'Your identity, permissions, and account details in one place.',
          badges: [
            AdminBadge(
              icon: Icons.verified_user_outlined,
              label: role.toUpperCase(),
            ),
            AdminBadge(
              icon: Icons.markunread_outlined,
              label: email,
            ),
            // AdminBadge(
            //   icon: Icons.fingerprint,
            //   label: user.uid,
            // ),
          ],
        );

        final overviewTiles = Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _MetricTile(
              title: 'Role',
              value: role.toUpperCase(),
              icon: Icons.badge_outlined,
            ),
            _MetricTile(
              title: 'Profile',
              value: '${(completeness * 100).round()}%',
              icon: Icons.health_and_safety_outlined,
            ),
            _MetricTile(
              title: 'Updated',
              value: _formatDate(data['updatedAt']),
              icon: Icons.update_outlined,
            ),
            _MetricTile(
              title: 'Created',
              value: _formatDate(metadata.creationTime),
              icon: Icons.event_outlined,
            ),
          ],
        );

        final editorCard = AdminSectionCard(
          title: 'Edit Profile',
          subtitle:
              'Keep your contact details current for admin and operational communication.',
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, formConstraints) {
                    final twoCols = formConstraints.maxWidth > 760;
                    if (!twoCols) {
                      return Column(
                        children: [
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Full name',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Name is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _phoneController,
                            decoration: const InputDecoration(
                              labelText: 'Phone',
                              prefixIcon: Icon(Icons.phone_outlined),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Phone is required';
                              }
                              return null;
                            },
                          ),
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Full name',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Name is required';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _phoneController,
                            decoration: const InputDecoration(
                              labelText: 'Phone',
                              prefixIcon: Icon(Icons.phone_outlined),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Phone is required';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed:
                          _saving ? null : () => _save(user.uid, role, email),
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(_saving ? 'Saving...' : 'Save Changes'),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton(
                      onPressed: _saving
                          ? null
                          : () {
                              _nameController.text = name;
                              _phoneController.text = phone;
                              setState(() {});
                            },
                      child: const Text('Reset'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );

        final accountCard = AdminSectionCard(
          title: 'Account Snapshot',
          subtitle: 'Identity and security details from Firebase Auth.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // _DetailRow(label: 'UID', value: user.uid),
              _DetailRow(label: 'Email', value: email),
              _DetailRow(
                label: 'Email verified',
                value: user.emailVerified ? 'Yes' : 'No',
              ),
              _DetailRow(
                label: 'Provider',
                value: user.providerData.isEmpty
                    ? 'Unknown'
                    : user.providerData.map((e) => e.providerId).join(', '),
              ),
              _DetailRow(
                label: 'Last sign-in',
                value: metadata.lastSignInTime == null
                    ? 'Unknown'
                    : _formatDate(metadata.lastSignInTime),
              ),
              _DetailRow(
                label: 'Created',
                value: metadata.creationTime == null
                    ? 'Unknown'
                    : _formatDate(metadata.creationTime),
              ),
            ],
          ),
        );

        // final insightCard = AdminSectionCard(
        //   title: 'Profile Health',
        //   subtitle: 'A quick read on how complete your admin profile is.',
        //   child: Column(
        //     crossAxisAlignment: CrossAxisAlignment.start,
        //     children: [
        //       LinearProgressIndicator(
        //         value: completeness,
        //         minHeight: 10,
        //         backgroundColor: scheme.primary.withValues(alpha: 0.12),
        //         valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
        //       ),
        //       const SizedBox(height: 10),
        //       Text(
        //         '${(completeness * 100).round()}% complete',
        //         style: Theme.of(context).textTheme.titleMedium?.copyWith(
        //               fontWeight: FontWeight.w700,
        //             ),
        //       ),
        //       const SizedBox(height: 6),
        //       Text(
        //         'Complete the remaining fields to keep your admin contact card polished and reliable.',
        //         style: Theme.of(context).textTheme.bodySmall,
        //       ),
        //     ],
        //   ),
        // );

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1240),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 1120;

                  if (wide) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        hero,
                        const SizedBox(height: 12),
                        overviewTiles,
                        const SizedBox(height: 14),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: editorCard,
                            ),
                            const SizedBox(width: 14),
                            SizedBox(
                              width: 360,
                              child: Column(
                                children: [
                                  accountCard,
                                  const SizedBox(height: 14),
                                  // insightCard,
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      hero,
                      const SizedBox(height: 12),
                      overviewTiles,
                      const SizedBox(height: 14),
                      editorCard,
                      const SizedBox(height: 14),
                      accountCard,
                      const SizedBox(height: 14),
                      // insightCard,
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Colors.black54,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
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

class _ProfilePageSkeleton extends StatelessWidget {
  const _ProfilePageSkeleton();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1240),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox(height: 138),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: SkeletonBox(height: 90)),
                  SizedBox(width: 12),
                  Expanded(child: SkeletonBox(height: 90)),
                  SizedBox(width: 12),
                  Expanded(child: SkeletonBox(height: 90)),
                  SizedBox(width: 12),
                  Expanded(child: SkeletonBox(height: 90)),
                ],
              ),
              SizedBox(height: 16),
              SkeletonBox(height: 280),
            ],
          ),
        ),
      ),
    );
  }
}
