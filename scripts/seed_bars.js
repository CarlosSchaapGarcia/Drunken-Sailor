const admin = require('firebase-admin');
const ngeohash = require('ngeohash');
const serviceAccount = require('./serviceAccountKey.json');
const { bars: rawBars } = require('./emmen_bars.js');

admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

function toMinutes(timeStr) {
  const [h, m] = timeStr.split(':').map(Number);
  return h * 60 + m;
}

function convertHours(rawHours) {
  if (!rawHours) return {};
  const result = {};
  for (const [day, slot] of Object.entries(rawHours)) {
    if (slot) {
      result[day] = { opens: toMinutes(slot.open), closes: toMinutes(slot.close) };
    }
  }
  return result;
}

async function deleteAll() {
  const snapshot = await db.collection('bars').get();
  const batch = db.batch();
  snapshot.docs.forEach(doc => batch.delete(doc.ref));
  await batch.commit();
  console.log(`Deleted ${snapshot.size} existing bars.`);
}

async function seed() {
  await deleteAll();
  for (const bar of rawBars) {
    const ref = await db.collection('bars').add({
      name: bar.name,
      latitude: bar.latitude,
      longitude: bar.longitude,
      geohash: ngeohash.encode(bar.latitude, bar.longitude, 9),
      location: new admin.firestore.GeoPoint(bar.latitude, bar.longitude),
      gay_friendly: bar.gay_friendly,
      hours: convertHours(bar.hours),
    });
    console.log(`Added "${bar.name}" → ${ref.id}`);
  }
  console.log('Done.');
}

seed().catch(console.error).finally(() => process.exit(0));
