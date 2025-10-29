import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/app_data.dart';
import '../../data/models.dart';
import '../../data/db/app_database.dart'; // DB
import '../../notifications/notification_bridge.dart'; // ⬅️ الجسر الجديد
import '../screens/add_medicine_page.dart'; // لفتح شاشة التعديل
import '../home_page.dart'; // ⬅️ لإنعاش تبويب "أدويتي اليوم" فورًا

class AllTab extends StatefulWidget {
  const AllTab({super.key});

  @override
  State<AllTab> createState() => _AllTabState();
}

class _AllTabState extends State<AllTab> with AutomaticKeepAliveClientMixin {
  static const String allPatientsLabel = 'كل المرضى';
  String _selectedPatient = allPatientsLabel;

  /// تُستدعى من HomePage عبر GlobalKey بعد الإضافة/التعديل/الحذف
  void refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // بسبب AutomaticKeepAliveClientMixin

    final doses = AppData.I.doses;
    final patients = AppData.I.patients.map((p) => p.name).toList();

    if (doses.isEmpty) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: DropdownButtonFormField<String>(
              value: _selectedPatient,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'اختيار المريض',
                prefixIcon: Icon(Icons.person_search),
                border: OutlineInputBorder(),
              ),
              items: <String>[allPatientsLabel, ...patients]
                  .map((name) => DropdownMenuItem(value: name, child: Text(name)))
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() => _selectedPatient = v);
              },
            ),
          ),
          const Expanded(
            child: Center(child: Text('لا توجد أدوية مُضافة بعد')),
          ),
        ],
      );
    }

    // نجمع الجرعات حسب (المريض + الدواء + الجرعة)
    final Map<String, _MedGroup> groups = {};
    for (final d in doses) {
      final key = '${d.patientName}|${d.medicineName}|${d.doseText}';
      groups.putIfAbsent(
        key,
            () => _MedGroup(
          patientName: d.patientName,
          medicineName: d.medicineName,
          doseText: d.doseText,
          firstTime: d.time,
        ),
      );
      groups[key]!.considerTime(d.time);
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: DropdownButtonFormField<String>(
            value: _selectedPatient,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'اختيار المريض',
              prefixIcon: Icon(Icons.person_search),
              border: OutlineInputBorder(),
            ),
            items: <String>[allPatientsLabel, ...patients]
                .map((name) => DropdownMenuItem(value: name, child: Text(name)))
                .toList(),
            onChanged: (v) {
              if (v == null) return;
              setState(() => _selectedPatient = v);
            },
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: _selectedPatient == allPatientsLabel
              ? _buildAllPatients(groups)
              : _buildSinglePatient(groups, _selectedPatient),
        ),
      ],
    );
  }

  Widget _buildAllPatients(Map<String, _MedGroup> groups) {
    final byPatient = <String, List<_MedGroup>>{};
    for (final g in groups.values) {
      byPatient.putIfAbsent(g.patientName, () => []).add(g);
    }
    for (final list in byPatient.values) {
      list.sort((a, b) => a.medicineName.compareTo(b.medicineName));
    }
    final sortedPatientNames = byPatient.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: sortedPatientNames.length,
      itemBuilder: (ctx, i) {
        final patientName = sortedPatientNames[i];
        final items = byPatient[patientName]!;
        return _PatientSection(
          title: patientName,
          items: items,
          onChanged: () => setState(() {}),
        );
      },
    );
  }

  Widget _buildSinglePatient(Map<String, _MedGroup> groups, String patientName) {
    final items = groups.values
        .where((g) => g.patientName == patientName)
        .toList()
      ..sort((a, b) => a.medicineName.compareTo(b.medicineName));

    if (items.isEmpty) {
      return Center(child: Text('لا توجد أدوية للمريض "$patientName"'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) => _MedCard(group: items[i], onChanged: () => setState(() {})),
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class _PatientSection extends StatelessWidget {
  final String title;
  final List<_MedGroup> items;
  final VoidCallback onChanged;
  const _PatientSection({required this.title, required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(4, 8, 4, 6),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        ...items.map((g) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _MedCard(group: g, onChanged: onChanged),
        )),
      ],
    );
  }
}

class _MedCard extends StatelessWidget {
  final _MedGroup group;
  final VoidCallback onChanged;
  const _MedCard({required this.group, required this.onChanged});

  Future<void> _deleteGroupFromDbMemoryAndNotifications() async {
    // 1) اجلب الجرعات المطابقة من الذاكرة (حتى نكنسل إشعاراتها)
    final groupDoses = AppData.I.doses
        .where((d) =>
    d.patientName == group.patientName &&
        d.medicineName == group.medicineName &&
        d.doseText == group.doseText)
        .toList();

    // 2) ألغِ إشعارات كل جرعة في المجموعة
    for (final d in groupDoses) {
      try {
        await NotificationBridge.cancelDose(d);
      } catch (_) {}
    }

    // 3) احذف من قاعدة البيانات
    await AppDatabase.I.db.delete(
      'doses',
      where: 'patient_name = ? AND medicine_name = ? AND dose_text = ?',
      whereArgs: [group.patientName, group.medicineName, group.doseText],
    );

    // 4) احذف من الذاكرة
    AppData.I.doses.removeWhere((d) =>
    d.patientName == group.patientName &&
        d.medicineName == group.medicineName &&
        d.doseText == group.doseText);
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat.yMMMd('ar');
    final timeFmt = DateFormat.jm('ar');

    final typeName = _inferTypeName(group.doseText);
    final typeColor = _typeColor(typeName);
    final typeIcon = _typeIcon(typeName);

    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: typeColor.withOpacity(0.15),
          child: Icon(typeIcon, color: typeColor),
        ),
        title: Text('$typeName • ${group.medicineName}'),
        subtitle: Text(
          'أول جرعة: ${dateFmt.format(group.firstTime)} • ${timeFmt.format(group.firstTime)}\n'
              'الجرعة: ${group.doseText}',
        ),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'تعديل',
              icon: const Icon(Icons.edit, color: Colors.green),
              onPressed: () async {
                // --- جمع جرعات المجموعة لحساب الفاصل/الأيام والإرسال لصفحة التعديل ---
                final groupDoses = AppData.I.doses
                    .where((d) =>
                d.patientName == group.patientName &&
                    d.medicineName == group.medicineName &&
                    d.doseText == group.doseText)
                    .toList()
                  ..sort((a, b) => a.time.compareTo(b.time));

                // أول جرعة
                final first = groupDoses.first.time;
                // نحسب الفاصل بالساعات من أصغر فرق بين جرعات متتالية (إن وُجد)
                int intervalHours = 8;
                for (int i = 1; i < groupDoses.length; i++) {
                  final diff = groupDoses[i].time.difference(groupDoses[i - 1].time).inHours;
                  if (diff > 0) {
                    intervalHours = diff;
                    break;
                  }
                }
                // عدد الأيام بالتقريب من (آخر - أول)
                final last = groupDoses.last.time;
                final totalHours = (last.difference(first).inHours);
                final days = (totalHours / 24).ceil().clamp(1, 90);

                // استنتاج النوع من الوحدة
                final typeName = _inferTypeName(group.doseText);

                // شطر الجرعة إلى رقم + وحدة (مثلاً "2حبة" → 2 و"حبة")
                final doseMatch = RegExp(r'^(\d+)\s*(.*)$').firstMatch(group.doseText);
                final initialDoseNumber = doseMatch != null ? doseMatch.group(1) ?? '1' : '1';
                final initialUnit = doseMatch != null ? (doseMatch.group(2) ?? '') : '';

                // تحويل الفاصل إلى (قيمة + وحدة)
                final intervalValue =
                (intervalHours % 24 == 0) ? (intervalHours ~/ 24) : intervalHours;
                final intervalUnit = (intervalHours % 24 == 0) ? 'أيام' : 'ساعات';

                // نفتح صفحة "إضافة دواء" بوضع تعديل
                final saved = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => AddMedicinePage.edit(
                      originalPatientName: group.patientName,
                      originalMedicineName: group.medicineName,
                      originalDoseText: group.doseText,
                      // قيم مبدئية:
                      initialPatientName: group.patientName,
                      initialMedicineName: group.medicineName,
                      initialType: typeName,
                      initialDoseNumber: initialDoseNumber,
                      initialUnit: initialUnit,
                      initialFirstDate: DateTime(first.year, first.month, first.day),
                      initialFirstTime: TimeOfDay(hour: first.hour, minute: first.minute),
                      initialIntervalValue: intervalValue,
                      initialIntervalUnit: intervalUnit, // 'ساعات' أو 'أيام'
                      initialDays: days,
                    ),
                  ),
                );

                if (saved == true) {
                  onChanged(); // ← إعادة بناء القائمة مباشرةً هنا
                  // ← تحديث تبويب "أدويتي اليوم" مباشرةً
                  HomePage.gKey.currentState?.refreshTodayTab();
                }
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
                    content: Text(
                      'سيتم حذف جميع الجرعات لدواء "${group.medicineName}" (${group.doseText}) للمريض ${group.patientName}.',
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف')),
                    ],
                  ),
                );
                if (ok == true) {
                  await _deleteGroupFromDbMemoryAndNotifications();
                  onChanged(); // تحديث بطاقة "كل الأدوية"
                  // ← تحديث تبويب "أدويتي اليوم" مباشرةً
                  HomePage.gKey.currentState?.refreshTodayTab();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(const SnackBar(content: Text('تم الحذف')));
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // استنتاج النوع من الوحدة
  static String _inferTypeName(String doseText) {
    if (doseText.endsWith('حبة')) return 'حب';
    if (doseText.endsWith('كبسولة')) return 'كبسول';
    if (doseText.endsWith('ml')) return 'شراب';
    if (doseText.endsWith('cc')) return 'حقن';
    if (doseText.endsWith('بخة')) return 'بخاخ';
    if (doseText.endsWith('تحميلة')) return 'تحميلة';
    return 'دواء';
  }

  static IconData _typeIcon(String typeName) {
    switch (typeName) {
      case 'حب':
        return Icons.medication;
      case 'كبسول':
        return Icons.radio_button_checked;
      case 'شراب':
        return Icons.local_drink;
      case 'حقن':
        return Icons.healing;
      case 'بخاخ':
        return Icons.air;
      case 'تحميلة':
        return Icons.water_drop;
      default:
        return Icons.medication_outlined;
    }
  }

  static Color _typeColor(String typeName) {
    switch (typeName) {
      case 'حب':
        return const Color(0xFF42A5F5);
      case 'كبسول':
        return const Color(0xFF7E57C2);
      case 'شراب':
        return const Color(0xFF66BB6A);
      case 'حقن':
        return const Color(0xFFEF5350);
      case 'بخاخ':
        return const Color(0xFFFFA726);
      case 'تحميلة':
        return const Color(0xFF26C6DA);
      default:
        return Colors.blueGrey;
    }
  }
}

/// مجموعة تمثّل دواء واحد (مريض + اسم + جرعة) مع أقدم موعد جرعة
class _MedGroup {
  final String patientName;
  final String medicineName;
  final String doseText;

  DateTime _minTime;

  _MedGroup({
    required this.patientName,
    required this.medicineName,
    required this.doseText,
    required DateTime firstTime,
  }) : _minTime = firstTime;

  void considerTime(DateTime t) {
    if (t.isBefore(_minTime)) _minTime = t;
  }

  DateTime get firstTime => _minTime;
}
