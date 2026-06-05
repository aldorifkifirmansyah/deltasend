import 'package:flutter/material.dart';
import '../customer/customer_home_screen.dart';
import '../driver/driver_home_screen.dart';
import '../admin/admin_home_screen.dart';
import 'select_role_screen.dart';

// Helper bersama: menentukan home screen berdasarkan role user.
// Role kosong (mis. user Google baru) diarahkan ke SelectRoleScreen.
Widget homeForRole(String role) {
  switch (role) {
    case 'driver':
      return const DriverHomeScreen();
    case 'admin':
      return const AdminHomeScreen();
    case 'customer':
      return const CustomerHomeScreen();
    default:
      return const SelectRoleScreen();
  }
}
