# Milestone 1 — Driver Order List & Accept Order Flow

## 1. Ringkasan Milestone

Milestone 1 berfokus pada alur kerja **role Driver** tahap awal: bagaimana seorang driver dapat melihat daftar order yang masih berstatus `pending`, mengambil salah satu order, dan langsung diarahkan ke halaman peta untuk memulai proses pengantaran.

Pada milestone ini dibuat halaman baru **DriverOrderListScreen** sebagai titik masuk aplikasi (sementara, untuk kebutuhan testing). Order ditampilkan secara *real-time* dari Cloud Firestore, dan ketika driver menekan tombol **"Ambil Order"**, order tersebut langsung di-update di Firestore lalu aplikasi berpindah ke **MapDriverScreen** dengan `orderId` yang diteruskan secara dinamis.

## 2. Tujuan Fitur

- Memberikan driver daftar order yang tersedia (`status = pending`) secara langsung dari database.
- Menyediakan aksi sederhana bagi driver untuk **mengambil order** dengan satu tombol.
- Memastikan saat order diambil, data di Firestore terupdate konsisten (`driver_id`, `status`, `updated_at`).
- Menghubungkan alur daftar order ke fitur peta/tracking yang sudah ada, dengan `orderId` dinamis (bukan hardcoded).
- Menyiapkan fondasi flow Driver agar mudah dilanjutkan ke milestone berikutnya (auth, seleksi driver berdasarkan jarak, dsb).

## 3. Scope Fitur yang Dikerjakan

Fitur yang **termasuk** dalam Milestone 1:

- Halaman daftar order pending untuk driver (`DriverOrderListScreen`).
- Pengambilan data order secara real-time via `OrderService.watchPendingOrders()`.
- Aksi "Ambil Order" via `OrderService.acceptOrder()`.
- Navigasi dinamis ke `MapDriverScreen` dengan `orderId`.
- Penghapusan hardcoded `fetchOrderData('order_test_123')` dari `MapDriverScreen`.
- Integrasi dengan fitur map/tracking yang sudah ada (marker, polyline OSRM, jarak & estimasi).

Fitur yang **TIDAK** termasuk (lihat juga *Known Limitation*):

- Autentikasi / login multi-role.
- Pembuatan order oleh Customer.
- Screen Admin & Customer.
- Kamera proof of delivery, chat, rating, dan push notification.

## 4. Flow Aplikasi

```
[App dibuka]
      │
      ▼
[DriverOrderListScreen]
  - StreamBuilder mendengarkan OrderService.watchPendingOrders()
  - Menampilkan semua order dengan status "pending" secara real-time
      │
      │  Driver menekan tombol "Ambil Order" pada salah satu order
      ▼
[OrderService.acceptOrder(orderId, "driver_test_001")]
  - driver_id      → "driver_test_001"
  - status         → "pending"  ➜  "pickingUp"
  - updated_at     → serverTimestamp()
      │
      │  Order tidak lagi "pending" → otomatis hilang dari daftar (real-time)
      ▼
[Navigasi push → MapDriverScreen(orderId: <orderId>)]
      │
      ▼
[MapDriverScreen]
  - fetchOrderData(orderId) membaca order dari Firestore
  - Membaca GPS / current location
  - Menampilkan marker driver (hijau) & target (merah)
  - Menampilkan route/polyline OSRM
  - Menampilkan jarak & estimasi waktu
```

## 5. Struktur File yang Terlibat

```
lib/
├── main.dart                          # entry point, sementara → DriverOrderListScreen
├── views/
│   ├── driver_order_list_screen.dart  # [BARU] daftar order pending + tombol Ambil Order
│   └── map_driver_screen.dart         # [DIUBAH] terima orderId via constructor
├── services/
│   └── order_service.dart             # [PENDUKUNG] logic Firestore (watch & accept)
├── models/
│   └── order_model.dart               # [PENDUKUNG] mapping data order Firestore
└── viewmodels/
    └── map_viewmodel.dart             # [PENDUKUNG] state map/tracking
```

**File yang berubah di Milestone 1:**

