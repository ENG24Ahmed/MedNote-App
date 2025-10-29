import 'package:flutter/material.dart';

import 'common/add_fab_menu.dart';
import 'tabs/today_tab.dart';
import 'tabs/all_tab.dart';
import 'common/app_colors.dart';
import 'common/app_routes.dart';
import 'screens/add_medicine_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  /// مفتاح عام للوصول إلى حالة الصفحة وتحديث التبويبات من أماكن أخرى (مثل main.dart أو AllTab).
  static final GlobalKey<_HomePageState> gKey = GlobalKey<_HomePageState>();

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  // مفاتيح للتحديث الفوري (اليوم/كل الأدوية) عند الإضافة/التعديل
  final GlobalKey _todayTabKey = GlobalKey();
  final GlobalKey _allTabKey = GlobalKey();

  late final List<Widget> _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = <Widget>[
      TodayTab(key: _todayTabKey),
      AllTab(key: _allTabKey),
    ];
  }

  void _onItemTapped(int index) => setState(() => _selectedIndex = index);

  void _refreshToday() {
    final st = _todayTabKey.currentState;
    (st as dynamic?)?.refresh();
  }

  void _refreshAll() {
    final st = _allTabKey.currentState;
    (st as dynamic?)?.refresh();
  }

  /// استدعِها من الخارج لتحديث تبويب اليوم فقط
  void refreshTodayTab() => _refreshToday();

  /// استدعِها من الخارج لتحديث تبويب كل الأدوية فقط
  void refreshAllTab() => _refreshAll();

  /// استدعِها من الخارج لتحديث التبويبين معًا
  void refreshBothTabs() {
    _refreshToday();
    _refreshAll();
  }

  // فتح إضافة دواء مباشرة بدون routes (الأضمن)
  void _goAddMedicine() {
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true)
        .push<bool>(MaterialPageRoute(builder: (_) => const AddMedicinePage()))
        .then((saved) {
      if (saved == true) {
        _refreshToday();
        _refreshAll();
      }
    });
  }

  void _goAddPatient() {
    Navigator.of(context, rootNavigator: true)
        .pushNamed(AppRoutes.addPatient)
        .then((saved) {
      if (saved == true) {
        _refreshToday();
        _refreshAll();
      }
    });
  }

  void _goAddAppointment() {
    Navigator.of(context, rootNavigator: true)
        .pushNamed(AppRoutes.addAppointment)
        .then((saved) {
      if (saved == true) {
        _refreshToday();
        _refreshAll();
      }
    });
  }

  void _goAddReminder() {
    Navigator.of(context, rootNavigator: true)
        .pushNamed(AppRoutes.addReminder)
        .then((saved) {
      if (saved == true) {
        _refreshToday();
        _refreshAll();
      }
    });
  }

  void _goManagePatients() {
    Navigator.of(context).pushNamed(AppRoutes.patients).then((_) {
      _refreshToday();
      _refreshAll();
    });
  }

  void _goAppointments() {
    Navigator.of(context).pushNamed(AppRoutes.appointments).then((_) {
      _refreshToday();
      _refreshAll();
    });
  }

  void _goReminders() {
    Navigator.of(context).pushNamed(AppRoutes.reminders).then((_) {
      _refreshToday();
      _refreshAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("مذكرة الدواء"),
        backgroundColor: AppColors.primary,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'settings') {
                Navigator.pushNamed(context, AppRoutes.settings);
              } else if (value == 'patients') {
                _goManagePatients(); // إدارة المرضى
              } else if (value == 'appointments') {
                _goAppointments();    // موعد الطبيب
              } else if (value == 'reminders') {
                _goReminders();       // التذكيرات
              } else if (value == 'about') {
                Navigator.pushNamed(context, AppRoutes.about);
              }
            },
            itemBuilder: (ctx) => const [
              PopupMenuItem(
                value: 'settings',
                child: Text('الإعدادات', textDirection: TextDirection.rtl),
              ),
              PopupMenuItem(
                value: 'patients',
                child: Text('إدارة المرضى', textDirection: TextDirection.rtl),
              ),
              PopupMenuItem(
                value: 'appointments',
                child: Text('مواعيد الطبيب', textDirection: TextDirection.rtl),
              ),
              PopupMenuItem(
                value: 'reminders',
                child: Text('التذكيرات', textDirection: TextDirection.rtl),
              ),
              PopupMenuItem(
                value: 'about',
                child: Text('حول التطبيق', textDirection: TextDirection.rtl),
              ),
            ],
          ),
        ],
      ),

      body: IndexedStack(index: _selectedIndex, children: _tabs),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: AppColors.primary,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.today), label: "أدويتي اليوم"),
          BottomNavigationBarItem(icon: Icon(Icons.medication), label: "كل الأدوية"),
        ],
      ),

      floatingActionButton: AddFabMenu(
        items: [
          FabMenuItem(icon: Icons.medical_services, label: "إضافة دواء", onTap: _goAddMedicine),
          FabMenuItem(icon: Icons.person,           label: "إضافة مريض", onTap: _goAddPatient),
          FabMenuItem(icon: Icons.calendar_today,   label: "إضافة موعد طبيب", onTap: _goAddAppointment),
          FabMenuItem(icon: Icons.notifications,    label: "إضافة تذكير", onTap: _goAddReminder),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}
