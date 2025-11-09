// lib/data/db/app_database.dart
import 'dart:async';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase I = AppDatabase._();

  Database? _db;
  Database get db => _db!;

  Future<void> init() async {
    if (_db != null) return;
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, 'mednote.db');

    _db = await openDatabase(
      dbPath,
      version: 2,
      onCreate: (db, v) async {
        await db.execute('''
          CREATE TABLE patients(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT UNIQUE NOT NULL,
            gender TEXT,
            dob TEXT
          );
        ''');

        await db.execute('''
          CREATE TABLE appointments(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            patient_name TEXT NOT NULL,
            doctor_name TEXT NOT NULL,
            title TEXT NOT NULL,
            date_time TEXT NOT NULL,
            notes TEXT
          );
        ''');

        await db.execute('''
          CREATE TABLE reminders(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            date_time TEXT NOT NULL,
            notes TEXT
          );
        ''');

        await db.execute('''
          CREATE TABLE doses(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            patient_name TEXT NOT NULL,
            medicine_name TEXT NOT NULL,
            dose_text TEXT NOT NULL,
            time TEXT NOT NULL,
            taken INTEGER NOT NULL
          );
        ''');

        await db.execute('''
          CREATE TABLE stopped_medicines(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            patient_name TEXT NOT NULL,
            medicine_name TEXT NOT NULL,
            dose_text TEXT NOT NULL,
            first_time TEXT NOT NULL,
            stopped_at TEXT NOT NULL
          );
        ''');

        // مريض افتراضي
        await db.insert(
          'patients',
          {'name': 'مستخدم', 'gender': null, 'dob': null},
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS stopped_medicines(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              patient_name TEXT NOT NULL,
              medicine_name TEXT NOT NULL,
              dose_text TEXT NOT NULL,
              first_time TEXT NOT NULL,
              stopped_at TEXT NOT NULL
            );
          ''');
        }
      },
    );
  }

  // ================= Patients =================
  Future<List<Map<String, Object?>>> getPatients() async =>
      db.query('patients', orderBy: 'name ASC');

  Future<int> insertPatient(String name, {String? gender, String? dob}) async {
    return db.insert('patients', {
      'name': name,
      'gender': gender,
      'dob': dob,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> updatePatientByName(String oldName,
      {required String newName, String? gender, String? dob}) async {
    return db.update(
      'patients',
      {'name': newName, 'gender': gender, 'dob': dob},
      where: 'name = ?',
      whereArgs: [oldName],
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> deletePatientByName(String name) async =>
      db.delete('patients', where: 'name = ?', whereArgs: [name]);

  // ================= Doses =================
  Future<List<Map<String, Object?>>> getDoses() async =>
      db.query('doses', orderBy: 'time ASC');

  Future<int> insertDose({
    required String patientName,
    required String medicineName,
    required String doseText,
    required String timeIso,
    required bool taken,
  }) async {
    return db.insert('doses', {
      'patient_name': patientName,
      'medicine_name': medicineName,
      'dose_text': doseText,
      'time': timeIso,
      'taken': taken ? 1 : 0,
    });
  }

  /// إدراج دفعة واحدة (أسرع)
  Future<void> insertDosesBulk(List<Map<String, Object?>> rows) async {
    if (rows.isEmpty) return;
    final batch = db.batch();
    for (final r in rows) {
      batch.insert('doses', r);
    }
    await batch.commit(noResult: true);
  }

  /// تحديث taken عبر مفتاح (patient, medicine, doseText, timeIso)
  Future<int> updateDoseTakenByKey({
    required String patientName,
    required String medicineName,
    required String doseText,
    required String timeIso,
    required bool taken,
  }) {
    return db.update(
      'doses',
      {'taken': taken ? 1 : 0},
      where:
      'patient_name = ? AND medicine_name = ? AND dose_text = ? AND time = ?',
      whereArgs: [patientName, medicineName, doseText, timeIso],
    );
  }

  /// حذف مجموعة جرعات كاملة (مفتاح المجموعة)
  Future<int> deleteDoseGroup({
    required String patientName,
    required String medicineName,
    required String doseText,
  }) {
    return db.delete(
      'doses',
      where: 'patient_name = ? AND medicine_name = ? AND dose_text = ?',
      whereArgs: [patientName, medicineName, doseText],
    );
  }

  /// استبدال مجموعة جرعات في معاملة واحدة
  Future<void> replaceDoseGroup({
    required String oldPatientName,
    required String oldMedicineName,
    required String oldDoseText,
    required List<Map<String, Object?>> newRows,
  }) async {
    await db.transaction((txn) async {
      await txn.delete(
        'doses',
        where: 'patient_name = ? AND medicine_name = ? AND dose_text = ?',
        whereArgs: [oldPatientName, oldMedicineName, oldDoseText],
      );
      final b = txn.batch();
      for (final r in newRows) {
        b.insert('doses', r);
      }
      await b.commit(noResult: true);
    });
  }

  Future<int> updateDoseTaken(int id, bool taken) async =>
      db.update('doses', {'taken': taken ? 1 : 0},
          where: 'id = ?', whereArgs: [id]);

  Future<int> deleteDoseById(int id) async =>
      db.delete('doses', where: 'id = ?', whereArgs: [id]);

  Future<int> deleteDosesByPatient(String patientName) async =>
      db.delete('doses', where: 'patient_name = ?', whereArgs: [patientName]);

  // ================= Stopped medicines =================
  Future<List<Map<String, Object?>>> getStoppedMedicines() async =>
      db.query('stopped_medicines', orderBy: 'stopped_at DESC');

  Future<int> insertStoppedMedicine({
    required String patientName,
    required String medicineName,
    required String doseText,
    required String firstTimeIso,
    required String stoppedAtIso,
  }) async {
    return db.insert('stopped_medicines', {
      'patient_name': patientName,
      'medicine_name': medicineName,
      'dose_text': doseText,
      'first_time': firstTimeIso,
      'stopped_at': stoppedAtIso,
    });
  }

  Future<int> deleteStoppedMedicineById(int id) async => db.delete(
        'stopped_medicines',
        where: 'id = ?',
        whereArgs: [id],
      );

  Future<int> deleteStoppedMedicineByKey({
    required String patientName,
    required String medicineName,
    required String doseText,
  }) async {
    return db.delete(
      'stopped_medicines',
      where: 'patient_name = ? AND medicine_name = ? AND dose_text = ?',
      whereArgs: [patientName, medicineName, doseText],
    );
  }

  Future<int> deleteStoppedMedicinesByPatient(String patientName) async {
    return db.delete(
      'stopped_medicines',
      where: 'patient_name = ?',
      whereArgs: [patientName],
    );
  }

  // ================= Appointments =================
  Future<List<Map<String, Object?>>> getAppointments() async =>
      db.query('appointments', orderBy: 'date_time ASC');

  Future<int> insertAppointment({
    required String patientName,
    required String doctorName,
    required String title,
    required String dateTimeIso,
    String? notes,
  }) async {
    return db.insert('appointments', {
      'patient_name': patientName,
      'doctor_name': doctorName,
      'title': title,
      'date_time': dateTimeIso,
      'notes': notes,
    });
  }

  Future<int> deleteAppointmentByRowId(int id) async =>
      db.delete('appointments', where: 'id = ?', whereArgs: [id]);

  Future<int> deleteAppointmentsByPatient(String patientName) async =>
      db.delete('appointments',
          where: 'patient_name = ?', whereArgs: [patientName]);

  // ================= Reminders =================
  Future<List<Map<String, Object?>>> getReminders() async =>
      db.query('reminders', orderBy: 'date_time ASC');

  Future<int> insertReminder({
    required String title,
    required String dateTimeIso,
    String? notes,
  }) async {
    return db.insert('reminders', {
      'title': title,
      'date_time': dateTimeIso,
      'notes': notes,
    });
  }

  Future<int> deleteReminderByRowId(int id) async =>
      db.delete('reminders', where: 'id = ?', whereArgs: [id]);
}