- `lib/views/driver_order_list_screen.dart` (baru)
- `lib/views/map_driver_screen.dart` (diubah)
- `lib/main.dart` (diubah)

**File pendukung yang sudah dibuat sebelumnya:**

- `lib/services/order_service.dart`
- `lib/models/order_model.dart`
- `lib/viewmodels/map_viewmodel.dart`

## 6. Detail Perubahan per File

### `lib/views/driver_order_list_screen.dart` — **(BARU)**

Halaman baru yang menampilkan daftar order pending.

- Menggunakan `StreamBuilder<List<OrderModel>>` yang mendengarkan `OrderService.watchPendingOrders()` sehingga daftar selalu *real-time*.
- Menangani tiga kondisi tampilan: **loading** (spinner), **error** (pesan kesalahan), dan **kosong** (ikon inbox + "Belum ada order pending").
- Setiap order ditampilkan dalam bentuk `Card` berisi: deskripsi barang, alamat jemput → alamat tujuan, jarak, dan biaya.
- Tombol **"Ambil Order"** memanggil `OrderService.acceptOrder()` dengan dummy `driver_id = "driver_test_001"`, lalu melakukan navigasi ke `MapDriverScreen(orderId: ...)`.
- Saat proses pengambilan berjalan, tombol berubah menjadi *loading spinner* dan dinonaktifkan untuk mencegah double-tap.
- Dummy driver id disimpan dalam konstanta `kDummyDriverId` agar mudah diganti nanti.

### `lib/views/map_driver_screen.dart` — **(DIUBAH)**

- Constructor sekarang menerima parameter wajib: `required String orderId`.
- Pemanggilan order tidak lagi hardcoded. Sebelumnya `fetchOrderData('order_test_123')`, sekarang `fetchOrderData(widget.orderId)`.
- Tidak ada perubahan pada logic map/tracking — fitur peta tetap berjalan seperti sebelumnya.

### `lib/main.dart` — **(DIUBAH)**

- Properti `home:` pada `MaterialApp` diarahkan ke `DriverOrderListScreen` (sementara, untuk kebutuhan testing).
- Provider `MapViewModel` tetap dipasang di root sehingga `MapDriverScreen` yang di-*push* dari daftar order tetap dapat mengakses ViewModel.

## 7. Struktur Firestore yang Dipakai

Koleksi utama yang digunakan pada milestone ini adalah **`orders`**. Berikut field yang dibaca/ditulis oleh flow ini (berdasarkan mapping di `OrderModel`):

| Field | Tipe | Keterangan |
|-------|------|------------|
| `customer_id` | string | ID customer pemilik order |
| `driver_id` | string \| null | Diisi `"driver_test_001"` saat order diambil |
| `weight_category_id` | string \| null | Kategori berat barang |
| `pickup_lat` | number | Latitude lokasi jemput |
| `pickup_lng` | number | Longitude lokasi jemput |
| `dest_lat` | number | Latitude lokasi tujuan |
| `dest_lng` | number | Longitude lokasi tujuan |
| `driver_lat` | number | Latitude posisi driver (diupdate saat tracking) |
| `driver_lng` | number | Longitude posisi driver (diupdate saat tracking) |
| `pickup_address` | string | Alamat teks lokasi jemput |
| `dest_address` | string | Alamat teks lokasi tujuan |
| `item_description` | string | Deskripsi barang |
| `distance_km` | number | Jarak order (km) |
| `total_cost` | number | Total biaya |
| `proof_photo_url` | string | URL foto bukti pengiriman (belum dipakai milestone ini) |
| `status` | string | `pending` → `pickingUp` → `delivering` → `completed` |
| `created_at` | timestamp | Waktu order dibuat (dipakai untuk sorting daftar) |
| `updated_at` | timestamp | Diperbarui setiap perubahan status / lokasi |

**Operasi Firestore pada milestone ini:**

- **Read (stream):** `orders` di-*filter* `where status == "pending"` dan diurutkan berdasarkan `created_at` (terbaru di atas).
- **Update (accept order):** dokumen order di-update `driver_id`, `status = "pickingUp"`, dan `updated_at = serverTimestamp()`.

