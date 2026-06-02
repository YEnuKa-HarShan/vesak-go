class UserModel {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String passwordHash;
  final String role;
  final DateTime createdAt;
  final int totalXp;
  final int currentLevel;

  UserModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.passwordHash,
    this.role = 'logged',
    required this.createdAt,
    required this.totalXp,
    required this.currentLevel,
  });

  String get fullName => '$firstName $lastName';

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'password_hash': passwordHash,
      'role': role,
      'created_at': createdAt.toIso8601String(),
      'total_xp': totalXp,
      'current_level': currentLevel,
    };
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      firstName: json['first_name'],
      lastName: json['last_name'],
      email: json['email'],
      passwordHash: json['password_hash'],
      role: json['role'] ?? 'logged',
      createdAt: DateTime.parse(json['created_at']),
      totalXp: json['total_xp'] ?? 0,
      currentLevel: json['current_level'] ?? 0,
    );
  }
}
