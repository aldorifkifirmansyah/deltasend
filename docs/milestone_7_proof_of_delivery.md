# Milestone 7 — Proof of Delivery (Bukti Pengantaran)

## 1. Ringkasan Milestone

Milestone 7 menambahkan fitur **bukti pengantaran (proof of delivery)**: driver wajib mengambil **foto bukti** lewat kamera sebelum menyelesaikan order, dan customer dapat **melihat foto tersebut** saat memberi rating.

Saat order berstatus `delivering` dan driver berada **≤ 50 meter** dari lokasi tujuan, tombol aksi berubah menjadi **"Ambil Foto Bukti Pengantaran"**. Foto diambil via kamera native (`image_picker`), dikompresi (quality 20, maksimal 500×500 px), lalu dikonversi ke **base64 di memory** dan disimpan langsung ke field `proof_photo_url` pada dokumen order — **tanpa upload ke Firebase Storage**. Setelah foto terambil, tombol berubah menjadi **"Selesaikan Pesanan"** yang menandai order `completed`.

Di sisi customer, `RatingScreen` mendekode base64 (`Image.memory` + `base64Decode`) dan menampilkan foto pada bagian **"Bukti Pengantaran"** sebelum customer memberi rating.

> Fitur ini diimplementasikan oleh Aldo pada commit `b60b0c1` langsung ke `main` tanpa dokumentasi; dokumen ini melengkapinya secara retroaktif. Sudah diverifikasi end-to-end di device fisik (foto tersimpan & tampil normal di sisi customer).

## 2. Tujuan Milestone

- Memberi bukti visual bahwa paket benar-benar sampai di lokasi tujuan.
- Memaksa pengambilan foto sebagai syarat penyelesaian order (`delivering` → `completed`).
- Menampilkan bukti ke customer agar transparan sebelum memberi rating.
- Menjaga ukuran data tetap kecil lewat kompresi native sebelum dikonversi base64.

## 3. Flow Proof of Delivery

```
[MapDriverScreen — status order: delivering]
  - Jarak driver > 50 m  → tombol "Menuju Lokasi Tujuan" (disabled)
  - Jarak driver ≤ 50 m & belum ada foto → tombol "Ambil Foto Bukti Pengantaran"
      │  tap
      ▼
[_captureProofPhoto()]
  - image_picker buka kamera (quality 20, maxWidth/Height 500)
  - foto → readAsBytes → base64Encode → _base64Photo (di memory)
      │  foto tersimpan di state
      ▼
[Tombol berubah → "Selesaikan Pesanan"]
      │  tap
      ▼
[_completeOrderWithPhoto() → MapViewModel.completeOrderWithPhoto()]
  → OrderService.updateOrderWithProofPhoto(orderId, proofPhotoUrl: base64)
      - orders/{orderId}.proof_photo_url = base64
      - orders/{orderId}.status = completed
      - orders/{orderId}.updated_at = serverTimestamp()
      │
      ▼
[Order completed] → muncul di "Perlu Dirating" milik customer

[RatingScreen — sisi Customer]
  - proof_photo_url tidak kosong → tampil "Bukti Pengantaran" (Image.memory base64Decode)
  - proof_photo_url kosong → "Driver tidak menyertakan foto bukti."
```

## 4. File yang Dibuat/Diubah

**File diubah:**
- `android/app/src/main/AndroidManifest.xml` — tambah permission `CAMERA`.
- `lib/services/order_service.dart` — tambah `updateOrderWithProofPhoto()`.
- `lib/viewmodels/map_viewmodel.dart` — tambah `completeOrderWithPhoto()` + getter publik `distanceInMeters`.
- `lib/views/map_driver_screen.dart` — `_captureProofPhoto()`, `_completeOrderWithPhoto()`, dan logika tombol berdasarkan jarak & status foto.
- `lib/views/customer/rating_screen.dart` — tampilan "Bukti Pengantaran" (preview foto base64).
- `pubspec.yaml` — tambah `image_picker` dan `firebase_storage`.

> Tidak ada file Dart baru; fitur ditambahkan ke alur driver & rating yang sudah ada.

## 5. Detail Teknis

### `android/app/src/main/AndroidManifest.xml`
Menambahkan `<uses-permission android:name="android.permission.CAMERA" />` agar kamera dapat diakses.

### `lib/services/order_service.dart`
Method baru `updateOrderWithProofPhoto({orderId, proofPhotoUrl})`:
```dart
await _db.collection('orders').doc(orderId).update({
  'proof_photo_url': proofPhotoUrl,   // base64 string
  'status': OrderStatus.completed.name,
  'updated_at': FieldValue.serverTimestamp(),
});
```
Satu operasi update menyimpan foto sekaligus menandai order `completed`.

### `lib/viewmodels/map_viewmodel.dart`
- Getter publik `distanceInMeters` (mengekspos `_distanceInMeters`) agar UI bisa membandingkan jarak ke ambang 50 m.
- `completeOrderWithPhoto({orderId, base64Photo})` — memanggil `updateOrderWithProofPhoto`, lalu set `_currentOrder.status = completed`, reset `_isAtLocation`, bersihkan `_routePoints`, dan `notifyListeners()`. Error di-`rethrow` agar UI bisa menampilkan SnackBar.

