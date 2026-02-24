import 'app_user.dart';

class AdminSummaryStats {
  const AdminSummaryStats({
    required this.totalUsers,
    required this.doctorsCount,
    required this.patientsCount,
    required this.disabledUsersCount,
  });

  final int totalUsers;
  final int doctorsCount;
  final int patientsCount;
  final int disabledUsersCount;
}

class AdminVisitorsStats {
  const AdminVisitorsStats({
    required this.today,
    required this.month,
    required this.year,
    required this.currentOnline,
  });

  final int today;
  final int month;
  final int year;
  final int currentOnline;
}

class AdminDoctorKpi {
  const AdminDoctorKpi({
    required this.id,
    required this.name,
    required this.phoneNumber,
    required this.photoUrl,
    required this.specialty,
    required this.hospitalName,
    required this.isDisabled,
    required this.patientsToday,
    required this.patientsMonth,
    required this.patientsYear,
    required this.consultationsToday,
    required this.consultationsMonth,
    required this.consultationsYear,
  });

  final String id;
  final String name;
  final String phoneNumber;
  final String photoUrl;
  final String specialty;
  final String hospitalName;
  final bool isDisabled;
  final int patientsToday;
  final int patientsMonth;
  final int patientsYear;
  final int consultationsToday;
  final int consultationsMonth;
  final int consultationsYear;
}

class AdminCurrentVisitor {
  const AdminCurrentVisitor({
    required this.id,
    required this.name,
    required this.phoneNumber,
    required this.role,
    required this.photoUrl,
    required this.isDisabled,
    required this.lastSeenAt,
  });

  final String id;
  final String name;
  final String phoneNumber;
  final UserRole role;
  final String photoUrl;
  final bool isDisabled;
  final DateTime? lastSeenAt;
}

class AdminDashboardData {
  const AdminDashboardData({
    required this.summary,
    required this.visitors,
    required this.doctors,
    required this.currentVisitors,
  });

  final AdminSummaryStats summary;
  final AdminVisitorsStats visitors;
  final List<AdminDoctorKpi> doctors;
  final List<AdminCurrentVisitor> currentVisitors;
}
