import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'analytics_page.dart';
import 'audit_logs_page.dart';
import 'crm_page.dart';
import 'finance_page.dart';
import 'foods_page.dart';
import 'orders_page.dart';
import 'profile_page.dart';
import 'promotions_page.dart';
import 'users_roles_page.dart';
import 'vendors_page.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  static const _navItems = [
    _NavItem(icon: Icons.dashboard_customize_outlined, label: 'Analytics'),
    _NavItem(icon: Icons.receipt_long, label: 'Orders'),
    _NavItem(icon: Icons.storefront_outlined, label: 'Vendors'),
    _NavItem(icon: Icons.restaurant_menu, label: 'Foods'),
    _NavItem(icon: Icons.manage_accounts_outlined, label: 'Users & Roles'),
    _NavItem(icon: Icons.campaign_outlined, label: 'Promotions & Ads'),
    _NavItem(icon: Icons.groups_outlined, label: 'Customer CRM'),
    _NavItem(icon: Icons.account_balance_wallet_outlined, label: 'Finance'),
    _NavItem(icon: Icons.fact_check_outlined, label: 'Audit Logs'),
    _NavItem(icon: Icons.account_circle, label: 'Profile'),
  ];

  int _selectedIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  final ValueNotifier<String> _searchQuery = ValueNotifier<String>('');
  bool _sidebarCollapsed = false;

  void _resetSearch() {
    _searchController.clear();
    _searchQuery.value = '';
    FocusScope.of(context).unfocus();
  }

  void _selectPage(int index) {
    if (index == _selectedIndex) {
      return;
    }
    _resetSearch();
    setState(() => _selectedIndex = index);
  }

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
    final pageTitle = _titleForIndex(_selectedIndex);
    final pageSubtitle = _subtitleForIndex(_selectedIndex);

    return Scaffold(
      body: Row(
        children: [
          _Sidebar(
            selectedIndex: _selectedIndex,
            onSelect: _selectPage,
            isWide: isWide,
            collapsed: collapse,
            onToggle: () =>
                setState(() => _sidebarCollapsed = !_sidebarCollapsed),
          ),
          Expanded(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (collapse) ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: scheme.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Image.asset(
                            'assets/logo/logo-icon.png',
                            height: 28,
                            width: 28,
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pageTitle,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              pageSubtitle,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 14),
                            if (_selectedIndex != 0)
                              ValueListenableBuilder<TextEditingValue>(
                                valueListenable: _searchController,
                                builder: (context, value, _) {
                                  return SearchBar(
                                    controller: _searchController,
                                    hintText: _hintForIndex(_selectedIndex),
                                    leading: const Icon(Icons.search),
                                    trailing: [
                                      if (value.text.isNotEmpty)
                                        IconButton(
                                          icon: const Icon(Icons.close),
                                          onPressed: () {
                                            _searchController.clear();
                                            _searchQuery.value = '';
                                          },
                                        ),
                                    ],
                                    onChanged: (query) {
                                      _searchQuery.value = query;
                                    },
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              _navItems[_selectedIndex].label,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(
                                    color: scheme.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                          const SizedBox(height: 12),
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
                    ],
                  ),
                ),
                Expanded(
                  child: KeyedSubtree(
                    key: ValueKey(_selectedIndex),
                    child: _buildPage(_selectedIndex),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _titleForIndex(int index) {
    switch (index) {
      case 0:
        return 'Control Center';
      case 1:
        return 'Order Operations';
      case 2:
        return 'Vendor Directory';
      case 3:
        return 'Menu Catalog';
      case 4:
        return 'Users & Roles';
      case 5:
        return 'Promotions Studio';
      case 6:
        return 'Customer CRM';
      case 7:
        return 'Finance Hub';
      case 8:
        return 'Audit Trail';
      case 9:
      default:
        return 'Profile';
    }
  }

  String _subtitleForIndex(int index) {
    switch (index) {
      case 0:
        return 'Track the health of the business across orders, revenue, foods, and staff.';
      case 1:
        return 'Monitor incoming orders, vendor queues, and fulfillment status in real time.';
      case 2:
        return 'Manage food vendors, their availability, and the menus they own.';
      case 3:
        return 'Build a clean multi-vendor food catalog with categories and pricing.';
      case 4:
        return 'Control team access, accountability, and operational permissions.';
      case 5:
        return 'Launch promotions, pricing rules, and announcements from one surface.';
      case 6:
        return 'Understand customers, note important context, and nurture repeat orders.';
      case 7:
        return 'Review revenue, payment channels, and reconciliation records.';
      case 8:
        return 'See who changed what and keep the admin workspace accountable.';
      case 9:
      default:
        return 'Update your admin identity and operational contact details.';
    }
  }

  String _hintForIndex(int index) {
    switch (index) {
      case 0:
        return 'Search metrics, revenue, trends...';
      case 1:
        return 'Search orders, users, phones, payments...';
      case 2:
        return 'Search vendors, contacts, locations...';
      case 3:
        return 'Search foods, categories...';
      case 4:
        return 'Search users, roles, emails, phones...';
      case 5:
        return 'Search promotions, pricing rules, ads...';
      case 6:
        return 'Search customers, notes, phone, segment...';
      case 7:
        return 'Search finance entries, payment summaries...';
      case 8:
        return 'Search action, target, details, actor...';
      case 9:
      default:
        return 'Search profile details...';
    }
  }

  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return const AnalyticsPage();
      case 1:
        return OrdersPage(searchQuery: _searchQuery);
      case 2:
        return VendorsPage(searchQuery: _searchQuery);
      case 3:
        return FoodsPage(searchQuery: _searchQuery);
      case 4:
        return UsersRolesPage(searchQuery: _searchQuery);
      case 5:
        return PromotionsPage(searchQuery: _searchQuery);
      case 6:
        return CrmPage(searchQuery: _searchQuery);
      case 7:
        return FinancePage(searchQuery: _searchQuery);
      case 8:
        return AuditLogsPage(searchQuery: _searchQuery);
      case 9:
      default:
        return const ProfilePage();
    }
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
    const items = _AdminShellState._navItems;

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
                    // color: Colors.white,
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
                  final navTile = InkWell(
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
                  );

                  return Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: collapsed
                        ? Tooltip(
                            message: items[index].label,
                            waitDuration: const Duration(milliseconds: 300),
                            child: navTile,
                          )
                        : navTile,
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
