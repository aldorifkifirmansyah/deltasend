# Milestone 9 — Haversine Driver Order Ranking

## 1. Ringkasan Milestone

Milestone 9 mengubah daftar **"Order Tersedia"** di sisi driver agar diurutkan berdasarkan **jarak driver → lokasi pickup** (ascending) dan **menyembunyikan order di luar radius** tertentu (default 10 km) — meniru perilaku Gojek/GoSend. Implementasi **pure client-side**: jarak dihitung di aplikasi memakai formula **Haversine manual**, **tanpa menulis lokasi driver ke Firestore** dan tanpa mengubah query `watchPendingOrders()` yang sudah ada.

Sebelumnya driver melihat semua order pending tanpa konteks jarak. Sekarang tiap card menampilkan badge "X.X km dari kamu", order terdekat di atas, dan order yang terlalu jauh tidak ditampilkan.

## 2. Tujuan Milestone

- Mengurutkan order pending dari yang terdekat ke pickup.
- Menyembunyikan order di luar radius `kMaxOrderRadiusKm` (10 km).
- Menampilkan jarak per order ke driver (badge).
- Memakai Haversine murni (rumus terdokumentasi), bukan algoritma ellipsoidal `Geolocator.distanceBetween()`.
- Tetap robust saat lokasi tidak tersedia (izin ditolak / GPS mati): tampilkan semua order + banner fallback.

## 3. Flow

```
[DriverOrderListScreen dibuka]
  - initState → _initDriverLocation() (pola sama dgn MapViewModel.initLocation)
      ├─ GPS off               → _LocationState.serviceOff
      ├─ izin ditolak/denied   → _LocationState.denied
      ├─ error                 → _LocationState.error
      └─ ok → getCurrentPosition() → _driverPosition, _LocationState.ready

[Section "Order Tersedia"] (StreamBuilder watchPendingOrders())
  - _driverPosition != null:
        sortAndFilterByDistance(orders, driverPosition, maxRadiusKm)
          → hitung Haversine driver→pickup tiap order
          → filter distanceKm <= 10 km
          → sort ascending
        ├─ hasil kosong → "Tidak ada order dalam radius 10 km dari lokasimu"
        └─ ada → card per order + badge "X.X km dari kamu"
  - _driverPosition == null:
        banner kuning ("Lokasi tidak aktif…" / izin ditolak / GPS mati) + "Coba Lagi"
        + tampilkan SEMUA order tanpa filter/sort

[Pull-to-refresh (RefreshIndicator)] → _initDriverLocation() (re-fetch posisi)
```

## 4. File yang Dibuat/Diubah

**File baru:**
- `lib/utils/distance_helper.dart` — `calculateHaversineDistance()` + konstanta `kMaxOrderRadiusKm`.

**File diubah:**
- `lib/services/order_service.dart` — class `OrderWithDistance` + method `sortAndFilterByDistance()`.
- `lib/views/driver_order_list_screen.dart` — fetch lokasi driver, RefreshIndicator, ranking/filter, badge jarak, banner fallback, empty state radius.

> `watchPendingOrders()` **tidak diubah** — transformasi jarak adalah langkah terpisah yang dipanggil dari screen setelah snapshot diterima.

## 5. Detail Teknis

### `lib/utils/distance_helper.dart`
- `calculateHaversineDistance(lat1, lon1, lat2, lon2)` → jarak **km** dengan rumus Haversine manual (`dart:math`: `sin`, `cos`, `atan2`, `sqrt`), radius bumi 6371 km. Helper `_degreesToRadians`.
- `const double kMaxOrderRadiusKm = 10.0;`
- **Sengaja tidak memakai `Geolocator.distanceBetween()`** (ellipsoidal/Vincenty) agar metode sesuai janji proposal (Haversine) dan rumusnya bisa didokumentasikan persis.

### `lib/services/order_service.dart`
- `class OrderWithDistance { final OrderModel order; final double distanceKm; }` — agar UI bisa menampilkan badge jarak per card.
- `List<OrderWithDistance> sortAndFilterByDistance({required List<OrderModel> orders, required Position driverPosition, double maxRadiusKm = kMaxOrderRadiusKm})`:
  - map tiap order → hitung Haversine `driverPosition` → `order.pickupLocation`,
  - `.where((item) => item.distanceKm <= maxRadiusKm)`,
  - `sort((a, b) => a.distanceKm.compareTo(b.distanceKm))`.
  - Pure function; tidak menyentuh Firestore.

### `lib/views/driver_order_list_screen.dart`
- Enum privat `_LocationState { loading, ready, denied, serviceOff, error }`; state `Position? _driverPosition`.
- `_initDriverLocation()` mengikuti pola `MapViewModel.initLocation()`: cek `isLocationServiceEnabled` → `checkPermission`/`requestPermission` → `getCurrentPosition()`; set state sesuai hasil. Dipanggil di `initState` dan oleh pull-to-refresh.
- `build()` membungkus `ListView` dengan `RefreshIndicator(onRefresh: _initDriverLocation)` + `AlwaysScrollableScrollPhysics` (agar pull tetap jalan walau konten pendek).
- `_buildPendingOrdersSection`: jika `_driverPosition != null` → `sortAndFilterByDistance` + render `OrderWithDistance` (badge jarak); jika kosong setelah filter → empty state radius; jika `_driverPosition == null` → banner + semua order tanpa filter.
- `_buildLocationBanner()` — banner kuning, pesan sesuai `_LocationState` (denied / serviceOff / generic) + tombol **"Coba Lagi"** (`_initDriverLocation`).
- `_buildDistanceBadge(distanceKm)` — chip "X.X km dari kamu" (tampil di header card pending, menggantikan posisi status chip).