### `lib/views/map_driver_screen.dart`
- State: `String _base64Photo = ''` dan `bool _isLoading = false`.
- `_captureProofPhoto()` — `ImagePicker().pickImage(source: camera, imageQuality: 20, maxWidth: 500, maxHeight: 500)`; jika foto ada → `readAsBytes()` → `base64Encode` → simpan ke `_base64Photo` via `setState`. Error ditangkap & SnackBar.
- `_completeOrderWithPhoto()` — guard `_base64Photo`/`orderId` kosong; set `_isLoading`, panggil `viewModel.completeOrderWithPhoto`, SnackBar sukses/gagal.
- **Logika tombol** saat status `delivering` (dievaluasi di `build()`):
  - jarak > 50 m → "Menuju Lokasi Tujuan" (disabled),
  - jarak ≤ 50 m & `_base64Photo` kosong → "Ambil Foto Bukti Pengantaran" (`_captureProofPhoto`),
  - `_base64Photo` terisi → "Selesaikan Pesanan" (`_completeOrderWithPhoto`),
  - tombol menampilkan `CircularProgressIndicator` saat `_isLoading`.

### `lib/views/customer/rating_screen.dart`
- Jika `order.proofPhotoUrl` tidak kosong → bagian **"Bukti Pengantaran"**: `ClipRRect` + `Image.memory(base64Decode(order.proofPhotoUrl), height: 200, fit: contain)` dengan `errorBuilder` ("Gagal memuat gambar bukti.").
- Jika kosong → teks italic **"Driver tidak menyertakan foto bukti."**

### `pubspec.yaml`
```yaml
firebase_storage: ^13.4.2   # ditambahkan, BELUM dipakai di kode
image_picker: ^1.2.2        # kamera + kompresi native
```

## 6. Struktur Firestore yang Dipakai

Tidak ada koleksi baru. Field pada dokumen `orders/{orderId}` yang dipakai:

| Field | Tipe | Keterangan |
|---|---|---|
| `proof_photo_url` | string (base64) | Foto bukti hasil enkode base64 (bukan URL Storage) |
| `status` | string | Diubah menjadi `completed` saat foto disimpan |
| `updated_at` | timestamp | `serverTimestamp()` saat penyelesaian |

> Walau field bernama `proof_photo_url`, isinya adalah **string base64** dari gambar, bukan URL.

## 7. Cara Testing Manual

**Prasyarat:** akun driver dengan order aktif berstatus `delivering`, di device fisik (kamera). Lokasi GPS bisa di-mock dekat titik tujuan.

1. Login sebagai **driver**, buka order aktif → `MapDriverScreen`.
2. Saat masih jauh (> 50 m) dari tujuan → tombol **"Menuju Lokasi Tujuan"** (nonaktif).
3. Dekati tujuan hingga ≤ 50 m → tombol berubah jadi **"Ambil Foto Bukti Pengantaran"**.
4. Tap → kamera native terbuka → ambil foto. Foto terkompres otomatis (quality 20, maks 500×500).
5. Tombol berubah jadi **"Selesaikan Pesanan"** → tap → muncul SnackBar "Pesanan berhasil diselesaikan"; status order jadi `completed`.
6. Cek Firestore `orders/{orderId}`: `proof_photo_url` berisi string base64 panjang, `status: completed`.
7. Login sebagai **customer** pemilik order → buka **RatingScreen** dari "Perlu Dirating" → bagian **"Bukti Pengantaran"** menampilkan foto.
8. (Negatif) Jika `proof_photo_url` kosong → muncul teks **"Driver tidak menyertakan foto bukti."**

## 8. Hasil Pengujian

- Diverifikasi **end-to-end di device fisik**: foto bukti tersimpan & tampil normal di sisi customer. ✔
- Tombol berubah sesuai jarak (≤ 50 m) dan status foto. ✔
- `updateOrderWithProofPhoto` menyimpan `proof_photo_url` (base64) + set `status: completed`. ✔
- Order completed muncul di "Perlu Dirating" customer. ✔
- Preview foto tampil di `RatingScreen`; fallback teks saat foto kosong. ✔

## 9. Known Limitation

- **Foto disimpan base64 LANGSUNG di dokumen Firestore** (bukan Firebase Storage), berisiko menabrak **limit dokumen 1 MB** bila foto besar — walau sudah dikompresi (quality 20, maks 500×500 px) sehingga risiko kecil untuk skala testing.
- **Package `firebase_storage` sudah ada di `pubspec.yaml` tapi belum dipakai di kode sama sekali** — kandidat migrasi ke depan.
- **Tidak ada preview / ambil ulang foto sebelum submit** — mengambil ulang berarti menimpa foto sebelumnya (tidak ada konfirmasi).
- **Pengecekan jarak dilakukan langsung di `build()` tanpa caching**, sehingga dievaluasi ulang setiap rebuild.

## 10. Next Improvement / Backlog

1. **Migrasi ke Firebase Storage** — upload foto ke Storage, simpan URL di `proof_photo_url` (hindari limit 1 MB & perkecil dokumen).
2. **Preview & retake** foto sebelum submit (konfirmasi sebelum menyelesaikan order).
3. **Caching jarak** / pindahkan logika proximity ke ViewModel agar tidak dihitung ulang di `build()`.
4. **Watermark / timestamp + lokasi** pada foto bukti untuk validitas.
5. Integrasi dengan Seleksi Driver by Jarak (Haversine), Admin Dashboard, dan Notifikasi.

## Status

> **SELESAI** — Proof of Delivery.
> Diimplementasikan pada commit `b60b0c1` (oleh Aldo) di `main`; dokumentasi dilengkapi retroaktif.
