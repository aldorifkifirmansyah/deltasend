# Milestone 6 — Driver Rating

## 1. Ringkasan Milestone

Milestone 6 menambahkan fitur **rating driver**: setelah sebuah order berstatus `completed`, customer dapat memberi penilaian **bintang 1–5** kepada driver. Rating disimpan di dokumen order (`orders/{orderId}.rating`) sekaligus diakumulasi menjadi rata-rata pada profil driver (`users/{driverId}.rating_avg` & `rating_count`).

Customer melihat daftar order yang sudah selesai namun belum dirating melalui section **"Perlu Dirating"** di `CustomerHomeScreen`. Dari situ customer membuka `RatingScreen`, memilih bintang, dan mengirim rating.

## 2. Tujuan Milestone

- Memberi customer cara menilai kualitas layanan driver setelah order selesai.
- Menyimpan rating per-order dan rata-rata rating per-driver di Firestore.
- Menampilkan order completed yang belum dirating secara real-time di home customer.

## 3. Flow Rating

```
[CustomerHomeScreen]
  - Section "Perlu Dirating" (StreamBuilder watchCompletedUnratedOrders(uid))
  - Hanya muncul jika ada order completed & rating == null
      │  tap "Beri Rating"
      ▼
[RatingScreen(order)]
  - Tampilkan deskripsi barang + alamat tujuan
  - Pilih bintang 1–5 (amber = terpilih)
  - Tombol "Kirim Rating" (disabled jika belum pilih)
      │  submitRating(orderId, driverId, rating)
      ▼
[OrderService.submitRating]
  - update orders/{orderId}.rating
  - hitung ulang rata-rata dari semua order completed driver yang sudah dirating
  - simpan users/{driverId}.rating_avg & rating_count
      │  sukses
      ▼
[pop kembali ke Home] → order hilang dari "Perlu Dirating" (real-time)
```

## 4. File yang Dibuat/Diubah

**File baru:**
- `lib/views/customer/rating_screen.dart` — layar pemberian rating bintang.

**File diubah:**
- `lib/models/order_model.dart` — tambah field `int? rating`.
- `lib/services/order_service.dart` — tambah `watchCompletedUnratedOrders()` & `submitRating()`.
- `lib/views/customer/customer_home_screen.dart` — tambah section "Perlu Dirating".

## 5. Detail Teknis

### `lib/models/order_model.dart`
- Tambah field `final int? rating;` (null = belum dirating).
- Constructor: `this.rating`.
- `fromFirestore`: `rating: data['rating'] as int?`.

### `lib/services/order_service.dart`

`watchCompletedUnratedOrders(customerId)` — stream order milik customer:
- Query Firestore hanya `where('customer_id', isEqualTo: customerId)` (single-field, **tanpa composite index**).
- Filter `status == completed && rating == null` dan sort `updatedAt`/`createdAt` desc dilakukan di memory.

`submitRating({orderId, driverId, rating})`:
1. Update `orders/{orderId}` field `rating` (+ `updated_at`).
2. Baca semua order milik `driverId`, ambil yang `completed` & sudah punya `rating`.
3. Hitung rata-rata, simpan ke `users/{driverId}` field `rating_avg` (double) & `rating_count` (int) via `set(..., merge: true)`.

### `lib/views/customer/rating_screen.dart`
- `StatefulWidget` dengan parameter `OrderModel order`.
- State `_rating` (0 = belum pilih) & `_isSubmitting`.
- 5 `IconButton` bintang: terpilih `Icons.star` amber, sisanya `Icons.star_border` abu-abu.
- Tombol "Kirim Rating" disabled jika `_rating == 0` atau sedang submit; menampilkan spinner saat submit; sukses → `Navigator.pop()`; error → SnackBar.
- Guard: jika `order.driverId` null/kosong → SnackBar dan batal.

### `lib/views/customer/customer_home_screen.dart`
- Dikonversi ke `StatefulWidget`; stream `watchCompletedUnratedOrders` dibuat sekali di `initState` (stabil, tidak dibuat ulang tiap rebuild).
- Section "Perlu Dirating" via `StreamBuilder`: kosong → `SizedBox.shrink()` (section tidak muncul sama sekali); ada → card per order (nama barang + alamat tujuan + tombol "Beri Rating" → `RatingScreen`).
- `currentUser` diambil via `context.read<AuthViewModel>()`.

## 6. Struktur Firestore yang Dipakai

| Dokumen | Field baru | Tipe | Keterangan |
|---|---|---|---|
| `orders/{orderId}` | `rating` | int (1–5) | null = belum dirating |
| `users/{driverId}` | `rating_avg` | double | rata-rata seluruh rating completed driver |
| `users/{driverId}` | `rating_count` | int | jumlah order yang sudah dirating |

## 7. Cara Testing Manual

**Prasyarat:** ada minimal 1 order dengan `status: completed`, `customer_id` = UID customer yang login, dan `driver_id` terisi.

1. Login sebagai customer → di **CustomerHomeScreen** muncul section **"Perlu Dirating"** berisi order completed yang belum dirating. (Jika tidak ada → section tidak muncul.)
2. Tap **"Beri Rating"** pada salah satu card → masuk **RatingScreen**.
3. Pilih bintang (mis. 4) → bintang 1–4 jadi amber; tombol **"Kirim Rating"** aktif.
4. Tap **"Kirim Rating"** → spinner → kembali ke Home. Order hilang dari section (real-time).
5. Cek Firestore:
   - `orders/{orderId}.rating` = 4.
   - `users/{driverId}.rating_avg` & `rating_count` terupdate sesuai akumulasi.
6. Beri rating order lain milik driver yang sama → `rating_avg` menyesuaikan rata-rata baru.

## 8. Hasil Pengujian

- `flutter analyze` pada `order_model.dart`, `order_service.dart`, `rating_screen.dart`, `customer_home_screen.dart` → **No issues found!**
- Section "Perlu Dirating" muncul hanya saat ada order completed belum dirating. ✔
- Pilih bintang & kirim rating menyimpan `rating` ke order. ✔
- `rating_avg` & `rating_count` driver terhitung & tersimpan. ✔
- Order yang sudah dirating otomatis hilang dari section. ✔

> Catatan: 2 error pre-existing di `lib/viewmodels/auth_viewmodel.dart` (migrasi `google_sign_in` v7) berada di luar scope milestone ini dan sedang dihandle di branch terpisah — tidak disentuh.

## 9. Known Limitation

- Belum ada kolom ulasan teks (hanya bintang).
- Rata-rata dihitung ulang dengan membaca seluruh order driver setiap submit — sederhana namun kurang efisien untuk volume order besar.
- Belum ada validasi bahwa hanya customer pemilik order yang bisa memberi rating (mengandalkan filter `customer_id` di query; idealnya ditegakkan via Firestore Security Rules).
- `rating_avg`/`rating_count` driver belum ditampilkan di UI manapun (mis. di daftar order driver atau profil).

## 10. Next Improvement / Backlog

1. Tampilkan `rating_avg` driver di UI (badge di order, profil driver).
2. Tambah ulasan teks opsional pada rating.
3. Hitung rata-rata via increment/transaction agar efisien.
4. Firestore Security Rules untuk membatasi penulisan `rating` hanya oleh customer pemilik order.
5. Proof of Delivery, Chat, Push Notification, Admin Dashboard.

## Status

> **SELESAI** — Driver Rating.
> Branch: `feature/driver-rating` (dari `main`).
