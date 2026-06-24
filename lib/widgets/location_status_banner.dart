import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';

/// State masalah lokasi yang ditampilkan sebagai banner kuning persistent.
/// Pola visual & aksi mengikuti _buildLocationBanner() di driver_order_list_screen.
enum LocationBannerState { denied, deniedForever, serviceOff, error }

class LocationStatusBanner extends StatelessWidget {
  final LocationBannerState state;
  final VoidCallback onRetry;
  final EdgeInsetsGeometry margin;

  const LocationStatusBanner({
    super.key,
    required this.state,
    required this.onRetry,
    this.margin = const EdgeInsets.only(bottom: 12),
  });

  @override
  Widget build(BuildContext context) {
    final String message;
    final String actionLabel;
    final VoidCallback action;

    switch (state) {
      case LocationBannerState.deniedForever:
        message =
            'Izin lokasi diblokir permanen. Aktifkan lewat Settings lalu coba lagi.';
        actionLabel = 'Settings';
        action = Geolocator.openAppSettings;
        break;
      case LocationBannerState.serviceOff:
        message = 'GPS tidak aktif.';
        actionLabel = 'Aktifkan';
        action = Geolocator.openLocationSettings;
        break;
      case LocationBannerState.denied:
        message = 'Izin lokasi ditolak.';
        actionLabel = 'Coba Lagi';
        action = onRetry;
        break;
      case LocationBannerState.error:
        message = 'Lokasi tidak dapat diperoleh.';
        actionLabel = 'Coba Lagi';
        action = onRetry;
        break;
    }

    return Container(
      margin: margin,
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6E0),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: const Color(0xFFF0C95C)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Color(0xFFB8860B),
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                color: const Color(0xFF8A6D00),
                fontSize: 11.5,
              ),
            ),
          ),
          TextButton(
            onPressed: action,
            child: Text(
              actionLabel,
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
