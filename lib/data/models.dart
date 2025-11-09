// lib/data/models.dart

class Patient {
  String name;
  String? gender;      // 'male' | 'female' | null
  DateTime? dob;       // تاريخ الميلاد (اختياري)

  Patient(this.name, {this.gender, this.dob});

  String ageLabel() {
    if (dob == null) return '—';
    final now = DateTime.now();

    int years = now.year - dob!.year;
    int months = now.month - dob!.month;
    int days = now.day - dob!.day;

    if (days < 0) months -= 1;
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
}

class Dose {
  final String patientName;
  final String medicineName;
  final String doseText;
  final DateTime time;
  bool taken;

  Dose({
    required this.patientName,
    required this.medicineName,
    required this.doseText,
    required this.time,
    this.taken = false,
  });
}

class StoppedMedicine {
  final int? id;
  final String patientName;
  final String medicineName;
  final String doseText;
  final DateTime firstTime;
  final DateTime stoppedAt;

  const StoppedMedicine({
    this.id,
    required this.patientName,
    required this.medicineName,
    required this.doseText,
    required this.firstTime,
    required this.stoppedAt,
  });

  StoppedMedicine copyWith({int? id}) {
    return StoppedMedicine(
      id: id ?? this.id,
      patientName: patientName,
      medicineName: medicineName,
      doseText: doseText,
      firstTime: firstTime,
      stoppedAt: stoppedAt,
    );
  }
}

class Appointment {
  final String patientName;
  final String doctorName;
  final String title;
  final DateTime dateTime;
  final String? notes;

  Appointment({
    required this.patientName,
    required this.doctorName,
    required this.title,
    required this.dateTime,
    this.notes,
  });
}

class Reminder {
  final String title;
  final DateTime dateTime;
  final String? notes;

  Reminder({
    required this.title,
    required this.dateTime,
    this.notes,
  });
}
