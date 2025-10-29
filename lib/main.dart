// lib/main.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'ui/home_page.dart';
import 'ui/common/app_colors.dart';
import 'ui/common/app_routes.dart';
import 'ui/screens/settings_page.dart';
import 'ui/screens/about_page.dart';
import 'ui/screens/add_medicine_page.dart';
import 'ui/screens/add_patient_page.dart';
import 'ui/screens/add_appointment_page.dart';
import 'ui/screens/add_reminder_page.dart';
import 'ui/screens/patients_page.dart';
import 'ui/screens/appointments_page.dart';
import 'ui/screens/reminders_page.dart';

// إشعارات
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'data/settings.dart';
import 'data/db/app_database.dart';
import 'data/app_data.dart';
import 'data/models.dart';

// الجسر (يبقى كما هو)
import 'notifications/notification_bridge.dart';

final FlutterLocalNotificationsPlugin flnp = FlutterLocalNotificationsPlugin();
const MethodChannel _notifCh = MethodChannel('mednote/notifications');

final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();

Future<void> _initNotifications() async {
  tz.initializeTimeZones();

  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  try {
    await flnp.initialize(
      const InitializationSettings(android: androidInit),
      onDidReceiveNotificationResponse: (resp) async {
        _openTodayMedications();
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );
  } catch (_) {}

  // نطلب إذن الإشعارات + شاشة المنبّهات الدقيقة (مرة عند التشغيل)
  try {
    await _notifCh.invokeMethod('requestPermissions');
  } catch (_) {}
  try {
    await _notifCh.invokeMethod('openExactAlarmSettings');
  } catch (_) {}
}

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {}

void _openTodayMedications() {
  _navKey.currentState?.popUntil((r) => r.isFirst);
  HomePage.gKey.currentState?.refreshTodayTab();
}

/// سحب طابور "أخذت الجرعة" القادم من الأندرويد وتطبيقه على الـ DB والذاكرة
Future<void> _drainTakenQueue() async {
  try {
    final res = await _notifCh.invokeMethod<List<dynamic>>('getAndClearTakenQueue');
    if (res == null || res.isEmpty) return;

    for (final item in res) {
      if (item is Map) {
        final patient = (item['patientName'] ?? '').toString();
        final med = (item['medicineName'] ?? '').toString();
        final doseText = (item['doseText'] ?? '').toString();
        final timeMillis = (item['timeMillis'] as num?)?.toInt() ?? 0;
        if (patient.isEmpty || med.isEmpty || doseText.isEmpty || timeMillis <= 0) continue;

        final time = DateTime.fromMillisecondsSinceEpoch(timeMillis);
        await AppData.I.markDoseTakenByKey(
          patientName: patient,
          medicineName: med,
          doseText: doseText,
          time: time,
          taken: true,
        );
      }
    }
    // بعد السحب والتأشير → حدّث تبويب اليوم مباشرة
    HomePage.gKey.currentState?.refreshTodayTab();
  } catch (_) {}
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔹 مهم جداً لعلاج رجوع الإعدادات للوضع الافتراضي
  await Settings.I.init();

  await AppDatabase.I.init();
  await AppData.I.loadFromDb();
  await _initNotifications();

  // اسحب الطابور عند الإقلاع (لو فيه ضغط زر "أخذت" حصل والتطبيق كان مغلق)
  await _drainTakenQueue();

  _notifCh.setMethodCallHandler((call) async {
    try {
      if (call.method == 'notificationAction') {
        final Map<dynamic, dynamic> p = call.arguments as Map<dynamic, dynamic>;
        final action = (p['action'] as String?) ?? '';
        final patient = (p['patientName'] as String?) ?? '';
        final med = (p['medicineName'] as String?) ?? '';
        final doseText = (p['doseText'] as String?) ?? '';
        final timeMillis = (p['timeMillis'] as num?)?.toInt() ?? 0;
        final snooze = (p['snoozeMinutes'] as num?)?.toInt() ?? Settings.I.snoozeMinutes.value;

        final time = DateTime.fromMillisecondsSinceEpoch(timeMillis);

        if (action == 'OPEN_TODAY') {
          _openTodayMedications();
        } else if (action == 'TAKEN') {
          // (لو تم تمريرها عبر القناة مباشرة)
          if (patient.isNotEmpty && med.isNotEmpty && doseText.isNotEmpty && timeMillis > 0) {
            await AppData.I.markDoseTakenByKey(
              patientName: patient,
              medicineName: med,
              doseText: doseText,
              time: time,
              taken: true,
            );
            HomePage.gKey.currentState?.refreshBothTabs();
          } else {
            // أو اسحب من الطابور الاحتياطي
            await _drainTakenQueue();
          }
        } else if (action == 'SNOOZE') {
          final d = Dose(
            patientName: patient,
            medicineName: med,
            doseText: doseText,
            time: time.add(Duration(minutes: snooze)),
          );
          await NotificationBridge.scheduleDose(
            dose: d,
            snoozeMinutes: snooze,
            reminderLeadMinutes: Settings.I.reminderLeadMinutes.value,
            type: 'دواء',
          );
          HomePage.gKey.currentState?.refreshTodayTab();
        }
      }
    } catch (_) {}
    return;
  });

  runApp(const _MedNoteRoot());
}

/// غلاف Stateful لمراقبة دورة حياة التطبيق وسحب الطابور عند الرجوع من الخلفية
class _MedNoteRoot extends StatefulWidget {
  const _MedNoteRoot({super.key});
  @override
  State<_MedNoteRoot> createState() => _MedNoteRootState();
}

class _MedNoteRootState extends State<_MedNoteRoot> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // عند الرجوع للواجهة: اسحب أي ضغطات "أخذت" تمت بينما التطبيق بالخلفية/مغلق
      _drainTakenQueue();
    }
  }

  @override
  Widget build(BuildContext context) => const MedNoteApp();
}

class MedNoteApp extends StatelessWidget {
  const MedNoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    final lightScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      secondary: AppColors.primaryDark,
      brightness: Brightness.light,
    );
    final darkScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primaryDark,
      primary: AppColors.primaryDark,
      secondary: AppColors.primary,
      brightness: Brightness.dark,
    );

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: Settings.I.themeMode,
      builder: (context, mode, _) {
        return ValueListenableBuilder<Locale?>(
          valueListenable: Settings.I.locale,
          builder: (context, loc, __) {
            return MaterialApp(
              navigatorKey: _navKey,
              debugShowCheckedModeBanner: false,
              title: 'MedNote',
              themeMode: mode,
              theme: ThemeData(colorScheme: lightScheme, useMaterial3: true),
              darkTheme: ThemeData(colorScheme: darkScheme, useMaterial3: true),
              locale: loc ?? const Locale('ar'),
              supportedLocales: const [Locale('ar'), Locale('en')],
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              // نستخدم مفتاح HomePage.gKey لتحديث التبويبات من main.dart
              home: HomePage(key: HomePage.gKey),
              routes: {
                AppRoutes.settings: (_) => const SettingsPage(),
                AppRoutes.about: (_) => const AboutPage(),
                AppRoutes.patients: (_) => const PatientsPage(),
                AppRoutes.appointments: (_) => const AppointmentsPage(),
                AppRoutes.reminders: (_) => const RemindersPage(),
                AppRoutes.addMedicine: (_) => const AddMedicinePage(),
                AppRoutes.addPatient: (_) => const AddPatientPage(),
                AppRoutes.addAppointment: (_) => const AddAppointmentPage(),
                AppRoutes.addReminder: (_) => const AddReminderPage(),
              },
            );
          },
        );
      },
    );
  }
}
