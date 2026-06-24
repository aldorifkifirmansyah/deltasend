import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../constants/app_constants.dart';
import '../models/user_model.dart';
import '../services/notification_service.dart';

class AuthViewModel extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  bool _googleInitialized = false;

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _registerFcmToken(String uid) {
    unawaited(NotificationService().registerTokenForUser(uid));
  }

  Future<UserModel?> _loadUserDoc(String uid) async {
    final DocumentSnapshot<Map<String, dynamic>> doc = await _db
        .collection('users')
        .doc(uid)
        .get();

    if (!doc.exists) {
      return null;
    }

    final Map<String, dynamic> data = doc.data() ?? {};

    return UserModel.fromMap({...data, 'uid': uid});
  }

  Future<bool> signInWithEmailPassword(String email, String password) async {
    _errorMessage = null;
    _setLoading(true);

    try {
      final UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final String? uid = credential.user?.uid;

      if (uid == null || uid.isEmpty) {
        _errorMessage = 'Data akun tidak ditemukan.';
        return false;
      }

      final UserModel? user = await _loadUserDoc(uid);

      if (user == null) {
        _errorMessage = 'Data profil tidak ditemukan.';

        await _auth.signOut();

        return false;
      }

      _currentUser = user;
      _registerFcmToken(user.uid);

      return true;
    } on FirebaseAuthException catch (error) {
      _errorMessage = _mapAuthError(error);
      return false;
    } catch (error) {
      _errorMessage = 'Gagal login: $error';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> registerWithEmailPassword(
    String email,
    String password,
    String name,
    String role,
  ) async {
    _errorMessage = null;
    _setLoading(true);

    try {
      final UserCredential credential = await _auth
          .createUserWithEmailAndPassword(
            email: email.trim(),
            password: password,
          );

      final String? uid = credential.user?.uid;

      if (uid == null || uid.isEmpty) {
        _errorMessage = 'Gagal membuat akun.';
        return false;
      }

      final String cleanEmail = email.trim();
      final String cleanName = name.trim();
      final String cleanRole = role.trim().toLowerCase();

      await _db.collection('users').doc(uid).set({
        'uid': uid,
        'email': cleanEmail,
        'name': cleanName,
        'role': cleanRole,
        'created_at': FieldValue.serverTimestamp(),
      });

      _currentUser = UserModel(
        uid: uid,
        email: cleanEmail,
        name: cleanName,
        role: cleanRole,
      );

      _registerFcmToken(uid);

      return true;
    } on FirebaseAuthException catch (error) {
      _errorMessage = _mapAuthError(error);
      return false;
    } catch (error) {
      _errorMessage = 'Gagal daftar: $error';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> signInWithGoogle() async {
    _errorMessage = null;
    _setLoading(true);

    try {
      if (!_googleInitialized) {
        await _googleSignIn.initialize(serverClientId: kGoogleServerClientId);

        _googleInitialized = true;
      }

      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();

      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      final OAuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      final UserCredential firebaseCredential = await _auth
          .signInWithCredential(credential);

      final User? firebaseUser = firebaseCredential.user;

      if (firebaseUser == null) {
        _errorMessage = 'Data akun Google tidak ditemukan.';
        return false;
      }

      final UserModel? existingUser = await _loadUserDoc(firebaseUser.uid);

      if (existingUser != null) {
        _currentUser = existingUser;
        _registerFcmToken(existingUser.uid);
      } else {
        _currentUser = UserModel(
          uid: firebaseUser.uid,
          email: firebaseUser.email ?? '',
          name: firebaseUser.displayName ?? '',
          role: '',
        );
      }

      return true;
    } on GoogleSignInException catch (error) {
      if (error.code != GoogleSignInExceptionCode.canceled) {
        _errorMessage =
            'Gagal login Google: '
            '${error.description ?? error.code.name}';
      }

      return false;
    } on FirebaseAuthException catch (error) {
      _errorMessage = _mapAuthError(error);
      return false;
    } catch (error) {
      _errorMessage = 'Gagal login Google: $error';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> selectRole(String role) async {
    final UserModel? user = _currentUser;

    if (user == null) {
      return false;
    }

    _errorMessage = null;
    _setLoading(true);

    try {
      final String cleanRole = role.trim().toLowerCase();

      await _db.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': user.email,
        'name': user.name,
        'role': cleanRole,
        'created_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _currentUser = user.copyWith(role: cleanRole);

      _registerFcmToken(user.uid);

      return true;
    } catch (error) {
      _errorMessage = 'Gagal menyimpan role: $error';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> sendPasswordResetEmail(String email) async {
    _errorMessage = null;
    _setLoading(true);

    try {
      await _auth
          .sendPasswordResetEmail(email: email.trim())
          .timeout(const Duration(seconds: 15));

      return true;
    } on TimeoutException {
      _errorMessage =
          'Permintaan terlalu lama. '
          'Periksa koneksi internet lalu coba kembali.';

      return false;
    } on FirebaseAuthException catch (error) {
      switch (error.code) {
        case 'invalid-email':
          _errorMessage = 'Format email tidak valid.';
          break;

        case 'user-not-found':
          _errorMessage = 'Akun dengan email tersebut tidak ditemukan.';
          break;

        case 'too-many-requests':
          _errorMessage =
              'Terlalu banyak permintaan. '
              'Silakan coba lagi beberapa saat.';
          break;

        case 'network-request-failed':
          _errorMessage =
              'Koneksi internet bermasalah. '
              'Periksa jaringan Anda.';
          break;

        default:
          _errorMessage =
              'Gagal mengirim link reset. '
              'Periksa koneksi internet dan coba lagi.';
      }

      return false;
    } catch (_) {
      _errorMessage =
          'Gagal mengirim link reset. '
          'Periksa koneksi internet dan coba lagi.';

      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updateUserName(String name) async {
    final UserModel? user = _currentUser;

    if (user == null) {
      return false;
    }

    final String trimmedName = name.trim();

    if (trimmedName.isEmpty) {
      _errorMessage = 'Nama tidak boleh kosong.';
      return false;
    }

    _errorMessage = null;
    _setLoading(true);

    try {
      await _db.collection('users').doc(user.uid).update({'name': trimmedName});

      _currentUser = user.copyWith(name: trimmedName);

      return true;
    } catch (error) {
      _errorMessage = 'Gagal memperbarui nama: $error';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signOut() async {
    final String? uid = _currentUser?.uid ?? _auth.currentUser?.uid;

    _errorMessage = null;
    _setLoading(true);

    try {
      // Firebase Auth dikeluarkan terlebih dahulu.
      // Dengan begitu sesi utama langsung berakhir.
      await _auth.signOut();

      // Logout Google tidak boleh menggagalkan
      // logout Firebase.
      try {
        await _googleSignIn.signOut().timeout(const Duration(seconds: 5));
      } catch (_) {}

      // Token notifikasi dibersihkan setelah sesi
      // Firebase sudah keluar.
      // Jika proses ini gagal atau terlalu lama,
      // logout tetap dianggap berhasil.
      if (uid != null && uid.isNotEmpty) {
        try {
          await NotificationService()
              .clearTokenForUser(uid)
              .timeout(const Duration(seconds: 5));
        } catch (_) {}
      }

      _currentUser = null;
      _errorMessage = null;
    } catch (error) {
      _errorMessage = 'Gagal keluar dari akun: $error';

      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<UserModel?> loadCurrentUser() async {
    final User? firebaseUser = _auth.currentUser;

    if (firebaseUser == null) {
      _currentUser = null;
      notifyListeners();
      return null;
    }

    final UserModel? user = await _loadUserDoc(firebaseUser.uid);

    if (user != null) {
      _currentUser = user;
      _registerFcmToken(user.uid);
    } else {
      _currentUser = UserModel(
        uid: firebaseUser.uid,
        email: firebaseUser.email ?? '',
        name: firebaseUser.displayName ?? '',
        role: '',
      );
    }

    notifyListeners();

    return _currentUser;
  }

  String _mapAuthError(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'Format email tidak valid.';

      case 'user-not-found':
        return 'Akun tidak ditemukan.';

      case 'wrong-password':
      case 'invalid-credential':
        return 'Email atau password salah.';

      case 'email-already-in-use':
        return 'Email sudah terdaftar.';

      case 'weak-password':
        return 'Password terlalu lemah '
            '(minimal 6 karakter).';

      case 'network-request-failed':
        return 'Koneksi internet bermasalah.';

      case 'too-many-requests':
        return 'Terlalu banyak percobaan. '
            'Coba kembali beberapa saat.';

      default:
        return error.message ?? 'Terjadi kesalahan autentikasi.';
    }
  }
}
