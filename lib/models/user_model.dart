class UserModel {
  final String uid;
  final String email;
  final String name;
  final String role;

  UserModel({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
  });
  factory UserModel.fromMap(Map<String, dynamic> data) {
    return UserModel(
      uid: data['uid'] ?? '',
      email: data['email'] ?? '',
      name: data['name'] ?? '',
      role: data['role'] ?? 'customer',
    );
  }
}
