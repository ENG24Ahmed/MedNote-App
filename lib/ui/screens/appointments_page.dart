import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/app_data.dart';
import '../../data/models.dart';
import '../common/app_routes.dart';

class AppointmentsPage extends StatefulWidget {
  const AppointmentsPage({super.key});

  @override
  State<AppointmentsPage> createState() => _AppointmentsPageState();
}

class _AppointmentsPageState extends State<AppointmentsPage> {
  @override
  Widget build(BuildContext context) {
    final list = [...AppData.I.appointments]..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    final dateFmt = DateFormat.yMMMd('ar');
    final timeFmt = DateFormat.jm('ar');

    return Scaffold(
      appBar: AppBar(title: const Text('مواعيد الطبيب')),
      body: list.isEmpty
          ? const Center(child: Text('لا توجد مواعيد بعد'))
          : ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (ctx, i) {
          final a = list[i];
          final dateStr = '${dateFmt.format(a.dateTime)} • ${timeFmt.format(a.dateTime)}';
          return Card(
            elevation: 1.5,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: CircleAvatar(
                child: Icon(Icons.local_hospital, color: Theme.of(context).colorScheme.primary),
              ),
              title: Text(a.title.isEmpty ? 'موعد طبيب' : a.title),
              subtitle: Text(
                'المريض: ${a.patientName}\n'
                    'الطبيب: ${a.doctorName}\n'
                    'الوقت: $dateStr${a.notes == null || a.notes!.trim().isEmpty ? '' : '\nملاحظات: ${a.notes}'}',
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
                        AppRoutes.addAppointment,
                        arguments: {
                          'mode': 'edit',
                          'appointment': a,
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
                          content: Text('سيتم حذف الموعد:\n"${a.title}" للمريض ${a.patientName}.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف')),
                          ],
                        ),
                      );
                      if (ok == true) {
                        AppData.I.deleteAppointment(a);
                        if (context.mounted) {
                          setState(() {});
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('تم حذف الموعد')),
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
