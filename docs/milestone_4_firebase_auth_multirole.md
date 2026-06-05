# Milestone 4 — Firebase Auth Multi-Role

## 1. Ringkasan Milestone

Milestone 4 menambahkan **autentikasi multi-role** menggunakan Firebase Authentication, menggantikan dummy `customer_test_001` dan `driver_test_001` yang dipakai pada milestone sebelumnya dengan **UID asli** dari akun yang login.

Aplikasi kini dibuka lewat **SplashScreen** yang mengecek status login. Jika belum login, user diarahkan ke **LoginScreen** (email/password atau Google Sign-In). Setelah login/daftar, user diarahkan ke home sesuai **role** (Customer, Driver, atau Admin). User yang login lewat Google namun belum punya role akan diarahkan ke **SelectRoleScreen** untuk memilih peran.

`RoleSwitcherScreen` (mode testing manual dari Milestone 2) dihapus dan digantikan oleh alur autentikasi yang nyata.

Catatan: konfigurasi sisi Firebase Console (enable Email/Password, enable Google Sign-In, Firestore rules untuk koleksi `users`) dilakukan terpisah di luar kode.

## 2. Tujuan Milestone

- Mengganti dummy `customer_id` / `driver_id` dengan UID Firebase Auth asli.
- Menyediakan login & register via Email/Password.
- Menyediakan login via Google Sign-In.
- Menyediakan pemilihan role untuk user Google baru.
- Mengarahkan user ke home screen sesuai role (Customer / Driver / Admin).
- Menyimpan profil user di Firestore koleksi `users`.

## 3. Masalah dari Milestone Sebelumnya yang Diselesaikan

| Masalah sebelumnya | Solusi Milestone 4 |
|--------------------|--------------------|
| `customer_id` masih dummy `customer_test_001` | Diisi UID dari `AuthViewModel.currentUser.uid` |
| `driver_id` masih dummy `driver_test_001` | Diisi UID dari `AuthViewModel.currentUser.uid` |
| Belum ada Firebase Auth multi-role | Email/Password + Google Sign-In + role routing |
| `RoleSwitcherScreen` hanya untuk testing | Diganti SplashScreen → Login → home sesuai role |

## 4. Flow Autentikasi setelah Milestone 4

```
[SplashScreen]
   - loadCurrentUser() cek FirebaseAuth.instance.currentUser
        │
        ├── tidak ada user → [LoginScreen]
        └── ada user → home sesuai role:
                customer → CustomerHomeScreen
                driver   → DriverHomeScreen
                admin    → AdminHomeScreen
                role ""  → SelectRoleScreen

[LoginScreen]
   - Email + Password → signInWithEmailPassword()
   - "Login dengan Google" → signInWithGoogle()
   - Link "Daftar" → [RegisterScreen]
        │  sukses
        ▼
   pushReplacement → homeForRole(currentUser.role)

[RegisterScreen]
   - Nama, Email, Password, Konfirmasi Password
   - Dropdown role (customer / driver)
   - "Daftar" → registerWithEmailPassword()
        │  sukses (buat dokumen users/{uid})
        ▼
   pushReplacement → homeForRole(role)

[SelectRoleScreen]  (khusus user Google tanpa role)
   - Tampilkan nama & email akun Google
   - "Saya Customer" / "Saya Driver" → selectRole(role)
        │  sukses (update users/{uid})
        ▼
   pushReplacement → homeForRole(role)
```

## 5. Flow Home per Role

```
[CustomerHomeScreen]
   - AppBar: nama user + tombol logout
   - Tombol "Buat Order Baru" → CustomerCreateOrderScreen
       (createOrder kini pakai currentUser.uid sebagai customer_id)

[DriverHomeScreen]
   - AppBar: nama user + tombol logout
   - Body: DriverOrderListScreen
       (acceptOrder & watchActiveOrdersForDriver pakai currentUser.uid)

[AdminHomeScreen]
   - AppBar: nama user + tombol logout
   - Body: "Admin Dashboard — Coming Soon"

[Logout]
   - signOut() (Firebase + Google) → pushReplacement → LoginScreen
```

## 6. File yang Dibuat/Diubah

**File baru:**

- `lib/views/auth/splash_screen.dart` — cek auth saat start, redirect sesuai role.
- `lib/views/auth/login_screen.dart` — login email/password + Google.
- `lib/views/auth/register_screen.dart` — registrasi email/password + pilih role.
- `lib/views/auth/select_role_screen.dart` — pilih role untuk user Google baru.
- `lib/views/auth/role_home.dart` — helper `homeForRole(role)`.
- `lib/views/customer/customer_home_screen.dart` — home customer.
- `lib/views/driver/driver_home_screen.dart` — home driver.
- `lib/views/admin/admin_home_screen.dart` — home admin (placeholder).

