import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../cashier/cashier_page.dart';
import '../customers/customers_page.dart';
import '../products/products_page.dart';
import '../reports/reports_page.dart';
import '../settings/backup_status_controller.dart';
import '../settings/settings_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  final Set<int> _visitedTabs = {0};

  Widget _tab(int index) {
    if (!_visitedTabs.contains(index)) return const SizedBox.shrink();
    return switch (index) {
      0 => const CashierPage(),
      1 => const CustomersPage(),
      2 => const ProductsPage(),
      3 => const ReportsPage(),
      4 => const SettingsPage(),
      _ => const SizedBox.shrink(),
    };
  }

  void _selectTab(int index) {
    setState(() {
      _index = index;
      _visitedTabs.add(index);
    });
  }

  Widget _backupBanner() {
    final b = Get.find<BackupStatusController>();
    return Obx(() {
      if (!b.overdue || b.dismissed.value) return const SizedBox.shrink();
      final lb = b.lastBackup.value;
      final text = lb == null
          ? 'ما أخذت أي نسخة احتياطية بعد. بياناتك على هذا الجوال فقط.'
          : 'آخر نسخة احتياطية قبل ${DateTime.now().difference(lb).inDays} يوم.';
      return MaterialBanner(
        backgroundColor: Colors.amber.shade100,
        content: Text(text),
        leading: const Icon(Icons.warning_amber, color: Colors.orange),
        actions: [
          TextButton(
            onPressed: () async {
              try {
                await b.backupNow();
              } catch (e) {
                Get.snackbar('خطأ', 'تعذر إنشاء النسخة: $e');
              }
            },
            child: const Text('نسخ الآن'),
          ),
          TextButton(
            onPressed: () => b.dismissed.value = true,
            child: const Text('لاحقًا'),
          ),
        ],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: List.generate(5, _tab)),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _backupBanner(),
          NavigationBar(
            selectedIndex: _index,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            onDestinationSelected: _selectTab,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.point_of_sale),
                label: 'الكاشير',
              ),
              NavigationDestination(icon: Icon(Icons.people), label: 'الزبائن'),
              NavigationDestination(
                icon: Icon(Icons.inventory_2),
                label: 'المنتجات',
              ),
              NavigationDestination(
                icon: Icon(Icons.bar_chart),
                label: 'التقارير',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings),
                label: 'الإعدادات',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
