import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// بيانات
import '../../data/app_data.dart';
import '../../data/models.dart';
import '../../data/settings.dart';
import '../../data/db/app_database.dart';

// الجسر الجديد
import '../../notifications/notification_bridge.dart';

class AddMedicinePage extends StatefulWidget {
  // وضع الإضافة الافتراضي
  const AddMedicinePage({super.key})
      : isEdit = false,
        originalPatientName = null,
        originalMedicineName = null,
        originalDoseText = null,
        initialPatientName = null,
        initialMedicineName = null,
        initialType = null,
        initialDoseNumber = null,
        initialUnit = null,
        initialFirstDate = null,
        initialFirstTime = null,
        initialIntervalValue = null,
        initialIntervalUnit = null,
        initialDays = null;

  // وضع التعديل
  const AddMedicinePage.edit({
    super.key,
    required this.originalPatientName,
    required this.originalMedicineName,
    required this.originalDoseText,
    required this.initialPatientName,
    required this.initialMedicineName,
    required this.initialType,
    required this.initialDoseNumber,
    required this.initialUnit,
    required this.initialFirstDate,
    required this.initialFirstTime,
    required this.initialIntervalValue,
    required this.initialIntervalUnit, // 'ساعات' أو 'أيام'
    required this.initialDays,
  }) : isEdit = true;

  final bool isEdit;

  // مفاتيح المجموعة القديمة (لازم بالاستبدال)
  final String? originalPatientName;
  final String? originalMedicineName;
  final String? originalDoseText;

  // قيم أولية لملء الحقول
  final String? initialPatientName;
  final String? initialMedicineName;
  final String? initialType;
  final String? initialDoseNumber;
  final String? initialUnit;
  final DateTime? initialFirstDate;
  final TimeOfDay? initialFirstTime;
  final int? initialIntervalValue;
  final String? initialIntervalUnit; // 'ساعات' | 'أيام'
  final int? initialDays;

  @override
  State<AddMedicinePage> createState() => _AddMedicinePageState();
}

