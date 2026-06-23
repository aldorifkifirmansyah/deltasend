import 'package:cloud_firestore/cloud_firestore.dart';
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
import '../chat/chat_screen.dart';
import '../driver_order_list_screen.dart';
import 'driver_bottom_bar.dart';

class DriverHomeScreen extends StatefulWidget {
  final int initialIndex;

  const DriverHomeScreen({super.key, this.initialIndex = 0});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  final OrderService _orderService = OrderService();

  final Map<String, Future<Map<String, dynamic>?>> _customerProfileCache = {};

  late int _selectedIndex;

  static const Color _primaryBlue = Color(0xFF133D87);
  static const Color _titleBlue = Color(0xFF608BC0);
  static const Color _textDark = Color(0xFF1B1B1B);
  static const Color _textGrey = Color(0xFF687386);
  static const Color _borderBlue = Color(0xFFC9D9ED);
  static const Color _pageBackground = Color(0xFFF8FAFD);
  static const Color _successGreen = Color(0xFF0AAA55);

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  Future<void> _logout() async {
    await context.read<AuthViewModel>().signOut();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
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

  void _changeTab(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<Map<String, dynamic>?> _fetchCustomerProfile(String customerId) {
    if (customerId.trim().isEmpty) {
      return Future.value(null);
    }

    return _customerProfileCache.putIfAbsent(customerId, () async {
      try {
        final DocumentSnapshot<Map<String, dynamic>> document =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(customerId)
                .get();

        return document.data();
      } catch (_) {
        return null;
      }
    });
  }

  String _formatOrderId(String orderId) {
    final String cleanId = orderId
        .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
        .toUpperCase();

    final String shortId = cleanId.length > 8
        ? cleanId.substring(0, 8)
        : cleanId;

    return '#ORD-$shortId';
  }

  String _statusLabel(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'Pending';

      case OrderStatus.accepted:
        return 'Accepted';

      case OrderStatus.pickingUp:
        return 'Picking Up';

      case OrderStatus.delivering:
        return 'Delivering';

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
        return _successGreen;

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

  void _openChat({required OrderModel order, required String driverId}) {
    if (driverId.trim().isEmpty) {
      _showMessage('Data driver belum tersedia.');
      return;
    }

    if (order.customerId.trim().isEmpty) {
      _showMessage('Data customer belum tersedia.');
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          orderId: order.orderId,
          currentUserId: driverId,
          customerId: order.customerId,
          driverId: driverId,
        ),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter()),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AuthViewModel auth = context.watch<AuthViewModel>();

    final user = auth.currentUser;

    final String driverName = user?.name.trim().isNotEmpty == true
        ? user!.name.trim()
        : 'Driver';

    final String email = user?.email.trim().isNotEmpty == true
        ? user!.email.trim()
        : 'Email tidak tersedia';

    final String driverId = user?.uid ?? '';

    return Scaffold(
      backgroundColor: _pageBackground,
      extendBody: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            AppAssets.loginBackground,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) {
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
                          _buildHomePage(driverName),
                          _buildOrdersPage(),
                          _buildChatPage(driverId),
                          _buildProfilePage(
                            auth: auth,
                            name: driverName,
                            email: email,
                          ),
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
      bottomNavigationBar: DriverBottomBar(
        selectedIndex: _selectedIndex,
        onTap: _changeTab,
      ),
    );
  }

  Widget _buildHomePage(String driverName) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 115),
      children: [
        Text(
          'Hi, $driverName!',
          style: GoogleFonts.getFont(
            'ADLaM Display',
            color: _titleBlue,
            fontSize: 24,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          'Siap mengantar pesanan hari ini?',
          style: GoogleFonts.inter(color: _textGrey, fontSize: 15),
        ),
        const SizedBox(height: 24),
        _buildOnlineStatusCard(),
        const SizedBox(height: 25),
        Row(
          children: [
            Text(
              'Order Driver',
              style: GoogleFonts.inter(
                color: _textDark,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => _changeTab(1),
              child: Text(
                'See All',
                style: GoogleFonts.inter(
                  color: const Color(0xFF0066FF),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const DriverOrderListScreen(embedded: true, compact: true),
      ],
    );
  }

  Widget _buildOrdersPage() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 115),
      children: [
        Text(
          'Orders',
          style: GoogleFonts.getFont(
            'ADLaM Display',
            color: _titleBlue,
            fontSize: 24,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          'Kelola order aktif dan order yang tersedia.',
          style: GoogleFonts.inter(color: _textGrey, fontSize: 14),
        ),
        const SizedBox(height: 22),
        const DriverOrderListScreen(embedded: true, compact: false),
      ],
    );
  }

  Widget _buildOnlineStatusCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xFFE9F8EF),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFBCE8CE)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 47,
            height: 47,
            decoration: const BoxDecoration(
              color: _successGreen,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.delivery_dining_rounded,
              color: Colors.white,
              size: 27,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Driver Online',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF087F43),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Kamu dapat menerima order yang tersedia.',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF438363),
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 11,
            height: 11,
            decoration: const BoxDecoration(
              color: _successGreen,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatPage(String driverId) {
    if (driverId.trim().isEmpty) {
      return _buildCenteredError('Data akun driver tidak tersedia.');
    }

    return StreamBuilder<List<OrderModel>>(
      stream: _orderService.watchActiveOrdersForDriver(driverId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildCenteredError('Gagal memuat percakapan.');
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: _primaryBlue),
          );
        }

        final List<OrderModel> orders = snapshot.data ?? [];

        final List<OrderModel> chatOrders =
            orders.where((order) {
              final bool validCustomer = order.customerId.trim().isNotEmpty;

              final bool validDriver =
                  order.driverId != null && order.driverId!.trim().isNotEmpty;

              final bool chatAvailable =
                  order.status == OrderStatus.accepted ||
                  order.status == OrderStatus.pickingUp ||
                  order.status == OrderStatus.delivering;

              return validCustomer && validDriver && chatAvailable;
            }).toList()..sort((a, b) {
              final DateTime aDate =
                  a.updatedAt ??
                  a.createdAt ??
                  DateTime.fromMillisecondsSinceEpoch(0);

              final DateTime bDate =
                  b.updatedAt ??
                  b.createdAt ??
                  DateTime.fromMillisecondsSinceEpoch(0);

              return bDate.compareTo(aDate);
            });

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
            const SizedBox(height: 7),
            Text(
              'Hubungi customer terkait proses pengiriman.',
              style: GoogleFonts.inter(color: _textGrey, fontSize: 14),
            ),
            const SizedBox(height: 26),

            if (chatOrders.isEmpty)
              _buildPlaceholderCard(
                icon: Icons.forum_outlined,
                title: 'Belum ada percakapan',
                description:
                    'Chat dengan customer akan muncul setelah order diterima.',
              )
            else
              ...chatOrders.map(
                (order) => _buildChatCard(order: order, driverId: driverId),
              ),
          ],
        );
      },
    );
  }

  Widget _buildChatCard({required OrderModel order, required String driverId}) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _fetchCustomerProfile(order.customerId),
      builder: (context, snapshot) {
        final Map<String, dynamic>? customerData = snapshot.data;

        final String customerName =
            customerData?['name'] as String? ?? 'Customer';

        final String photoUrl = customerData?['photo_url'] as String? ?? '';

        return Container(
          width: double.infinity,
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
                _openChat(order: order, driverId: driverId);
              },
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
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
                              errorBuilder: (_, __, ___) {
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
                            customerName,
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
                            _formatOrderId(order.orderId),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: _textGrey,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _statusBackground(order.status),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _statusLabel(order.status),
                              style: GoogleFonts.inter(
                                color: _statusColor(order.status),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 42,
                      height: 42,
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

  Widget _buildProfilePage({
    required AuthViewModel auth,
    required String name,
    required String email,
  }) {
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
        const SizedBox(height: 7),
        Text(
          'Kelola informasi akun driver.',
          style: GoogleFonts.inter(color: _textGrey, fontSize: 14),
        ),
        const SizedBox(height: 28),
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
                  Icons.delivery_dining_rounded,
                  color: _primaryBlue,
                  size: 43,
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
              const _ProfileInformationRow(
                icon: Icons.badge_outlined,
                label: 'Role',
                value: 'Driver',
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
        const SizedBox(height: 90),
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
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCenteredError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Color(0xFFD14343),
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: _textGrey, fontSize: 13.5),
            ),
          ],
        ),
      ),
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
