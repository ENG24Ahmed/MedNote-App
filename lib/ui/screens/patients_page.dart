// lib/ui/screens/patients_page.dart
import 'package:flutter/material.dart';
import '../../data/app_data.dart';
import '../../data/models.dart';
import 'add_patient_page.dart';

class PatientsPage extends StatefulWidget {
  const PatientsPage({super.key});

  @override
  State<PatientsPage> createState() => _PatientsPageState();
}

class _PatientsPageState extends State<PatientsPage> {
  Future<void> _deletePatientDialog(Patient p) async {
    // الخطوة 1: تأكيد عام
    final ok1 = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('سيتم حذف المريض "${p.name}".'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('متابعة')),
        ],
      ),
    );
    if (ok1 != true) return;

    // تحقق من وجود أدوية مرتبطة
    final hasDoses = AppData.I.doses.any((d) => d.patientName == p.name);

    if (hasDoses) {
      // الخطوة 2: تحذير إضافي
      final ok2 = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('تنبيه مهم'),
          content: Text(
            'المريض "${p.name}" لديه أدوية/جرعات مسجّلة.\n'
                'سيتم حذفها جميعاً إذا تم حذف هذا المريض.\n\n'
                'هل تريد المتابعة؟',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('نعم، احذف')),
          ],
        ),
      );
      if (ok2 != true) return;
    }

    // تنفيذ الحذف
    AppData.I.deletePatient(p.name);
    if (context.mounted) {
      setState(() {});
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('تم الحذف')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final patients = AppData.I.patients;

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة المرضى'),
      ),
      body: patients.isEmpty
          ? const Center(child: Text('لا يوجد مرضى مُسجلين بعد'))
          : ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: patients.length,
        separatorBuilder: (_, __) => const Divider(),
        itemBuilder: (ctx, i) {
          final p = patients[i];
          return ListTile(
            leading: CircleAvatar(
              child: Text(
                p.name.isNotEmpty ? p.name.characters.first : '؟',
              ),
            ),
            title: Text(p.name),
            subtitle: Text(
              [
                if (p.gender != null)
                  (p.gender == 'male' ? '👨 ذكر' : '👩 أنثى'),
                if (p.dob != null)
                  'العمر: ${p.ageLabel()}',
              ].join(' • '),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'تعديل المريض',
                  icon: const Icon(Icons.edit, color: Colors.green),
                  onPressed: () async {
                    final saved = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => AddPatientPage.edit(
                          originalName: p.name,
                          initialName: p.name,
                          initialGender: p.gender,
                          initialDob: p.dob,
                        ),
                      ),
                    );
                    if (saved == true && context.mounted) {
                      setState(() {});
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تم حفظ التعديل')),
                      );
                    }
                  },
                ),
                IconButton(
                  tooltip: 'حذف',
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deletePatientDialog(p),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
