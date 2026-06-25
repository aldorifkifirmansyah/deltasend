# FCM Notifier Service

Service Node.js yang jalan di VPS pribadi (kurumi-sekai.my.id), terpisah dari aplikasi Flutter.
Listen perubahan koleksi `orders` di Firestore secara real-time via Firebase Admin SDK,
kirim push notification lewat FCM saat status order berubah atau order baru `pending` dibuat.

Dijalankan via PM2: `pm2 start index.js --name deltasend-fcm-notifier`

Dependency: `firebase-admin` (lihat `package.json` di VPS)

**PENTING:** `service-account.json` TIDAK disertakan di sini (real secret, hanya ada di VPS,
tidak pernah masuk git). File ini wajib di-generate ulang dari Firebase Console kalau service
ini di-deploy ulang di tempat lain.