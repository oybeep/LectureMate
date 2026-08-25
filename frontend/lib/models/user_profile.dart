class UserProfile {
  final int id;
  final String name;
  final String email;
  final String? profileImageUrl;

  UserProfile({
    required this.id,
    required this.name,
    required this.email,
    this.profileImageUrl,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] ?? 1,
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      profileImageUrl: json['profile_image_url'],
    );
  }

  // 💡 id, email, profileImageUrl을 포함하도록 수정
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'profile_image_url': profileImageUrl,
    };
  }
}