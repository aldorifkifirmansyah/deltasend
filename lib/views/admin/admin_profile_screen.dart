import 'package:flutter/material.dart';

class AdminProfileScreen extends StatelessWidget {
  const AdminProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: const Color(0xFF133D87),
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Text('Admin Profile Screen'),
      ),
    );
  }
}