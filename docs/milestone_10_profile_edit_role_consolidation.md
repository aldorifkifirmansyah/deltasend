# Milestone 10 — Profile Edit Name & Role-Selection Consolidation

## 1. Ringkasan Milestone

Milestone 10 mencakup tiga hal yang saling berkaitan di alur akun:

1. **Edit Nama Profile** — customer bisa mengubah nama tampilannya langsung dari tab Profile; perubahan tersimpan ke `users/{uid}.name` dan langsung tampil di UI.
2. **Konsolidasi Role-Selection** — dua screen pemilihan peran yang sebelumnya terpisah (dan membingungkan) disatukan menjadi satu `RoleSelectionScreen` ber-UI card modern, dengan parameter `isExistingAuthUser` untuk membedakan dua use-case (buat akun baru vs update role akun yang sudah login).
3. **Fix crash `_dependents.isEmpty`** saat menyimpan edit nama — disebabkan timing dispose `TextEditingController` yang bertabrakan dengan animasi tutup dialog + rebuild dari `notifyListeners()`.

## 2. Tujuan Milestone

- Memberi customer kontrol atas nama profilnya tanpa perlu intervensi manual di Firestore.
- Menghilangkan duplikasi/kebingungan dua role screen dengan logic berbeda.
- Memastikan flow edit nama mulus dan bebas crash, walau dibuka-tutup berulang cepat.

## 3. Masalah yang Diselesaikan

| Masalah | Solusi |
|---|---|
| Nama user tidak bisa diubah dari app | `AuthViewModel.updateUserName()` + tombol edit di Profile |
| Dua role screen (`register_role_screen` & `select_role_screen`) dengan logic beda → rawan salah pakai | Satu `RoleSelectionScreen(isExistingAuthUser)` |
| Crash `'_dependents.isEmpty': is not true` setelah "Simpan" edit nama | Ekstrak `EditNameDialog` (controller dikelola route-nya sendiri), async dipindah ke caller |
| Pensil edit menggeser nama dari posisi center | Pensil dipindah ke `Stack` + `Positioned` (pojok kanan-atas card) |

## 4. Flow

### Edit Nama
```
[Profile tab] tap ikon pensil (pojok kanan-atas card)
      │
      ▼
showDialog → [EditNameDialog]  (kelola controller sendiri, HANYA pop teks)
      │  pop(newName)
      ▼
[caller] dialog sudah tertutup → context.read<AuthViewModel>().updateUserName(newName)
      → users/{uid}.update({name}) + currentUser.copyWith(name) + notifyListeners()
      │
      ▼
Profile (context.watch) rebuild → nama baru tampil + SnackBar "Nama berhasil diperbarui"
```

### Role Selection (konsolidasi)
```
[LoginScreen] "Sign up"
      └→ RoleSelectionScreen(isExistingAuthUser: false)
            tap role → RegisterScreen(role)        // buat akun baru (belum auth)

[Google sign-in new-user] role == '' → homeForRole('')
      └→ RoleSelectionScreen(isExistingAuthUser: true)
            tap role → auth.selectRole(role)        // update role uid yg sudah auth
                     → homeForRole(role)
```

## 5. File yang Dibuat/Diubah

**File baru:**
- `lib/widgets/edit_name_dialog.dart` — dialog edit nama (StatefulWidget, controller mandiri).
- `lib/views/auth/role_selection_screen.dart` — role screen tunggal hasil konsolidasi.

**File diubah:**
- `lib/viewmodels/auth_viewmodel.dart` — tambah `updateUserName()`.
- `lib/views/customer/customer_home_screen.dart` — tombol edit nama (Stack+Positioned), `_showEditNameDialog()` versi aman.
- `lib/views/auth/login_screen.dart` — arahkan "Sign up" ke `RoleSelectionScreen()`.
- `lib/views/auth/role_home.dart` — default case → `RoleSelectionScreen(isExistingAuthUser: true)`.

**File dihapus:**
- `lib/views/auth/register_role_screen.dart` (lama, create-account-flow).
- `lib/views/auth/select_role_screen.dart` (lama, update-role-flow).

## 6. Detail Teknis

### `lib/viewmodels/auth_viewmodel.dart`
`updateUserName(String name)` → `Future<bool>`:
- guard `currentUser != null` & nama tidak kosong (trim),
- `users/{uid}.update({'name': trimmed})`,
- `_currentUser = user.copyWith(name: trimmed)` + `notifyListeners()`,
- error → set `errorMessage`, return `false`. Pakai `_setLoading` seperti method auth lain.

### `lib/widgets/edit_name_dialog.dart`
- `EditNameDialog(initialName)` — **StatefulWidget**; membuat `TextEditingController` di `initState`, **dispose di `State.dispose`** (jadi baru dilepas saat route dialog benar-benar hilang).
- Tombol "Simpan" / `onSubmitted` hanya `Navigator.pop(context, teks)` — **tidak ada async, Firestore, atau Provider** di dalam dialog.

