# Milestone 5 — Customer Tracking Screen

## 1. Ringkasan Milestone

Milestone 5 menambahkan **Customer Tracking Screen** — layar yang memungkinkan customer memantau posisi driver secara real-time di peta setelah order diterima (status `pickingUp` atau `delivering`).

Sebelum milestone ini, ketika driver menerima order, `CustomerWaitingScreen` secara keliru mengarahkan customer ke `MapDriverScreen` (screen navigasi milik driver). Hal ini menyebabkan HP customer ikut melakukan GPS tracking dan menimpa data `driver_lat`/`driver_lng` di Firestore dengan posisi GPS customer — bug yang merusak data lokasi driver.

Milestone ini menggantikan navigasi keliru tersebut dengan `CustomerTrackingScreen` yang dirancang khusus untuk sisi customer: hanya **membaca** posisi driver dari Firestore (read-only), menampilkannya di peta, dan memantau perubahan status order secara real-time.

## 2. Tujuan Milestone

- Membuat `CustomerTrackingScreen` — peta real-time posisi driver dari sudut pandang customer.
- Fix bug navigasi di `CustomerWaitingScreen`: ganti tujuan push dari `MapDriverScreen` ke `CustomerTrackingScreen`.
- Menambahkan `watchOrder(orderId)` stream ke `OrderService` untuk listen satu dokumen order secara real-time.
- Menampilkan status order, posisi driver, dan rute driver → tujuan di peta customer.
- Menangani state `completed` (pesanan tiba) dengan pesan konfirmasi.

## 3. Masalah dari Milestone Sebelumnya yang Diselesaikan

| Masalah | Solusi Milestone 5 |
|---|---|
| Customer dikirim ke `MapDriverScreen` setelah driver accept | Diganti ke `CustomerTrackingScreen` |
| GPS customer menimpa `driver_lat`/`driver_lng` di Firestore | `CustomerTrackingScreen` hanya baca Firestore, tidak start GPS |
| Tidak ada cara customer memantau driver di peta | `CustomerTrackingScreen` dengan marker driver real-time |

## 4. Flow Customer setelah Milestone 5

```
[CustomerCreateOrderScreen]
  - Customer isi form + pilih lokasi di peta
  - Tap "Buat Order"
      │
      ▼
[CustomerWaitingScreen]
  - Radar animation, tunggu driver accept
  - Countdown 10 detik cancel manual
  - System timeout 60 detik → order di-cancel otomatis
  - Listen Firestore: order.driver_id berubah dari null → ada
      │  driver accept (driverAssigned state)
      ▼
[CustomerTrackingScreen]  ← BARU
  - Peta flutter_map + OSM
  - Marker driver (motor, hijau) — update real-time dari Firestore driver_lat/driver_lng
  - Marker tujuan (flag, merah) — dari dest_lat/dest_lng order
  - Polyline rute driver → tujuan (recalculate tiap driver bergerak > 50 m)
  - Panel bawah: status order (chip), alamat tujuan, estimasi jarak
  - Jika driver_lat/driver_lng null → "Menunggu driver bergerak..."
  - Jika status = completed → "Pesanan telah tiba!" + tombol "Kembali ke Home"
```

## 5. File yang Dibuat/Diubah

**File baru:**
- `lib/views/customer/customer_tracking_screen.dart` — tracking screen customer.

**File diubah:**
- `lib/services/order_service.dart` — tambah method `watchOrder(String orderId)`.
- `lib/views/customer_waiting_screen.dart` — fix navigasi: ganti `MapDriverScreen` → `CustomerTrackingScreen`.

## 6. Detail Teknis

### `lib/services/order_service.dart`

Tambah method baru:

```dart
Stream<OrderModel?> watchOrder(String orderId) {
  return _db
      .collection('orders')
      .doc(orderId)
      .snapshots()
      .map((doc) => doc.exists ? OrderModel.fromFirestore(doc) : null);
}
```

### `lib/views/customer_waiting_screen.dart`

Ganti di `_handleViewModelUpdate()`:

```dart
// SEBELUM (bug):
builder: (_) => MapDriverScreen(orderId: widget.orderId),

// SESUDAH (fix):
builder: (_) => CustomerTrackingScreen(orderId: widget.orderId),
```

