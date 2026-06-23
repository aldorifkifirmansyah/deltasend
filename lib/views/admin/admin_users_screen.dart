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

  static const Color _textDark = Color(0xFF1B1B1B);

  static const Color _textGrey = Color(0xFF687386);

  static const Color _borderBlue = Color(0xFFC9D9ED);

  static const Color _pageBackground = Color(0xFFF8FAFD);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
                const SizedBox(height: 18),
                SvgPicture.asset(AppAssets.logo, width: 215),
                const SizedBox(height: 24),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(28),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.10),
                          blurRadius: 18,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(28),
                      ),
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(22, 28, 22, 120),
                        children: [
                          Text(
                            'Users',
                            style: GoogleFonts.getFont(
                              'ADLaM Display',
                              color: _titleBlue,
                              fontSize: 24,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            'Kelola akun customer dan driver.',
                            style: GoogleFonts.inter(
                              color: _textGrey,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 22),
                          _buildSearchField(admin),
                          const SizedBox(height: 16),
                          _buildRoleSelector(admin),
                          const SizedBox(height: 20),
                          _buildUserList(admin),
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
      bottomNavigationBar: const AdminBottomBar(selectedIndex: 1),
    );
  }

  Widget _buildSearchField(AdminViewModel admin) {
    return TextField(
      controller: _searchController,
      onChanged: (value) {
        admin.changeUserSearchQuery(value);
        setState(() {});
      },
      decoration: InputDecoration(
        hintText: 'Cari nama, email, atau nomor telepon',
        hintStyle: GoogleFonts.inter(color: _textGrey, fontSize: 12),
        prefixIcon: const Icon(Icons.search_rounded, color: _titleBlue),
        suffixIcon: _searchController.text.isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  _searchController.clear();
                  admin.changeUserSearchQuery('');
                  setState(() {});
                },
                icon: const Icon(Icons.close_rounded),
              ),
        filled: true,
        fillColor: const Color(0xFFF8FAFD),
        contentPadding: const EdgeInsets.symmetric(vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _borderBlue),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _borderBlue),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _primaryBlue, width: 1.4),
        ),
      ),
    );
  }

  Widget _buildRoleSelector(AdminViewModel admin) {
    return Row(
      children: [
        Expanded(
          child: _RoleButton(
            label: 'Driver',
            selected: admin.selectedUserRole == 'driver',
            onTap: () {
              admin.changeUserRole('driver');
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _RoleButton(
            label: 'Customer',
            selected: admin.selectedUserRole == 'customer',
            onTap: () {
              admin.changeUserRole('customer');
            },
          ),
        ),
      ],
    );
  }

  Widget _buildUserList(AdminViewModel admin) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: admin.watchSelectedUsers(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildMessageCard(
            icon: Icons.error_outline_rounded,
            text: 'Gagal memuat data user.',
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(36),
            child: Center(
              child: CircularProgressIndicator(color: _primaryBlue),
            ),
          );
        }

        final List<QueryDocumentSnapshot<Map<String, dynamic>>> users =
            (snapshot.data?.docs ?? [])
                .where((document) => admin.isUserMatchSearch(document.data()))
                .toList();

        users.sort((first, second) {
          final String firstName =
              first.data()['name']?.toString().toLowerCase() ?? '';

          final String secondName =
              second.data()['name']?.toString().toLowerCase() ?? '';

          return firstName.compareTo(secondName);
        });

        if (users.isEmpty) {
          return _buildMessageCard(
            icon: Icons.people_outline_rounded,
            text: 'User tidak ditemukan.',
          );
        }

        return Column(
          children: users.map((document) {
            final Map<String, dynamic> data = document.data();

            final String name =
                data['name']?.toString().trim().isNotEmpty == true
                ? data['name'].toString().trim()
                : 'Tanpa nama';

            final String email = data['email']?.toString() ?? '-';

            final String photoUrl =
                (data['photo_url'] ?? data['photoUrl'] ?? '').toString();

            final bool isOnline =
                data['is_online'] == true || data['isOnline'] == true;

            return _buildUserCard(
              uid: document.id,
              name: name,
              email: email,
              photoUrl: photoUrl,
              showOnlineStatus: admin.selectedUserRole == 'driver',
              isOnline: isOnline,
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildUserCard({
    required String uid,
    required String name,
    required String email,
    required String photoUrl,
    required bool showOnlineStatus,
    required bool isOnline,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _borderBlue),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
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
                builder: (_) => AdminUserDetailScreen(uid: uid),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Container(
                  width: 51,
                  height: 51,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: _titleBlue.withValues(alpha: 0.15),
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
                          errorBuilder: (context, error, stackTrace) {
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
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: _textDark,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: _textGrey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (showOnlineStatus) ...[
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: isOnline
                          ? const Color(0xFF0AAA55)
                          : const Color(0xFFB9C1CC),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 9),
                ],
                const Icon(Icons.chevron_right_rounded, color: _titleBlue),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageCard({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _borderBlue),
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
}

class _RoleButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RoleButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 43,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: selected ? Colors.white : const Color(0xFF133D87),
          backgroundColor: selected ? const Color(0xFF133D87) : Colors.white,
          side: const BorderSide(color: Color(0xFF133D87)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
