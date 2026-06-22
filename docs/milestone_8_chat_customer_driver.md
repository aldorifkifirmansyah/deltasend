# Milestone 8 — Chat Customer–Driver

## 1. Ringkasan Milestone

Milestone 8 menambahkan fitur **chat real-time per order** antara customer dan driver, mengikuti pola arsitektur yang sudah ada (Service + Firestore stream + StreamBuilder).

Karena setiap order sudah memiliki `customer_id` dan `driver_id` begitu driver menerima order (status `pickingUp`), **`orderId` dipakai sekaligus sebagai `chatId`** (1:1 deterministic) — tidak perlu generate ID baru atau proses "connect" manual. Dokumen `chats/{orderId}` dibuat secara **lazy** saat chat pertama kali dibuka (`ensureChatExists`).

Tombol chat muncul di `MapDriverScreen` (sisi driver) dan `CustomerTrackingScreen` (sisi customer), keduanya menuju `ChatScreen` yang sama dengan `orderId` terkait.

## 2. Tujuan Milestone

- Komunikasi langsung customer ↔ driver dalam satu sesi order.
- Real-time via Firestore stream, tanpa polling.
- Tanpa proses pairing manual — chat memakai `orderId` sebagai room.
- Menandai pesan terbaca (`is_read`) saat lawan membuka chat.

## 3. Flow Chat

```
[MapDriverScreen / CustomerTrackingScreen]
  - Tombol chat di AppBar (muncul jika order sudah punya driver_id)
      │  tap
      ▼
[ChatScreen(orderId, currentUserId, customerId, driverId)]
  - initState → ensureChatExists(orderId, customerId, driverId)  (lazy create)
  - initState → markMessagesAsRead(orderId, currentUserId)
  - load nama lawan dari users/{otherUserId} untuk judul AppBar
  - StreamBuilder watchMessages(orderId) → bubble chat real-time
      │  ketik + kirim
      ▼
[ChatService.sendMessage] → chats/{orderId}/messages (sent_at serverTimestamp)
      │
      ▼
[Stream emit] → bubble baru muncul, auto-scroll ke bawah
```

Bubble: pesan dari `currentUserId` rata kanan (warna primary), pesan lawan rata kiri (abu-abu).

## 4. File yang Dibuat/Diubah

**File baru:**
- `lib/models/message_model.dart` — model pesan.
- `lib/services/chat_service.dart` — service chat (Firestore).
- `lib/views/chat/chat_screen.dart` — layar percakapan.
- `firestore.rules` — referensi security rules (termasuk aturan `chats`).

**File diubah:**
- `lib/views/map_driver_screen.dart` — tombol chat di AppBar (sisi driver).
- `lib/views/customer/customer_tracking_screen.dart` — tombol chat di AppBar (sisi customer) + fetch participant.

> Tidak menyentuh `order_model.dart` maupun `order_service.dart` — `chat_service.dart` berdiri independen.

## 5. Detail Teknis

### `lib/models/message_model.dart`
`MessageModel`: `messageId`, `senderId`, `content`, `sentAt` (DateTime?), `isRead` (bool). Factory `fromFirestore` membaca `sender_id`, `content`, `sent_at` (Timestamp), `is_read`.

### `lib/services/chat_service.dart`
- `ensureChatExists({orderId, customerId, driverId})` — cek dokumen `chats/{orderId}`; jika belum ada → `set(..., merge: true)` dengan `order_id`, `customer_id`, `driver_id`, `created_at` (serverTimestamp).
- `sendMessage({orderId, senderId, content})` — tambah dokumen ke subcollection `messages` (`sent_at` serverTimestamp, `is_read: false`). Konten kosong diabaikan.
- `watchMessages(orderId)` — `Stream<List<MessageModel>>`, `orderBy('sent_at')` ascending (single field, tanpa composite index).
- `markMessagesAsRead({orderId, currentUserId})` — query pesan `is_read == false`, lalu batch-update `is_read = true` untuk pesan yang `sender_id != currentUserId`.

Semua method dibungkus try-catch dengan `Exception` berpesan Bahasa Indonesia (mengikuti gaya `order_service.dart`).

### `lib/views/chat/chat_screen.dart`
- Parameter: `orderId`, `currentUserId`, `customerId`, `driverId`. Lawan chat (`_otherUserId`) diturunkan: jika `currentUserId == customerId` → driver, selain itu → customer.
- `initState`: `ensureChatExists` + `markMessagesAsRead`, lalu load nama lawan dari `users/{otherUserId}` untuk judul AppBar (fallback "Chat").
- `StreamBuilder` → `ListView.builder` bubble; **auto-scroll** ke bawah saat ada pesan baru (`ScrollController` + post-frame).
- Input bar: `TextField` + tombol kirim (`IconButton.filled`); submit lewat tombol atau keyboard action.

