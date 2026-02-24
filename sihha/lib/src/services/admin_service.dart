import '../models/app_user.dart';
import '../models/admin_dashboard.dart';
import 'api_service.dart';

class AdminService {
  AdminService(this._apiService);

  final ApiService _apiService;

  Future<List<AppUser>> fetchUsers() async {
    final body = await _apiService.get('/admin/users');
    final map = _readMap(body);
    final list = _readList(map['users']);
    return list
        .map((raw) => _readMap(raw))
        .map((raw) => AppUser.fromMap((raw['id'] as String?) ?? '', raw))
        .toList();
  }

  Future<AdminDashboardData> fetchDashboard() async {
    final body = await _apiService.get('/admin/dashboard');
    final map = _readMap(body);
    final summaryMap = _readMap(map['summary']);
    final visitorsMap = _readMap(map['visitors']);
    final doctorsList = _readList(map['doctors']);
    final currentVisitorsList = _readList(map['currentVisitors']);

    final summary = AdminSummaryStats(
      totalUsers: _readInt(summaryMap['totalUsers']),
      doctorsCount: _readInt(summaryMap['doctorsCount']),
      patientsCount: _readInt(summaryMap['patientsCount']),
      disabledUsersCount: _readInt(summaryMap['disabledUsersCount']),
    );
    final visitors = AdminVisitorsStats(
      today: _readInt(visitorsMap['today']),
      month: _readInt(visitorsMap['month']),
      year: _readInt(visitorsMap['year']),
      currentOnline: _readInt(visitorsMap['currentOnline']),
    );

    final doctors = doctorsList.map((raw) {
      final doctor = _readMap(raw);
      return AdminDoctorKpi(
        id: (doctor['id'] as String?) ?? '',
        name: (doctor['name'] as String?) ?? '',
        phoneNumber: (doctor['phoneNumber'] as String?) ?? '',
        photoUrl: (doctor['photoUrl'] as String?) ?? '',
        specialty: (doctor['specialty'] as String?) ?? '',
        hospitalName: (doctor['hospitalName'] as String?) ?? '',
        isDisabled: _readBool(doctor['isDisabled']),
        patientsToday: _readInt(doctor['patientsToday']),
        patientsMonth: _readInt(doctor['patientsMonth']),
        patientsYear: _readInt(doctor['patientsYear']),
        consultationsToday: _readInt(doctor['consultationsToday']),
        consultationsMonth: _readInt(doctor['consultationsMonth']),
        consultationsYear: _readInt(doctor['consultationsYear']),
      );
    }).toList();

    final currentVisitors = currentVisitorsList.map((raw) {
      final visitor = _readMap(raw);
      return AdminCurrentVisitor(
        id: (visitor['id'] as String?) ?? '',
        name: (visitor['name'] as String?) ?? '',
        phoneNumber: (visitor['phoneNumber'] as String?) ?? '',
        role: UserRole.fromValue(visitor['role'] as String?),
        photoUrl: (visitor['photoUrl'] as String?) ?? '',
        isDisabled: _readBool(visitor['isDisabled']),
        lastSeenAt: _readDate(visitor['lastSeenAt']),
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
    final map = _readMap(body);
    final userMap = _readMap(map['user']);
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
    final map = _readMap(body);
    final userMap = _readMap(map['user']);
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

  Map<String, dynamic> _readMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    throw const ApiException(
      code: 'invalid-response',
      message: 'Unexpected response from backend.',
    );
  }

  List<dynamic> _readList(dynamic value) {
    if (value is List<dynamic>) {
      return value;
    }
    throw const ApiException(
      code: 'invalid-response',
      message: 'Unexpected list payload from backend.',
    );
  }

  int _readInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value.trim()) ?? 0;
    }
    return 0;
  }

  bool _readBool(dynamic value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized == 'true' || normalized == '1';
    }
    return false;
  }

  DateTime? _readDate(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}