### `lib/views/customer/customer_tracking_screen.dart`

- `StatefulWidget` dengan parameter `orderId`.
- Gunakan `StreamBuilder<OrderModel?>` dari `orderService.watchOrder(orderId)`.
- Peta `flutter_map` + tile OpenStreetMap.
- Track posisi driver terakhir dengan `LatLng? _lastDriverPos` — hitung ulang rute via `RoutingService.getRoute()` jika driver bergerak > 50 meter.
- Tidak menggunakan `MapViewModel` dan tidak memanggil `Geolocator` — screen ini hanya read Firestore.

## 7. Struktur Firestore yang Dipakai

Field yang dibaca oleh `CustomerTrackingScreen` dari dokumen `orders/{orderId}`:

| Field | Keterangan |
|---|---|
| `driver_lat` / `driver_lng` | Posisi driver terkini (update oleh `MapViewModel` milik driver) |
| `dest_lat` / `dest_lng` | Koordinat tujuan (tetap, tidak berubah) |
| `dest_address` | Label alamat tujuan untuk ditampilkan di panel |
| `status` | Dipantau untuk deteksi `completed` |

## 8. Known Limitation

- Polyline rute dari posisi driver ke tujuan menggunakan OSRM publik — bisa lambat atau gagal jika server OSRM sedang down.
- `CustomerTrackingScreen` tidak menampilkan posisi customer sendiri (hanya driver).
- Jika driver mematikan app (GPS berhenti update), posisi driver di peta customer akan berhenti di posisi terakhir — tidak ada indikator "driver offline".
- Auth (`AuthViewModel`) belum terintegrasi di branch ini — akan tersambung otomatis setelah PR Milestone 4 di-merge ke main.

## 9. Hasil Pengujian

- `flutter analyze` pada file Milestone 5 (`customer_tracking_screen.dart`, `order_service.dart`, `customer_waiting_screen.dart`) → **tidak ada issue**.
- `watchOrder(orderId)` berhasil men-stream satu dokumen order secara real-time. ✔
- Navigasi `CustomerWaitingScreen` saat `driverAssigned` kini mengarah ke `CustomerTrackingScreen` (bukan lagi `MapDriverScreen`). ✔
- `CustomerTrackingScreen` menampilkan marker driver (hijau) & tujuan (merah), serta polyline rute biru. ✔
- Rute dihitung ulang hanya saat driver bergerak > 50 meter dari posisi kalkulasi terakhir (`_lastRouteCalcPos` + `Distance` dari latlong2). ✔
- Saat `driver_lat`/`driver_lng` null → panel menampilkan "Menunggu driver bergerak...". ✔
- Saat status `completed` → panel menampilkan "Pesanan telah tiba!" + tombol "Kembali ke Home" (`popUntil` ke route pertama). ✔
- Screen hanya membaca Firestore — tidak memanggil `Geolocator`/GPS dan tidak memakai `MapViewModel`. ✔

> **Catatan known issue terpisah (di luar scope Milestone 5):** `flutter analyze` global saat ini melaporkan 2 error pre-existing di `lib/viewmodels/auth_viewmodel.dart` karena `google_sign_in` sudah di-upgrade ke `^7.2.0` sementara kode auth masih memakai API lama (`GoogleSignIn()` + `.signIn()`). Error ini sudah ada di branch sebelum pengerjaan Milestone 5 dan tidak berkaitan dengan tracking screen. Perlu migrasi `google_sign_in` v7 secara terpisah.

## 10. Next Improvement / Backlog

1. Migrasi `signInWithGoogle()` ke API `google_sign_in` 7.x (`GoogleSignIn.instance` + `initialize()` + `authenticate()`) agar `flutter analyze` bersih.
2. Proof of Delivery — driver upload foto bukti pengiriman.
3. Rating Driver — customer beri rating setelah order selesai.
4. Push Notification — notifikasi order diterima, status berubah.
5. Admin Dashboard — kelola harga, kategori berat, lihat data order/user.
6. Chat Customer-Driver — pesan per order.

## Status

> **SELESAI** — Customer Tracking Screen.
> Branch: `feature/customer-tracking-screen` (dari `main`).
