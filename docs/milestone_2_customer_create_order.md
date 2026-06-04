# Milestone 2 — Customer Create Order

## 1. Ringkasan Milestone

Milestone 2 berfokus pada alur kerja **role Customer** tahap awal: bagaimana seorang customer dapat membuat order pengiriman baru langsung dari aplikasi, tanpa perlu lagi memasukkan data secara manual melalui Firebase Console.

Pada milestone ini dibuat halaman baru **CustomerCreateOrderScreen** berisi form sederhana. Ketika customer mengisi form dan menekan tombol **"Buat Order"**, sebuah dokumen baru ditulis ke koleksi `orders` di Cloud Firestore dengan `status: "pending"`. Order ini kemudian otomatis muncul di **DriverOrderListScreen** (Milestone 1) dan siap diambil oleh driver — sehingga alur **Customer → Driver** kini dapat diuji secara penuh (*end-to-end*).

Selain itu, `main.dart` kini membuka **RoleSwitcherScreen**, sebuah halaman switch sederhana untuk berpindah antara mode Customer dan mode Driver selama testing.

## 2. Tujuan Fitur

- Memberikan customer kemampuan membuat order pengiriman langsung dari aplikasi.
- Menghilangkan kebutuhan membuat data order secara manual di Firebase Console.
- Memastikan order baru tersimpan dengan struktur dan status yang konsisten (`status = pending`).
- Menyambungkan alur Customer ke alur Driver yang sudah ada (Milestone 1) agar dapat diuji menyeluruh.
- Menyiapkan fondasi sebelum nanti dihubungkan dengan autentikasi multi-role.

## 3. Scope Fitur yang Dikerjakan

Fitur yang **termasuk** dalam Milestone 2:

- Method `createOrder()` baru di `OrderService` untuk menulis order ke Firestore.
- Halaman form pembuatan order (`CustomerCreateOrderScreen`).
- Validasi input sederhana (field wajib & field angka).
- Notifikasi SnackBar sukses/gagal dan reset form setelah sukses.
- Switcher mode sederhana di `main.dart` untuk menguji flow Customer & Driver.

Fitur yang **TIDAK** termasuk (lihat juga *Known Limitation*):

- Autentikasi / login multi-role.
- Pemilihan lokasi via peta interaktif (saat ini koordinat diisi manual).
- Perhitungan otomatis `distance_km` dan `total_cost`.
- Screen Admin.
- Kamera proof of delivery, chat, rating, dan push notification.

## 4. Flow Aplikasi

```
[App dibuka]
      │
      ▼
[RoleSwitcherScreen]  (main.dart)
  - Tombol "Customer — Buat Order"
  - Tombol "Driver — Daftar Order"
      │
      │  Pilih "Customer — Buat Order"
      ▼
[CustomerCreateOrderScreen]
  - Form: pickup, tujuan, detail barang
  - Tekan "Buat Order"
      │
      ▼
[OrderService.createOrder(...)]
  - customer_id    → "customer_test_001"
  - driver_id      → null
  - status         → "pending"
  - proof_photo_url→ ""
  - created_at     → serverTimestamp()
  - updated_at     → serverTimestamp()
      │
      ▼
[Order tersimpan di Firestore + SnackBar sukses + form di-reset]
      │
      │  (kembali ke RoleSwitcherScreen → pilih "Driver — Daftar Order")
      ▼
[DriverOrderListScreen]  (Milestone 1)
  - Order baru muncul real-time (status "pending")
  - Driver tekan "Ambil Order" → status "pickingUp" → MapDriverScreen
```

## 5. Struktur File yang Terlibat

```
lib/
├── main.dart                            # [DIUBAH] home → RoleSwitcherScreen (switch Customer/Driver)
├── views/
│   ├── customer_create_order_screen.dart# [BARU] form pembuatan order customer
│   ├── driver_order_list_screen.dart    # [PENDUKUNG] daftar order pending (Milestone 1)
│   └── map_driver_screen.dart           # [PENDUKUNG] peta & tracking driver
├── services/
│   └── order_service.dart               # [DIUBAH] tambah method createOrder()
└── models/
    └── order_model.dart                 # [PENDUKUNG] mapping data order Firestore
```

**File yang berubah di Milestone 2:**