**File diubah:**

- `lib/viewmodels/auth_viewmodel.dart` — ditimpa total dengan logic auth lengkap.
- `lib/models/user_model.dart` — tambah method `copyWith()`.
- `lib/main.dart` — tambah `AuthViewModel` ke provider, `home: SplashScreen`, hapus `RoleSwitcherScreen`.
- `lib/views/customer_create_order_screen.dart` — `customer_id` dari `AuthViewModel.currentUser.uid`.
- `lib/views/driver_order_list_screen.dart` — `driver_id` dari `AuthViewModel.currentUser.uid`.

## 7. Detail Teknis Perubahan

### `lib/viewmodels/auth_viewmodel.dart`

State: `UserModel? currentUser`, `bool isLoading`, `String? errorMessage`.

Method:

- `signInWithEmailPassword(email, password)` — login Firebase Auth, lalu load dokumen `users/{uid}` ke `currentUser`. Mengembalikan `bool`.
- `registerWithEmailPassword(email, password, name, role)` — buat akun, lalu tulis dokumen `users/{uid}` berisi `uid`, `email`, `name`, `role`, `created_at` (`serverTimestamp()`).
- `signInWithGoogle()` — alur Google Sign-In (classic API `GoogleSignIn().signIn()` + credential ke Firebase). Jika dokumen `users/{uid}` belum ada → set `currentUser` dengan `role` kosong (agar UI redirect ke SelectRoleScreen); jika sudah ada → load normal.
- `selectRole(role)` — update `users/{uid}` (merge) dan `currentUser.role` via `copyWith`.
- `signOut()` — `FirebaseAuth.signOut()` + `GoogleSignIn.signOut()`, reset `currentUser`.
- `loadCurrentUser()` — cek `FirebaseAuth.instance.currentUser`; jika ada, load dari Firestore (atau role kosong jika dokumen belum ada); jika tidak ada → `null`.

Error `FirebaseAuthException` dipetakan ke pesan Bahasa Indonesia yang ramah (`_mapAuthError`).

### `lib/models/user_model.dart`

- Menambahkan `copyWith()` agar `currentUser.role` bisa diperbarui setelah `selectRole` tanpa membuat ulang seluruh objek manual.

### `lib/main.dart`

- `MultiProvider` kini menyediakan `MapViewModel` **dan** `AuthViewModel`.
- `home` diubah dari `RoleSwitcherScreen` → `SplashScreen`.
- Class `RoleSwitcherScreen` dihapus.

### `lib/views/customer_create_order_screen.dart`

- Konstanta `kDummyCustomerId` dihapus.
- `createOrder` memakai `context.read<AuthViewModel>().currentUser?.uid ?? ''` sebagai `customer_id`.

### `lib/views/driver_order_list_screen.dart`

- Konstanta `kDummyDriverId` dihapus.
- `driver_id` diambil dari `AuthViewModel.currentUser.uid` dan disimpan ke field `_driverId` pada `initState`, dipakai untuk `acceptOrder()` dan `watchActiveOrdersForDriver()`.

### Home screens

- `CustomerHomeScreen` & `DriverHomeScreen` & `AdminHomeScreen` masing-masing punya AppBar (nama user + logout).
- `DriverHomeScreen` menampilkan `DriverOrderListScreen` sebagai body sesuai instruksi.
- `role_home.dart` menyediakan `homeForRole(role)` agar routing per-role tidak diduplikasi di tiap screen.

## 8. Struktur Firestore yang Dipakai

### Koleksi `users/{uid}`

| Field | Tipe | Keterangan |
|-------|------|------------|
| `uid` | string | UID Firebase Auth |
| `email` | string | email user |
| `name` | string | nama user |
| `role` | string | `customer` / `driver` / `admin` |
| `created_at` | timestamp | `serverTimestamp()` saat dokumen dibuat |

### Koleksi `orders` (perubahan relasi)

- `customer_id` kini berisi UID customer yang login (bukan dummy).
- `driver_id` kini berisi UID driver yang login saat mengambil order (bukan dummy).

> Koleksi lain (`pricing_config`, `weight_categories`, dll) tidak berubah pada milestone ini.

## 9. Konfigurasi Firebase Console (di luar kode)

