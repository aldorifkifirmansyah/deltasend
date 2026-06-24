const admin = require('firebase-admin');
const path = require('path');
const serviceAccount = require(path.join(__dirname, 'service-account.json'));

admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

const lastKnownStatus = new Map();
let isFirstSnapshot = true;

async function sendNotification(uid, title, body, data = {}) {
  if (!uid) return;
  const userDoc = await db.collection('users').doc(uid).get();
  const token = userDoc.data()?.fcm_token;
  if (!token) {
    console.log(`[skip] uid=${uid} belum punya fcm_token (mungkin belum login ulang setelah Fase 1)`);
    return;
  }
  try {
    await admin.messaging().send({ token, notification: { title, body }, data });
    console.log(`[sent] uid=${uid} title="${title}"`);
  } catch (err) {
    console.error(`[error] gagal kirim ke uid=${uid}:`, err.message);
  }
}

async function notifyAllDrivers(orderId, order) {
  const drivers = await db.collection('users').where('role', '==', 'driver').get();
  drivers.forEach((doc) => {
    sendNotification(
      doc.id,
      'Order Baru Tersedia',
      `${order.item_description ?? 'Barang'} menunggu driver`,
      { orderId, type: 'new_order' }
    );
  });
}

const statusCopy = {
  pickingUp: 'Driver sedang menjemput barangmu',
  delivering: 'Barang sedang diantar ke tujuan',
  completed: 'Pesanan selesai! Yuk beri rating ke driver',
};

db.collection('orders').onSnapshot(
  (snapshot) => {
    if (isFirstSnapshot) {
      snapshot.docs.forEach((doc) => lastKnownStatus.set(doc.id, doc.data().status));
      isFirstSnapshot = false;
      console.log(`[init] ${snapshot.size} order ter-cache, siap listen perubahan baru`);
      return;
    }

    snapshot.docChanges().forEach((change) => {
      const order = change.doc.data();
      const orderId = change.doc.id;

      if (change.type === 'added' && order.status === 'pending') {
        console.log(`[event] order baru pending: ${orderId}`);
        notifyAllDrivers(orderId, order);
      }

      if (change.type === 'modified') {
        const prevStatus = lastKnownStatus.get(orderId);
        if (prevStatus && prevStatus !== order.status && statusCopy[order.status]) {
          console.log(`[event] order ${orderId} status ${prevStatus} -> ${order.status}`);
          sendNotification(order.customer_id, 'Update Pesanan', statusCopy[order.status], {
            orderId,
            type: 'status_update',
          });
        }
      }

      lastKnownStatus.set(orderId, order.status);
    });
  },
  (err) => {
    console.error('[fatal] Firestore listener error:', err.message);
  }
);

console.log('FCM notifier listening on orders collection...');