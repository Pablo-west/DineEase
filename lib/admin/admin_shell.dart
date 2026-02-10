import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'foods_page.dart';
import 'orders_page.dart';
import 'profile_page.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _selectedIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  final ValueNotifier<String> _searchQuery = ValueNotifier<String>('');
  bool _sidebarCollapsed = false;

  @override
  void dispose() {
    _searchController.dispose();
    _searchQuery.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isWide = MediaQuery.of(context).size.width > 1024;
    final collapse = !isWide ? true : _sidebarCollapsed;

    return Scaffold(
      body: Row(
        children: [
          _Sidebar(
            selectedIndex: _selectedIndex,
            onSelect: (index) => setState(() => _selectedIndex = index),
            isWide: isWide,
            collapsed: collapse,
            onToggle: () =>
                setState(() => _sidebarCollapsed = !_sidebarCollapsed),
          ),
          Expanded(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  height: 72,
                  child: Row(
                    children: [
                      if (collapse) ...[
                        Image.asset(
                          'assets/logo/logo-icon.png',
                          height: 28,
                          width: 28,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'DineEase Admin',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(width: 18),
                      ],
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (value) {
                            _searchQuery.value = value;
                            setState(() {});
                          },
                          decoration: InputDecoration(
                            hintText: _selectedIndex == 0
                                ? 'Search orders, users, phones, payments...'
                                : 'Search foods, categories...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _searchController.text.isEmpty
                                ? null
                                : IconButton(
                                    icon: const Icon(Icons.close),
                                    onPressed: () {
                                      _searchController.clear();
                                      _searchQuery.value = '';
                                      setState(() {});
                                    },
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      FilledButton.icon(
                        onPressed: () async {
                          await FirebaseAuth.instance.signOut();
                        },
                        icon: const Icon(Icons.logout, size: 18),
                        label: const Text('Logout'),
                        style: FilledButton.styleFrom(
                          backgroundColor: scheme.secondary,
                          foregroundColor: scheme.onSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: IndexedStack(
                    index: _selectedIndex,
                    children: [
                      OrdersPage(searchQuery: _searchQuery),
                      FoodsPage(searchQuery: _searchQuery),
                      const ProfilePage(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.selectedIndex,
    required this.onSelect,
    required this.isWide,
    required this.collapsed,
    required this.onToggle,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final bool isWide;
  final bool collapsed;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const items = [
      _NavItem(icon: Icons.receipt_long, label: 'Orders'),
      _NavItem(icon: Icons.restaurant_menu, label: 'Foods'),
      _NavItem(icon: Icons.account_circle, label: 'Profile'),
    ];

    final width = collapsed ? 84.0 : 240.0;

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment:
              collapsed ? CrossAxisAlignment.center : CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: collapsed
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                children: [
                  Image.asset(
                    'assets/logo/logo-icon.png',
                    height: 28,
                    width: 28,
                    color: Colors.white,
                  ),
                  if (!collapsed) ...[
                    const SizedBox(width: 12),
                    Text(
                      'DineEase',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(color: Colors.white),
                    ),
                  ],
                ],
              ),
            ),
            if (isWide)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Align(
                  alignment:
                      collapsed ? Alignment.center : Alignment.centerRight,
                  child: IconButton(
                    tooltip: collapsed ? 'Expand' : 'Collapse',
                    onPressed: onToggle,
                    icon: Icon(
                      collapsed ? Icons.chevron_right : Icons.chevron_left,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final active = index == selectedIndex;
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => onSelect(index),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: active
                              ? Colors.white.withValues(alpha: 0.18)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisAlignment: collapsed
                              ? MainAxisAlignment.center
                              : MainAxisAlignment.start,
                          children: [
                            Icon(
                              items[index].icon,
                              color: Colors.white,
                            ),
                            if (!collapsed) ...[
                              const SizedBox(width: 12),
                              Text(
                                items[index].label,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(color: Colors.white),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (isWide)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Admin Dashboard',
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(color: Colors.white70),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}
