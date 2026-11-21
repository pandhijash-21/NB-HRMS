class ModuleConfig {
  final bool enabled;
  final String title;
  final String message;

  const ModuleConfig({
    this.enabled = false,
    this.title = '',
    this.message = '',
  });

  factory ModuleConfig.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ModuleConfig();
    return ModuleConfig(
      enabled: json['enabled'] == true,
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'title': title,
    'message': message,
  };

  ModuleConfig copyWith({
    bool? enabled,
    String? title,
    String? message,
  }) {
    return ModuleConfig(
      enabled: enabled ?? this.enabled,
      title: title ?? this.title,
      message: message ?? this.message,
    );
  }
}

class MaintenancePolicy {
  final ModuleConfig global;
  final Map<String, ModuleConfig> modules;
  final String? estimatedEndTime;
  final String? updatedAt;
  final String? updatedBy;

  const MaintenancePolicy({
    required this.global,
    required this.modules,
    this.estimatedEndTime,
    this.updatedAt,
    this.updatedBy,
  });

  factory MaintenancePolicy.fromJson(Map<String, dynamic> json) {
    final modulesRaw = json['modules'] is Map ? Map<String, dynamic>.from(json['modules'] as Map) : <String, dynamic>{};
    final Map<String, ModuleConfig> mods = {};
    for (final key in ['CRM', 'HRMS', 'ERP', 'COLLAB']) {
      mods[key] = ModuleConfig.fromJson(
        modulesRaw[key] is Map ? Map<String, dynamic>.from(modulesRaw[key] as Map) : null,
      );
    }

    return MaintenancePolicy(
      global: ModuleConfig.fromJson(
        json['global'] is Map ? Map<String, dynamic>.from(json['global'] as Map) : null,
      ),
      modules: mods,
      estimatedEndTime: json['estimatedEndTime']?.toString(),
      updatedAt: json['updatedAt']?.toString(),
      updatedBy: json['updatedBy']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'global': global.toJson(),
    'modules': modules.map((k, v) => MapEntry(k, v.toJson())),
    'estimatedEndTime': estimatedEndTime,
  };

  MaintenancePolicy copyWith({
    ModuleConfig? global,
    Map<String, ModuleConfig>? modules,
    String? estimatedEndTime,
  }) {
    return MaintenancePolicy(
      global: global ?? this.global,
      modules: modules ?? this.modules,
      estimatedEndTime: estimatedEndTime ?? this.estimatedEndTime,
      updatedAt: updatedAt,
      updatedBy: updatedBy,
    );
  }
}
