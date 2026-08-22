class AppSettings {
  final bool isAutoSummaryEnabled;
  final bool isNotificationEnabled;
  final bool isDarkMode;
  final String language;

  AppSettings({
    required this.isAutoSummaryEnabled,
    required this.isNotificationEnabled,
    required this.isDarkMode,
    required this.language,
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      isAutoSummaryEnabled: json['is_auto_summary_enabled'] ?? true,
      isNotificationEnabled: json['is_notification_enabled'] ?? true,
      isDarkMode: json['is_dark_mode'] ?? false,
      language: json['language'] ?? 'ko',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'is_auto_summary_enabled': isAutoSummaryEnabled,
      'is_notification_enabled': isNotificationEnabled,
      'is_dark_mode': isDarkMode,
      'language': language,
    };
  }

  AppSettings copyWith({
    bool? isAutoSummaryEnabled,
    bool? isNotificationEnabled,
    bool? isDarkMode,
    String? language,
  }) {
    return AppSettings(
      isAutoSummaryEnabled: isAutoSummaryEnabled ?? this.isAutoSummaryEnabled,
      isNotificationEnabled: isNotificationEnabled ?? this.isNotificationEnabled,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      language: language ?? this.language,
    );
  }
}