# Milestone 3 — Customer Map Picker & Auto Price Calculation

## 1. Ringkasan Milestone

Milestone 3 berfokus pada **penyempurnaan alur pembuatan order oleh Customer** agar lebih realistis dan nyaman bagi user nyata, sekaligus **memperbaiki flow order aktif milik Driver**.

Pada Milestone 2, customer masih harus mengetik koordinat (`pickup_lat`, `pickup_lng`, `dest_lat`, `dest_lng`), jarak, dan biaya secara manual — hal yang tidak masuk akal untuk user asli. Di Milestone 3, customer cukup **memilih titik pickup dan tujuan langsung di peta**. Aplikasi kemudian **menghitung jarak otomatis** menggunakan OSRM dan **menghitung total biaya otomatis** dari konfigurasi harga di Firestore (`pricing_config/default` dan `weight_categories`).

Selain itu, sisi Driver dipoles: `DriverOrderListScreen` kini memiliki bagian **"Order Aktif Saya"** sehingga driver tidak kehilangan akses ke order yang sedang dikerjakan, dan driver **dibatasi maksimal 1 order aktif** dalam satu waktu.

Catatan teknologi: proposal awal menyebut Google Maps SDK, namun implementasi tetap memakai **flutter_map + OpenStreetMap + OSRM** agar konsisten dengan repository yang sudah berjalan.

## 2. Tujuan Milestone

- Menghilangkan input koordinat manual pada form customer.
- Menyediakan pemilihan lokasi pickup & tujuan lewat peta interaktif.
- Menghitung jarak tempuh secara otomatis dari rute OSRM.
- Menghitung total biaya secara otomatis berdasarkan `cost_per_km` dan `additional_cost` kategori berat.
- Menjaga konsistensi data order (tetap dibuat dengan `status: pending`).
- Memastikan driver dapat melanjutkan order aktif dan tidak mengambil lebih dari satu order aktif.

## 3. Masalah dari Milestone 2 yang Diselesaikan

| Masalah Milestone 2 | Solusi Milestone 3 |
|---------------------|--------------------|
| Customer harus mengetik `pickup_lat`, `pickup_lng`, `dest_lat`, `dest_lng` manual | Pilih titik lewat peta (`CustomerMapPickerScreen`) |
| Customer harus mengisi `distance_km` manual | Jarak dihitung otomatis dari rute OSRM |
| Customer harus mengisi `total_cost` manual | Biaya dihitung otomatis dari `pricing_config` + `weight_categories` |
| Driver kehilangan akses ke order setelah menekan back dari peta | Bagian "Order Aktif Saya" + tombol "Lanjutkan Pengiriman" |
| Driver berpotensi mengambil banyak order sekaligus | Pembatasan maksimal 1 order aktif (UI + validasi service) |

## 4. Flow Customer Create Order setelah Milestone 3

```
[RoleSwitcherScreen]
      │  pilih "Customer — Buat Order"
      ▼
[CustomerCreateOrderScreen]
  - Load cost_per_km (pricing_config/default)
  - Load daftar kategori berat (weight_categories)
  - Form: Nama/Alamat Jemput, Nama/Alamat Tujuan,
          Deskripsi Barang, Dropdown Kategori Berat
      │  tap "Pilih Lokasi di Peta"
      ▼
[CustomerMapPickerScreen]
  - (opsional) center ke lokasi user via Geolocator, fallback Jember
  - Mode "Set Pickup" / "Set Tujuan"
  - Tap peta → set marker pickup (hijau) / tujuan (merah)
  - Kedua titik terisi → OSRM getRouteInfo() → polyline + jarak
  - Auto-fit kamera ke kedua titik
  - Tombol "Gunakan Lokasi Ini" (aktif jika pickup+tujuan+route siap)
      │  pop(MapPickerResult{pickup, destination, distanceMeters})
      ▼
[CustomerCreateOrderScreen]
  - distance_km = distanceMeters / 1000 (read-only)
  - total_cost  = distance_km * cost_per_km + additional_cost (read-only)
  - Tombol "Buat Order" aktif jika semua data siap
      │  tap "Buat Order"
      ▼
[OrderService.createOrder(...)]
  - status = pending
  - customer_id = customer_test_001
  - driver_id = null
  - created_at / updated_at = serverTimestamp()
      │
      ▼
[Order tersimpan di Firestore + SnackBar sukses + form di-reset]
```

## 5. Flow Driver Active Order setelah Patch