> **Catatan parameter:** Spesifikasi menyebut `otherUserName`, tetapi bagian integrasi meminta meneruskan id lawan. Agar `ensureChatExists(customerId, driverId)` benar dan nama lawan bisa di-resolve, `ChatScreen` menerima `customerId` + `driverId` (keduanya = UID), menurunkan `otherUserId`, lalu mengambil nama lawan dari koleksi `users` secara internal.

### Integrasi tombol
- **Driver** (`MapDriverScreen`): chat icon di AppBar muncul saat `currentOrder.driverId` terisi. `currentUserId = currentOrder.driverId`, `customerId = currentOrder.customerId`.
- **Customer** (`CustomerTrackingScreen`): participant (`customer_id`/`driver_id`) di-fetch sekali via `fetchOrderById` di `initState`; chat icon muncul setelahnya. `currentUserId = customerId` (UID customer).

## 6. Struktur Firestore yang Dipakai

```
chats/{orderId}
  - order_id: string
  - customer_id: string
  - driver_id: string
  - created_at: timestamp
  messages/ (subcollection)
    {messageId}
      - sender_id: string
      - content: string
      - sent_at: timestamp (serverTimestamp)
      - is_read: boolean (default false)
```

### Security Rules (`firestore.rules`)
Hanya user dengan `uid` == `customer_id` **atau** `driver_id` pada `chats/{orderId}` yang boleh read/write dokumen chat & subcollection `messages` (messages memverifikasi partisipan via `get()` ke dokumen chat induk). File `firestore.rules` di root adalah referensi untuk di-merge ke Firebase Console.

## 7. Cara Testing Manual

**Prasyarat:** ada order yang sudah di-accept driver (status `pickingUp`/`delivering`) sehingga `driver_id` terisi. Siapkan 2 akun (1 customer, 1 driver) di 2 device/emulator.

1. **Driver** buka order aktif → `MapDriverScreen` → tap **ikon chat** di AppBar.
2. ChatScreen terbuka, judul = nama customer. Kirim pesan "Halo".
3. **Customer** buka `CustomerTrackingScreen` untuk order yang sama → tap **ikon chat** → pesan "Halo" muncul real-time (rata kiri/abu-abu).
4. Customer balas "Siap" → di sisi driver muncul real-time (rata kiri), di sisi customer rata kanan (primary).
5. Cek Firestore: `chats/{orderId}` ada (`order_id`, `customer_id`, `driver_id`, `created_at`); subcollection `messages` berisi pesan dengan `sent_at` & `is_read`.
6. Cek `is_read`: pesan yang sudah dibuka lawan → `is_read: true`.
7. Cek auto-scroll: kirim banyak pesan → list otomatis scroll ke bawah.

## 8. Hasil Pengujian

- `flutter analyze` → **No issues found!** (seluruh project).
- Dokumen `chats/{orderId}` dibuat lazy saat chat pertama dibuka. ✔
- Pesan terkirim & tampil real-time dua arah. ✔
- Bubble: pesan sendiri rata kanan (primary), lawan rata kiri (abu-abu). ✔
- Auto-scroll ke pesan terbaru. ✔
- `markMessagesAsRead` menandai pesan lawan `is_read = true`. ✔
- Tombol chat muncul di driver & customer saat `driver_id` terisi. ✔

## 9. Known Limitation

- **Belum ada badge unread** di tombol chat (jumlah pesan belum dibaca tidak ditampilkan), meski `is_read` sudah dicatat.
- `markMessagesAsRead` hanya dipanggil saat membuka screen; jika chat tetap terbuka dan pesan baru masuk, tanda baca tidak otomatis diperbarui.
- Belum ada notifikasi (FCM) saat pesan baru — perlu Milestone notifikasi.
- Chat hanya tersedia setelah order punya `driver_id`; order `pending` belum punya lawan chat.
- Tidak ada hapus/edit pesan, kirim gambar, atau indikator "sedang mengetik".
- Nama lawan di AppBar gagal dimuat → fallback teks "Chat" (tetap berfungsi).

## 10. Next Improvement / Backlog

1. Badge jumlah pesan belum dibaca di tombol chat.
2. Push Notification (FCM) untuk pesan baru.
3. Tandai terbaca real-time saat screen aktif (listen + update).
4. Seleksi Driver by Jarak (Haversine), Admin Dashboard.

## Status

> **SELESAI** — Chat Customer–Driver.
> Branch acuan: dibuat dari `main`.
