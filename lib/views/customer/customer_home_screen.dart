import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/order_model.dart';
import '../../services/order_service.dart';
import '../../utils/app_assets.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../widgets/edit_name_dialog.dart';
import '../auth/login_screen.dart';
import 'customer_create_order_screen.dart';
import 'customer_order_detail_screen.dart';
import 'customer_order_history_screen.dart';
import 'rating_screen.dart';
import '../chat/chat_screen.dart';

class CustomerHomeScreen extends StatefulWidget {
  final int initialIndex;

  const CustomerHomeScreen({super.key, this.initialIndex = 0});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  final OrderService _orderService = OrderService();

  late final Stream<List<OrderModel>> _customerOrdersStream;
  late final Stream<List<OrderModel>> _unratedStream;

  late int _selectedIndex;

  static const Color _primaryBlue = Color(0xFF133D87);
  static const Color _titleBlue = Color(0xFF608BC0);
  static const Color _textDark = Color(0xFF1B1B1B);
  static const Color _textGrey = Color(0xFF687386);
  static const Color _borderBlue = Color(0xFFC9D9ED);
  static const Color _pageBackground = Color(0xFFF8FAFD);

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;

    final String customerId =
        context.read<AuthViewModel>().currentUser?.uid ?? '';

    _customerOrdersStream = _orderService.watchCustomerOrders(customerId);