```
[DriverOrderListScreen]
  ├── Bagian "Order Aktif Saya"
  │     - stream: watchActiveOrdersForDriver(driver_test_001)
  │     - filter status pickingUp / delivering (di memory)
  │     - kosong → "Tidak ada order aktif"
  │     - ada → card + chip status + tombol "Lanjutkan Pengiriman"
  │
  └── Bagian "Order Tersedia"
        - stream: watchPendingOrders()
        - kosong → "Belum ada order pending"
        - ada → card + tombol "Ambil Order"
        - jika driver punya order aktif:
              tombol disabled + label "Selesaikan order aktif dulu"

[Ambil Order]
   - acceptOrder() cek dulu:
       * driver tidak boleh punya order aktif → kalau ada, throw
       * order harus masih ada & status pending → kalau tidak, throw
   - jika aman: driver_id = driver_test_001, status = pickingUp,
                updated_at = serverTimestamp()
   - Navigator.push → MapDriverScreen(orderId)

[Lanjutkan Pengiriman]
   - Navigator.push → MapDriverScreen(orderId order aktif)

[Back dari MapDriverScreen]
   - kembali ke DriverOrderListScreen
   - order tetap terlihat di "Order Aktif Saya"
```

## 6. File yang Dibuat/Diubah

**File baru:**

- `lib/services/pricing_service.dart` — service harga + model `WeightCategory`.
- `lib/views/customer_map_picker_screen.dart` — pemilihan lokasi lewat peta.

**File diubah:**

- `lib/services/routing_service.dart` — tambah `RouteInfo` + `getRouteInfo()`.
- `lib/services/order_service.dart` — `createOrder()`, `watchActiveOrdersForDriver()`, `hasActiveOrderForDriver()`, pengetatan `acceptOrder()`.
- `lib/views/customer_create_order_screen.dart` — refactor form (tanpa koordinat manual, dropdown kategori, read-only jarak & biaya).
- `lib/views/driver_order_list_screen.dart` — dua bagian (Order Aktif Saya & Order Tersedia) + pembatasan 1 order aktif.

**File pendukung (tidak diubah di milestone ini):**

- `lib/views/map_driver_screen.dart`
- `lib/viewmodels/map_viewmodel.dart`
- `lib/models/order_model.dart`
- `lib/main.dart` (RoleSwitcherScreen dari Milestone 2)

## 7. Detail Teknis Perubahan

### `lib/services/routing_service.dart`

- Menambahkan class `RouteInfo` berisi `routePoints`, `distanceMeters`, dan `durationSeconds`.
- Menambahkan method `getRouteInfo(LatLng start, LatLng end)` yang memanggil OSRM dan mengembalikan `RouteInfo` (jarak diambil dari field `distance` response OSRM, durasi dari `duration`).
- Method lama `getRoute()` **tidak diubah** karena masih dipakai `MapViewModel`.

### `lib/services/pricing_service.dart` *(baru)*

- Model `WeightCategory` (`id`, `name`, `additionalCost`) dengan factory `fromDoc()` yang defensif terhadap field kosong.
- `getCostPerKm()` membaca `pricing_config/default`. Jika dokumen / field `cost_per_km` tidak ada → melempar `Exception` yang jelas.
- `getWeightCategories()` membaca koleksi `weight_categories`. Jika kosong → melempar `Exception`.

### `lib/services/order_service.dart`

- `createOrder(...)` menulis dokumen order baru dengan `status: pending`, `driver_id: null`, `proof_photo_url: ""`, timestamp `serverTimestamp()`, dan mengembalikan `orderId`.
- `watchActiveOrdersForDriver(driverId)` — stream order milik driver. Query hanya `driver_id == driverId` (single-field, **tanpa composite index**); filter status `pickingUp`/`delivering` dan sorting `updatedAt`/`createdAt` desc dilakukan di memory.
- `hasActiveOrderForDriver(driverId)` — `Future<bool>`, cek apakah driver masih punya order aktif.
- `acceptOrder(...)` diperketat:
  1. Jika driver sudah punya order aktif → `Exception("Driver masih memiliki order aktif. Selesaikan order tersebut terlebih dahulu.")`.
  2. Jika order tidak ada atau statusnya bukan `pending` → `Exception("Order sudah tidak tersedia.")`.
  3. Jika aman → update `driver_id`, `status = pickingUp`, `updated_at = serverTimestamp()`.

### `lib/views/customer_map_picker_screen.dart` *(baru)*