- **Authentication** → aktifkan provider **Email/Password**.
- **Authentication** → aktifkan provider **Google**.
- **Firestore Rules** → izinkan akses koleksi `users` sesuai kebutuhan (mis. user hanya boleh baca/tulis dokumennya sendiri).

## 10. Cara Testing Manual

**Prasyarat:** provider Email/Password & Google sudah diaktifkan di Firebase Console.

1. Jalankan `flutter run` → muncul **SplashScreen** lalu **LoginScreen** (karena belum login).
2. **Register (Email/Password):**
   - Tap "Daftar di sini" → isi Nama, Email, Password, Konfirmasi Password, pilih role **Customer**.
   - Tap "Daftar" → masuk ke **CustomerHomeScreen** (AppBar menampilkan nama).
   - Cek Firestore: dokumen `users/{uid}` terbentuk dengan `role: customer`.
3. **Buat order sebagai customer:**
   - Tap "Buat Order Baru" → buat order seperti Milestone 3.
   - Cek Firestore: `customer_id` = UID customer (bukan dummy).
4. **Logout & register sebagai Driver:**
   - Logout dari AppBar → kembali ke LoginScreen.
   - Daftar akun baru dengan role **Driver** → masuk **DriverHomeScreen**.
   - Ambil order pending → `driver_id` di Firestore = UID driver (bukan dummy).
5. **Login Email/Password:**
   - Logout → login pakai akun yang tadi → diarahkan ke home sesuai role.
6. **Google Sign-In (akun baru):**
   - Di LoginScreen tap "Login dengan Google" → pilih akun Google baru.
   - Karena belum punya dokumen `users`, diarahkan ke **SelectRoleScreen**.
   - Pilih "Saya Customer" / "Saya Driver" → masuk home sesuai pilihan; dokumen `users/{uid}` terbentuk.
7. **Persistensi sesi:**
   - Tutup & buka ulang app → SplashScreen langsung mengarahkan ke home sesuai role tanpa login ulang.
8. **Validasi error:**
   - Login dengan password salah → SnackBar "Email atau password salah."
   - Register dengan email terdaftar → SnackBar "Email sudah terdaftar."
   - Register dengan konfirmasi password berbeda → pesan validasi di form.

## 11. Hasil Pengujian

- `flutter analyze` → **No issues found!**
- Register & login Email/Password berfungsi. ✔
- Google Sign-In + alur SelectRoleScreen berfungsi. ✔
- Routing home sesuai role (Customer / Driver / Admin). ✔
- `customer_id` & `driver_id` kini memakai UID asli. ✔
- Logout mengembalikan ke LoginScreen. ✔
- Sesi tetap tersimpan setelah restart app. ✔
- Fitur Milestone 1–3 tetap berjalan (create order, ambil order, map picker, harga otomatis, order aktif). ✔

## 12. Known Limitation

- Role `admin` belum bisa dibuat dari aplikasi (hanya `customer` & `driver` di register); admin diset manual di Firestore.
- `DriverHomeScreen` menampilkan `DriverOrderListScreen` (yang punya AppBar sendiri) sebagai body, sehingga muncul dua AppBar bertumpuk — perlu dirapikan di iterasi berikutnya.
- Belum ada fitur reset password / verifikasi email.
- Firestore Security Rules diatur manual di Console, belum disertakan dalam repo.
- Belum ada halaman profil / edit profil user.
- Belum ada customer tracking screen, proof of delivery, rating, chat, admin dashboard, dan notifikasi.
- Alamat order masih input manual sebagai label lokasi; belum ada geocoding.
- Tombol "Pick Up Pesanan" di MapDriverScreen masih hanya aktif jika driver dekat target (< 50 meter).

## 13. Next Improvement / Backlog

1. **Rapikan DriverHomeScreen** agar tidak ada dua AppBar (jadikan `DriverOrderListScreen` non-Scaffold atau gabungkan AppBar).
2. **Reset password & verifikasi email** lewat Firebase Auth.
3. **Halaman profil user** (lihat & edit nama, role, dsb).
4. **Customer Tracking Screen** — pantau posisi driver real-time.
5. **Seleksi Order Driver Berdasarkan Jarak (Haversine)** sesuai fitur inti proposal.
6. **Proof of Delivery, Chat, Rating, Notifikasi, dan Admin Dashboard.**
7. **Firestore Security Rules** versi final + dimasukkan ke repo.

## Status Milestone

> **SELESAI** — autentikasi multi-role (Email/Password + Google) berfungsi, dummy ID sudah diganti UID asli.
