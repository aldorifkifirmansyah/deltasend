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

  final FocusNode _searchFocusNode = FocusNode();

  static const Color _primaryBlue = Color(0xFF133D87);

  static const Color _titleBlue = Color(0xFF608BC0);

  static const Color _textDark = Color(0xFF202832);

  static const Color _textGrey = Color(0xFF8A929C);

  static const Color _borderColor = Color(0xFFE0E5EB);

  static const Color _pageBackground = Color(0xFFF8FAFD);

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _focusSearch() {
    _searchFocusNode.requestFocus();
  }

  String _normalizeRole(dynamic value) {
    return value?.toString().trim().toLowerCase() ?? '';
  }

  bool _matchesSearch(Map<String, dynamic> data, String searchQuery) {
    if (searchQuery.isEmpty) {
      return true;
    }

    final String name = data['name']?.toString().toLowerCase() ?? '';

    final String email = data['email']?.toString().toLowerCase() ?? '';

    final String phone = (data['phone'] ?? data['phone_number'] ?? '')
        .toString()
        .toLowerCase();

    return name.contains(searchQuery) ||
        email.contains(searchQuery) ||
        phone.contains(searchQuery);
  }

  @override
  Widget build(BuildContext context) {
    final AdminViewModel admin = context.watch<AdminViewModel>();

    return Scaffold(
      backgroundColor: _pageBackground,
      extendBody: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            AppAssets.loginBackground,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return const ColoredBox(color: _pageBackground);
            },
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                const SizedBox(height: 17),
                SvgPicture.asset(AppAssets.logo, width: 218),
                const SizedBox(height: 24),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(30),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.10),
                          blurRadius: 20,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(30),
                      ),
                      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return _buildFullPageMessage(
                              icon: Icons.error_outline_rounded,
                              text: 'Gagal memuat data user.',
                            );
                          }

                          if (!snapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(
                                color: _primaryBlue,
                              ),
                            );
                          }

                          final List<
                            QueryDocumentSnapshot<Map<String, dynamic>>
                          >
                          allUsers = snapshot.data!.docs;

                          final int driverCount = allUsers.where((document) {
                            final String role = _normalizeRole(
                              document.data()['role'],
                            );

                            return role == 'driver';
                          }).length;

                          final int customerCount = allUsers.where((document) {
                            final String role = _normalizeRole(
                              document.data()['role'],
                            );

                            return role == 'customer';
                          }).length;

                          final String searchQuery = _searchController.text
                              .trim()
                              .toLowerCase();

                          final List<
                            QueryDocumentSnapshot<Map<String, dynamic>>
                          >
                          filteredUsers = allUsers.where((document) {
                            final Map<String, dynamic> data = document.data();

                            final String role = _normalizeRole(data['role']);

                            return role == admin.selectedUserRole &&
                                _matchesSearch(data, searchQuery);
                          }).toList();

                          filteredUsers.sort((first, second) {
                            final String firstName =
                                first
                                    .data()['name']
                                    ?.toString()
                                    .toLowerCase() ??
                                '';

                            final String secondName =
                                second
                                    .data()['name']
                                    ?.toString()
                                    .toLowerCase() ??
                                '';

                            return firstName.compareTo(secondName);
                          });

                          return ListView(
                            padding: const EdgeInsets.fromLTRB(22, 34, 22, 120),
                            children: [
                              _buildHeader(),
                              const SizedBox(height: 32),
                              _buildSearchField(admin),
                              const SizedBox(height: 24),
                              _buildRoleSelector(
                                admin: admin,
                                driverCount: driverCount,
                                customerCount: customerCount,
                              ),
                              const SizedBox(height: 26),
                              _buildUserList(
                                users: filteredUsers,
                                selectedRole: admin.selectedUserRole,
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
      bottomNavigationBar: const AdminBottomBar(selectedIndex: 1),
    );
  }

  Widget _buildHeader() {
    return SizedBox(
      height: 42,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: Text(
              'Users',
              style: GoogleFonts.inter(
                color: _textDark,
                fontSize: 21,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Positioned(
            right: 0,
            child: IconButton(
              onPressed: _focusSearch,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 42, minHeight: 42),
              icon: const Icon(
                Icons.search_rounded,
                color: Color(0xFF111820),
                size: 33,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField(AdminViewModel admin) {
    return TextField(
      controller: _searchController,
      focusNode: _searchFocusNode,
      onChanged: (value) {
        admin.changeUserSearchQuery(value);

        setState(() {});
      },
      style: GoogleFonts.inter(color: _textDark, fontSize: 13),
      decoration: InputDecoration(
        hintText: 'Search name, email, or phone...',
        hintStyle: GoogleFonts.inter(
          color: const Color(0xFFB1BAC5),
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: const Padding(
          padding: EdgeInsets.only(left: 15, right: 10),
          child: Icon(Icons.search_rounded, color: Color(0xFF8D9AA8), size: 25),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 50),
        suffixIcon: _searchController.text.isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  _searchController.clear();

                  admin.changeUserSearchQuery('');

                  setState(() {});
                },
                icon: const Icon(Icons.close_rounded, color: _textGrey),
              ),
        filled: true,
        fillColor: const Color(0xFFF3F6F8),
        contentPadding: const EdgeInsets.symmetric(vertical: 19),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _titleBlue, width: 1.2),
        ),
      ),
    );
  }

  Widget _buildRoleSelector({
    required AdminViewModel admin,
    required int driverCount,
    required int customerCount,
  }) {
    return Row(
      children: [
        Expanded(
          child: _RoleTab(
            icon: Icons.delivery_dining_rounded,
            label: 'Drivers',
            count: driverCount,
            selected: admin.selectedUserRole == 'driver',
            onTap: () {
              admin.changeUserRole('driver');
            },
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _RoleTab(
            icon: Icons.person_rounded,
            label: 'Customers',
            count: customerCount,
            selected: admin.selectedUserRole == 'customer',
            onTap: () {
              admin.changeUserRole('customer');
            },
          ),
        ),
      ],
    );
  }

  Widget _buildUserList({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> users,
    required String selectedRole,
  }) {
    if (users.isEmpty) {
      return _buildMessageCard(
        icon: Icons.people_outline_rounded,
        text: 'User tidak ditemukan.',
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFE1E6EC)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: users.length,
        separatorBuilder: (context, index) {
          return const Divider(height: 18, color: Color(0xFFE9EDF1));
        },
        itemBuilder: (context, index) {
          final document = users[index];
          final data = document.data();

          final String userId = document.id;

          final String name = data['name']?.toString().trim().isNotEmpty == true
              ? data['name'].toString().trim()
              : 'Tanpa nama';

          final String email = data['email']?.toString() ?? '-';

          final String phone = (data['phone'] ?? data['phone_number'] ?? '')
              .toString();

          final String photoUrl = (data['photo_url'] ?? data['photoUrl'] ?? '')
              .toString();

          final String driverReferenceId =
              (data['driver_id'] ?? data['driverId'] ?? userId).toString();

          return _buildUserRow(
            userId: userId,
            driverReferenceId: driverReferenceId,
            name: name,
            email: email,
            phone: phone,
            photoUrl: photoUrl,
            showDriverStatus: selectedRole == 'driver',
          );
        },
      ),
    );
  }

  Widget _buildUserRow({
    required String userId,
    required String driverReferenceId,
    required String name,
    required String email,
    required String phone,
    required String photoUrl,
    required bool showDriverStatus,
  }) {
    final String secondaryText = phone.trim().isNotEmpty ? phone : name;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AdminUserDetailScreen(uid: userId),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          child: Row(
            children: [
              Container(
                width: 53,
                height: 53,
                clipBehavior: Clip.antiAlias,
                decoration: const BoxDecoration(
                  color: Color(0xFFDCEEFF),
                  shape: BoxShape.circle,
                ),
                child: photoUrl.trim().isEmpty
                    ? const Icon(
                        Icons.person_rounded,
                        color: _primaryBlue,
                        size: 33,
                      )
                    : Image.network(
                        photoUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.person_rounded,
                            color: _primaryBlue,
                            size: 33,
                          );
                        },
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: _textDark,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      secondaryText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(color: _textGrey, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (showDriverStatus) ...[
                const SizedBox(width: 8),
                _DriverOnlineStatus(driverReferenceId: driverReferenceId),
              ],
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF9CA7B1),
                size: 27,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageCard({required IconData icon, required String text}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        children: [
          Icon(icon, color: _titleBlue, size: 40),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: _textGrey, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildFullPageMessage({required IconData icon, required String text}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: _titleBlue, size: 48),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: _textGrey, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class _DriverOnlineStatus extends StatelessWidget {
  final String driverReferenceId;

  const _DriverOnlineStatus({required this.driverReferenceId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('driver_locations')
          .doc(driverReferenceId)
          .snapshots(),
      builder: (context, directSnapshot) {
        if (directSnapshot.hasData && directSnapshot.data?.exists == true) {
          final Map<String, dynamic> data = directSnapshot.data!.data() ?? {};

          final bool isOnline =
              data['is_online'] == true || data['isOnline'] == true;

          return _OnlineStatusBadge(isOnline: isOnline);
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('driver_locations')
              .where('driver_id', isEqualTo: driverReferenceId)
              .limit(1)
              .snapshots(),
          builder: (context, querySnapshot) {
            bool isOnline = false;

            if (querySnapshot.hasData && querySnapshot.data!.docs.isNotEmpty) {
              final Map<String, dynamic> data = querySnapshot.data!.docs.first
                  .data();

              isOnline = data['is_online'] == true || data['isOnline'] == true;
            }

            return _OnlineStatusBadge(isOnline: isOnline);
          },
        );
      },
    );
  }
}

class _OnlineStatusBadge extends StatelessWidget {
  final bool isOnline;

  const _OnlineStatusBadge({required this.isOnline});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isOnline ? const Color(0xFFE0F7E9) : const Color(0xFFFFF2D7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        isOnline ? 'Online' : 'Offline',
        style: GoogleFonts.inter(
          color: isOnline ? const Color(0xFF22A86C) : const Color(0xFFD69A22),
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _RoleTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _RoleTab({
    required this.icon,
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const Color primaryBlue = Color(0xFF133D87);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 170),
          height: 68,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFF2F7FD) : Colors.white,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: selected
                  ? const Color(0xFFBED8F1)
                  : const Color(0xFFE0E5EB),
              width: selected ? 1.4 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.025),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: selected ? primaryBlue : const Color(0xFF7F8792),
                size: 23,
              ),
              const SizedBox(width: 9),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: selected ? primaryBlue : const Color(0xFF68717D),
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '($count)',
                style: GoogleFonts.inter(
                  color: const Color(0xFF9AA3AD),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
