// lib/ui/screens/add_reminder_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/app_data.dart';
import '../../data/models.dart';
import '../../notifications/notification_bridge.dart'; // ✨

class AddReminderPage extends StatefulWidget {
  const AddReminderPage({super.key});

  @override
  State<AddReminderPage> createState() => _AddReminderPageState();
}

class _AddReminderPageState extends State<AddReminderPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  DateTime _date = DateTime.now();
  TimeOfDay _time = TimeOfDay.now();

  // وضع التعديل
  bool _isEdit = false;
  Reminder? _editing; // المرجع الأصلي إن وُجد
  int? _editingIndex;

  bool _argsLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsLoaded) return;
    _argsLoaded = true;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      final mode = args['mode'] as String?;
      if (mode == 'edit') {
        _isEdit = true;
        final r = args['reminder'];
        if (r is Reminder) {
          _editing = r;
          _titleCtrl.text = r.title;
          _notesCtrl.text = r.notes ?? '';
          _date = DateTime(r.dateTime.year, r.dateTime.month, r.dateTime.day);
          _time = TimeOfDay(hour: r.dateTime.hour, minute: r.dateTime.minute);
        }
        final idx = args['index'];
        if (idx is int) _editingIndex = idx;
      }
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  DateTime get _dateTime =>
      DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final updated = Reminder(
      title: _titleCtrl.text.trim(),
      dateTime: _dateTime,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    );

    if (_isEdit) {
      if (_editingIndex != null &&
          _editingIndex! >= 0 &&
          _editingIndex! < AppData.I.reminders.length &&
          identical(AppData.I.reminders[_editingIndex!], _editing)) {
        AppData.I.reminders[_editingIndex!] = updated;
      } else {
        final i = AppData.I.reminders.indexOf(_editing!);
        if (i >= 0) {
          AppData.I.reminders[i] = updated;
        } else {
          // احتياط لو ما لقيناه
          AppData.I.addReminder(updated);
        }
      }

      // ✨ إلغاء القديم ثم جدولة الجديد
      if (_editing != null) {
        NotificationBridge.cancelReminder(_editing!);
      }
      NotificationBridge.scheduleReminder(updated);

      Navigator.pop(context, true);
    } else {
      AppData.I.addReminder(updated);

      // ✨ جدولة التذكير
      NotificationBridge.scheduleReminder(updated);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تمت إضافة التذكير')),
      );
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = DateFormat.yMMMd('ar').format(_date);
    final t = DateFormat.jm('ar').format(DateTime(0, 1, 1, _time.hour, _time.minute));

    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'تعديل تذكير' : 'إضافة تذكير')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'عنوان التذكير',
                prefixIcon: Icon(Icons.notifications_active),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'أدخل عنوانًا' : null,
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.event),
                    label: Text('التاريخ: $d'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickTime,
                    icon: const Icon(Icons.access_time),
                    label: Text('الوقت: $t'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _notesCtrl,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'ملاحظات (اختياري)',
                prefixIcon: Icon(Icons.note_alt_outlined),
              ),
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _save,
                icon: Icon(_isEdit ? Icons.check : Icons.save),
                label: Text(_isEdit ? 'حفظ التعديل' : 'حفظ'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
