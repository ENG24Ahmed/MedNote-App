// lib/ui/screens/add_patient_page.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/app_data.dart';

class AddPatientPage extends StatefulWidget {
  // وضع الإضافة (الافتراضي)
  const AddPatientPage({super.key})
      : isEdit = false,
        originalName = null,
        initialName = null,
        initialGender = null,
        initialDob = null;

  // وضع التعديل
  const AddPatientPage.edit({
    super.key,
    required this.originalName,
    required this.initialName,
    this.initialGender,
    this.initialDob,
  }) : isEdit = true;

  final bool isEdit;
  final String? originalName;
  final String? initialName;
  final String? initialGender; // 'male' | 'female'
  final DateTime? initialDob;

  @override
  State<AddPatientPage> createState() => _AddPatientPageState();
}

class _AddPatientPageState extends State<AddPatientPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();

  String? _gender; // 'male' | 'female'
  DateTime? _dob;  // تاريخ الميلاد

  @override
  void initState() {
    super.initState();
    if (widget.isEdit) {
      _nameCtrl.text = widget.initialName ?? '';
      _gender = widget.initialGender;
      _dob = widget.initialDob;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  String _ageLabel() {
    if (_dob == null) return '—';
    final now = DateTime.now();

    int years = now.year - _dob!.year;
    int months = now.month - _dob!.month;
    int days = now.day - _dob!.day;

    if (days < 0) {
      final prevMonthLastDay = DateTime(now.year, now.month, 0).day;
      days += prevMonthLastDay;
      months -= 1;
    }
    if (months < 0) {
      years -= 1;
      months += 12;
    }

    if (years <= 0 && months <= 0 && days <= 0) return 'أقل من يوم';

    final y = years > 0 ? '$years سنة' : '';
    final m = months > 0 ? ' $months شهر' : '';
    final d = days > 0 ? ' $days يوم' : '';
    return (y + m + d).trim();
  }

  Future<void> _pickDob() async {
    DateTime temp = _dob ?? DateTime(DateTime.now().year - 30, 1, 1);
    await showModalBottomSheet(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (ctx) {
        return SizedBox(
          height: 300,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  children: [
                    Text('اختيار تاريخ الميلاد',
                        style: Theme.of(context).textTheme.titleMedium),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('تم'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: temp,
                  maximumDate: DateTime.now(),
                  minimumYear: 1900,
                  onDateTimeChanged: (d) {
                    temp = d;
                    setState(() {
                      _dob = d;
                    });
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
    setState(() {});
  }

  void _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final name = _nameCtrl.text.trim();

    // تحقق من التكرار
    final exists = AppData.I.patients
        .any((p) => p.name.trim() == name.trim());

    if (widget.isEdit) {
      final changingName = name.trim() != (widget.originalName ?? '').trim();
      if (changingName && exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('الاسم موجود بالفعل')),
        );
        return;
      }
      await AppData.I.upsertPatient(
        originalName: widget.originalName!,
        name: name,
        gender: _gender,
        dob: _dob,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } else {
      if (exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('الاسم موجود بالفعل')),
        );
        return;
      }
      await AppData.I.addPatient(name, gender: _gender, dob: _dob);
      if (!mounted) return;
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat.yMMMd('ar');
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(widget.isEdit ? 'تعديل مريض' : 'إضافة مريض')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // الاسم
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'اسم المريض',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'الاسم مطلوب';
                if (v.trim().length < 2) return 'الاسم قصير جدًا';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // الجنس (إيموجي + نص)
            Text('الجنس', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment<String>(value: 'male', label: Text('👨 ذكر')),
                ButtonSegment<String>(value: 'female', label: Text('👩 أنثى')),
              ],
              emptySelectionAllowed: true,
              selected: _gender == null ? <String>{} : <String>{_gender!},
              onSelectionChanged: (set) {
                setState(() => _gender = set.isNotEmpty ? set.first : null);
              },
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return cs.primaryContainer;
                  }
                  return null;
                }),
              ),
            ),

            const SizedBox(height: 20),

            // تاريخ الميلاد (عجلة)
            Text('تاريخ الميلاد', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.cake),
              label: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _dob == null ? 'اختر التاريخ' : dateFmt.format(_dob!),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              onPressed: _pickDob,
            ),

            const SizedBox(height: 8),

            // العمر
            Row(
              children: [
                const Icon(Icons.hourglass_bottom, size: 18),
                const SizedBox(width: 6),
                Text('العمر: ${_ageLabel()}'),
              ],
            ),

            const SizedBox(height: 28),

            // زر الحفظ
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: Icon(widget.isEdit ? Icons.check : Icons.save),
                label: Text(widget.isEdit ? 'حفظ' : 'إضافة'),
                onPressed: _save,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
