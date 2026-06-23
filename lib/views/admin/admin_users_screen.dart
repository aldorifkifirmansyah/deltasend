import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../utils/app_assets.dart';
import '../../viewmodels/admin_viewmodel.dart';

import 'admin_home_screen.dart';
import 'admin_order_list_screen.dart';
import 'admin_tracking_list_screen.dart';
import 'admin_profile_screen.dart';
import 'admin_user_detail_screen.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  void _goTo(Widget page) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminViewModel>();

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              AppAssets.loginBackground,
              fit: BoxFit.cover,
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(26, 20, 26, 95),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 18,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Spacer(),
                        Text(
                          'Users',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Spacer(),
                        Icon(Icons.search, size: 28),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F3F5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        onChanged: admin.changeUserSearchQuery,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          icon: Icon(
                            Icons.search,
                            color: Color(0xFF9AA6B2),
                          ),
                          hintText: 'Search user by email...',
                          hintStyle: TextStyle(
                            color: Color(0xFF9AA6B2),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _roleButton(
                            admin: admin,
                            icon: Icons.delivery_dining,
                            title: 'Drivers',
                            count: '100',
                            role: 'driver',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _roleButton(
                            admin: admin,
                            icon: Icons.person,
                            title: 'Customers',
                            count: '250',
                            role: 'customer',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFE5E7EB),
                          ),
                        ),
                        child: StreamBuilder(
                          stream: admin.watchSelectedUsers(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }

                            if (!snapshot.hasData ||
                                snapshot.data!.docs.isEmpty) {
                              return const Center(
                                child: Text('Belum ada user'),
                              );
                            }

                            final users = snapshot.data!.docs.where((doc) {
                              final data = doc.data();
                              return admin.isUserMatchSearch(data);
                            }).toList();

                            if (users.isEmpty) {
                              return const Center(
                                child: Text('User tidak ditemukan'),
                              );
                            }

                            return ListView.builder(
                              itemCount: users.length,
                              itemBuilder: (context, index) {
                                final doc = users[index];
                                final data = doc.data();

                                final name = data['name']?.toString() ?? '-';
                                final email = data['email']?.toString() ?? '-';
                                final phone = data['phone']?.toString() ?? '';
                                final photoUrl =
                                    data['photo_url']?.toString() ?? '';

                                final isOnline =
                                    data['is_online'] == true || index < 4;

                                return InkWell(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => AdminUserDetailScreen(
                                          userId: doc.id,
                                        ),
                                      ),
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      14,
                                      8,
                                      10,
                                      8,
                                    ),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 24,
                                          backgroundColor:
                                              const Color(0xFFD6E7F8),
                                          backgroundImage: photoUrl.isNotEmpty
                                              ? NetworkImage(photoUrl)
                                              : null,
                                          child: photoUrl.isEmpty
                                              ? const Icon(
                                                  Icons.person,
                                                  color: Color(0xFF133D87),
                                                )
                                              : null,
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                email,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.black,
                                                ),
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                phone.isEmpty ? name : phone,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  color: Color(0xFF5F6770),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 3,
                                              ),
                                              decoration: BoxDecoration(
                                                color: isOnline
                                                    ? const Color(0xFFD9FBE2)
                                                    : const Color(0xFFFFE8C8),
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: Text(
                                                isOnline
                                                    ? 'Active'
                                                    : 'Offline',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: isOnline
                                                      ? const Color(0xFF00A651)
                                                      : Colors.orange,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Row(
                                              children: [
                                                Text(
                                                  isOnline
                                                      ? 'Online'
                                                      : '2 jam lalu',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Color(0xFF5F6770),
                                                  ),
                                                ),
                                                if (isOnline) ...[
                                                  const SizedBox(width: 5),
                                                  const CircleAvatar(
                                                    radius: 3,
                                                    backgroundColor:
                                                        Color(0xFF00A651),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ),
                                        const SizedBox(width: 6),
                                        const Icon(
                                          Icons.chevron_right,
                                          size: 30,
                                          color: Color(0xFF9AA6B2),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _bottomNav(),
        ],
      ),
    );
  }

  Widget _roleButton({
    required AdminViewModel admin,
    required IconData icon,
    required String title,
    required String count,
    required String role,
  }) {
    final isActive = admin.selectedUserRole == role;

    return GestureDetector(
      onTap: () {
        admin.changeUserRole(role);
      },
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
          border: Border.all(
            color: isActive
                ? const Color(0xFFD6E7F8)
                : const Color(0xFFF0F0F0),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isActive
                  ? const Color(0xFF133D87)
                  : const Color(0xFF5F6770),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: isActive
                    ? const Color(0xFF133D87)
                    : const Color(0xFF5F6770),
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '($count)',
              style: const TextStyle(
                color: Color(0xFF608BC0),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomNav() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        height: 82,
        decoration: const BoxDecoration(
          color: Color(0xFF133D87),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(100),
            topRight: Radius.circular(100),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _BottomItem(
              icon: Icons.home_rounded,
              label: 'Dashboard',
              onTap: () => _goTo(const AdminHomeScreen()),
            ),
            const _BottomItem(
              icon: Icons.groups_rounded,
              label: 'Users',
              active: true,
            ),
            _BottomItem(
              icon: Icons.inventory_2_rounded,
              label: 'Orders',
              onTap: () => _goTo(const AdminOrdersScreen()),
            ),
            _BottomItem(
              icon: Icons.route_rounded,
              label: 'Tracking',
              onTap: () => _goTo(AdminTrackingListScreen()),
            ),
            _BottomItem(
              icon: Icons.person_rounded,
              label: 'Profile',
              onTap: () => _goTo(AdminProfileScreen()),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  const _BottomItem({
    required this.icon,
    required this.label,
    this.active = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? Colors.white : Colors.white.withOpacity(0.6);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.only(top: 12, left: 8, right: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}