## 8. Cara Testing Manual di Android

1. **Siapkan data uji di Firebase Console.** Buat / ubah minimal satu dokumen pada koleksi `orders` dengan `status: "pending"` dan field koordinat (`pickup_lat`, `pickup_lng`, `dest_lat`, `dest_lng`) serta field pendukung (`pickup_address`, `dest_address`, `item_description`, `distance_km`, `total_cost`, `created_at`).
2. **Sambungkan HP Android** (USB debugging aktif), lalu cek perangkat terdeteksi: `flutter devices`.
3. **Jalankan aplikasi:** `flutter run` dan pilih device Android.
4. **Verifikasi alur:**
   - Aplikasi membuka halaman **"Order Tersedia"** berisi daftar order pending. Jika kosong, muncul ikon inbox + teks "Belum ada order pending".
   - Tekan **"Ambil Order"** → tombol berubah menjadi spinner → aplikasi otomatis berpindah ke **MapDriverScreen**.
   - Cek di Firebase Console: dokumen order tadi kini memiliki `driver_id = "driver_test_001"`, `status = "pickingUp"`, dan `updated_at` terbarui. Order otomatis hilang dari daftar karena bukan lagi `pending`.
   - Di MapDriverScreen: izinkan permission lokasi → muncul marker driver (hijau), marker target (merah), polyline rute OSRM, serta kartu jarak & estimasi waktu.
5. **Cek navigasi balik:** tekan back dari peta → kembali ke daftar order; ambil order pending lain untuk memastikan `orderId` diteruskan secara dinamis (bukan hardcoded).

> **Catatan:** dibutuhkan izin **Location**, **GPS aktif**, dan **koneksi internet** (tile OpenStreetMap + routing OSRM).

## 9. Hasil Pengujian

- `flutter analyze` → **No issues found!**
- Daftar order pending tampil real-time dari Firestore. ✔
- Tombol "Ambil Order" berhasil meng-update `driver_id`, `status`, dan `updated_at`. ✔
- Navigasi ke `MapDriverScreen` dengan `orderId` dinamis berfungsi. ✔
- Fitur map driver tetap berjalan setelah order diambil (marker, polyline OSRM, jarak & estimasi). ✔

## 10. Catatan Sementara / Known Limitation

- `driver_id` masih dummy `"driver_test_001"`. Nantinya akan diganti dengan **FirebaseAuth UID** setelah fitur login dibuat.
- `main.dart` untuk sementara langsung membuka `DriverOrderListScreen` hanya untuk kebutuhan testing.
- Order pending masih dibuat **manual dari Firebase Console** karena fitur **Customer Create Order** belum dibuat.
- Stack peta saat ini memakai **flutter_map + OpenStreetMap + OSRM**, **bukan** Google Maps SDK seperti pada proposal awal (adaptasi teknologi).
- **Autentikasi multi-role belum dibuat.**
- **Customer screen, Admin screen, kamera proof of delivery, chat, rating, dan notifikasi** belum termasuk dalam milestone ini.

## 11. Next Milestone yang Disarankan

1. **Autentikasi Multi-Role (Firebase Auth + Google Sign-In):** ganti dummy `driver_id` dengan UID asli dan arahkan navigasi awal sesuai role (Admin / Driver / Customer).
2. **Seleksi Order Driver Berdasarkan Jarak (Haversine):** urutkan / filter order berdasarkan jarak koordinat driver ke lokasi pickup, sesuai fitur inti pada proposal.
3. **Customer Create Order:** halaman customer untuk membuat order sehingga data pending tidak perlu dibuat manual dari Console.
4. **Lifecycle MapViewModel:** rapikan agar `initLocation()` / `startTracking()` tidak menumpuk position stream saat `MapDriverScreen` dibuka berulang.
5. **Proof of Delivery, Chat, Rating, dan Notifikasi:** lanjutan fitur sesuai proposal.

## Status Milestone

> **SELESAI** untuk versi dummy driver / testing.
