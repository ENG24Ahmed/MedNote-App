import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/app_data.dart';
import '../../data/models.dart';
import '../../data/db/app_database.dart'; // DB للتحديث
import '../../data/settings.dart'; // ⬅️ قيم الغفوة والتنبيه المبكر
import '../../notifications/notification_bridge.dart'; // ⬅️ الجسر الجديد
import '../screens/add_medicine_page.dart';

class TodayTab extends StatefulWidget {
  const TodayTab({super.key});

  @override
  State<TodayTab> createState() => _TodayTabState();
}

class _TodayTabState extends State<TodayTab> with AutomaticKeepAliveClientMixin {
  DateTime _selectedDate = _stripTime(DateTime.now());

  /// يستدعيه الـ HomePage عبر GlobalKey بعد أي إضافة/تعديل
  void refresh() {
    if (mounted) setState(() {});
  }

  static DateTime _stripTime(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<void> _openDatePicker() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(today.year - 1, 1, 1),
      lastDate: DateTime(today.year + 1, 12, 31),
      currentDate: _stripTime(today),
    );
    if (picked != null) {
      setState(() => _selectedDate = _stripTime(picked));
    }
  }

  void _changeDay(int delta) {
    setState(() => _selectedDate = _selectedDate.add(Duration(days: delta)));
  }

  void _goToday() {
    setState(() => _selectedDate = _stripTime(DateTime.now()));
  }

  Future<void> _toggleTaken(int indexInFiltered, List<Dose> filtered) async {
    final dose = filtered[indexInFiltered];
    final now = DateTime.now();
    final minutesDiff = dose.time.difference(now).inMinutes;

    // منع التأشير قبل الموعد بـ 15 دقيقة إلا مع تأكيد
    if (!dose.taken && minutesDiff > -15 && dose.time.isAfter(now)) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("تأكيد"),
          content: const Text("الجرعة قبل موعدها بـ 15 دقيقة، هل تريد تأكيد أخذها؟"),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("إلغاء")),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("تأكيد")),
          ],
        ),
      );
      if (ok != true) return;
    }

    // اقلب الحالة في الذاكرة
    setState(() {
      dose.taken = !dose.taken;
    });

    // خزّن في قاعدة البيانات (مطابقة بالحقول الأربعة)
    final iso = dose.time.toIso8601String();
    await AppDatabase.I.db.update(
      'doses',
      {'taken': dose.taken ? 1 : 0},
      where: 'patient_name = ? AND medicine_name = ? AND dose_text = ? AND time = ?',
      whereArgs: [dose.patientName, dose.medicineName, dose.doseText, iso],
    );

    // إدارة الإشعار فورًا:
    try {
      if (dose.taken) {
        // أُخذت الجرعة → ألغِ إشعارها إن كان مجدولًا/ظاهرًا
        await NotificationBridge.cancelDose(dose);
      } else {
        // ألغيت التأشير:
        // - إذا الوقت لاحق (مستقبلي): أعد جدولة الإشعار
        // - إذا الوقت مضى: ما نعيد جدولة (متأخرة)
        if (dose.time.isAfter(DateTime.now())) {
          await NotificationBridge.scheduleDose(
            dose: dose,
            snoozeMinutes: Settings.I.snoozeMinutes.value,
            reminderLeadMinutes: Settings.I.reminderLeadMinutes.value,
            type: 'دواء',
          );
        }
      }
    } catch (_) {
      // تجاهل أي خطأ من قناة المنصة
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // مهم مع AutomaticKeepAliveClientMixin

    final filtered = AppData.I.dosesForDay(_selectedDate);
    final timeFmt = DateFormat.jm('ar'); // 12h ص/م
    final dateLabel = DateFormat.yMMMMd('ar').format(_selectedDate);

    return Column(
      children: [
        // شريط التاريخ الصغير
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
          child: Row(
            children: [
              IconButton(
                tooltip: 'اليوم السابق',
                onPressed: () => _changeDay(-1),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _openDatePicker,
                  icon: const Icon(Icons.calendar_today),
                  label: Text(dateLabel, overflow: TextOverflow.ellipsis),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'اليوم التالي',
                onPressed: () => _changeDay(1),
                icon: const Icon(Icons.chevron_right),
              ),
              const SizedBox(width: 8),
              TextButton(onPressed: _goToday, child: const Text('اليوم')),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(children: [Text('عدد الجرعات: ${filtered.length}')]),
        ),

        const SizedBox(height: 4),

        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text('لا توجد جرعات لهذا التاريخ'))
              : ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final dose = filtered[i];
              final late = DateTime.now().isAfter(dose.time) && !dose.taken;

              return Card(
                color: late ? Colors.pink[100] : null,
                child: ListTile(
                  leading: Theme(
                    data: Theme.of(context).copyWith(
                      checkboxTheme: CheckboxThemeData(
                        fillColor: MaterialStateProperty.resolveWith<Color>(
                              (states) {
                            if (late) return Colors.white; // بطن أبيض
                            if (states.contains(MaterialState.selected)) {
                              return Theme.of(context).colorScheme.primary;
                            }
                            return Theme.of(context).colorScheme.onSurfaceVariant;
                          },
                        ),
                        checkColor: MaterialStateProperty.resolveWith<Color>(
                              (states) {
                            if (late) return Colors.pink.shade700; // الصح وردي
                            return Colors.white;
                          },
                        ),
                        side: MaterialStateBorderSide.resolveWith((states) {
                          if (late) {
                            return BorderSide(color: Colors.pink.shade700, width: 2);
                          }
                          return BorderSide(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          );
                        }),
                      ),
                    ),
                    child: Checkbox(
                      value: dose.taken,
                      onChanged: (_) => _toggleTaken(i, filtered),
                    ),
                  ),
                  title: Text(
                    "${dose.medicineName}  (${dose.doseText})",
                    style: TextStyle(
                      color: late
                          ? Colors.pink[900]
                          : Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    "المريض: ${dose.patientName}",
                    style: TextStyle(
                      color: late
                          ? Colors.pink[800]
                          : Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.7),
                    ),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        timeFmt.format(dose.time),
                        style: TextStyle(
                          color: late
                              ? Colors.red[700]
                              : Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (late)
                        Text(
                          "متأخرة",
                          style: TextStyle(
                            color: Colors.red[700],
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  bool get wantKeepAlive => true;
}