- `lib/services/order_service.dart` (diubah — tambah `createOrder()`)
- `lib/views/customer_create_order_screen.dart` (baru)
- `lib/main.dart` (diubah — `RoleSwitcherScreen`)

**File pendukung dari milestone sebelumnya:**

- `lib/views/driver_order_list_screen.dart`
- `lib/views/map_driver_screen.dart`
- `lib/models/order_model.dart`

## 6. Detail Perubahan per File

### `lib/services/order_service.dart` — **(DIUBAH)**

Menambahkan method `createOrder()` (method ke-7 di service).

- Menggunakan `_db.collection('orders').add({...})` untuk membuat dokumen baru dengan ID otomatis.
- Field yang ditulis: `customer_id`, `driver_id` (null), `weight_category_id`, `pickup_address`, `pickup_lat`, `pickup_lng`, `dest_address`, `dest_lat`, `dest_lng`, `item_description`, `distance_km`, `total_cost`, `status` (`pending`), `proof_photo_url` (`""`), `created_at` & `updated_at` (`FieldValue.serverTimestamp()`).
- Mengembalikan `String` berisi `orderId` baru (id dokumen) agar bisa ditampilkan / dipakai pemanggil.
- `distance_km` dan `total_cost` punya nilai default `0.0`; `weight_category_id` bertipe nullable.

### `lib/views/customer_create_order_screen.dart` — **(BARU)**

Halaman form pembuatan order.

- Menggunakan `Form` + `GlobalKey<FormState>` dengan beberapa `TextFormField`.
- Field form: `pickup_address`, `pickup_lat`, `pickup_lng`, `dest_address`, `dest_lat`, `dest_lng`, `item_description`, `weight_category_id` (opsional), `distance_km`, `total_cost`.
- Validasi: alamat & deskripsi barang wajib diisi; lat/lng/jarak/biaya wajib berupa angka; weight category boleh kosong (akan dikirim `null`).
- `customer_id` memakai dummy `"customer_test_001"` (konstanta `kDummyCustomerId`).
- Tombol **"Buat Order"** menampilkan loading spinner saat proses, memanggil `OrderService.createOrder()`, lalu menampilkan **SnackBar sukses** (hijau) dan **mereset form**. Jika gagal, menampilkan SnackBar error.
- Semua `TextEditingController` di-*dispose* dengan benar.

### `lib/main.dart` — **(DIUBAH)**

- Properti `home:` diarahkan ke `RoleSwitcherScreen` yang baru.
- `RoleSwitcherScreen` adalah halaman sederhana berisi dua tombol: **"Customer — Buat Order"** (push ke `CustomerCreateOrderScreen`) dan **"Driver — Daftar Order"** (push ke `DriverOrderListScreen`).
- Provider `MapViewModel` tetap dipasang di root.

## 7. Struktur Firestore yang Dipakai

Koleksi utama tetap **`orders`**. Saat `createOrder()` dipanggil, dokumen baru dibuat dengan field berikut:

| Field | Tipe | Nilai saat Create |
|-------|------|-------------------|
| `customer_id` | string | `"customer_test_001"` (dummy) |
| `driver_id` | null | `null` (belum ada driver) |
| `weight_category_id` | string \| null | dari input (opsional) |
| `pickup_address` | string | dari input |
| `pickup_lat` | number | dari input |
| `pickup_lng` | number | dari input |
| `dest_address` | string | dari input |
| `dest_lat` | number | dari input |
| `dest_lng` | number | dari input |
| `item_description` | string | dari input |
| `distance_km` | number | dari input (default `0.0`) |
| `total_cost` | number | dari input (default `0.0`) |
| `status` | string | `"pending"` |
| `proof_photo_url` | string | `""` |
| `created_at` | timestamp | `FieldValue.serverTimestamp()` |
| `updated_at` | timestamp | `FieldValue.serverTimestamp()` |

**Operasi Firestore pada milestone ini:**

- **Create (add):** menulis dokumen baru ke koleksi `orders` dengan ID otomatis.

> Setelah order dibuat, alur Milestone 1 mengambil alih: `watchPendingOrders()` membaca order `pending` ini secara real-time, dan `acceptOrder()` akan meng-update `driver_id` & `status` ketika driver mengambilnya.

## 8. Cara Testing Manual di Android

