class Company {
  final String id;
  final String domain;
  final String name;
  final String? hsseEmail;
  final String? phone;
  final String? address;
  final Map<String, dynamic> settings;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Company({
    required this.id,
    required this.domain,
    required this.name,
    this.hsseEmail,
    this.phone,
    this.address,
    required this.settings,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Company.fromMap(Map<String, dynamic> map) {
    return Company(
      id: map['id'],
      domain: map['domain'],
      name: map['name'],
      hsseEmail: map['hsse_email'],
      phone: map['phone'],
      address: map['address'],
      settings: Map<String, dynamic>.from(map['settings'] ?? {}),
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'domain': domain,
      'name': name,
      'hsse_email': hsseEmail,
      'phone': phone,
      'address': address,
      'settings': settings,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class UserProfile {
  final String id;
  final String email;
  final String password; // Added password field for testing
  final String? fullName;
  final String role;
  final String? companyDomain;
  final String? phone;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserProfile({
    required this.id,
    required this.email,
    required this.password,
    this.fullName,
    required this.role,
    this.companyDomain,
    this.phone,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'],
      email: map['email'],
      password: map['password'],
      fullName: map['full_name'],
      role: map['role'],
      companyDomain: map['company_domain'],
      phone: map['phone'],
      isActive: map['is_active'] ?? true,
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'password': password,
      'full_name': fullName,
      'role': role,
      'company_domain': companyDomain,
      'phone': phone,
      'is_active': isActive,
    };
  }
}