class _AddMedicinePageState extends State<AddMedicinePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _doseCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String? _patient;
  String _type = 'حب';
  String _unit = 'حبة';

  int _intervalValue = 8;
  String _intervalUnit = 'ساعات';
  int _days = 3;

  DateTime _firstDate = DateTime.now();
  TimeOfDay _firstTime = TimeOfDay.now();

  List<String> get _distinctPatientNames {
    final set = <String>{};
    for (final p in AppData.I.patients) {
      final n = p.name.trim();
      if (n.isNotEmpty) set.add(n);
    }
    final list = set.toList()..sort();
    return list;
  }

  void _ensureValidPatientSelection() {
    final names = _distinctPatientNames;
    if (names.isEmpty) {
      _patient = null;
      return;
    }
    if (_patient == null || !names.contains(_patient)) {
      _patient = names.first;
    }
  }

  @override
  void initState() {
    super.initState();

    final names = _distinctPatientNames;
    _patient = names.isNotEmpty ? names.first : null;

    if (widget.isEdit) {
      _patient = widget.initialPatientName ?? _patient;
      _type = widget.initialType ?? _type;
      _applyUnitForType(_type);

      _nameCtrl.text = widget.initialMedicineName ?? '';
      _doseCtrl.text = widget.initialDoseNumber ?? '';
      _unit = widget.initialUnit?.isNotEmpty == true ? widget.initialUnit! : _unit;

      _firstDate = widget.initialFirstDate ?? _firstDate;
      _firstTime = widget.initialFirstTime ?? _firstTime;

      _intervalValue = widget.initialIntervalValue ?? _intervalValue;
      _intervalUnit = widget.initialIntervalUnit ?? _intervalUnit;
      _days = widget.initialDays ?? _days;
    } else {
      _applyUnitForType(_type);
    }

    _ensureValidPatientSelection();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _doseCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  static const Map<String, IconData> _typeIcons = {
    'حب'     : Icons.medication,
    'كبسول'  : Icons.radio_button_checked,
    'شراب'   : Icons.local_drink,
    'حقن'    : Icons.healing,
    'بخاخ'   : Icons.air,
    'تحميلة' : Icons.water_drop,
  };

  static const Map<String, Color> _typeColors = {
    'حب'     : Color(0xFF42A5F5),
    'كبسول'  : Color(0xFF7E57C2),
    'شراب'   : Color(0xFF66BB6A),
    'حقن'    : Color(0xFFEF5350),
    'بخاخ'   : Color(0xFFFFA726),
    'تحميلة' : Color(0xFF26C6DA),
  };

  Widget _typeChip(String t) {
    final icon = _typeIcons[t] ?? Icons.medication_outlined;
    final bg   = _typeColors[t] ?? Colors.grey;
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: bg.withOpacity(0.15),
            shape: BoxShape.circle,
            border: Border.all(color: bg.withOpacity(0.45)),
          ),
          child: Icon(icon, size: 16, color: bg),
        ),
        const SizedBox(width: 8),
        Text(t),
      ],
    );
  }

  void _applyUnitForType(String type) {
    switch (type) {
      case 'حب':
        _unit = 'حبة';
        break;
      case 'كبسول':
        _unit = 'كبسولة';
        break;
      case 'شراب':
        _unit = 'ml';
        break;
      case 'حقن':
        _unit = 'cc';
        break;
      case 'بخاخ':
        _unit = 'بخة';
        break;
      case 'تحميلة':
        _unit = 'تحميلة';
        break;
      default:
        _unit = 'حبة';
    }
  }

  void _onTypeChanged(String? v) {
    if (v == null) return;
    setState(() {
      _type = v;
      _applyUnitForType(_type);
    });
  }

  DateTime get _firstDateTime => DateTime(
      _firstDate.year, _firstDate.month, _firstDate.day, _firstTime.hour, _firstTime.minute);

  int get _intervalHours => _intervalUnit == 'أيام' ? _intervalValue * 24 : _intervalValue;
  int get _totalHours => _days * 24;
  int get _doseCount => ((_totalHours + _intervalHours - 1) ~/ _intervalHours);
  DateTime get _lastDoseTime =>
      _firstDateTime.add(Duration(hours: (_doseCount - 1) * _intervalHours));

  Future<void> _pickInterval() async {
    int tempValue = _intervalValue;
    String tempUnit = _intervalUnit;
    await showCupertinoModalPopup(
      context: context,
      builder: (ctx) {
        return _PickerSheet(
          title: 'الفاصل بين الجرعات',
          child: Row(
            children: [
              Expanded(
                child: CupertinoPicker(
                  itemExtent: 36,
                  scrollController:
                  FixedExtentScrollController(initialItem: (tempValue - 1).clamp(0, 47)),
                  onSelectedItemChanged: (i) => tempValue = i + 1,
                  children: List.generate(48, (i) => Center(child: Text('${i + 1}'))),
                ),
              ),
              Expanded(
                child: CupertinoPicker(
                  itemExtent: 36,
                  scrollController:
                  FixedExtentScrollController(initialItem: tempUnit == 'ساعات' ? 0 : 1),
                  onSelectedItemChanged: (i) => tempUnit = i == 0 ? 'ساعات' : 'أيام',
                  children: const [Center(child: Text('ساعات')), Center(child: Text('أيام'))],
                ),
              ),
            ],
          ),
          onDone: () {
            setState(() {
              _intervalValue = tempValue;
              _intervalUnit = tempUnit;
              if (_intervalHours <= 0) {
                _intervalValue = 1;
                _intervalUnit = 'ساعات';
              }
            });
            Navigator.pop(ctx);
          },
        );
      },
    );
  }

  Future<void> _pickDays() async {
    int tempDays = _days;
    await showCupertinoModalPopup(
      context: context,
      builder: (ctx) {
        return _PickerSheet(
          title: 'عدد أيام العلاج',
          child: CupertinoPicker(
            itemExtent: 36,
            scrollController:
            FixedExtentScrollController(initialItem: (tempDays - 1).clamp(0, 89)),
            onSelectedItemChanged: (i) => tempDays = i + 1, // 1..90
            children: List.generate(90, (i) => Center(child: Text('${i + 1}'))),
          ),
          onDone: () {
            setState(() => _days = tempDays);
            Navigator.pop(ctx);
          },
        );
      },
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _firstDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked != null) setState(() => _firstDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _firstTime);
    if (picked != null) setState(() => _firstTime = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    _ensureValidPatientSelection();

    if (_patient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أضف مريضًا أولًا من الإعدادات/إدارة المرضى')),
      );
      return;
    }
    if (_intervalHours <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الفاصل بين الجرعات غير صالح')),
      );
      return;
    }

    final name = _nameCtrl.text.trim();
    final doseNum = _doseCtrl.text.trim();
    final doseText = "$doseNum$_unit";

    // توليد الجرعات (لا نخفي القديمة)
    final List<Dose> generated = [];
    for (int h = 0; h < _totalHours; h += _intervalHours) {
      generated.add(Dose(
        patientName: _patient!,
        medicineName: name,
        doseText: doseText,
        time: _firstDateTime.add(Duration(hours: h)),
      ));
    }

    if (widget.isEdit) {
      // 1) إلغاء إشعارات المجموعة القديمة
      final oldGroup = AppData.I.doses
          .where((d) =>
      d.patientName == widget.originalPatientName &&
          d.medicineName == widget.originalMedicineName &&
          d.doseText == widget.originalDoseText)
          .toList();
      for (final d in oldGroup) {
        try {
          await NotificationBridge.cancelDose(d);
        } catch (_) {}
      }

      // 2) استبدال في DB + الذاكرة
      await AppData.I.replaceDoseGroup(
        oldPatientName: widget.originalPatientName!,
        oldMedicineName: widget.originalMedicineName!,
        oldDoseText: widget.originalDoseText!,
        newDoses: generated,
      );

      // 3) جدولة الجديدة
      for (final d in generated) {
        try {
          await NotificationBridge.scheduleDose(
            dose: d,
            snoozeMinutes: Settings.I.snoozeMinutes.value,
            reminderLeadMinutes: Settings.I.reminderLeadMinutes.value,
            type: 'دواء',
          );
        } catch (_) {}
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('تم حفظ التعديل')));
      if (mounted) Navigator.pop(context, true);
    } else {
      // إضافة جديد + جدولة
      await AppData.I.addDoses(generated);
      for (final d in generated) {
        try {
          await NotificationBridge.scheduleDose(
            dose: d,
            snoozeMinutes: Settings.I.snoozeMinutes.value,
            reminderLeadMinutes: Settings.I.reminderLeadMinutes.value,
            type: 'دواء',
          );
        } catch (_) {}
      }

      final dateFmt = DateFormat.yMMMd('ar');
      final timeFmt = DateFormat.jm('ar');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تمت إضافة ${generated.length} جرعة (ينتهي: ${dateFmt.format(_lastDoseTime)} • ${timeFmt.format(_lastDoseTime)})',
          ),
        ),
      );
      if (mounted) Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat.yMMMd('ar');
    final timeFmt = DateFormat.jm('ar');
    final intervalLabel =
    _intervalUnit == 'أيام' ? 'كل $_intervalValue يوم' : 'كل $_intervalValue ساعة';

    final patientNames = _distinctPatientNames;
    if (_patient != null && !patientNames.contains(_patient)) {
      _patient = patientNames.isNotEmpty ? patientNames.first : null;
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.isEdit ? 'تعديل دواء' : 'إضافة دواء')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<String>(
              value: _patient,
              items: patientNames
                  .map((name) => DropdownMenuItem(value: name, child: Text(name)))
                  .toList(),
              onChanged: (v) => setState(() => _patient = v),
              decoration: const InputDecoration(
                labelText: 'اسم المريض',
                prefixIcon: Icon(Icons.person),
              ),
              validator: (_) {
                if (patientNames.isEmpty) {
                  return 'أضف مريضًا أولًا من الإعدادات/إدارة المرضى';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'اسم الدواء',
                prefixIcon: Icon(Icons.medication),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'أدخل اسم الدواء' : null,
            ),
            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              value: _type,
              items: ['حب','كبسول','شراب','حقن','بخاخ','تحميلة']
                  .map((t) => DropdownMenuItem(value: t, child: _typeChip(t)))
                  .toList(),
              onChanged: _onTypeChanged,
              decoration: const InputDecoration(
                labelText: 'نوع الدواء',
                prefixIcon: Icon(Icons.category),
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _doseCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'الجرعة (رقم)',
                      prefixIcon: Icon(Icons.numbers),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'أدخل قيمة الجرعة';
                      if (num.tryParse(v) == null) return 'الرجاء إدخال رقم صالح';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'الوحدة'),
                    child: Text(_unit, style: Theme.of(context).textTheme.bodyLarge),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            OutlinedButton.icon(
              onPressed: _pickInterval,
              icon: const Icon(Icons.schedule),
              label: Align(
                alignment: Alignment.centerLeft,
                child: Text('الفاصل بين الجرعات: $intervalLabel', overflow: TextOverflow.ellipsis),
              ),
            ),
            const SizedBox(height: 12),

            OutlinedButton.icon(
              onPressed: _pickDays,
              icon: const Icon(Icons.calendar_month),
              label: Align(
                alignment: Alignment.centerLeft,
                child: Text('عدد أيام العلاج: $_days يوم'),
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.event),
                    label: Text('تاريخ أول جرعة: ${dateFmt.format(_firstDate)}'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickTime,
                    icon: const Icon(Icons.access_time),
                    label: Text(
                      'وقت أول جرعة: ${timeFmt.format(DateTime(0,1,1,_firstTime.hour,_firstTime.minute))}',
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),
            Builder(
              builder: (context) {
                final endStr =
                    '${dateFmt.format(_lastDoseTime)} • ${timeFmt.format(_lastDoseTime)}';
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'ينتهي العلاج: $endStr',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                );
              },
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
                icon: Icon(widget.isEdit ? Icons.check : Icons.save),
                label: Text(widget.isEdit ? 'حفظ التعديل' : 'إضافة'),
                onPressed: _save,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickerSheet extends StatelessWidget {
  final String title;
  final Widget child;
  final VoidCallback onDone;

  const _PickerSheet({required this.title, required this.child, required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.25),
      child: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            height: 260,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Column(
              children: [
                SizedBox(
                  height: 48,
                  child: Row(
                    children: [
                      const SizedBox(width: 8),
                      Text(title, style: Theme.of(context).textTheme.titleMedium),
                      const Spacer(),
                      TextButton(onPressed: onDone, child: const Text('تم')),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
