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
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      profileImageUrl: json['profile_image_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
    };
  }
}