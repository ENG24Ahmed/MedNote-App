// lib/data/settings.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// إعدادات التطبيق (سنجلتون) — تحميل/حفظ تلقائي من وإلى ملف JSON.
class Settings {
  Settings._();
  static final Settings I = Settings._();
fu gpt ;
  /// ملاحظة مهمة:
  /// - استدعِ `await Settings.I.init()` مرة واحدة في main() قبل runApp.

  // ------------------ القيم ------------------
  final ValueNotifier<ThemeMode> themeMode =
  ValueNotifier<ThemeMode>(ThemeMode.system);

  /// اللغة: null = لغة النظام
  final ValueNotifier<Locale?> locale =
  ValueNotifier<Locale?>(const Locale('ar'));

  /// "ذكرني لاحقاً" بالدقائق (>=1)
  final ValueNotifier<int> snoozeMinutes = ValueNotifier<int>(10);

  /// التذكير قبل الموعد بالدقائق (0 = إيقاف)
  final ValueNotifier<int> reminderLeadMinutes = ValueNotifier<int>(10);

  /// مسار مجلّد النسخ الاحتياطي الذي يختاره المستخدم (null = مجلّد التطبيق الداخلي)
  final ValueNotifier<String?> backupDirPath = ValueNotifier<String?>(null);

  // ------------------ تخزين ------------------
  late final File _file;
  bool _initialized = false;
  Timer? _debounce;

  /// يُنادى مرة واحدة عند بدء التطبيق.
  Future<void> init() async {
    if (_initialized) return;

    final dir = await getApplicationDocumentsDirectory();
    _file = File(p.join(dir.path, 'settings.json'));

    if (await _file.exists()) {
      try {
        final txt = await _file.readAsString();
        final Map<String, dynamic> jsonMap = json.decode(txt);
        loadFromJson(jsonMap);
      } catch (_) {
        // لو فشل التحميل لأي سبب نترك القيم الافتراضية
      }
    } else {
      // لا شيء — تُحفظ أول مرة عند أول تغيير أو عند الإنهاء
      await _save(); // احفظ ملف افتراضي أول مرة
    }

    // اربط المستمعين لعمل حفظ تلقائي على أي تغيير
    themeMode.addListener(_saveDebounced);
    locale.addListener(_saveDebounced);
    snoozeMinutes.addListener(_saveDebounced);
    reminderLeadMinutes.addListener(_saveDebounced);
    backupDirPath.addListener(_saveDebounced);

    _initialized = true;
  }

  void _saveDebounced() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _save();
    });
  }

  Future<void> _save() async {
    try {
      final jsonStr = const JsonEncoder.withIndent('  ').convert(toJson());
      await _file.writeAsString(jsonStr, flush: true);
    } catch (_) {
      // نتجاهل بصمت؛ التطبيق يستمر بالعمل وقيم الذاكرة تبقى صحيحة
    }
  }

  // ------------------ تحويلات ------------------

  Map<String, dynamic> toJson() => {
    'themeMode': switch (themeMode.value) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      _ => 'system',
    },
    'locale': switch (locale.value?.languageCode) {
      'ar' => 'ar',
      'en' => 'en',
      _ => 'system',
    },
    'snoozeMinutes': snoozeMinutes.value,
    'reminderLeadMinutes': reminderLeadMinutes.value,
    'backupDirPath': backupDirPath.value,
  };

  /// تحميل من JSON (تُستخدم عند init أو عند استرجاع نسخة احتياطية)
  void loadFromJson(Map<String, dynamic> json) {
    // theme
    final modeStr = (json['themeMode'] as String?) ?? 'system';
    themeMode.value = switch (modeStr) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };

    // locale
    final locStr = (json['locale'] as String?) ?? 'ar';
    locale.value = switch (locStr) {
      'ar' => const Locale('ar'),
      'en' => const Locale('en'),
      _ => null, // system
    };

    // snooze
    final snooze = json['snoozeMinutes'];
    if (snooze is int && snooze >= 1) snoozeMinutes.value = snooze;

    // lead (0 مسموح يعني إيقاف)
    final lead = json['reminderLeadMinutes'];
    if (lead is int && lead >= 0) reminderLeadMinutes.value = lead;

    // backup dir
    final bdir = json['backupDirPath'];
    backupDirPath.value = (bdir is String && bdir.trim().isNotEmpty) ? bdir : null;
  }
}
