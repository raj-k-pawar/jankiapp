import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/booking_model.dart';

class DataService {
  static const String _customersKey = 'customers_list';
  static const String _workersKey = 'workers_list';

  // Sample customers
  static final List<Map<String, dynamic>> _sampleCustomers = [
    {
      'id': '1',
      'name': 'Amit Shah',
      'phone': '9876543220',
      'email': 'amit@gmail.com',
      'guestCount': 4,
      'visitDate': DateTime.now().toIso8601String(),
      'amount': 2800.0,
      'paymentMethod': 'cash',
      'status': 'confirmed',
      'notes': 'Family visit with kids',
      'createdAt': DateTime.now().toIso8601String(),
    },
    {
      'id': '2',
      'name': 'Priya Sharma',
      'phone': '9876543221',
      'email': 'priya@gmail.com',
      'guestCount': 6,
      'visitDate': DateTime.now().toIso8601String(),
      'amount': 4200.0,
      'paymentMethod': 'online',
      'status': 'confirmed',
      'notes': 'Corporate team outing',
      'createdAt': DateTime.now().toIso8601String(),
    },
    {
      'id': '3',
      'name': 'Rohit Verma',
      'phone': '9876543222',
      'email': 'rohit@gmail.com',
      'guestCount': 2,
      'visitDate': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
      'amount': 1400.0,
      'paymentMethod': 'online',
      'status': 'completed',
      'notes': '',
      'createdAt': DateTime.now().subtract(const Duration(hours: 3)).toIso8601String(),
    },
    {
      'id': '4',
      'name': 'Neha Patel',
      'phone': '9876543223',
      'email': 'neha@gmail.com',
      'guestCount': 8,
      'visitDate': DateTime.now().toIso8601String(),
      'amount': 5600.0,
      'paymentMethod': 'cash',
      'status': 'pending',
      'notes': 'Birthday celebration',
      'createdAt': DateTime.now().toIso8601String(),
    },
  ];

  static final List<Map<String, dynamic>> _sampleWorkers = [
    {
      'id': '1',
      'name': 'Mohan Lal',
      'phone': '9876543230',
      'role': 'Guide',
      'isPresent': true,
      'joiningDate': DateTime(2022, 1, 15).toIso8601String(),
    },
    {
      'id': '2',
      'name': 'Sita Devi',
      'phone': '9876543231',
      'role': 'Cook',
      'isPresent': true,
      'joiningDate': DateTime(2021, 6, 10).toIso8601String(),
    },
    {
      'id': '3',
      'name': 'Raju Yadav',
      'phone': '9876543232',
      'role': 'Security',
      'isPresent': false,
      'joiningDate': DateTime(2023, 3, 20).toIso8601String(),
    },
    {
      'id': '4',
      'name': 'Kavita Joshi',
      'phone': '9876543233',
      'role': 'Receptionist',
      'isPresent': true,
      'joiningDate': DateTime(2022, 9, 5).toIso8601String(),
    },
    {
      'id': '5',
      'name': 'Deepak Tiwari',
      'phone': '9876543234',
      'role': 'Gardener',
      'isPresent': true,
      'joiningDate': DateTime(2020, 11, 1).toIso8601String(),
    },
  ];

  Future<List<CustomerModel>> getCustomers() async {
    await Future.delayed(const Duration(milliseconds: 500));
    final prefs = await SharedPreferences.getInstance();
    final customersJson = prefs.getString(_customersKey);

    List<Map<String, dynamic>> allCustomers = List.from(_sampleCustomers);

    if (customersJson != null) {
      final List<dynamic> savedCustomers = jsonDecode(customersJson);
      for (var c in savedCustomers) {
        allCustomers.add(Map<String, dynamic>.from(c));
      }
    }

    return allCustomers.map((c) => CustomerModel.fromJson(c)).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<List<CustomerModel>> getTodaysCustomers() async {
    final all = await getCustomers();
    final today = DateTime.now();
    return all.where((c) {
      return c.visitDate.year == today.year &&
          c.visitDate.month == today.month &&
          c.visitDate.day == today.day;
    }).toList();
  }

  Future<DashboardStats> getDashboardStats() async {
    final todaysCustomers = await getTodaysCustomers();

    int totalGuests = 0;
    double cashPayment = 0;
    double onlinePayment = 0;

    for (var customer in todaysCustomers) {
      totalGuests += customer.guestCount;
      if (customer.paymentMethod == PaymentMethod.cash) {
        cashPayment += customer.amount;
      } else {
        onlinePayment += customer.amount;
      }
    }

    return DashboardStats(
      totalBookings: todaysCustomers.length,
      totalGuests: totalGuests,
      totalRevenue: cashPayment + onlinePayment,
      cashPayment: cashPayment,
      onlinePayment: onlinePayment,
      date: DateTime.now(),
    );
  }

  Future<void> addCustomer(CustomerModel customer) async {
    final prefs = await SharedPreferences.getInstance();
    final customersJson = prefs.getString(_customersKey);
    List<dynamic> savedCustomers = customersJson != null ? jsonDecode(customersJson) : [];
    savedCustomers.add(customer.toJson());
    await prefs.setString(_customersKey, jsonEncode(savedCustomers));
  }

  Future<List<WorkerModel>> getWorkers() async {
    await Future.delayed(const Duration(milliseconds: 400));
    final prefs = await SharedPreferences.getInstance();
    final workersJson = prefs.getString(_workersKey);

    List<Map<String, dynamic>> allWorkers = List.from(_sampleWorkers);

    if (workersJson != null) {
      final List<dynamic> savedWorkers = jsonDecode(workersJson);
      for (var w in savedWorkers) {
        allWorkers.add(Map<String, dynamic>.from(w));
      }
    }

    return allWorkers.map((w) => WorkerModel.fromJson(w)).toList();
  }

  Future<void> addWorker(WorkerModel worker) async {
    final prefs = await SharedPreferences.getInstance();
    final workersJson = prefs.getString(_workersKey);
    List<dynamic> savedWorkers = workersJson != null ? jsonDecode(workersJson) : [];
    savedWorkers.add(worker.toJson());
    await prefs.setString(_workersKey, jsonEncode(savedWorkers));
  }

  Future<void> updateWorkerAttendance(String workerId, bool isPresent) async {
    final prefs = await SharedPreferences.getInstance();
    final workersJson = prefs.getString(_workersKey);
    List<dynamic> savedWorkers = workersJson != null ? jsonDecode(workersJson) : [];

    for (var i = 0; i < savedWorkers.length; i++) {
      if (savedWorkers[i]['id'] == workerId) {
        savedWorkers[i]['isPresent'] = isPresent;
        break;
      }
    }
    await prefs.setString(_workersKey, jsonEncode(savedWorkers));
  }
}
