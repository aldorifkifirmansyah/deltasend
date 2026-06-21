import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/order_model.dart';
import '../../services/order_service.dart';
import '../../utils/app_assets.dart';

class RatingScreen extends StatefulWidget {
  final OrderModel order;

  const RatingScreen({super.key, required this.order});

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  final OrderService _orderService = OrderService();

  final TextEditingController _noteController = TextEditingController();

  int _rating = 0;
  bool _isSubmitting = false;

  String? _cachedDriverId;
  Future<Map<String, dynamic>?>? _driverProfileFuture;

  static const Color _primaryBlue = Color(0xFF133D87);
  static const Color _titleBlue = Color(0xFF608BC0);
  static const Color _textDark = Color(0xFF1A1D23);
  static const Color _textGrey = Color(0xFF6F7784);
  static const Color _borderBlue = Color(0xFFC5D8EE);
  static const Color _successGreen = Color(0xFF0AAA55);
  static const Color _starYellow = Color(0xFFFFB800);

  @override
  void initState() {
    super.initState();

    _rating = widget.order.rating ?? 0;
    _noteController.text = widget.order.ratingNote;
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>?>? _getDriverProfile() {
    final String? driverId = widget.order.driverId;

    if (driverId == null || driverId.trim().isEmpty) {
      return null;
    }

    if (_cachedDriverId != driverId || _driverProfileFuture == null) {
      _cachedDriverId = driverId;

      _driverProfileFuture = _orderService.fetchDriverProfile(driverId);
    }

    return _driverProfileFuture;
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter()),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatOrderId(String orderId) {
    final String cleanId = orderId
        .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
        .toUpperCase();

    final String shortenedId = cleanId.length > 8
        ? cleanId.substring(0, 8)
        : cleanId;

    return '#ORD-$shortenedId';
  }

  String _ratingDescription() {
    switch (_rating) {
      case 1:
        return 'Sangat Buruk';

      case 2:
        return 'Buruk';

      case 3:
        return 'Cukup';

      case 4:
        return 'Bagus';

      case 5:
        return 'Sangat Bagus';

      default:
        return 'Pilih rating';
    }
  }

  Future<void> _submit() async {
    if (_rating == 0 || _isSubmitting) {
      return;
    }

    final String? driverId = widget.order.driverId;

    if (driverId == null || driverId.trim().isEmpty) {
      _showSnack('Driver tidak ditemukan untuk order ini.');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await _orderService.submitRating(
        orderId: widget.order.orderId,
        driverId: driverId,
        rating: _rating,
        ratingNote: _noteController.text.trim(),
      );

      if (!mounted) return;

      await _showSuccessDialog();

      if (!mounted) return;

      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error) {
      if (!mounted) return;

      _showSnack('Gagal mengirim rating: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _showSuccessDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: _successGreen.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: _successGreen,
                  size: 48,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Rating Berhasil Dikirim',
                textAlign: TextAlign.center,
                style: GoogleFonts.getFont(
                  'ADLaM Display',
                  color: _titleBlue,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Terima kasih atas penilaian yang Anda berikan.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: _textGrey,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Kembali ke Home',
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Uint8List? _decodeBase64Image(String value) {
    try {
      String cleanedValue = value.trim();

      if (cleanedValue.contains(',')) {
        cleanedValue = cleanedValue.split(',').last;
      }

      return base64Decode(cleanedValue);
    } catch (_) {
      return null;
    }
  }

  bool _isNetworkImage(String value) {
    final String normalizedValue = value.trim().toLowerCase();

    return normalizedValue.startsWith('http://') ||
        normalizedValue.startsWith('https://');
  }

  @override
  Widget build(BuildContext context) {
    final OrderModel order = widget.order;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            AppAssets.loginBackground,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) {
              return const ColoredBox(color: Color(0xFFF7F9FC));
            },
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                const SizedBox(height: 16),
                SvgPicture.asset(AppAssets.logo, width: 214),
                const SizedBox(height: 26),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(28),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 18,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 36),
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 20),
                        _buildCompletedBanner(),
                        const SizedBox(height: 20),
                        _buildOrderInformation(order),
                        const SizedBox(height: 20),
                        _buildProofPhoto(order),
                        const SizedBox(height: 20),
                        _buildDriverInformation(),
                        const SizedBox(height: 24),
                        _buildRatingSection(),
                        const SizedBox(height: 22),
                        _buildNoteField(),
                        const SizedBox(height: 26),
                        _buildSubmitButton(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        IconButton(
          onPressed: () {
            Navigator.of(context).maybePop();
          },
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: _textDark,
            size: 23,
          ),
        ),
        Expanded(
          child: Text(
            'Order Selesai',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: _textDark,
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 48),
      ],
    );
  }

  Widget _buildCompletedBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
      decoration: BoxDecoration(
        color: _primaryBlue,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _primaryBlue.withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.inventory_2_rounded,
              color: Colors.white,
              size: 37,
            ),
          ),
          const SizedBox(height: 13),
          Text(
            'Paket Telah Diterima',
            textAlign: TextAlign.center,
            style: GoogleFonts.getFont(
              'ADLaM Display',
              color: Colors.white,
              fontSize: 21,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Pengiriman telah selesai dengan baik.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderInformation(OrderModel order) {
    final String itemDescription = order.itemDescription.trim().isNotEmpty
        ? order.itemDescription.trim()
        : 'Paket';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDCE5F1)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Detail Pengiriman',
                style: GoogleFonts.inter(
                  color: _textDark,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                _formatOrderId(order.orderId),
                style: GoogleFonts.inter(
                  color: _titleBlue,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const Divider(height: 26, color: Color(0xFFE2E7ED)),
          _InformationRow(label: 'Barang', value: itemDescription),
          const SizedBox(height: 11),
          _InformationRow(label: 'Tujuan', value: order.destinationAddress),
          const SizedBox(height: 11),
          _InformationRow(
            label: 'Status',
            value: 'Completed',
            valueColor: _successGreen,
          ),
        ],
      ),
    );
  }

