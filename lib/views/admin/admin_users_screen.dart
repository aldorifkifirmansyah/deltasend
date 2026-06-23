import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../utils/app_assets.dart';
import '../../viewmodels/admin_viewmodel.dart';
import 'admin_bottom_bar.dart';
import 'admin_user_detail_screen.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final TextEditingController _searchController = TextEditingController();

  static const Color _primaryBlue = Color(0xFF133D87);

  static const Color _titleBlue = Color(0xFF608BC0);

  static const Color _textDark = Color(0xFF1A1D23);

  static const Color _textGrey = Color(0xFF687386);

  static const Color _borderBlue = Color(0xFFDCE5F1);

  static const Color _pageBackground = Color(0xFFF7F9FC);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openUserDetail(String userId) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AdminUserDetailScreen(userId: userId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AdminViewModel admin = context.watch<AdminViewModel>();

    return Scaffold(
      backgroundColor: _pageBackground,
      bottomNavigationBar: const AdminBottomBar(selectedIndex: 1),
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
                const SizedBox(height: 16),

                SvgPicture.asset(AppAssets.logo, width: 214),

                const SizedBox(height: 24),

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 0, 22, 0),
                    child: Container(
                      width: double.infinity,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(28),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 18,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: admin.watchAllUsers(),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return _buildErrorState();
                          }

                          if (!snapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(
                                color: _primaryBlue,
                              ),
                            );
                          }

                          final documents = snapshot.data!.docs;

                          final int driverCount = documents.where((document) {
                            final String role =
                                document
                                    .data()['role']
                                    ?.toString()
                                    .toLowerCase() ??
                                '';

                            return role == 'driver';
                          }).length;

                          final int customerCount = documents.where((document) {
                            final String role =
                                document
                                    .data()['role']
                                    ?.toString()
                                    .toLowerCase() ??
                                '';

                            return role == 'customer';
                          }).length;

                          final filteredUsers = documents.where((document) {
                            final data = document.data();

                            final String role =
                                data['role']?.toString().toLowerCase() ?? '';

                            final bool roleMatches =
                                role == admin.selectedUserRole;

                            return roleMatches && admin.isUserMatchSearch(data);
                          }).toList();

                          return Column(
                            children: [
                              _buildHeader(),
                              _buildSearchField(admin),
                              _buildRoleSelector(
                                admin: admin,
                                driverCount: driverCount,
                                customerCount: customerCount,
                              ),
                              Expanded(
                                child: _buildUserList(
                                  admin: admin,
                                  users: filteredUsers,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 12),
      child: Row(
        children: [
          const SizedBox(width: 36),
          Expanded(
            child: Text(
              'Users',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: _textDark,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              FocusScope.of(context).unfocus();
            },
            icon: const Icon(Icons.search_rounded, color: _textDark, size: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField(AdminViewModel admin) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          admin.changeUserSearchQuery(value);
          setState(() {});
        },
        style: GoogleFonts.inter(color: _textDark, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search name, email, or phone...',
          hintStyle: GoogleFonts.inter(
            color: const Color(0xFF9AA6B2),
            fontSize: 13,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: Color(0xFF9AA6B2),
          ),
          suffixIcon: _searchController.text.isEmpty
              ? null
              : IconButton(
                  onPressed: () {
                    _searchController.clear();

                    admin.changeUserSearchQuery('');

                    setState(() {});
                  },
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
          filled: true,
          fillColor: const Color(0xFFF2F4F6),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 13),
        ),
      ),
    );
  }

  Widget _buildRoleSelector({
    required AdminViewModel admin,
    required int driverCount,
    required int customerCount,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 18, 28, 17),
      child: Row(
        children: [
          Expanded(
            child: _buildRoleButton(
              admin: admin,
              icon: Icons.delivery_dining_rounded,
              title: 'Drivers',
              count: driverCount,
              role: 'driver',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildRoleButton(
              admin: admin,
              icon: Icons.person_rounded,
              title: 'Customers',
              count: customerCount,
              role: 'customer',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleButton({
    required AdminViewModel admin,
    required IconData icon,
    required String title,
    required int count,
    required String role,
  }) {
    final bool isActive = admin.selectedUserRole == role;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          admin.changeUserRole(role);
        },
        borderRadius: BorderRadius.circular(11),
        child: Ink(
          height: 48,
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFFF4F8FF) : Colors.white,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: isActive
                  ? const Color(0xFFD6E7F8)
                  : const Color(0xFFF0F1F3),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.07),
                blurRadius: 7,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isActive ? _primaryBlue : _textGrey, size: 22),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  style: GoogleFonts.inter(
                    color: isActive ? _primaryBlue : _textGrey,
                    fontSize: 13,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '($count)',
                style: GoogleFonts.inter(color: _titleBlue, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserList({
    required AdminViewModel admin,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> users,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(28, 0, 28, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: users.isEmpty
          ? _buildEmptyState()
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 14),
              itemCount: users.length,
              separatorBuilder: (_, __) => const SizedBox(height: 2),
              itemBuilder: (context, index) {
                final document = users[index];

                return _buildUserItem(
                  admin: admin,
                  userId: document.id,
                  data: document.data(),
                );
              },
            ),
    );
  }

  Widget _buildUserItem({
    required AdminViewModel admin,
    required String userId,
    required Map<String, dynamic> data,
  }) {
    final String role = data['role']?.toString().toLowerCase() ?? '';

    if (role == 'driver') {
      return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: admin.watchDriverLocation(userId),
        builder: (context, locationSnapshot) {
          final locationData = locationSnapshot.data?.data();

          final bool isOnline = locationData?['is_online'] == true;

          final dynamic updatedAt =
              locationData?['updated_at'] ?? locationData?['last_seen'];

          return _userTile(
            userId: userId,
            data: data,
            isOnline: isOnline,
            lastActive: _formatLastActive(updatedAt, isOnline),
          );
        },
      );
    }

    final bool isActive = data['is_active'] != false;

    return _userTile(
      userId: userId,
      data: data,
      isOnline: isActive,
      lastActive: isActive ? 'Active' : 'Inactive',
    );
  }

  Widget _userTile({
    required String userId,
    required Map<String, dynamic> data,
    required bool isOnline,
    required String lastActive,
  }) {
    final String name = data['name']?.toString().trim() ?? '';

    final String email = data['email']?.toString().trim() ?? '';

    final String phone = data['phone']?.toString().trim() ?? '';

    final String photoUrl = data['photo_url']?.toString().trim() ?? '';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openUserDetail(userId),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(13, 8, 8, 8),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: const Color(0xFFD6E7F8),
                  shape: BoxShape.circle,
                  border: Border.all(color: _borderBlue),
                ),
                child: photoUrl.isEmpty
                    ? const Icon(
                        Icons.person_rounded,
                        color: _primaryBlue,
                        size: 29,
                      )
                    : Image.network(
                        photoUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) {
                          return const Icon(
                            Icons.person_rounded,
                            color: _primaryBlue,
                            size: 29,
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
                      email.isNotEmpty ? email : name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: _textDark,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      phone.isNotEmpty ? phone : name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(color: _textGrey, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 7),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isOnline
                          ? const Color(0xFFE2F9EB)
                          : const Color(0xFFFFF0D8),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(
                      isOnline ? 'Active' : 'Offline',
                      style: GoogleFonts.inter(
                        color: isOnline
                            ? const Color(0xFF0AAA55)
                            : const Color(0xFFE08B00),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        lastActive,
                        style: GoogleFonts.inter(
                          color: _textGrey,
                          fontSize: 10.5,
                        ),
                      ),
                      if (isOnline) ...[
                        const SizedBox(width: 5),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF0AAA55),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFA6B0BC),
                size: 30,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatLastActive(dynamic value, bool isOnline) {
    if (isOnline) return 'Online';

    if (value is! Timestamp) {
      return 'Offline';
    }

    final Duration difference = DateTime.now().difference(value.toDate());

    if (difference.inMinutes < 1) {
      return 'Baru saja';
    }

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} menit lalu';
    }

    if (difference.inHours < 24) {
      return '${difference.inHours} jam lalu';
    }

    return '${difference.inDays} hari lalu';
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.person_search_rounded,
              color: _titleBlue,
              size: 44,
            ),
            const SizedBox(height: 10),
            Text(
              'User tidak ditemukan',
              style: GoogleFonts.inter(
                color: _textDark,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Text(
        'Gagal memuat data user.',
        style: GoogleFonts.inter(color: const Color(0xFFD14343), fontSize: 14),
      ),
    );
  }
}