- Peta `flutter_map` + tile OpenStreetMap.
- Mode pilih titik: **Set Pickup** / **Set Tujuan**; tap peta menentukan marker sesuai mode aktif.
- Marker pickup (hijau) & tujuan (merah), polyline rute (biru).
- Saat kedua titik terisi → panggil `getRouteInfo()` untuk menghitung rute + jarak, lalu **auto-fit** kamera ke kedua titik.
- Saat dibuka: mencoba ambil lokasi user via `Geolocator` lalu center ke sana; jika izin ditolak / gagal → fallback ke koordinat default Jember (tidak crash).
- FAB **"Lokasi Saya"** muncul bila lokasi user tersedia.
- Tombol **"Gunakan Lokasi Ini"** hanya aktif jika pickup, tujuan, dan rute sudah siap; mengembalikan `MapPickerResult{pickup, destination, distanceMeters}`.

### `lib/views/customer_create_order_screen.dart`

- Form tidak lagi memuat input koordinat manual.
- Field: **Nama/Alamat Jemput**, **Nama/Alamat Tujuan** (dengan helper text bahwa koordinat ditentukan lewat peta), **Deskripsi Barang**, **Dropdown Kategori Berat**.
- Tombol **"Pilih Lokasi di Peta"** membuka `CustomerMapPickerScreen`.
- Menampilkan baris **read-only**: koordinat pickup, koordinat tujuan, `distance_km`, dan `total_cost`.
- `total_cost = distance_km × cost_per_km + additional_cost`, dihitung ulang setiap kali jarak atau kategori berubah.
- Jika `pricing_config` / `weight_categories` gagal dimuat → tampilkan layar error + tombol "Coba Lagi" (tidak crash). Tombol "Buat Order" disabled sampai semua data siap.

### `lib/views/driver_order_list_screen.dart`

- Dua bagian dalam satu `ListView`: **"Order Aktif Saya"** dan **"Order Tersedia"**.
- Bagian Order Aktif memakai `watchActiveOrdersForDriver()`; tombol **"Lanjutkan Pengiriman"** → `MapDriverScreen(orderId)`.
- Bagian Order Tersedia memakai `watchPendingOrders()`; tombol **"Ambil Order"**.
- Jika driver punya order aktif: tombol Ambil Order **disabled** dengan label **"Selesaikan order aktif dulu"**.
- Jika terdeteksi lebih dari 1 order aktif (sisa data testing lama) → tampilkan warning, namun semua order aktif tetap ditampilkan.
- Error dari `acceptOrder` ditampilkan via SnackBar.

## 8. Struktur Firestore yang Dipakai

### Koleksi `orders`

| Field | Tipe | Keterangan |
|-------|------|------------|
| `customer_id` | string | dummy `customer_test_001` |
| `driver_id` | string \| null | `null` saat dibuat; `driver_test_001` saat diambil |
| `weight_category_id` | string | id kategori berat terpilih |
| `pickup_address` | string | label alamat jemput (input manual) |
| `pickup_lat` | number | dari map picker |
| `pickup_lng` | number | dari map picker |
| `dest_address` | string | label alamat tujuan (input manual) |
| `dest_lat` | number | dari map picker |
| `dest_lng` | number | dari map picker |
| `item_description` | string | deskripsi barang |
| `distance_km` | number | dihitung otomatis (OSRM) |
| `total_cost` | number | dihitung otomatis |
| `status` | string | `pending` → `pickingUp` → `delivering` → `completed` |
| `proof_photo_url` | string | default `""` |
| `created_at` | timestamp | `serverTimestamp()` |
| `updated_at` | timestamp | `serverTimestamp()` |

### Dokumen `pricing_config/default`

| Field | Tipe | Keterangan |
|-------|------|------------|
| `cost_per_km` | number | tarif dasar per kilometer |

### Koleksi `weight_categories/{category_id}`

| Field | Tipe | Keterangan |
|-------|------|------------|
| `name` | string | nama kategori berat |
| `additional_cost` | number | biaya tambahan kategori |

**Rumus biaya:**

```
baseCost   = distance_km × cost_per_km
total_cost = baseCost + additional_cost (dari kategori berat terpilih)
```

## 9. Cara Testing Manual

**Prasyarat data Firestore (sekali saja, via Firebase Console):**

