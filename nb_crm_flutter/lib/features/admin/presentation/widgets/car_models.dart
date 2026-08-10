/// Shared 3D car asset paths for live tracking + trip replay.
class CarModels {
  CarModels._();

  static const List<String> assets = [
    'assets/3d/car.glb',
    'assets/3d/cyberpunk_car.glb',
    'assets/3d/dominus_-_rocket_league_car.glb',
  ];

  /// Stable pseudo-random pick from a trip id (same car for the whole trip).
  static String forTrip(String? tripId, {int? fallbackSeed}) {
    final seed = tripId?.hashCode ?? fallbackSeed ?? 0;
    final idx = seed.abs() % assets.length;
    return assets[idx];
  }
}
