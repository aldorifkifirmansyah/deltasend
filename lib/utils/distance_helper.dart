import 'dart:math';

/// Radius maksimum order yang ditampilkan ke driver (km).
const double kMaxOrderRadiusKm = 10.0;

/// Hitung jarak antara dua titik koordinat memakai formula Haversine.
///
/// Implementasi manual (bukan Geolocator.distanceBetween yang ellipsoidal)
/// supaya rumusnya bisa didokumentasikan persis sesuai proposal.
/// Mengembalikan jarak dalam kilometer.
double calculateHaversineDistance(
  double lat1,
  double lon1,
  double lat2,
  double lon2,
) {
  const double earthRadiusKm = 6371.0;

  final double dLat = _degreesToRadians(lat2 - lat1);
  final double dLon = _degreesToRadians(lon2 - lon1);

  final double a =
      sin(dLat / 2) * sin(dLat / 2) +
      cos(_degreesToRadians(lat1)) *
          cos(_degreesToRadians(lat2)) *
          sin(dLon / 2) *
          sin(dLon / 2);

  final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

  return earthRadiusKm * c;
}

double _degreesToRadians(double degrees) => degrees * pi / 180.0;
