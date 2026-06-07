import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';

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

  Future<UserModel?> _loadUserDoc(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    final data = doc.data() ?? {};
    return UserModel.fromMap({...data, 'uid': uid});
  }

  Future<bool> signInWithEmailPassword(String email, String password) async {
    _errorMessage = null;
    _setLoading(true);
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = await _loadUserDoc(cred.user!.uid);
      if (user == null) {
        _errorMessage = 'Data profil tidak ditemukan.';
        return false;
      }
      _currentUser = user;
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _mapAuthError(e);
      return false;
    } catch (e) {
      _errorMessage = 'Gagal login: $e';
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
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = cred.user!.uid;
      await _db.collection('users').doc(uid).set({
        'uid': uid,
        'email': email,
        'name': name,
        'role': role,
        'created_at': FieldValue.serverTimestamp(),
      });
      _currentUser = UserModel(uid: uid, email: email, name: name, role: role);
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _mapAuthError(e);
      return false;
    } catch (e) {
      _errorMessage = 'Gagal daftar: $e';
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
        await _googleSignIn.initialize();
        _googleInitialized = true;
      }

      final googleUser = await _googleSignIn.authenticate();
      final googleAuth = googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );
      final cred = await _auth.signInWithCredential(credential);
      final fbUser = cred.user!;

      final existing = await _loadUserDoc(fbUser.uid);
      if (existing != null) {
        _currentUser = existing;
      } else {
        // belum ada dokumen → role kosong supaya UI redirect ke select-role
        _currentUser = UserModel(
          uid: fbUser.uid,
          email: fbUser.email ?? '',
          name: fbUser.displayName ?? '',
          role: '',
        );
      }
      return true;
    } on GoogleSignInException catch (e) {
      if (e.code != GoogleSignInExceptionCode.canceled) {
        _errorMessage = 'Gagal login Google: ${e.description ?? e.code.name}';
      }
      return false;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _mapAuthError(e);
      return false;
    } catch (e) {
      _errorMessage = 'Gagal login Google: $e';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> selectRole(String role) async {
    if (_currentUser == null) return false;
    _errorMessage = null;
    _setLoading(true);
    try {
      final uid = _currentUser!.uid;
      await _db.collection('users').doc(uid).set({
        'uid': uid,
        'email': _currentUser!.email,
        'name': _currentUser!.name,
        'role': role,
        'created_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _currentUser = _currentUser!.copyWith(role: role);
      return true;
    } catch (e) {
      _errorMessage = 'Gagal menyimpan role: $e';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    _currentUser = null;
    notifyListeners();
  }

  Future<UserModel?> loadCurrentUser() async {
    final fbUser = _auth.currentUser;
    if (fbUser == null) {
      _currentUser = null;
      return null;
    }

    final user = await _loadUserDoc(fbUser.uid);
    _currentUser = user ??
        UserModel(
          uid: fbUser.uid,
          email: fbUser.email ?? '',
          name: fbUser.displayName ?? '',
          role: '',
        );
    notifyListeners();
    return _currentUser;
  }

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
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
        return 'Password terlalu lemah (min. 6 karakter).';
      default:
        return e.message ?? 'Terjadi kesalahan autentikasi.';
    }
  }
}
