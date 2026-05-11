import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthViewModel extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  bool _isLoading = false;

  bool get isLoading => _isLoading;

  Future<void> handleGoogleLogin(BuildContext context) async {
    _isLoading = true;
    notifyListeners();

    try {
      User? user = _auth.currentUser;

      if (user != null) {
        DocumentSnapshot doc = await _db
            .collection('users')
            .doc(user.uid)
            .get();

        if (!context.mounted) return;

        if (!doc.exists) {
          Navigator.pushReplacementNamed(context, '/select-role');
        } else {
          String role = doc.get('role');

          if (role == 'admin') {
            Navigator.pushReplacementNamed(context, '/admin-home');
          } else if (role == 'driver') {
            Navigator.pushReplacementNamed(context, '/driver-home');
          } else {
            Navigator.pushReplacementNamed(context, '/customer-home');
          }
        }
      }
    } catch (e) {
      debugPrint("Error Login: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
