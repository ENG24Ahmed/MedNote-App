// lib/notifications/notification_bridge.dart
import 'package:flutter/services.dart';
import '../data/models.dart';

/// جسر ثابت للتعامل مع قناة الإشعارات على الأندرويد.
/// لا توجد أي تبعيات على UI أو main.dart لتفادي الدوران في الاستيراد.
class NotificationBridge {
  static const MethodChannel _notifCh = MethodChannel('mednote/notifications');

  // ====== موجود مسبقاً: جرعات الدواء ======
  static Future<void> scheduleDose({
    required Dose dose,
    required int snoozeMinutes,
    required int reminderLeadMinutes,
    String type = 'دواء',
  }) async {
    final args = {
      'patientName': dose.patientName,
      'medicineName': dose.medicineName,
      'doseText': dose.doseText,
      'timeMillis': dose.time.millisecondsSinceEpoch,
      'timeLabel': dose.time.toIso8601String(),
      'snoozeMinutes': snoozeMinutes,
      'reminderLeadMinutes': reminderLeadMinutes,
      'type': type,
    };
    try {
      await _notifCh.invokeMethod('scheduleDose', args);
    } catch (_) {}
  }

  static Future<void> cancelDose(Dose dose) async {
    final args = {
      'patientName': dose.patientName,
      'medicineName': dose.medicineName,
      'doseText': dose.doseText,
      'timeMillis': dose.time.millisecondsSinceEpoch,
    };
    try {
      await _notifCh.invokeMethod('cancelDose', args);
    } catch (_) {}
  }

  static Future<void> cancelAllDoses() async {
    try {
      await _notifCh.invokeMethod('cancelAllDoses');
    } catch (_) {}
  }

  // ====== جديد: تذكير عام ======
  static Future<void> scheduleReminder(Reminder r) async {
    final args = {
      'title': r.title,
      'notes': r.notes,
      'timeMillis': r.dateTime.millisecondsSinceEpoch,
    };
    try {
      await _notifCh.invokeMethod('scheduleReminder', args);
    } catch (_) {}
  }

  static Future<void> cancelReminder(Reminder r) async {
    final args = {
      'title': r.title,
      'timeMillis': r.dateTime.millisecondsSinceEpoch,
    };
    try {
      await _notifCh.invokeMethod('cancelReminder', args);
    } catch (_) {}
  }

  // ====== جديد: موعد طبيب ======
  static Future<void> scheduleAppointment(
      Appointment a, {
        int morningHour = 8,
        int preMinutes = 60,
      }) async {
    final args = {
      'patientName': a.patientName,
      'doctorName': a.doctorName,
      'title': a.title,
      'notes': a.notes,
      'timeMillis': a.dateTime.millisecondsSinceEpoch,
      'morningHour': morningHour,
      'preMinutes': preMinutes,
    };
    try {
      await _notifCh.invokeMethod('scheduleAppointment', args);
    } catch (_) {}
  }

  static Future<void> cancelAppointment(Appointment a) async {
    final args = {
      'patientName': a.patientName,
      'doctorName': a.doctorName,
      'title': a.title,
      'timeMillis': a.dateTime.millisecondsSinceEpoch,
    };
    try {
      await _notifCh.invokeMethod('cancelAppointment', args);
    } catch (_) {}
  }
}
