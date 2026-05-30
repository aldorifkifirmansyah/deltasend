import 'package:flutter/material.dart';
import '../models/order_model.dart';
import '../services/order_service.dart';
import 'map_driver_screen.dart';

// farell: dummy driver id sementara, nanti diganti dari auth setelah login dibuat
const String kDummyDriverId = 'driver_test_001';

class DriverOrderListScreen extends StatefulWidget {
  const DriverOrderListScreen({super.key});

  @override
  State<DriverOrderListScreen> createState() => _DriverOrderListScreenState();
}

class _DriverOrderListScreenState extends State<DriverOrderListScreen> {
  final OrderService _orderService = OrderService();

  // orderId yang sedang diproses, biar tombolnya bisa di-disable & loading
  String? _processingOrderId;

  void _openMap(String orderId) {
    // push (bukan pushReplacement) supaya back dari peta kembali ke daftar ini,
    // sehingga driver tetap bisa melihat & melanjutkan order aktifnya.
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MapDriverScreen(orderId: orderId),
      ),
    );
  }

  Future<void> _ambilOrder(OrderModel order) async {
    if (_processingOrderId != null) return;

    setState(() => _processingOrderId = order.orderId);

    try {
      await _orderService.acceptOrder(
        orderId: order.orderId,
        driverId: kDummyDriverId,
      );

      if (!mounted) return;
      _openMap(order.orderId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengambil order: $e')),
      );
    } finally {
      if (mounted) setState(() => _processingOrderId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Driver'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      // StreamBuilder order aktif membungkus body supaya bagian "Order Tersedia"
      // tahu apakah driver sudah punya order aktif (untuk disable tombol ambil).
      body: StreamBuilder<List<OrderModel>>(
        stream: _orderService.watchActiveOrdersForDriver(kDummyDriverId),
        builder: (context, activeSnapshot) {
          final activeOrders = activeSnapshot.data ?? [];
          final hasActive = activeOrders.isNotEmpty;

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _buildSectionTitle('Order Aktif Saya'),
              if (activeOrders.length > 1)
                _buildInfoText(
                  'Terdeteksi ${activeOrders.length} order aktif (data testing lama). '
                  'Selesaikan order-order ini; ke depan driver hanya boleh 1 order aktif.',
                ),
              _buildActiveContent(activeSnapshot),
              const SizedBox(height: 20),
              _buildSectionTitle('Order Tersedia'),
              _buildPendingOrdersSection(hasActive: hasActive),
            ],
          );
        },
      ),
    );
  }

  // ===== Bagian 1: Order aktif milik driver =====
  Widget _buildActiveContent(AsyncSnapshot<List<OrderModel>> snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (snapshot.hasError) {
      return _buildInfoText('Gagal memuat order aktif: ${snapshot.error}');
    }

    final orders = snapshot.data ?? [];
    if (orders.isEmpty) {
      return _buildInfoText('Tidak ada order aktif');
    }

    return Column(
      children: orders
          .map(
            (order) => _buildOrderCard(
              order: order,
              showStatus: true,
              buttonText: 'Lanjutkan Pengiriman',
              isProcessing: false,
              onPressed: () => _openMap(order.orderId),
            ),
          )
          .toList(),
    );
  }

  // ===== Bagian 2: Order pending yang bisa diambil =====
  Widget _buildPendingOrdersSection({required bool hasActive}) {
    return StreamBuilder<List<OrderModel>>(
      stream: _orderService.watchPendingOrders(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return _buildInfoText('Terjadi kesalahan: ${snapshot.error}');
        }

        final orders = snapshot.data ?? [];
        if (orders.isEmpty) {
          return _buildInfoText('Belum ada order pending');
        }

        // tombol ambil di-disable jika: driver sudah punya order aktif,
        // atau salah satu order sedang diproses.
        final isLocked = hasActive || _processingOrderId != null;

        return Column(
          children: orders
              .map(
                (order) => _buildOrderCard(
                  order: order,
                  showStatus: false,
                  buttonText: hasActive
                      ? 'Selesaikan order aktif dulu'
                      : 'Ambil Order',
                  isProcessing: _processingOrderId == order.orderId,
                  onPressed:
                      isLocked ? null : () => _ambilOrder(order),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 2),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildInfoText(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.grey),
        ),
      ),
    );
  }

  Widget _buildOrderCard({
    required OrderModel order,
    required bool showStatus,
    required String buttonText,
    required bool isProcessing,
    required VoidCallback? onPressed,
  }) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    order.itemDescription.isNotEmpty
                        ? order.itemDescription
                        : 'Paket',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (showStatus) _buildStatusChip(order.status),
              ],
            ),
            const SizedBox(height: 12),
            _buildLocationRow(
              Icons.my_location,
              Colors.green,
              'Jemput',
              order.pickupAddress,
            ),
            const SizedBox(height: 8),
            _buildLocationRow(
              Icons.flag,
              Colors.red,
              'Tujuan',
              order.destinationAddress,
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  order.distanceKm > 0
                      ? '${order.distanceKm.toStringAsFixed(1)} km'
                      : 'Jarak -',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
                Text(
                  order.totalCost > 0
                      ? 'Rp ${order.totalCost.toStringAsFixed(0)}'
                      : 'Rp -',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                  foregroundColor: Theme.of(context).colorScheme.onSecondary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: onPressed,
                child: isProcessing
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        buttonText,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(OrderStatus status) {
    final label = status == OrderStatus.pickingUp
        ? 'Menjemput'
        : status == OrderStatus.delivering
            ? 'Mengantar'
            : status.name;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildLocationRow(
    IconData icon,
    Color color,
    String label,
    String value,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              Text(value, style: const TextStyle(fontSize: 14)),
            ],
          ),
        ),
      ],
    );
  }
}