    _unratedStream = _orderService.watchCompletedUnratedOrders(customerId);
  }

  Future<void> _logout() async {
    await context.read<AuthViewModel>().signOut();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _openCreateOrder() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CustomerCreateOrderScreen()),
    );
  }

  void _goToOrdersTab() {
    setState(() {
      _selectedIndex = 1;
    });
  }

  void _openOrderDetail(OrderModel order) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CustomerOrderDetailScreen(orderId: order.orderId),
      ),
    );
  }

  void _openRating(OrderModel order) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => RatingScreen(order: order)));
  }

  Future<void> _showEditNameDialog(String currentName) async {
    final String? newName = await showDialog<String>(
      context: context,
      builder: (_) => EditNameDialog(initialName: currentName),
    );

    if (!mounted) return;
    if (newName == null || newName.isEmpty || newName == currentName) return;

    final auth = context.read<AuthViewModel>();
    final bool ok = await auth.updateUserName(newName);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Nama berhasil diperbarui'
              : (auth.errorMessage ?? 'Gagal memperbarui nama'),
          style: GoogleFonts.inter(),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AuthViewModel auth = context.watch<AuthViewModel>();

    final user = auth.currentUser;

    final String customerName = user?.name.trim().isNotEmpty == true
        ? user!.name.trim()
        : 'Customer';

    return Scaffold(
      backgroundColor: _pageBackground,
      extendBody: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            AppAssets.loginBackground,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) {
              return const ColoredBox(color: _pageBackground);
            },
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                const SizedBox(height: 18),
                SvgPicture.asset(AppAssets.logo, width: 215),
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
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(28),
                      ),
                      child: IndexedStack(
                        index: _selectedIndex,
                        children: [
                          _buildHomePage(customerName),
                          const CustomerOrderHistoryScreen(
                            embedded: true,
                            showHeader: true,
                          ),
                          _buildChatPage(user?.uid ?? ''),
                          _buildProfilePage(auth),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  Widget _buildHomePage(String customerName) {
    return StreamBuilder<List<OrderModel>>(
      stream: _customerOrdersStream,
      builder: (context, orderSnapshot) {
        if (orderSnapshot.hasError) {
          return Center(
            child: Text(
              'Gagal memuat order.',
              style: GoogleFonts.inter(
                color: const Color(0xFFD14343),
                fontSize: 14,
              ),
            ),
          );
        }

        final List<OrderModel> allOrders = orderSnapshot.data ?? [];

        final OrderModel? latestOrder = allOrders.isNotEmpty
            ? allOrders.first
            : null;

        return ListView(
          padding: const EdgeInsets.fromLTRB(24, 30, 24, 115),
          children: [
            Text(
              'Hi, $customerName!',
              style: GoogleFonts.getFont(
                'ADLaM Display',
                color: _titleBlue,
                fontSize: 24,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              'Mau kirim barang ke mana hari ini?',
              style: GoogleFonts.inter(
                color: _textGrey,
                fontSize: 15,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 28),
            _buildMainActionCard(),
            const SizedBox(height: 28),
            _buildSectionHeader(
              title: 'Order Terbaru',
              actionText: 'See All',
              onActionTap: _goToOrdersTab,
            ),
            const SizedBox(height: 12),

            if (orderSnapshot.connectionState == ConnectionState.waiting &&
                !orderSnapshot.hasData)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(color: _primaryBlue),
                ),
              )
            else if (latestOrder == null)
              _buildEmptyOrderCard()
            else
              _buildLatestOrderCard(latestOrder),

            StreamBuilder<List<OrderModel>>(
              stream: _unratedStream,
              builder: (context, unratedSnapshot) {
                final List<OrderModel> unratedOrders =
                    unratedSnapshot.data ?? [];

                if (unratedOrders.isEmpty) {
                  return const SizedBox.shrink();
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 26),
                    Text(
                      'Perlu Dirating',
                      style: GoogleFonts.inter(
                        color: _textDark,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...unratedOrders.map(_buildRatingCard),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildMainActionCard() {
    return Container(
      height: 88,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderBlue),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 9,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _ActionMenu(
              icon: Icons.add_box_outlined,
              title: 'Kirim Paket',
              subtitle: 'Buat pengiriman',
              onTap: _openCreateOrder,
            ),
          ),
          Container(width: 1, height: 58, color: const Color(0xFFD8E2EE)),
          Expanded(
            child: _ActionMenu(
              icon: Icons.receipt_long_outlined,
              title: 'Riwayat Order',
              subtitle: 'Lihat pesanan',
              onTap: _goToOrdersTab,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String actionText,
    required VoidCallback onActionTap,
  }) {
    return Row(
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            color: _textDark,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: onActionTap,
          child: Text(
            actionText,
            style: GoogleFonts.inter(
              color: const Color(0xFF0066FF),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  String _statusLabel(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'Waiting';

      case OrderStatus.accepted:
        return 'Accepted';

      case OrderStatus.pickingUp:
        return 'Picking Up';

      case OrderStatus.delivering:
        return 'On Delivery';

      case OrderStatus.completed:
        return 'Completed';

      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  Color _statusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return const Color(0xFFE08B00);

      case OrderStatus.accepted:
      case OrderStatus.pickingUp:
      case OrderStatus.delivering:
        return const Color(0xFF0066FF);

      case OrderStatus.completed:
        return const Color(0xFF0AA85A);

      case OrderStatus.cancelled:
        return const Color(0xFFD14343);
    }
  }

  Color _statusBackground(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return const Color(0xFFFFF3D8);

      case OrderStatus.accepted:
      case OrderStatus.pickingUp:
      case OrderStatus.delivering:
        return const Color(0xFFE7F0FF);

      case OrderStatus.completed:
        return const Color(0xFFE2F9EB);

      case OrderStatus.cancelled:
        return const Color(0xFFFFE8E8);
    }
  }

  Widget _buildLatestOrderCard(OrderModel order) {
    final String itemName = order.itemDescription.trim().isNotEmpty
        ? order.itemDescription.trim()
        : 'Paket';

    final String destination = order.destinationAddress.trim().isNotEmpty
        ? order.destinationAddress.trim()
        : 'Alamat tujuan tidak tersedia';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openOrderDetail(order),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _borderBlue),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 7,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: _titleBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.inventory_2_outlined,
                  color: _primaryBlue,
                  size: 23,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      itemName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: _textDark,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      destination,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(color: _textGrey, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _statusBackground(order.status),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  _statusLabel(order.status),
                  style: GoogleFonts.inter(
                    color: _statusColor(order.status),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRatingCard(OrderModel order) {
    final String itemName = order.itemDescription.trim().isNotEmpty
        ? order.itemDescription.trim()
        : 'Paket';

    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDCE5F1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.inventory_2_outlined, color: _primaryBlue, size: 25),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  itemName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: _textDark,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  order.destinationAddress,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(color: _textGrey, fontSize: 12),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 36,
            child: ElevatedButton.icon(
              onPressed: () => _openRating(order),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              icon: const Icon(Icons.star_rounded, size: 17),
              label: Text(
                'Rating',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyOrderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDCE5F1)),
      ),
      child: Column(
        children: [
          const Icon(Icons.inventory_2_outlined, color: _titleBlue, size: 36),
          const SizedBox(height: 9),
          Text(
            'Belum ada order terbaru',
            style: GoogleFonts.inter(
              color: _textDark,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Mulai kirim paket pertamamu sekarang.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: _textGrey, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildChatPage(String customerId) {
    return StreamBuilder<List<OrderModel>>(
      stream: _customerOrdersStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Gagal memuat percakapan.',
              style: GoogleFonts.inter(
                color: const Color(0xFFD14343),
                fontSize: 14,
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: _primaryBlue),
          );
        }

        final List<OrderModel> orders = snapshot.data ?? [];

        final List<OrderModel> chatOrders = orders.where((order) {
          final bool hasDriver =
              order.driverId != null && order.driverId!.trim().isNotEmpty;

          final bool chatAvailable =
              order.status == OrderStatus.accepted ||
              order.status == OrderStatus.pickingUp ||
              order.status == OrderStatus.delivering ||
              order.status == OrderStatus.completed;

          return hasDriver && chatAvailable;
        }).toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(24, 30, 24, 115),
          children: [
            Text(
              'Chat',
              style: GoogleFonts.getFont(
                'ADLaM Display',
                color: _titleBlue,
                fontSize: 24,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Hubungi driver terkait proses pengiriman.',
              style: GoogleFonts.inter(color: _textGrey, fontSize: 14),
            ),
            const SizedBox(height: 26),

            if (chatOrders.isEmpty)
              _buildPlaceholderCard(
                icon: Icons.forum_outlined,
                title: 'Belum ada percakapan',
                description:
                    'Chat dengan driver akan muncul setelah order diterima.',
              )
            else
              ...chatOrders.map(
                (order) =>
                    _buildChatOrderCard(order: order, customerId: customerId),
              ),
          ],
        );
      },
    );
  }

  Widget _buildChatOrderCard({
    required OrderModel order,
    required String customerId,
  }) {
    final String driverId = order.driverId ?? '';

    return FutureBuilder<Map<String, dynamic>?>(
      future: _orderService.fetchDriverProfile(driverId),
      builder: (context, snapshot) {
        final Map<String, dynamic>? driverData = snapshot.data;

        final String driverName = driverData?['name'] as String? ?? 'Driver';

        final String photoUrl = driverData?['photo_url'] as String? ?? '';

        final String itemName = order.itemDescription.trim().isNotEmpty
            ? order.itemDescription.trim()
            : 'Paket';

        return Container(
          margin: const EdgeInsets.only(bottom: 13),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: _borderBlue),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.07),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(15),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      orderId: order.orderId,
                      currentUserId: customerId,
                      customerId: customerId,
                      driverId: driverId,
                    ),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 53,
                      height: 53,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: _titleBlue.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: photoUrl.trim().isEmpty
                          ? const Icon(
                              Icons.person_rounded,
                              color: _primaryBlue,
                              size: 31,
                            )
                          : Image.network(
                              photoUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) {
                                return const Icon(
                                  Icons.person_rounded,
                                  color: _primaryBlue,
                                  size: 31,
                                );
                              },
                            ),
                    ),
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
                          Text(
                            itemName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: _textGrey,
                              fontSize: 12.5,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            _statusLabel(order.status),
                            style: GoogleFonts.inter(
                              color: _statusColor(order.status),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 41,
                      height: 41,
                      decoration: BoxDecoration(
                        color: _primaryBlue.withValues(alpha: 0.10),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.chat_bubble_outline_rounded,
                        color: _primaryBlue,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfilePage(AuthViewModel auth) {
    final user = auth.currentUser;

    final String name = user?.name.trim().isNotEmpty == true
        ? user!.name.trim()
        : 'Customer';

    final String email = user?.email.trim().isNotEmpty == true
        ? user!.email.trim()
        : 'Email tidak tersedia';

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 115),
      children: [
        Text(
          'Profile',
          style: GoogleFonts.getFont(
            'ADLaM Display',
            color: _titleBlue,
            fontSize: 24,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Kelola informasi akun DeltaSend.',
          style: GoogleFonts.inter(color: _textGrey, fontSize: 14),
        ),
        const SizedBox(height: 30),
        Stack(
          children: [
            Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _borderBlue),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  color: _titleBlue.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: _primaryBlue,
                  size: 44,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                name,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: _textDark,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                email,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: _textGrey, fontSize: 13),
              ),
              const SizedBox(height: 24),
              _ProfileInformationRow(
                icon: Icons.person_outline_rounded,
                label: 'Role',
                value: 'Customer',
              ),
              const Divider(height: 28, color: Color(0xFFE4E9F0)),
              _ProfileInformationRow(
                icon: Icons.email_outlined,
                label: 'Email',
                value: email,
              ),
            ],
          ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                icon: const Icon(
                  Icons.edit_outlined,
                  size: 20,
                  color: _titleBlue,
                ),
                tooltip: 'Edit nama',
                onPressed: () => _showEditNameDialog(name),
              ),
            ),
          ],
        ),
        const SizedBox(height: 100),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton.icon(
            onPressed: auth.isLoading ? null : _logout,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFD14343),
              side: const BorderSide(color: Color(0xFFD14343)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            icon: const Icon(Icons.logout_rounded, size: 21),
            label: Text(
              'SIGN OUT',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholderCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 34),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDCE5F1)),
      ),
      child: Column(
        children: [
          Icon(icon, color: _titleBlue, size: 42),
          const SizedBox(height: 13),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: _textDark,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            description,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: _textGrey,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      decoration: const BoxDecoration(
        color: _primaryBlue,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: Row(
            children: [
              _BottomNavigationItem(
                icon: Icons.home_rounded,
                label: 'Home',
                selected: _selectedIndex == 0,
                onTap: () {
                  setState(() {
                    _selectedIndex = 0;
                  });
                },
              ),
              _BottomNavigationItem(
                icon: Icons.receipt_long_outlined,
                label: 'Orders',
                selected: _selectedIndex == 1,
                onTap: _goToOrdersTab,
              ),
              _BottomNavigationItem(
                icon: Icons.forum_outlined,
                label: 'Chat',
                selected: _selectedIndex == 2,
                onTap: () {
                  setState(() {
                    _selectedIndex = 2;
                  });
                },
              ),
              _BottomNavigationItem(
                icon: Icons.person_outline_rounded,
                label: 'Profile',
                selected: _selectedIndex == 3,
                onTap: () {
                  setState(() {
                    _selectedIndex = 3;
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionMenu extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionMenu({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFF133D87), size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF1B1B1B),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF687386),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileInformationRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ProfileInformationRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF608BC0), size: 23),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  color: const Color(0xFF687386),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: GoogleFonts.inter(
                  color: const Color(0xFF1B1B1B),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BottomNavigationItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _BottomNavigationItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color itemColor = selected ? Colors.white : const Color(0xFFAFC4E8);

    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: itemColor, size: 27),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.inter(
                color: itemColor,
                fontSize: 10.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