1. **Jalankan aplikasi:** `flutter run` lalu pilih device Android. Aplikasi membuka halaman **"DeltaSend — Pilih Mode"**.
2. **Customer membuat order:**
   - Tap **"Customer — Buat Order"**.
   - Isi form. Contoh koordinat area Jember (sesuai default peta):
     - Pickup: lat `-8.1689`, lng `113.7022`, alamat bebas.
     - Tujuan: lat `-8.1750`, lng `113.7100`, alamat bebas.
     - Deskripsi barang, jarak (mis. `2.5`), total biaya (mis. `15000`). Weight category boleh dikosongkan.
   - Tap **"Buat Order"** → muncul **SnackBar hijau "Order berhasil dibuat (id: ...)"** dan form ter-reset.
3. **Order masuk Firestore status pending:**
   - Buka Firebase Console → koleksi `orders` → dokumen baru muncul dengan `status: "pending"`, `customer_id: "customer_test_001"`, `driver_id: null`, `proof_photo_url: ""`, serta `created_at` & `updated_at` terisi.
4. **Order muncul di DriverOrderListScreen:**
   - Kembali (back) ke halaman Pilih Mode → tap **"Driver — Daftar Order"**.
   - Order yang baru dibuat tampil real-time pada daftar (alamat jemput → tujuan, jarak, biaya).
5. **Driver bisa ambil order:**
   - Tap **"Ambil Order"** → `driver_id` jadi `"driver_test_001"`, `status` jadi `"pickingUp"`, order hilang dari daftar, lalu app masuk ke **MapDriverScreen** (izinkan lokasi → marker driver & target + polyline OSRM + jarak/estimasi).

> **Catatan:** dibutuhkan izin **Location**, **GPS aktif**, dan **koneksi internet** (tile OpenStreetMap + routing OSRM).

## 9. Hasil Pengujian

- `flutter analyze` → **No issues found!**
- Form customer berhasil membuat order baru ke Firestore. ✔
- Order tersimpan dengan `status: "pending"`, `customer_id` dummy, `driver_id: null`, dan timestamp terisi. ✔
- SnackBar sukses tampil dan form ter-reset setelah order dibuat. ✔
- Order baru muncul real-time di `DriverOrderListScreen`. ✔
- Driver dapat mengambil order tersebut hingga masuk ke `MapDriverScreen`. ✔
- Alur end-to-end **Customer → Driver** berfungsi tanpa input manual di Firebase Console. ✔

## 10. Catatan Sementara / Known Limitation

- `customer_id` masih dummy `"customer_test_001"`. Nantinya akan diganti dengan **FirebaseAuth UID** setelah fitur login dibuat.
- `main.dart` untuk sementara membuka `RoleSwitcherScreen` (switch manual Customer/Driver) hanya untuk kebutuhan testing — bukan routing berbasis role sungguhan.
- Koordinat `pickup` dan `dest` masih **diisi manual** lewat form, belum memakai pemilihan lokasi via peta interaktif.
- `distance_km` dan `total_cost` masih **diinput manual**, belum dihitung otomatis dari koordinat/jarak rute atau dari `pricing_config`.
- Stack peta tetap **flutter_map + OpenStreetMap + OSRM**, **bukan** Google Maps SDK seperti pada proposal awal (adaptasi teknologi).
- **Autentikasi multi-role belum dibuat.**
- **Screen Admin, kamera proof of delivery, chat, rating, dan notifikasi** belum termasuk dalam milestone ini.

## 11. Next Milestone yang Disarankan

1. **Autentikasi Multi-Role (Firebase Auth + Google Sign-In):** ganti dummy `customer_id` & `driver_id` dengan UID asli, dan arahkan navigasi awal sesuai role.
2. **Pemilihan Lokasi via Peta:** customer memilih titik pickup & tujuan dari peta (flutter_map) sehingga koordinat tidak perlu diketik manual.
3. **Kalkulasi Otomatis Jarak & Biaya:** hitung `distance_km` dari rute OSRM dan `total_cost` dari `weight_categories` / `pricing_config`.
4. **Seleksi Order Driver Berdasarkan Jarak (Haversine):** urutkan/filter order berdasarkan jarak driver ke lokasi pickup, sesuai fitur inti proposal.
5. **Proof of Delivery, Chat, Rating, dan Notifikasi:** lanjutan fitur sesuai proposal.

## Status Milestone

> **SELESAI** untuk versi dummy customer / testing.
