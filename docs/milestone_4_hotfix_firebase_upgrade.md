# Milestone 4 Hotfix — Firebase Package Upgrade & Double AppBar Fix

## 1. Ringkasan

Setelah implementasi Milestone 4 selesai, ditemukan dua masalah saat pengujian pertama:

1. **Double AppBar** pada halaman Driver — `DriverHomeScreen` (punya AppBar sendiri) membungkus `DriverOrderListScreen` yang juga masih punya `Scaffold` + AppBar sendiri, sehingga muncul dua AppBar bertumpuk.
2. **Crash saat register/login** dengan error Pigeon type mismatch: `type 'List<Object?>' is not a subtype of type 'PigeonUserDetails?'` — disebabkan oleh ketidakcocokan versi antara package `firebase_auth`/`firebase_core` yang lama dengan Kotlin 2.2.20 dan AGP 8.11.1 yang sudah menggunakan Pigeon API generasi baru.

Kedua masalah diselesaikan tanpa mengubah logika bisnis atau kode fitur.

## 2. Masalah dan Solusi

### Masalah 1 — Double AppBar Driver

**Root cause:** `DriverOrderListScreen.build()` masih return `Scaffold` dengan `AppBar("Order Driver")` padahal ia sudah selalu dipakai sebagai `body:` di dalam `Scaffold` milik `DriverHomeScreen`.

**Dampak:** Dua AppBar bertumpuk secara visual. Lebih dari kosmetik — dua Scaffold nested dapat menyebabkan `SnackBar` muncul di posisi salah dan Navigator stack berperilaku tidak terduga.

**Fix:** Hapus `Scaffold` + `AppBar` dari `DriverOrderListScreen.build()`. Widget ini sekarang langsung return `StreamBuilder`, karena Scaffold dan AppBar sudah disediakan oleh `DriverHomeScreen`.

**File diubah:** `lib/views/driver_order_list_screen.dart`

---

### Masalah 2 — Pigeon Type Mismatch (Firebase Auth Crash)

**Root cause:** Version mismatch antara layer Dart dan layer Android Native:

| Komponen | Versi Lama | Catatan |
|---|---|---|
| `firebase_auth` | 4.16.0 | Pigeon schema lama |
| `firebase_core` | 2.32.0 | Pigeon schema lama |
| Kotlin | 2.2.20 | Compile dengan Pigeon schema baru |
| AGP | 8.11.1 | Compile dengan Pigeon schema baru |

Sisi Dart mengharapkan `PigeonUserDetails?`, tapi sisi Android Native (dikompilasi dengan Kotlin/AGP baru) mengirim `List<Object?>`. Crash terjadi tepat setelah Firebase server berhasil mengautentikasi (backend OK, crash hanya di layer bridging Flutter↔Android).

**Fix:** Upgrade semua package Firebase ke generasi terbaru yang menggunakan Pigeon schema yang sama dengan Kotlin/AGP modern.

## 3. Perubahan File

### `pubspec.yaml`

```yaml
# Sebelum
firebase_core: ^2.10.0
firebase_auth: ^4.4.0
cloud_firestore: ^4.5.0
google_sign_in: ^5.4.0

# Sesudah
firebase_core: ^4.0.0
firebase_auth: ^6.0.0
cloud_firestore: ^6.0.0
google_sign_in: ^6.2.2
```

### `android/settings.gradle.kts`

```kotlin
# Sebelum
id("com.google.gms.google-services") version("4.3.15") apply false

# Sesudah
id("com.google.gms.google-services") version("4.4.2") apply false
```

### `android/app/build.gradle.kts`

```kotlin
# Sebelum
minSdk = flutter.minSdkVersion  # default 21

# Sesudah
minSdk = 23  # firebase_core 4.x mensyaratkan minimum API 23
```

### `lib/views/driver_order_list_screen.dart`

- Hapus `Scaffold` + `AppBar` dari method `build()`
- `build()` sekarang langsung return `StreamBuilder<List<OrderModel>>(...)`

## 4. Versi Package Sesudah Upgrade

| Package | Versi Constraint | Keterangan |
|---|---|---|
| `firebase_core` | `^4.0.0` | Pigeon v2 — kompatibel dengan Kotlin 2.x & AGP 8.x |
| `firebase_auth` | `^6.0.0` | Pigeon v2 — fix type mismatch |
| `cloud_firestore` | `^6.0.0` | Sesuai generasi firebase_core 4.x |
| `google_sign_in` | `^6.2.2` | API tidak berubah dari sisi kode |
| google-services plugin | `4.4.2` | Diperlukan untuk firebase_core 4.x |

**Kode di `auth_viewmodel.dart` tidak perlu diubah** — API `firebase_auth` v6 sepenuhnya backward-compatible dengan v4 untuk method yang dipakai (`signInWithEmailAndPassword`, `createUserWithEmailAndPassword`, `signInWithCredential`, `signOut`, `currentUser`).

## 5. Prasyarat Firebase Console yang Sudah Diselesaikan

| Item | Status |
|---|---|
| SHA-1 debug fingerprint didaftarkan ke Firebase Project Settings | ✅ |
| `google-services.json` di-download ulang setelah SHA-1 ditambahkan | ✅ |
| Email/Password Sign-In diaktifkan di Firebase Authentication | ✅ |
| Firestore Rules mengizinkan user terauthentikasi baca/tulis | ✅ |

## 6. Cara Build Ulang Setelah Upgrade

```bash
flutter clean
flutter pub get
flutter run
```

`flutter clean` wajib setelah upgrade major version — tanpa ini, cache Gradle lama masih memakai `.jar` versi lama dan crash tetap terjadi.

## 7. Hasil Pengujian

- `flutter analyze` → **No issues found**
- Register customer baru via Email/Password → sukses, data tersimpan di Firestore `users/{uid}` ✔
- Login dengan email/password yang sudah terdaftar → sukses, masuk home sesuai role ✔
- Persistent session (kill app → buka lagi) → langsung masuk home tanpa login ulang ✔
- Logout → kembali ke Login screen ✔
- Driver home screen → hanya satu AppBar (tidak ada double AppBar) ✔
- `customer_id` di Firestore adalah UID asli (bukan `customer_test_001`) ✔
- `driver_id` di Firestore adalah UID asli (bukan `driver_test_001`) ✔

## 8. Known Limitation

- Google Sign-In belum diuji penuh (memerlukan SHA-1 di Firebase Console sudah selesai, tapi flow end-to-end belum diverifikasi).
- Admin dashboard masih placeholder — untuk membuat user admin, role harus diset manual langsung di Firestore.
- Belum ada Firestore Rules berbasis role (rules saat ini mengizinkan semua user terauthentikasi akses semua koleksi).

## Status

> **SELESAI** — Auth multi-role berfungsi dengan UID asli. Siap lanjut Milestone 5.
