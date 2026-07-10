class Profile {
  final String id;
  final String? fullName;
  final String? avatarUrl;
  final String? email;
  final String language;
  final String? fcmToken;
  final int leagueTitles;
  final int diamonds;
  final DateTime createdAt;
  final DateTime updatedAt;

  Profile({
    required this.id,
    this.fullName,
    this.avatarUrl,
    this.email,
    required this.language,
    this.fcmToken,
    this.leagueTitles = 0,
    this.diamonds = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Profile.fromMap(Map<String, dynamic> map) {
    return Profile(
      id: map['id'] as String,
      fullName: map['full_name'] as String?,
      avatarUrl: map['avatar_url'] as String?,
      email: map['email'] as String?,
      language: map['language'] as String? ?? 'tr',
      fcmToken: map['fcm_token'] as String?,
      leagueTitles: (map['league_titles'] as num?)?.toInt() ?? 0,
      diamonds: (map['diamonds'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'full_name': fullName,
      'avatar_url': avatarUrl,
      'email': email,
      'language': language,
      'fcm_token': fcmToken,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
