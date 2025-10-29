// lib/data/app_data.dart
import 'models.dart';
import 'db/app_database.dart';

/// مخزن بيانات بسيط (Singleton) مع مزامنة DB
class AppData {
  AppData._();
  static final AppData I = AppData._();

  /// مرضى
  final List<Patient> patients = [];

  /// كل الجرعات المجدولة (لا نخفي القديمة)
  final List<Dose> doses = [];

  /// كل مواعيد الأطباء
  final List<Appointment> appointments = [];

  /// كل التذكيرات
  final List<Reminder> reminders = [];

  // =========================================================
  // التحميل من قاعدة البيانات
  // =========================================================
  Future<void> loadFromDb() async {
    final db = AppDatabase.I;

    // patients
    final pRows = await db.getPatients();
    final byName = <String, Patient>{};
    for (final e in pRows) {
      DateTime? dob;
      final dobStr = e['dob'] as String?;
      if (dobStr != null && dobStr.isNotEmpty) {
        dob = DateTime.tryParse(dobStr);
      }
      final name = (e['name'] ?? '').toString().trim();
      if (name.isEmpty) continue;
      byName[name] = Patient(name, gender: e['gender'] as String?, dob: dob);
    }
    patients
      ..clear()
      ..addAll(byName.values);

    // doses
    final dRows = await db.getDoses();
    doses
      ..clear()
      ..addAll(dRows.map((e) {
        final t = DateTime.tryParse((e['time'] ?? '').toString())!;
        return Dose(
          patientName: (e['patient_name'] ?? '').toString(),
          medicineName: (e['medicine_name'] ?? '').toString(),
          doseText: (e['dose_text'] ?? '').toString(),
          time: t,
          taken: (e['taken'] == 1),
        );
      }));

    // appointments
    final aRows = await db.getAppointments();
    appointments
      ..clear()
      ..addAll(aRows.map((e) {
        final t = DateTime.tryParse((e['date_time'] ?? '').toString())!;
        return Appointment(
          patientName: (e['patient_name'] ?? '').toString(),
          doctorName: (e['doctor_name'] ?? '').toString(),
          title: (e['title'] ?? '').toString(),
          dateTime: t,
          notes: e['notes'] as String?,
        );
      }));

    // reminders
    final rRows = await db.getReminders();
    reminders
      ..clear()
      ..addAll(rRows.map((e) {
        final t = DateTime.tryParse((e['date_time'] ?? '').toString())!;
        return Reminder(
          title: (e['title'] ?? '').toString(),
          dateTime: t,
          notes: e['notes'] as String?,
        );
      }));
  }

  // =========================================================
  // المرضى
  // =========================================================
  Future<void> addPatient(String name, {String? gender, DateTime? dob}) async {
    final n = name.trim();
    if (n.isEmpty) return;

    // منع التكرار في الذاكرة + DB
    final exists = patients.any((p) => p.name.trim() == n);
    if (exists) return;

    await AppDatabase.I.insertPatient(
      n,
      gender: gender,
      dob: dob?.toIso8601String(),
    );
    patients.add(Patient(n, gender: gender, dob: dob));
  }

  Future<bool> upsertPatient({
    required String originalName,
    required String name,
    String? gender,
    DateTime? dob,
  }) async {
    final newTrim = name.trim();
    if (newTrim.isEmpty) return false;

    // لو نحاول نغيّر الاسم إلى اسم موجود أساسًا لمريض آخر → نمنع
    final existsOther = patients.any(
          (p) => p.name.trim() == newTrim && p.name.trim() != originalName.trim(),
    );
    if (existsOther) return false;

    final idx = patients.indexWhere((p) => p.name == originalName);
    if (idx == -1) {
      await AppDatabase.I.insertPatient(
        newTrim,
        gender: gender,
        dob: dob?.toIso8601String(),
      );
      patients.add(Patient(newTrim, gender: gender, dob: dob));
      return true;
    }

    final old = patients[idx];
    final changedName = (newTrim != old.name);

    await AppDatabase.I.updatePatientByName(
      originalName,
      newName: newTrim,
      gender: gender ?? old.gender,
      dob: (dob ?? old.dob)?.toIso8601String(),
    );

    patients[idx] = Patient(
      newTrim,
      gender: gender ?? old.gender,
      dob: dob ?? old.dob,
    );

    if (changedName) {
      for (int i = 0; i < doses.length; i++) {
        final d = doses[i];
        if (d.patientName == originalName) {
          doses[i] = Dose(
            patientName: newTrim,
            medicineName: d.medicineName,
            doseText: d.doseText,
            time: d.time,
            taken: d.taken,
          );
        }
      }
      for (int i = 0; i < appointments.length; i++) {
        final a = appointments[i];
        if (a.patientName == originalName) {
          appointments[i] = Appointment(
            patientName: newTrim,
            doctorName: a.doctorName,
            title: a.title,
            dateTime: a.dateTime,
            notes: a.notes,
          );
        }
      }
    }
    return true;
  }

  Future<bool> renamePatient(String oldName, String newName) {
    return upsertPatient(originalName: oldName, name: newName);
  }

  Future<bool> deletePatient(String name) async {
    final before = patients.length;
    await AppDatabase.I.deletePatientByName(name);
    await AppDatabase.I.deleteDosesByPatient(name);
    await AppDatabase.I.deleteAppointmentsByPatient(name);

    patients.removeWhere((p) => p.name == name);
    final removed = patients.length < before;
    if (removed) {
      doses.removeWhere((d) => d.patientName == name);
      appointments.removeWhere((a) => a.patientName == name);
    }
    return removed;
  }

  // =========================================================
  // الجرعات
  // =========================================================

