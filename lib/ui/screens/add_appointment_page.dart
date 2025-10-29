// lib/ui/screens/add_appointment_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/app_data.dart';
import '../../data/models.dart';
import '../../notifications/notification_bridge.dart'; // ✨

class AddAppointmentPage extends StatefulWidget {
  const AddAppointmentPage({super.key});

  @override
  State<AddAppointmentPage> createState() => _AddAppointmentPageState();
}

class _AddAppointmentPageState extends State<AddAppointmentPage> {
  final _formKey = GlobalKey<FormState>();

  String? _patient;
  final _doctorCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  DateTime _date = DateTime.now();
  TimeOfDay _time = TimeOfDay.now();

  // وضع التعديل
  bool _isEdit = false;
  Appointment? _editing; // المرجع الأصلي في حال التعديل
  int? _editingIndex;    // لو القائمة أرسلت index

  bool _argsLoaded = false;

  @override
  void initState() {
    super.initState();
    _patient = AppData.I.patients.isNotEmpty ? AppData.I.patients.first.name : null;
  }

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
        final appt = args['appointment'];
        if (appt is Appointment) {
          _editing = appt;
          _patient = appt.patientName;
          _doctorCtrl.text = appt.doctorName;
          _titleCtrl.text = appt.title;
          _notesCtrl.text = appt.notes ?? '';
          _date = DateTime(appt.dateTime.year, appt.dateTime.month, appt.dateTime.day);
          _time = TimeOfDay(hour: appt.dateTime.hour, minute: appt.dateTime.minute);
        }
        // إن أرسلت صفحة القائمة index:
        final idx = args['index'];
        if (idx is int) _editingIndex = idx;
      }
    }
  }

  @override
  void dispose() {
    _doctorCtrl.dispose();
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
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
    );
    if (picked != null) setState(() => _time = picked);
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_patient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أضف مريضًا أولًا من إدارة المرضى')),
      );
      return;
    }

    final updated = Appointment(
      patientName: _patient!,
      doctorName: _doctorCtrl.text.trim(),
      title: _titleCtrl.text.trim(),
      dateTime: _dateTime,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    );

    if (_isEdit) {
      if (_editingIndex != null &&
          _editingIndex! >= 0 &&
          _editingIndex! < AppData.I.appointments.length &&
          identical(AppData.I.appointments[_editingIndex!], _editing)) {
        AppData.I.appointments[_editingIndex!] = updated;
      } else {
        final i = AppData.I.appointments.indexOf(_editing!);
        if (i >= 0) {
          AppData.I.appointments[i] = updated;
        } else {
          AppData.I.addAppointment(updated);
        }
      }

      // ✨ إلغاء القديم ثم جدولة الجديد
      if (_editing != null) {
        await NotificationBridge.cancelAppointment(_editing!);
      }
      await NotificationBridge.scheduleAppointment(updated);

      Navigator.pop(context, true);
    } else {
      await AppData.I.addAppointment(updated);

      // ✨ جدولة الموعد (صباح 8 وقبل الموعد بساعة افتراضياً)
      await NotificationBridge.scheduleAppointment(updated);

      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat.yMMMd('ar');
    final timeFmt = DateFormat.jm('ar');

    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'تعديل موعد طبيب' : 'إضافة موعد طبيب')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<String>(
              value: _patient,
              items: AppData.I.patients
                  .map((p) => DropdownMenuItem(value: p.name, child: Text(p.name)))
                  .toList(),
              onChanged: (v) => setState(() => _patient = v),
              decoration: const InputDecoration(
                labelText: 'اسم المريض',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _doctorCtrl,
              decoration: const InputDecoration(
                labelText: 'اسم الطبيب',
                prefixIcon: Icon(Icons.medical_information),
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'أدخل اسم الطبيب' : null,
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'عنوان الموعد (العيادة/المستشفى)',
                prefixIcon: Icon(Icons.local_hospital),
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'أدخل عنوان الموعد' : null,
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.event),
                    label: Text('التاريخ: ${dateFmt.format(_date)}'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickTime,
                    icon: const Icon(Icons.access_time),
                    label: Text('الوقت: ${timeFmt.format(DateTime(0,1,1,_time.hour,_time.minute))}'),
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
                prefixIcon: Icon(Icons.notes),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: Icon(_isEdit ? Icons.check : Icons.save),
                label: Text(_isEdit ? 'حفظ التعديل' : 'حفظ'),
                onPressed: _save,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