## 6. Struktur Firestore yang Dipakai

**Tidak ada koleksi/field baru dan tidak ada penulisan apa pun.** Fitur hanya **membaca** yang sudah ada:

| Sumber | Dipakai untuk |
|---|---|
| `orders` (via `watchPendingOrders()`, filter `status == pending`) | Daftar order pending |
| `pickup_lat` / `pickup_lng` (→ `OrderModel.pickupLocation`) | Titik tujuan perhitungan Haversine |

Lokasi driver diambil **lokal** dari GPS device (Geolocator), **tidak** ditulis ke Firestore.

## 7. Cara Testing Manual

Device fisik (atau emulator dengan mock location).

1. **Driver dekat (< 10 km)** dari order test → order **muncul**, urutan terdekat di atas, badge "X.X km dari kamu" sesuai.
2. **Driver jauh (> 10 km)** (pakai mock location) → order **hilang** dari list; jika tak ada yang dalam radius → "Tidak ada order dalam radius 10 km dari lokasimu".
3. **Izin lokasi ditolak** manual → banner kuning + "Coba Lagi" muncul, **semua order tetap tampil** tanpa filter. Tap "Coba Lagi" → re-trigger permission.
4. **GPS service dimatikan** → banner serupa ("GPS tidak aktif…").
5. **Pull-to-refresh** setelah pindah lokasi → urutan/daftar ter-update sesuai posisi baru.
6. **Verifikasi filter**: ubah sementara `kMaxOrderRadiusKm` jadi `1.0`, pastikan order di luar 1 km hilang, lalu **balikkan ke `10.0`**.

## 8. Hasil Pengujian

**Terverifikasi end-to-end di device fisik** (bukan sekadar analyze).

- `flutter analyze` (distance_helper, order_service, driver_order_list_screen) → **No issues found!** ✔
- **Filter radius tervalidasi pakai jarak geografis asli** — diuji dengan order di kota berbeda (driver di **Jember** vs lokasi order di **Bondowoso**, ±35 km), **bukan** dengan memaksa `kMaxOrderRadiusKm` jadi kecil. Order di luar radius 10 km **benar-benar hilang** dari list, dan kembali muncul saat dalam radius. ✔
- **Badge jarak akurat** — nilai "X.X km dari kamu" pada tiap card sesuai jarak Haversine driver→pickup yang sebenarnya. ✔
- Ranking ascending: order terdekat tampil paling atas. ✔
- **Ketiga banner state tervalidasi:**
  - `denied` → banner + tombol **"Coba Lagi"** → re-trigger permission request berfungsi. ✔
  - `deniedForever` → banner "diblokir permanen" + tombol **"Buka Settings"** → `Geolocator.openAppSettings()` membuka App Info/Permissions. ✔
  - `serviceOff` → banner "GPS tidak aktif" + tombol **"Buka Pengaturan"** → `Geolocator.openLocationSettings()` membuka toggle GPS. ✔
- Saat lokasi tidak tersedia: semua order tetap tampil tanpa filter (fallback aman). ✔
- **Pull-to-refresh** setelah pindah lokasi / mengaktifkan izin dari Settings → daftar & urutan ter-update sesuai posisi baru. ✔

> Status: **PASS**. Penanganan `deniedForever` (terpisah dari `denied`, dengan aksi `openAppSettings`) ditambahkan setelah iterasi awal dan ikut tervalidasi.

## 9. Known Limitation

- **Lokasi driver diambil sekali** saat screen dibuka (+ pull-to-refresh manual); tidak ada stream realtime, jadi bisa basi kalau driver idle lama tanpa refresh.
- Filter & ranking **client-side**: semua order pending tetap di-download dari Firestore dulu, baru disaring di device (kurang efisien bila jumlah order pending sangat banyak).
- Radius tetap (`kMaxOrderRadiusKm = 10.0`) — belum bisa diatur driver/admin.
- Jarak Haversine = garis lurus (as-the-crow-flies), bukan jarak rute jalan; bisa berbeda dari jarak tempuh OSRM.
- Belum ada **auto-assign driver terdekat** dari sisi server (pendekatan ini hanya membantu driver memilih, bukan sistem yang memilih driver).

## 10. Next Improvement / Backlog

1. Auto-assign order ke driver terdekat (server-side) — butuh publisher lokasi driver saat idle (mis. `driver_locations/{driverId}`) + Cloud Functions.
2. Radius dinamis (slider di UI / konfigurasi admin di `pricing_config`).
3. Ranking gabungan: jarak + rating driver / estimasi waktu rute (OSRM).
4. Stream lokasi periodik agar urutan auto-update tanpa pull manual.
5. FCM push notif order baru dalam radius, Admin Dashboard.

## Status

> **SELESAI** (kode + analyze bersih) — Haversine Driver Order Ranking.
> Branch: `feature/haversine-driver-selection` (dari `main`). Pengujian device fisik mengikuti checklist Section 7.