  Future<void> addDoses(List<Dose> newDoses) async {
    if (newDoses.isEmpty) return;

    // لو عندك دالة bulk في DB:
    try {
      await AppDatabase.I.insertDosesBulk(newDoses.map((d) {
        return <String, Object?>{
          'patient_name': d.patientName,
          'medicine_name': d.medicineName,
          'dose_text': d.doseText,
          'time': d.time.toIso8601String(),
          'taken': d.taken ? 1 : 0,
        };
      }).toList());
    } catch (_) {
      // fallback: إدراج فردي إذا ما متوفرة bulk
      for (final d in newDoses) {
        await AppDatabase.I.insertDose(
          patientName: d.patientName,
          medicineName: d.medicineName,
          doseText: d.doseText,
          timeIso: d.time.toIso8601String(),
          taken: d.taken,
        );
      }
    }
    doses.addAll(newDoses);
  }

  Future<void> replaceDoseGroup({
    required String oldPatientName,
    required String oldMedicineName,
    required String oldDoseText,
    required List<Dose> newDoses,
  }) async {
    // لو عندك دالة replace في DB:
    try {
      await AppDatabase.I.replaceDoseGroup(
        oldPatientName: oldPatientName,
        oldMedicineName: oldMedicineName,
        oldDoseText: oldDoseText,
        newRows: newDoses.map((d) {
          return <String, Object?>{
            'patient_name': d.patientName,
            'medicine_name': d.medicineName,
            'dose_text': d.doseText,
            'time': d.time.toIso8601String(),
            'taken': d.taken ? 1 : 0,
          };
        }).toList(),
      );
    } catch (_) {
      // fallback: حذف القديم ثم إدراج الجديد
      await AppDatabase.I.deleteDoseGroup(
        patientName: oldPatientName,
        medicineName: oldMedicineName,
        doseText: oldDoseText,
      );
      await addDoses(newDoses);
    }

    doses.removeWhere((d) =>
    d.patientName == oldPatientName &&
        d.medicineName == oldMedicineName &&
        d.doseText == oldDoseText);
    doses.addAll(newDoses);
  }

  Future<void> deleteDoseGroup({
    required String patientName,
    required String medicineName,
    required String doseText,
  }) async {
    await AppDatabase.I.deleteDoseGroup(
      patientName: patientName,
      medicineName: medicineName,
      doseText: doseText,
    );
    doses.removeWhere((d) =>
    d.patientName == patientName &&
        d.medicineName == medicineName &&
        d.doseText == doseText);
  }

  Future<void> markDoseTakenByKey({
    required String patientName,
    required String medicineName,
    required String doseText,
    required DateTime time,
    required bool taken,
  }) async {
    final iso = time.toIso8601String();

    try {
      await AppDatabase.I.updateDoseTakenByKey(
        patientName: patientName,
        medicineName: medicineName,
        doseText: doseText,
        timeIso: iso,
        taken: taken,
      );
    } catch (_) {
      // fallback: لو ما موجودة في DB نكمل على الذاكرة فقط
    }

    final idx = doses.indexWhere((d) =>
    d.patientName == patientName &&
        d.medicineName == medicineName &&
        d.doseText == doseText &&
        d.time.toIso8601String() == iso);
    if (idx != -1) {
      doses[idx] = Dose(
        patientName: doses[idx].patientName,
        medicineName: doses[idx].medicineName,
        doseText: doses[idx].doseText,
        time: doses[idx].time,
        taken: taken,
      );
    }
  }

  Future<void> toggleDoseTaken(Dose dose) async {
    final newValue = !dose.taken;
    await markDoseTakenByKey(
      patientName: dose.patientName,
      medicineName: dose.medicineName,
      doseText: dose.doseText,
      time: dose.time,
      taken: newValue,
    );
  }

  /// نُبقي الجرعات القديمة؛ فقط نرتّبها
  List<Dose> dosesForDay(DateTime day) {
    final d0 = DateTime(day.year, day.month, day.day);
    return doses
        .where((d) =>
    d.time.year == d0.year &&
        d.time.month == d0.month &&
        d.time.day == d0.day)
        .toList()
      ..sort((a, b) => a.time.compareTo(b.time));
  }

  // =========================================================
  // المواعيد
  // =========================================================
  Future<void> addAppointment(Appointment a) async {
    await AppDatabase.I.insertAppointment(
      patientName: a.patientName,
      doctorName: a.doctorName,
      title: a.title,
      dateTimeIso: a.dateTime.toIso8601String(),
      notes: a.notes,
    );
    appointments.add(a);
  }

  void deleteAppointment(Appointment a) {
    appointments.remove(a);
    // تحسين لاحق: حذف الصف من DB عند ربط id
  }

  List<Appointment> appointmentsForPatient(String patientName) {
    return appointments
        .where((e) => e.patientName == patientName)
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }

  List<Appointment> appointmentsForDay(DateTime day) {
    final d0 = DateTime(day.year, day.month, day.day);
    return appointments
        .where((a) =>
    a.dateTime.year == d0.year &&
        a.dateTime.month == d0.month &&
        a.dateTime.day == d0.day)
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }

  // =========================================================
  // التذكيرات
  // =========================================================
  Future<void> addReminder(Reminder r) async {
    await AppDatabase.I.insertReminder(
      title: r.title,
      dateTimeIso: r.dateTime.toIso8601String(),
      notes: r.notes,
    );
    reminders.add(r);
  }

  void deleteReminder(Reminder r) {
    reminders.remove(r);
  }

  List<Reminder> remindersForDay(DateTime day) {
    final d0 = DateTime(day.year, day.month, day.day);
    return reminders
        .where((r) =>
    r.dateTime.year == d0.year &&
        r.dateTime.month == d0.month &&
        r.dateTime.day == d0.day)
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }
}
