import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/auth_viewmodel.dart';
import 'role_home.dart';

class SelectRoleScreen extends StatelessWidget {
  const SelectRoleScreen({super.key});

  Future<void> _pick(BuildContext context, String role) async {
    final auth = context.read<AuthViewModel>();
    final ok = await auth.selectRole(role);
    if (!context.mounted) return;
    if (ok) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => homeForRole(role)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.errorMessage ?? 'Gagal memilih role')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final user = auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pilih Peran'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.badge, size: 64, color: Colors.grey),
              const SizedBox(height: 12),
              Text(
                user?.name.isNotEmpty == true ? user!.name : 'Pengguna Baru',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                user?.email ?? '',
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              const Text('Daftar sebagai:'),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.person),
                  label: const Text('Saya Customer'),
                  onPressed:
                      auth.isLoading ? null : () => _pick(context, 'customer'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.secondary,
                    foregroundColor: Theme.of(context).colorScheme.onSecondary,
                  ),
                  icon: const Icon(Icons.delivery_dining),
                  label: const Text('Saya Driver'),
                  onPressed:
                      auth.isLoading ? null : () => _pick(context, 'driver'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
