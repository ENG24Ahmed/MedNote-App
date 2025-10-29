// v3.4.0 – إضافة: زر استثناء تحسينات البطارية + اختيار مجلد النسخ الاحتياطي
import 'dart:convert';
import 'dart:io';

import 'package:excel/excel.dart' as xls;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData, rootBundle, MethodChannel;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart' as pdf;
import 'package:share_plus/share_plus.dart';

import '../../data/settings.dart';
import '../../data/app_data.dart';
import '../../data/models.dart';
import 'dart:ui' as ui show TextDirection;

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  // قناة أندرويد (نفس القناة المستخدمة للإشعارات)
  static const MethodChannel _notifCh = MethodChannel('mednote/notifications');

  // 0 = إيقاف
  static const _leadOptions = <int>[0, 1, 5, 10, 15, 20, 30];
  static const _snoozeOptions = <int>[5, 10, 15, 20, 30];

  Future<Directory> _effectiveBackupDir() async {
    final custom = Settings.I.backupDirPath.value;
    if (custom != null && custom.trim().isNotEmpty) {
      final dir = Directory(custom);
      if (await dir.exists()) return dir;
    }
    return getApplicationDocumentsDirectory(); // الإعداد الافتراضي
  }

  String _ts() => DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());

  Future<File> _writeJsonFile(String name, Map<String, dynamic> data) async {
    final dir = await _effectiveBackupDir();
    final file = File('${dir.path}/$name');
    final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
    await file.writeAsString(jsonStr, flush: true);
    return file;
  }

  Map<String, dynamic> _makeBackupJson() {
    return {
      'settings': Settings.I.toJson(),
      'patients': AppData.I.patients
          .map((p) => {
        'name': p.name,
        'gender': p.gender,
        'dob': p.dob?.toIso8601String(),
      })
          .toList(),
      'doses': AppData.I.doses
          .map((d) => {
        'patientName': d.patientName,
        'medicineName': d.medicineName,
        'doseText': d.doseText,
        'time': d.time.toIso8601String(),
        'taken': d.taken,
      })
          .toList(),
      'appointments': AppData.I.appointments
          .map((a) => {
        'patientName': a.patientName,
        'doctorName': a.doctorName,
        'title': a.title,
        'dateTime': a.dateTime.toIso8601String(),
        'notes': a.notes,
      })
          .toList(),
      'reminders': AppData.I.reminders
          .map((r) => {
        'title': r.title,
        'dateTime': r.dateTime.toIso8601String(),
        'notes': r.notes,
      })
          .toList(),
      'version': 1,
    };
  }

  void _loadBackupJson(Map<String, dynamic> json) {
    if (json['settings'] is Map) {
      Settings.I.loadFromJson(json['settings'] as Map<String, dynamic>);
    }

    final List<Patient> newPatients = [];
    if (json['patients'] is List) {
      for (final e in (json['patients'] as List)) {
        if (e is Map) {
          newPatients.add(Patient(
            (e['name'] ?? '').toString(),
            gender: (e['gender'] as String?),
            dob: (e['dob'] is String) ? DateTime.tryParse(e['dob']) : null,
          ));
        }
      }
    }

    final List<Dose> newDoses = [];
    if (json['doses'] is List) {
      for (final e in (json['doses'] as List)) {
        if (e is Map) {
          final t = (e['time'] is String) ? DateTime.tryParse(e['time']) : null;
          if (t != null) {
            newDoses.add(Dose(
              patientName: (e['patientName'] ?? '').toString(),
              medicineName: (e['medicineName'] ?? '').toString(),
              doseText: (e['doseText'] ?? '').toString(),
              time: t,
              taken: (e['taken'] is bool) ? (e['taken'] as bool) : false,
            ));
          }
        }
      }
    }

    final List<Appointment> newAppts = [];
    if (json['appointments'] is List) {
      for (final e in (json['appointments'] as List)) {
        if (e is Map) {
          final t =
          (e['dateTime'] is String) ? DateTime.tryParse(e['dateTime']) : null;
          if (t != null) {
            newAppts.add(Appointment(
              patientName: (e['patientName'] ?? '').toString(),
              doctorName: (e['doctorName'] ?? '').toString(),
              title: (e['title'] ?? '').toString(),
              dateTime: t,
              notes: (e['notes'] as String?),
            ));
          }
        }
      }
    }

    final List<Reminder> newRems = [];
    if (json['reminders'] is List) {
      for (final e in (json['reminders'] as List)) {
        if (e is Map) {
          final t =
          (e['dateTime'] is String) ? DateTime.tryParse(e['dateTime']) : null;
          if (t != null) {
            newRems.add(Reminder(
              title: (e['title'] ?? '').toString(),
              dateTime: t,
              notes: (e['notes'] as String?),
            ));
          }
        }
      }
    }

    AppData.I.patients
      ..clear()
      ..addAll(newPatients);
    AppData.I.doses
      ..clear()
      ..addAll(newDoses);
    AppData.I.appointments
      ..clear()
      ..addAll(newAppts);
    AppData.I.reminders
      ..clear()
      ..addAll(newRems);
  }

  xls.TextCellValue _txt(String s) => xls.TextCellValue(s);
  xls.BoolCellValue _bool(bool b) => xls.BoolCellValue(b);

  Future<void> _backupToFile(BuildContext context) async {
    final data = _makeBackupJson();
    final file = await _writeJsonFile('mednote_backup_${_ts()}.json', data);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تم حفظ النسخة الاحتياطية:\n${file.path}')),
    );
  }

  Future<void> _shareBackupFile(BuildContext context) async {
    final data = _makeBackupJson();
    final file = await _writeJsonFile('mednote_backup_${_ts()}.json', data);
    await Share.shareXFiles([XFile(file.path)], text: 'نسخة احتياطية MedNote');
  }

  Future<void> _restoreFromFile(BuildContext context) async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (res == null || res.files.isEmpty) return;

    try {
      final path = res.files.single.path!;
      final jsonStr = await File(path).readAsString();
      final map = json.decode(jsonStr) as Map<String, dynamic>;
      _loadBackupJson(map);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم الاسترجاع بنجاح')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل الاسترجاع: $e')),
      );
    }
  }

  Future<void> _exportExcel(BuildContext context) async {
    final excel = xls.Excel.createExcel();

    final shP = excel['Patients'];
    shP.appendRow([_txt('Name'), _txt('Gender'), _txt('DOB'), _txt('Age')]);
    for (final p in AppData.I.patients) {
      shP.appendRow([
        _txt(p.name),
        _txt(p.gender ?? ''),
        _txt(p.dob?.toIso8601String() ?? ''),
        _txt(p.ageLabel()),
      ]);
    }

    final shD = excel['Doses'];
    shD.appendRow([
      _txt('Patient'),
      _txt('Medicine'),
      _txt('DoseText'),
      _txt('Time'),
      _txt('Taken')
    ]);
    for (final d in AppData.I.doses) {
      shD.appendRow([
        _txt(d.patientName),
        _txt(d.medicineName),
        _txt(d.doseText),
        _txt(d.time.toIso8601String()),
        _bool(d.taken),
      ]);
    }

    final shA = excel['Appointments'];
    shA.appendRow(
        [_txt('Patient'), _txt('Doctor'), _txt('Title'), _txt('DateTime'), _txt('Notes')]);
    for (final a in AppData.I.appointments) {
      shA.appendRow([
        _txt(a.patientName),
        _txt(a.doctorName),
        _txt(a.title),
        _txt(a.dateTime.toIso8601String()),
        _txt(a.notes ?? ''),
      ]);
    }

    final shR = excel['Reminders'];
    shR.appendRow([_txt('Title'), _txt('DateTime'), _txt('Notes')]);
    for (final r in AppData.I.reminders) {
      shR.appendRow([
        _txt(r.title),
        _txt(r.dateTime.toIso8601String()),
        _txt(r.notes ?? ''),
      ]);
    }

    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    final dir = await _effectiveBackupDir();
    final path = '${dir.path}/mednote_report_${_ts()}.xlsx';
    final bytes = excel.encode()!;
    final file = File(path)..writeAsBytesSync(bytes, flush: true);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تم إنشاء تقرير Excel:\n$path')),
    );

    await Share.shareXFiles([XFile(file.path)], text: 'تقرير MedNote (Excel)');
  }

  Future<void> _exportPdf(BuildContext context) async {
    try {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              duration: Duration(milliseconds: 800),
              content: Text('جارٍ إنشاء PDF...')),
        );
      }

      // تحميل الخطوط العربية
      final fontRegular = pw.Font.ttf(
        await rootBundle.load('assets/fonts/NotoNaskhArabic-Regular.ttf'),
      );
      final fontBold = pw.Font.ttf(
        await rootBundle.load('assets/fonts/NotoNaskhArabic-Bold.ttf'),
      );

      final doc = pw.Document();

      final titleStyle =
      pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold);
      final small = pw.TextStyle(fontSize: 9);

      pw.Widget buildTable(String caption, List<List<String>> rows) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(caption, style: titleStyle),
            pw.SizedBox(height: 6),
            pw.Table.fromTextArray(
              data: rows,
              headerStyle:
              pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
              cellStyle: small,
              headerDecoration:
              const pw.BoxDecoration(color: pdf.PdfColors.grey300),
              cellAlignment: pw.Alignment.centerRight,
              headerAlignment: pw.Alignment.centerRight,
            ),
            pw.SizedBox(height: 16),
          ],
        );
      }

      // بيانات عربية
      final patientsRows = <List<String>>[
        ['الاسم', 'النوع', 'تاريخ الميلاد', 'العمر'],
        ...AppData.I.patients.map((p) => [
          p.name,
          p.gender ?? '',
          p.dob?.toIso8601String() ?? '',
          p.ageLabel(),
        ]),
      ];
      final dosesRows = <List<String>>[
        ['المريض', 'الدواء', 'الجرعة', 'الوقت', 'تم التناول'],
        ...AppData.I.doses.map((d) => [
          d.patientName,
          d.medicineName,
          d.doseText,
          d.time.toIso8601String(),
          d.taken ? 'نعم' : 'لا',
        ]),
      ];
      final apptRows = <List<String>>[
        ['المريض', 'الطبيب', 'العنوان', 'التاريخ/الوقت', 'ملاحظات'],
        ...AppData.I.appointments.map((a) => [
          a.patientName,
          a.doctorName,
          a.title,
          a.dateTime.toIso8601String(),
          a.notes ?? '',
        ]),
      ];
      final remRows = <List<String>>[
        ['العنوان', 'التاريخ/الوقت', 'ملاحظات'],
        ...AppData.I.reminders.map((r) => [
          r.title,
          r.dateTime.toIso8601String(),
          r.notes ?? '',
        ]),
      ];

      // مهم: لا نضع theme منفصل مع pageTheme
      doc.addPage(
        pw.MultiPage(
          pageTheme: pw.PageTheme(
            margin: const pw.EdgeInsets.all(24),
            textDirection: pw.TextDirection.rtl,
            theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
          ),
          build: (context) => [
            pw.Text('تقرير ميدنوت',
                style: pw.TextStyle(
                    fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 12),
            buildTable('المرضى', patientsRows),
            buildTable('الجرعات', dosesRows),
            buildTable('مواعيد الأطباء', apptRows),
            buildTable('التذكيرات', remRows),
          ],
        ),
      );

      final dir = await _effectiveBackupDir();
      final path = '${dir.path}/mednote_report_${_ts()}.pdf';
      final file = File(path)
        ..writeAsBytesSync(await doc.save(), flush: true);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم إنشاء تقرير PDF:\n$path')),
      );

      await Share.shareXFiles([XFile(file.path)], text: 'تقرير MedNote (PDF)');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حصل خطأ أثناء إنشاء PDF: $e')),
        );
      }
    }
  }

  Future<void> _pickBackupFolder(BuildContext context) async {
    final path = await FilePicker.platform.getDirectoryPath();
    if (path == null) return;

    try {
      // اختبار الكتابة في المجلد المختار
      final test = File('$path/.mednote_write_test');
      await test.writeAsString('ok', flush: true);
      await test.delete();

      Settings.I.backupDirPath.value = path;

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم تعيين مجلد النسخ الاحتياطي:\n$path')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('لا يمكن الكتابة في هذا المجلد: $e')),
      );
    }
  }

  Future<void> _resetBackupFolder(BuildContext context) async {
    Settings.I.backupDirPath.value = null;
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تمت إعادة التعيين لمجلد التطبيق الداخلي')),
    );
  }

  Future<void> _openBatteryOptSettings() async {
    try {
      await _notifCh.invokeMethod('openBatteryOptimizationSettings');
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('الإعدادات')),
        body: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            // اللغة
            ListTile(
              title: const Text('اللغة'),
              subtitle: const Text('العربية / الإنجليزية / حسب النظام'),
              trailing: ValueListenableBuilder<Locale?>(
                valueListenable: Settings.I.locale,
                builder: (context, loc, _) {
                  final current = loc?.languageCode ?? 'system';
                  return DropdownButton<String>(
                    value: current,
                    items: const [
                      DropdownMenuItem(value: 'ar', child: Text('العربية')),
                      DropdownMenuItem(value: 'en', child: Text('English')),
                      DropdownMenuItem(
                          value: 'system', child: Text('حسب النظام')),
                    ],
                    onChanged: (v) {
                      if (v == 'system') {
                        Settings.I.locale.value = null;
                      } else if (v == 'en') {
                        Settings.I.locale.value = const Locale('en');
                      } else {
                        Settings.I.locale.value = const Locale('ar');
                      }
                    },
                  );
                },
              ),
            ),

            // السِمة
            ListTile(
              title: const Text('السِمة'),
              subtitle: const Text('فاتح • داكن • تلقائي'),
              trailing: ValueListenableBuilder<ThemeMode>(
                valueListenable: Settings.I.themeMode,
                builder: (context, mode, _) {
                  return DropdownButton<ThemeMode>(
                    value: mode,
                    items: const [
                      DropdownMenuItem(
                          value: ThemeMode.system, child: Text('تلقائي')),
                      DropdownMenuItem(
                          value: ThemeMode.light, child: Text('فاتح')),
                      DropdownMenuItem(
                          value: ThemeMode.dark, child: Text('داكن')),
                    ],
                    onChanged: (v) {
                      if (v != null) Settings.I.themeMode.value = v;
                    },
                  );
                },
              ),
            ),

            const Divider(height: 1),

            // ذكرني لاحقاً
            ListTile(
              title: const Text('ذكرني لاحقاً'),
              subtitle: const Text('مدة التأجيل بالدقائق'),
              trailing: ValueListenableBuilder<int>(
                valueListenable: Settings.I.snoozeMinutes,
                builder: (context, value, _) {
                  return DropdownButton<int>(
                    value: value,
                    items: _snoozeOptions
                        .map((e) =>
                        DropdownMenuItem(value: e, child: Text('$e دقيقة')))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) Settings.I.snoozeMinutes.value = v;
                    },
                  );
                },
              ),
            ),

            // التذكير قبل الموعد/التذكير
            ListTile(
              title: const Text('التذكير قبل الموعد'),
              subtitle:
              const Text('اختر كم دقيقة قبل الوقت المحدد (أو إيقاف)'),
              trailing: ValueListenableBuilder<int>(
                valueListenable: Settings.I.reminderLeadMinutes,
                builder: (context, value, _) {
                  return DropdownButton<int>(
                    value: value,
                    items: _leadOptions
                        .map((e) => DropdownMenuItem(
                      value: e,
                      child: Text(e == 0 ? 'إيقاف' : '$e دقيقة'),
                    ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) Settings.I.reminderLeadMinutes.value = v;
                    },
                  );
                },
              ),
            ),

            const Divider(height: 1),

            // تحسينات البطارية
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.battery_saver),
                  label: const Text('استثناء التطبيق من تحسينات البطارية'),
                  onPressed: _openBatteryOptSettings,
                ),
              ),
            ),

            const Divider(height: 1),

            // إعداد مجلد النسخ الاحتياطي
            ValueListenableBuilder<String?>(
              valueListenable: Settings.I.backupDirPath,
              builder: (context, path, _) {
                final label = (path == null || path.trim().isEmpty)
                    ? 'مجلد التطبيق الداخلي (افتراضي)'
                    : path;
                return ListTile(
                  title: const Text('مجلد النسخ الاحتياطي'),
                  subtitle: Text(label),
                  isThreeLine: true,
                  trailing: Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.folder_open),
                        label: const Text('تغيير المجلد'),
                        onPressed: () => _pickBackupFolder(context),
                      ),
                      TextButton(
                        onPressed: () => _resetBackupFolder(context),
                        child: const Text('إرجاع للإفتراضي'),
                      ),
                    ],
                  ),
                );
              },
            ),

            const Divider(height: 1),

            // النسخة الاحتياطية (ملف)
            ListTile(
              title: const Text('أخذ نسخة احتياطية (ملف JSON)'),
              subtitle:
              const Text('سيتم الحفظ في المجلد المحدد أعلاه ويمكن مشاركته'),
              trailing: FilledButton.icon(
                icon: const Icon(Icons.save_alt),
                label: const Text('حفظ ملف'),
                onPressed: () => _backupToFile(context),
              ),
            ),

            // مشاركة البيانات (ملف)
            ListTile(
              title: const Text('مشاركة النسخة الاحتياطية'),
              subtitle: const Text('مشاركة ملف JSON عبر التطبيقات'),
              trailing: OutlinedButton.icon(
                icon: const Icon(Icons.share),
                label: const Text('مشاركة ملف'),
                onPressed: () => _shareBackupFile(context),
              ),
            ),

            // استرجاع
            ListTile(
              title: const Text('استرجاع نسخة احتياطية'),
              subtitle: const Text('اختر ملف JSON تمت مشاركته/حفظه سابقاً'),
              trailing: OutlinedButton.icon(
                icon: const Icon(Icons.restore),
                label: const Text('استرجاع'),
                onPressed: () => _restoreFromFile(context),
              ),
            ),

            const Divider(height: 1),

            // تقرير Excel و PDF
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cs.primaryContainer,
                        foregroundColor: cs.onPrimaryContainer,
                      ),
                      icon: const Icon(Icons.table_chart),
                      label: const Text('تقرير Excel (.xlsx)'),
                      onPressed: () => _exportExcel(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cs.secondaryContainer,
                        foregroundColor: cs.onSecondaryContainer,
                      ),
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text('تقرير PDF'),
                      onPressed: () => _exportPdf(context),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
