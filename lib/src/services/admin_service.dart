import '../models/app_user.dart';
import '../models/admin_dashboard.dart';
import '../utils/api_response_helpers.dart';
import '../utils/date_parser.dart';
import 'api_service.dart';

class AdminService {
  AdminService(this._apiService);

  final ApiService _apiService;

  Future<List<AppUser>> fetchUsers() async {
    final body = await _apiService.get('/admin/users');
    final map = readMap(body);
    final list = readList(map['users']);
    return list
        .map((raw) => readMap(raw))
        .map((raw) => AppUser.fromMap((raw['id'] as String?) ?? '', raw))
        .toList();
  }

  Future<AdminDashboardData> fetchDashboard() async {
    final body = await _apiService.get('/admin/dashboard');
    final map = readMap(body);
    final summaryMap = readMap(map['summary']);
    final visitorsMap = readMap(map['visitors']);
    final doctorsList = readList(map['doctors']);
    final currentVisitorsList = readList(map['currentVisitors']);

    final summary = AdminSummaryStats(
      totalUsers: readInt(summaryMap['totalUsers']),
      doctorsCount: readInt(summaryMap['doctorsCount']),
      patientsCount: readInt(summaryMap['patientsCount']),
      disabledUsersCount: readInt(summaryMap['disabledUsersCount']),
    );
    final visitors = AdminVisitorsStats(
      today: readInt(visitorsMap['today']),
      month: readInt(visitorsMap['month']),
      year: readInt(visitorsMap['year']),
      currentOnline: readInt(visitorsMap['currentOnline']),
    );

    final doctors = doctorsList.map((raw) {
      final doctor = readMap(raw);
      return AdminDoctorKpi(
        id: (doctor['id'] as String?) ?? '',
        name: (doctor['name'] as String?) ?? '',
        phoneNumber: (doctor['phoneNumber'] as String?) ?? '',
        photoUrl: (doctor['photoUrl'] as String?) ?? '',
        specialty: (doctor['specialty'] as String?) ?? '',
        hospitalName: (doctor['hospitalName'] as String?) ?? '',
        isDisabled: readBool(doctor['isDisabled']),
        patientsToday: readInt(doctor['patientsToday']),
        patientsMonth: readInt(doctor['patientsMonth']),
        patientsYear: readInt(doctor['patientsYear']),
        consultationsToday: readInt(doctor['consultationsToday']),
        consultationsMonth: readInt(doctor['consultationsMonth']),
        consultationsYear: readInt(doctor['consultationsYear']),
      );
    }).toList();

    final currentVisitors = currentVisitorsList.map((raw) {
      final visitor = readMap(raw);
      return AdminCurrentVisitor(
        id: (visitor['id'] as String?) ?? '',
        name: (visitor['name'] as String?) ?? '',
        phoneNumber: (visitor['phoneNumber'] as String?) ?? '',
        role: UserRole.fromValue(visitor['role'] as String?),
        photoUrl: (visitor['photoUrl'] as String?) ?? '',
        isDisabled: readBool(visitor['isDisabled']),
        lastSeenAt: parseNullableDate(visitor['lastSeenAt']),
      );
    }).toList();

    return AdminDashboardData(
      summary: summary,
      visitors: visitors,
      doctors: doctors,
      currentVisitors: currentVisitors,
    );
  }

  Future<AppUser> createUser({
    required String name,
    required String phoneNumber,
    required String password,
    required UserRole role,
    String specialty = '',
    String hospitalName = '',
    int experienceYears = 0,
    int studyYears = 0,
  }) async {
    final body = await _apiService.post(
      '/admin/users',
      body: {
        'name': name.trim(),
        'phoneNumber': phoneNumber,
        'password': password,
        'role': role.value,
        'specialty': specialty.trim(),
        'hospitalName': hospitalName.trim(),
        'experienceYears': experienceYears,
        'studyYears': studyYears,
      },
    );
    final map = readMap(body);
    final userMap = readMap(map['user']);
    return AppUser.fromMap((userMap['id'] as String?) ?? '', userMap);
  }

  Future<AppUser> setUserDisabled({
    required String userId,
    required bool disabled,
  }) async {
    final body = await _apiService.patch(
      '/admin/users/$userId/status',
      body: {'disabled': disabled},
    );
    final map = readMap(body);
    final userMap = readMap(map['user']);
    return AppUser.fromMap((userMap['id'] as String?) ?? '', userMap);
  }

  Future<void> resetUserPassword({
    required String userId,
    required String newPassword,
  }) async {
    await _apiService.post(
      '/admin/users/$userId/reset-password',
      body: {'newPassword': newPassword},
    );
  }

  Future<void> deleteUser({required String userId}) async {
    await _apiService.delete('/admin/users/$userId');
  }
}
