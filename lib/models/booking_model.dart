enum PaymentMethod { cash, online }
enum BookingStatus { confirmed, pending, cancelled, completed }

class CustomerModel {
  final String id;
  final String name;
  final String phone;
  final String email;
  final int guestCount;
  final DateTime visitDate;
  final double amount;
  final PaymentMethod paymentMethod;
  final BookingStatus status;
  final String? notes;
  final DateTime createdAt;

  CustomerModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.guestCount,
    required this.visitDate,
    required this.amount,
    required this.paymentMethod,
    required this.status,
    this.notes,
    required this.createdAt,
  });

  factory CustomerModel.fromJson(Map<String, dynamic> json) {
    return CustomerModel(
      id: json['id'],
      name: json['name'],
      phone: json['phone'],
      email: json['email'],
      guestCount: json['guestCount'],
      visitDate: DateTime.parse(json['visitDate']),
      amount: json['amount'].toDouble(),
      paymentMethod: PaymentMethod.values.firstWhere(
        (e) => e.toString() == 'PaymentMethod.${json['paymentMethod']}',
        orElse: () => PaymentMethod.cash,
      ),
      status: BookingStatus.values.firstWhere(
        (e) => e.toString() == 'BookingStatus.${json['status']}',
        orElse: () => BookingStatus.pending,
      ),
      notes: json['notes'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'guestCount': guestCount,
      'visitDate': visitDate.toIso8601String(),
      'amount': amount,
      'paymentMethod': paymentMethod.toString().split('.').last,
      'status': status.toString().split('.').last,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  String get paymentMethodDisplay {
    switch (paymentMethod) {
      case PaymentMethod.cash:
        return 'Cash';
      case PaymentMethod.online:
        return 'Online';
    }
  }

  String get statusDisplay {
    switch (status) {
      case BookingStatus.confirmed:
        return 'Confirmed';
      case BookingStatus.pending:
        return 'Pending';
      case BookingStatus.cancelled:
        return 'Cancelled';
      case BookingStatus.completed:
        return 'Completed';
    }
  }
}

class DashboardStats {
  final int totalBookings;
  final int totalGuests;
  final double totalRevenue;
  final double cashPayment;
  final double onlinePayment;
  final DateTime date;

  DashboardStats({
    required this.totalBookings,
    required this.totalGuests,
    required this.totalRevenue,
    required this.cashPayment,
    required this.onlinePayment,
    required this.date,
  });

  factory DashboardStats.empty() {
    return DashboardStats(
      totalBookings: 0,
      totalGuests: 0,
      totalRevenue: 0,
      cashPayment: 0,
      onlinePayment: 0,
      date: DateTime.now(),
    );
  }

  factory DashboardStats.sample() {
    return DashboardStats(
      totalBookings: 24,
      totalGuests: 86,
      totalRevenue: 42500,
      cashPayment: 18000,
      onlinePayment: 24500,
      date: DateTime.now(),
    );
  }
}

class WorkerModel {
  final String id;
  final String name;
  final String phone;
  final String role;
  final bool isPresent;
  final DateTime joiningDate;

  WorkerModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
    required this.isPresent,
    required this.joiningDate,
  });

  factory WorkerModel.fromJson(Map<String, dynamic> json) {
    return WorkerModel(
      id: json['id'],
      name: json['name'],
      phone: json['phone'],
      role: json['role'],
      isPresent: json['isPresent'],
      joiningDate: DateTime.parse(json['joiningDate']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'role': role,
      'isPresent': isPresent,
      'joiningDate': joiningDate.toIso8601String(),
    };
  }
}
