class AppVersionPolicy {
  const AppVersionPolicy({
    required this.minVersion,
    required this.maxVersion,
    required this.updateUrlWeb,
    required this.updateUrlAndroid,
    required this.updateUrlIos,
  });

  final String minVersion;
  final String maxVersion;
  final String updateUrlWeb;
  final String updateUrlAndroid;
  final String updateUrlIos;

  factory AppVersionPolicy.fromJson(Map<String, dynamic> json) {
    return AppVersionPolicy(
      minVersion: json['minVersion']?.toString() ?? '',
      maxVersion: json['maxVersion']?.toString() ?? '',
      updateUrlWeb: json['updateUrlWeb']?.toString() ?? '',
      updateUrlAndroid: json['updateUrlAndroid']?.toString() ?? '',
      updateUrlIos: json['updateUrlIos']?.toString() ?? '',
    );
  }
}
