import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/order_model.dart';
import '../../services/order_service.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../auth/login_screen.dart';
import 'customer_create_order_screen.dart';
import 'rating_screen.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  final OrderService _orderService = OrderService();
  late final Stream<List<OrderModel>> _unratedStream;

  @override
  void initState() {
    super.initState();
    final customerId = context.read<AuthViewModel>().currentUser?.uid ?? '';
    _unratedStream = _orderService.watchCompletedUnratedOrders(customerId);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final user = auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text(user?.name.isNotEmpty == true ? user!.name : 'Customer'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await context.read<AuthViewModel>().signOut();
              if (!context.mounted) return;
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 8),
          const Center(
            child: Icon(Icons.local_shipping, size: 72, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add_box),
              label: const Text('Buat Order Baru'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const CustomerCreateOrderScreen(),
                ),
              ),
            ),
          ),
          _buildRatingSection(),
        ],
      ),
    );
  }

  Widget _buildRatingSection() {
    return StreamBuilder<List<OrderModel>>(
      stream: _unratedStream,
      builder: (context, snapshot) {
        final orders = snapshot.data ?? [];
        if (orders.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 28),
            const Text(
              'Perlu Dirating',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...orders.map(_buildRatingCard),
          ],
        );
      },
    );
  }

  Widget _buildRatingCard(OrderModel order) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              order.itemDescription.isNotEmpty
                  ? order.itemDescription
                  : 'Paket',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              order.destinationAddress,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 42,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                  foregroundColor: Theme.of(context).colorScheme.onSecondary,
                ),
                icon: const Icon(Icons.star, size: 18),
                label: const Text('Beri Rating'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => RatingScreen(order: order),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