- `pricing_config/default` dengan field `cost_per_km`, contoh `3000`.
- Koleksi `weight_categories` dengan beberapa dokumen, contoh:
  - `ringan` → `{ name: "Ringan (<5kg)", additional_cost: 0 }`
  - `sedang` → `{ name: "Sedang (5-15kg)", additional_cost: 5000 }`
  - `berat` → `{ name: "Berat (>15kg)", additional_cost: 12000 }`

**Langkah pengujian:**

1. Jalankan `flutter run`, pilih device Android → halaman **Pilih Mode**.
2. **Customer membuat order:**
   - Tap **"Customer — Buat Order"** (tunggu data harga termuat; jika gagal → layar error + "Coba Lagi").
   - Isi Nama/Alamat Jemput, Nama/Alamat Tujuan, Deskripsi Barang, pilih Kategori Berat.
3. **Pilih lokasi di peta:**
   - Tap **"Pilih Lokasi di Peta"**. Izinkan lokasi (atau lanjut dengan fallback Jember).
   - Mode **Set Pickup** → tap peta (marker hijau); Mode **Set Tujuan** → tap peta (marker merah).
   - Polyline biru + jarak muncul, kamera auto-fit; tap **"Gunakan Lokasi Ini"**.
4. **Cek jarak & biaya otomatis:** kembali ke form, baris read-only menampilkan koordinat, `distance_km`, dan `total_cost`. Tombol **"Buat Order"** aktif.
5. **Buat order:** tap **"Buat Order"** → SnackBar sukses + form reset. Cek di Console: dokumen baru `status: pending`, `driver_id: null`, koordinat & biaya terisi.
6. **Driver mengambil order:**
   - Back ke Pilih Mode → **"Driver — Daftar Order"**. Order tampil di **"Order Tersedia"**.
   - Tap **"Ambil Order"** → status jadi `pickingUp`, `driver_id` jadi `driver_test_001`, masuk **MapDriverScreen**.
7. **Order aktif & pembatasan:**
   - Tekan back → order kini di **"Order Aktif Saya"** (chip "Menjemput").
   - Order pending lain kini tombolnya **disabled** ("Selesaikan order aktif dulu").
   - Tap **"Lanjutkan Pengiriman"** → masuk lagi ke **MapDriverScreen** untuk order yang sama.

## 10. Hasil Pengujian

- `flutter analyze` → **No issues found!**
- Customer dapat memilih pickup & tujuan lewat peta. ✔
- Jarak dihitung otomatis dari OSRM dan tampil read-only. ✔
- Total biaya dihitung otomatis dari `pricing_config` + `weight_categories`. ✔
- Order dibuat dengan `status: pending`. ✔
- Order muncul di "Order Tersedia" dan dapat diambil driver. ✔
- Bagian "Order Aktif Saya" + tombol "Lanjutkan Pengiriman" berfungsi. ✔
- Driver dibatasi maksimal 1 order aktif (UI disabled + validasi service). ✔
- Alur end-to-end Customer → Driver tetap berjalan. ✔

## 11. Known Limitation

- `customer_id` masih dummy `customer_test_001`.
- `driver_id` masih dummy `driver_test_001`.
- Alamat masih diinput manual sebagai label lokasi (`pickup_address` / `dest_address`).
- Belum ada search alamat / geocoding (koordinat hanya dari tap peta).
- Belum ada Firebase Auth multi-role.
- Belum ada customer tracking screen.
- Belum ada proof of delivery, rating, chat, admin dashboard, dan notifikasi.
- Tombol **"Pick Up Pesanan"** di MapDriverScreen hanya aktif jika driver berada dekat target (sekitar < 50 meter).

## 12. Next Improvement / Backlog

1. **Firebase Auth multi-role (Google Sign-In):** ganti dummy `customer_id` & `driver_id` dengan UID asli, dan routing awal berdasarkan role.
2. **Search alamat / geocoding:** isi alamat otomatis dari titik peta (reverse geocoding) atau cari lokasi via teks.
3. **Customer Tracking Screen:** customer memantau posisi driver secara real-time.
4. **Seleksi Order Driver Berdasarkan Jarak (Haversine):** urutkan/filter order pending berdasarkan jarak driver ke pickup, sesuai fitur inti proposal.
5. **Proof of Delivery, Chat, Rating, Notifikasi, dan Admin Dashboard:** lanjutan fitur sesuai proposal.
6. **Perapian lifecycle MapViewModel:** mencegah penumpukan position stream saat MapDriverScreen dibuka berulang.

## Status Milestone

> **SELESAI** untuk versi dummy customer/driver (testing).
