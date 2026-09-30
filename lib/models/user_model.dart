class UserModel {
  final String uid;
  final String email;
  final String role;
  final int points;

  UserModel({
    required this.uid,
    required this.email,
    required this.role,
    required this.points,
  });

  factory UserModel.fromFirestore(
      Map<String, dynamic> data, String docId) {
    return UserModel(
      uid: docId,
      email: data['email'] ?? '',
      role: data['role'] ?? 'CITIZEN',
      points: (data['points'] ?? 0) as int,
    );
  }
}
