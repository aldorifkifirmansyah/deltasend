import 'package:flutter/material.dart';
import '../customer/customer_home_screen.dart';
import '../driver/driver_home_screen.dart';
import '../admin/admin_home_screen.dart';
import 'role_selection_screen.dart';

// Helper bersama: menentukan home screen berdasarkan role user.
// Role kosong (mis. user Google baru) diarahkan ke RoleSelectionScreen
// dengan isExistingAuthUser: true (update role uid yg sudah authenticated).
Widget homeForRole(String role) {
  switch (role) {
    case 'driver':
      return const DriverHomeScreen();
    case 'admin':
      return const AdminHomeScreen();
    case 'customer':
      return const CustomerHomeScreen();
    default:
      return const RoleSelectionScreen(isExistingAuthUser: true);
  }
}
