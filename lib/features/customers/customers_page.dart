import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/empty_state.dart';
import '../ledger/customer_detail_page.dart';
import 'customers_controller.dart';

class CustomersPage extends StatelessWidget {
  const CustomersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(CustomersController());
    return Scaffold(
      appBar: AppBar(title: const Text('الزبائن')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addDialog(c),
        icon: const Icon(Icons.person_add),
        label: const Text('زبون جديد'),
      ),
      body: Obx(() {
        if (c.balances.isEmpty) {
          return EmptyState(
            icon: Icons.people_outline,
            title: 'دفتر زبائنك يبدأ هنا',
            message: 'أضف زبائنك لتسجيل الديون والمدفوعات ومتابعة أرصدتهم.',
            actionLabel: 'إضافة زبون',
            onAction: () => _addDialog(c),
          );
        }
        return ListView.separated(
          itemCount: c.balances.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final b = c.balances[i];
            final owes = b.balanceMinor > 0;
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .secondaryContainer,
                  child: Text(
                    b.name.trim().isEmpty
                        ? '?'
                        : b.name.trim().characters.first,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                onTap: () => Get.to(
                  () => CustomerDetailPage(customerId: b.id, name: b.name),
                ),
                title: Text(b.name),
                subtitle: b.phone == null ? null : Text(b.phone!),
                trailing: Text(
                  '${(b.balanceMinor / 100).toStringAsFixed(2)} ${b.currency ?? ''}'
                      .trim(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: owes ? Colors.red.shade700 : Colors.green.shade700,
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }

  void _addDialog(CustomersController c) {
    final name = TextEditingController();
    final phone = TextEditingController();
    Get.defaultDialog(
      title: 'زبون جديد',
      content: Column(
        children: [
          TextField(
            controller: name,
            decoration: const InputDecoration(labelText: 'الاسم'),
          ),
          TextField(
            controller: phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'الهاتف (اختياري)'),
          ),
        ],
      ),
      textConfirm: 'حفظ',
      textCancel: 'إلغاء',
      onConfirm: () async {
        if (name.text.trim().isEmpty) {
          Get.snackbar('الاسم مطلوب', 'اكتب اسم الزبون للمتابعة');
          return;
        }
        await c.add(name.text, phone.text);
        Get.back();
      },
    );
  }
}
