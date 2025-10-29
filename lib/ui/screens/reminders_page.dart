import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/app_data.dart';
import '../../data/models.dart';
import '../common/app_routes.dart';

class RemindersPage extends StatefulWidget {
  const RemindersPage({super.key});

  @override
  State<RemindersPage> createState() => _RemindersPageState();
}

class _RemindersPageState extends State<RemindersPage> {
  @override
  Widget build(BuildContext context) {
    final list = [...AppData.I.reminders]..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    final dateFmt = DateFormat.yMMMd('ar');
    final timeFmt = DateFormat.jm('ar');

    return Scaffold(
      appBar: AppBar(title: const Text('التذكيرات')),
      body: list.isEmpty
          ? const Center(child: Text('لا توجد تذكيرات بعد'))
          : ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (ctx, i) {
          final r = list[i];
          final dateStr = '${dateFmt.format(r.dateTime)} • ${timeFmt.format(r.dateTime)}';
          return Card(
            elevation: 1.5,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: CircleAvatar(
                child: Icon(Icons.notifications_active, color: Theme.of(context).colorScheme.primary),
              ),
              title: Text(r.title.isEmpty ? 'تذكير' : r.title),
              subtitle: Text(
                'الوقت: $dateStr${r.notes == null || r.notes!.trim().isEmpty ? '' : '\nملاحظات: ${r.notes}'}',
              ),
              isThreeLine: true,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'تعديل',
                    icon: const Icon(Icons.edit, color: Colors.green),
                    onPressed: () async {
                      // نفتح صفحة الإضافة في وضع التعديل مع تمرير الكائن
                      final saved = await Navigator.of(context).pushNamed(
                        AppRoutes.addReminder,
                        arguments: {
                          'mode': 'edit',
                          'reminder': r,
                        },
                      ) as bool?;
                      if (saved == true && context.mounted) setState(() {});
                    },
                  ),
                  IconButton(
                    tooltip: 'حذف',
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('تأكيد الحذف'),
                          content: Text('سيتم حذف التذكير:\n"${r.title}".'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف')),
                          ],
                        ),
                      );
                      if (ok == true) {
                        AppData.I.deleteReminder(r);
                        if (context.mounted) {
                          setState(() {});
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('تم حذف التذكير')),
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