  Widget _buildProofPhoto(OrderModel order) {
    final String proofPhoto = order.proofPhotoUrl.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bukti Pengantaran',
          style: GoogleFonts.inter(
            color: _textDark,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 11),
        Container(
          width: double.infinity,
          height: 200,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: const Color(0xFFF2F5F9),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _borderBlue),
          ),
          child: proofPhoto.isEmpty
              ? _buildEmptyProofPhoto()
              : _buildProofImage(proofPhoto),
        ),
      ],
    );
  }

  Widget _buildProofImage(String value) {
    if (_isNetworkImage(value)) {
      return Image.network(
        value,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) {
            return child;
          }

          return const Center(
            child: CircularProgressIndicator(color: _primaryBlue),
          );
        },
        errorBuilder: (_, __, ___) {
          return _buildInvalidProofPhoto();
        },
      );
    }

    final Uint8List? imageBytes = _decodeBase64Image(value);

    if (imageBytes == null) {
      return _buildInvalidProofPhoto();
    }

    return Image.memory(
      imageBytes,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) {
        return _buildInvalidProofPhoto();
      },
    );
  }

  Widget _buildEmptyProofPhoto() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.image_not_supported_outlined,
          color: _titleBlue,
          size: 42,
        ),
        const SizedBox(height: 10),
        Text(
          'Driver tidak menyertakan foto bukti.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(color: _textGrey, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildInvalidProofPhoto() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.broken_image_outlined,
          color: Color(0xFFD14343),
          size: 42,
        ),
        const SizedBox(height: 10),
        Text(
          'Foto bukti tidak dapat ditampilkan.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(color: _textGrey, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildDriverInformation() {
    final Future<Map<String, dynamic>?>? profileFuture = _getDriverProfile();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Driver',
          style: GoogleFonts.inter(
            color: _textDark,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 11),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _borderBlue),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.07),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: profileFuture == null
              ? _buildDriverRow(
                  driverName: 'Driver',
                  photoUrl: '',
                  rating: 0,
                  ratingCount: 0,
                )
              : FutureBuilder<Map<String, dynamic>?>(
                  future: profileFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData) {
                      return const SizedBox(
                        height: 58,
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _primaryBlue,
                          ),
                        ),
                      );
                    }

                    final Map<String, dynamic>? data = snapshot.data;

                    final String driverName =
                        data?['name'] as String? ?? 'Driver';

                    final String photoUrl = data?['photo_url'] as String? ?? '';

                    final double rating =
                        (data?['rating_avg'] as num?)?.toDouble() ?? 0;

                    final int ratingCount =
                        (data?['rating_count'] as num?)?.toInt() ?? 0;

                    return _buildDriverRow(
                      driverName: driverName,
                      photoUrl: photoUrl,
                      rating: rating,
                      ratingCount: ratingCount,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildDriverRow({
    required String driverName,
    required String photoUrl,
    required double rating,
    required int ratingCount,
  }) {
    return Row(
      children: [
        _DriverAvatar(imageUrl: photoUrl),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                driverName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: _textDark,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  const Icon(Icons.star_rounded, color: _starYellow, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    rating > 0 ? rating.toStringAsFixed(1) : 'Belum ada rating',
                    style: GoogleFonts.inter(
                      color: _textDark,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (ratingCount > 0) ...[
                    const SizedBox(width: 4),
                    Text(
                      '($ratingCount)',
                      style: GoogleFonts.inter(
                        color: _textGrey,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _successGreen.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            'Selesai',
            style: GoogleFonts.inter(
              color: _successGreen,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRatingSection() {
    return Column(
      children: [
        Text(
          'Bagaimana pengalaman pengirimanmu?',
          textAlign: TextAlign.center,
          style: GoogleFonts.getFont(
            'ADLaM Display',
            color: _titleBlue,
            fontSize: 19,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Berikan penilaian untuk pelayanan driver.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(color: _textGrey, fontSize: 13),
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            final int starValue = index + 1;

            final bool selected = starValue <= _rating;

            return GestureDetector(
              onTap: _isSubmitting
                  ? null
                  : () {
                      setState(() {
                        _rating = starValue;
                      });
                    },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 160),
                  scale: selected ? 1.08 : 1,
                  child: Icon(
                    selected ? Icons.star_rounded : Icons.star_border_rounded,
                    color: selected ? _starYellow : const Color(0xFFB8C0CB),
                    size: 44,
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 10),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: Text(
            _ratingDescription(),
            key: ValueKey<int>(_rating),
            style: GoogleFonts.inter(
              color: _rating == 0 ? _textGrey : _primaryBlue,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoteField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Catatan',
          style: GoogleFonts.inter(
            color: _textDark,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'Opsional',
          style: GoogleFonts.inter(color: _textGrey, fontSize: 12),
        ),
        const SizedBox(height: 9),
        TextField(
          controller: _noteController,
          minLines: 3,
          maxLines: 5,
          maxLength: 250,
          enabled: !_isSubmitting,
          style: GoogleFonts.inter(color: _textDark, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Tuliskan pengalaman atau masukan untuk driver...',
            hintStyle: GoogleFonts.inter(
              color: const Color(0xFFA0A9B6),
              fontSize: 13,
            ),
            filled: true,
            fillColor: const Color(0xFFF8FAFD),
            contentPadding: const EdgeInsets.all(14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: const BorderSide(color: _borderBlue),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: const BorderSide(color: _borderBlue),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: const BorderSide(color: _primaryBlue, width: 1.4),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 51,
      child: ElevatedButton.icon(
        onPressed: _rating == 0 || _isSubmitting ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryBlue,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _primaryBlue.withValues(alpha: 0.40),
          elevation: 3,
          shadowColor: Colors.black.withValues(alpha: 0.18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(11),
          ),
        ),
        icon: _isSubmitting
            ? const SizedBox.shrink()
            : const Icon(Icons.send_rounded, size: 19),
        label: _isSubmitting
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.4,
                ),
              )
            : Text(
                'Kirim Rating',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}

class _InformationRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InformationRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 74,
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: const Color(0xFF6F7784),
              fontSize: 12.5,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: GoogleFonts.inter(
              color: valueColor ?? const Color(0xFF1A1D23),
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _DriverAvatar extends StatelessWidget {
  final String imageUrl;

  const _DriverAvatar({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF608BC0).withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      child: imageUrl.trim().isEmpty
          ? const Icon(Icons.person_rounded, color: Color(0xFF133D87), size: 32)
          : Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) {
                return const Icon(
                  Icons.person_rounded,
                  color: Color(0xFF133D87),
                  size: 32,
                );
              },
            ),
    );
  }
}