### `lib/views/customer/customer_home_screen.dart`
- `_showEditNameDialog()`: `await showDialog(... EditNameDialog ...)` → cek `mounted` & validitas → **baru** `context.read<AuthViewModel>().updateUserName()` → SnackBar. Update (yang memicu rebuild via `notifyListeners`) dijalankan **setelah** dialog tertutup.
- Card profile dibungkus `Stack`; nama kembali jadi `Text` ter-center; ikon pensil di `Positioned(top: 4, right: 4)` → nama center tidak terganggu lebar ikon.

### `lib/views/auth/role_selection_screen.dart`
- `RoleSelectionScreen({bool isExistingAuthUser = false})`, StatefulWidget (`_busy` guard anti double-submit).
- `isExistingAuthUser == false` → tap role → `RegisterScreen(role)`; footer "Already have account? Sign in".
- `isExistingAuthUser == true` → tap role → `selectRole(role)` → `pushAndRemoveUntil(homeForRole(role))`; tanpa footer.
- UI card (`_RoleCard`, `_GradientBorderCard`) diadopsi dari screen "Choose your role" lama.

### `role_home.dart` / `login_screen.dart`
- `login_screen` "Sign up" → `RoleSelectionScreen()` (default new-account).
- `role_home.homeForRole` default (role `''`) → `RoleSelectionScreen(isExistingAuthUser: true)`. Ini titik masuk jalur Google new-user (auth_viewmodel sendiri tidak menavigasi; `signInWithGoogle` mengembalikan role `''` → `homeForRole`).

## 7. Struktur Firestore yang Dipakai

| Dokumen | Field | Operasi |
|---|---|---|
| `users/{uid}` | `name` | `update` saat edit nama |
| `users/{uid}` | `role` | `set(..., merge: true)` saat `selectRole` (Google new-user) |

> **Anti-duplikat:** `selectRole` memakai `_currentUser!.uid` (uid sama dari sesi sign-in) dengan `set(merge: true)` → dokumen yang sama di-update, **tidak** membuat dokumen kedua.

## 8. Cara Testing Manual

**Edit Nama:**
1. Login customer → tab **Profile** → tap ikon pensil (pojok kanan-atas card).
2. Ubah nama → **Simpan** → dialog tertutup mulus (tanpa crash), SnackBar sukses, nama baru langsung tampil tanpa restart.
3. Cek Firestore `users/{uid}.name` ter-update.
4. Ulangi buka-tutup dialog cepat 2–3× berturut → tidak ada race/crash.
5. Cek tampilan: nama tetap center, pensil di pojok card, layout rapi.

**Role Selection:**
6. Dari Login → "Sign up" → muncul `RoleSelectionScreen` (card style) → pilih role → masuk **RegisterScreen** dengan role tsesuai.
7. Sign-up email/password biasa → role selection pakai screen yang sama.
8. Sign-up akun **Google baru** → setelah auth, diarahkan ke role selection (card style yang sama) → pilih role → masuk home sesuai role.
9. Pastikan **uid sama persis** sebelum & sesudah pilih role (cek di Firestore: hanya 1 dokumen `users/{uid}`, tidak terduplikat).

## 9. Hasil Pengujian

- `flutter analyze` → **No issues found** pada file yang diubah/dibuat (sisa lint hanya pre-existing `unnecessary_underscores`/`withOpacity` di file lain).
- Crash `_dependents.isEmpty` **hilang** setelah ekstraksi `EditNameDialog` — verifikasi termasuk skenario buka-tutup cepat berulang. ✔
- Nama ter-update di Firestore & UI refresh real-time (tanpa restart). ✔
- Tampilan: nama center, pensil di pojok kanan-atas card. ✔
- Satu role screen melayani kedua jalur (new-account & Google update-role); tidak ada duplikasi dokumen user. ✔

## 10. Known Limitation

- Edit profile baru tersedia di sisi **customer** (tab Profile). **Driver tidak punya** screen profil (driver home = AppBar nama + logout + daftar order), jadi belum ada edit nama untuk driver.
- Yang bisa diedit baru **nama**; email, role, dan foto profil belum bisa diubah dari app.
- `RoleSelectionScreen(isExistingAuthUser: true)` belum punya opsi "keluar/batal" — user Google baru wajib memilih salah satu role untuk lanjut.
- Tidak ada validasi panjang/format nama selain "tidak boleh kosong".

## 11. Next Improvement / Backlog

1. Profile screen untuk **driver** + edit nama yang sama (reuse `EditNameDialog`).
2. Edit foto profil (integrasi Firebase Storage), edit data lain.
3. Opsi sign-out/ganti akun di `RoleSelectionScreen` untuk jalur Google.
4. Validasi nama lebih ketat (panjang min/maks, karakter).
5. FCM push notif, Admin Dashboard, badge unread chat.

## Status

> **SELESAI** — Profile Edit Name & Role-Selection Consolidation (analyze bersih; edit nama terverifikasi bebas crash).
