// Seeds demo sale data (menu with photos & discounts, hero + bottom banners,
// coupons, store settings) into Firestore as the HungryKya admin.
//
//   node tools/seed_demo.mjs            # uses admin@123 / 123456
//   EMULATOR=1 node tools/seed_demo.mjs # local emulators (auth :9099, firestore :8081)
//
// Re-running is safe: documents use fixed ids ("demo-…") and are overwritten.
const API_KEY = 'AIzaSyAhXbpUoca2H1WqLfiM9CMgTJZiJ-7oXe4';
const PROJECT = 'hungrykya-30719';
const EMAIL = process.env.ADMIN_EMAIL ?? 'admin@123.hungrykya.app';
const PASSWORD = process.env.ADMIN_PASSWORD ?? '123456';
const EMU = process.env.EMULATOR === '1';
const AUTH_BASE = EMU ? 'http://127.0.0.1:9099/identitytoolkit.googleapis.com' : 'https://identitytoolkit.googleapis.com';
const FS_BASE = EMU ? 'http://127.0.0.1:8081' : 'https://firestore.googleapis.com';

const img = (id, w = 800, h = 600) => `https://images.unsplash.com/photo-${id}?w=${w}&h=${h}&q=75&fit=crop&auto=format`;

const P = {
  chickenBiryani: '1589302168068-964664d93dc0',
  vegBiryani: '1563379091339-03b21ab4a4f8',
  paneerMasala: '1631452180519-c014fe946bc7',
  paneerTikka: '1567188040759-fb8a883dc6d8',
  kebab: '1599487488170-d11ec9c172f0',
  pavBhaji: '1606491956689-2ea866880c84',
  samosa: '1601050690597-df0568f70950',
  chickenCurry: '1596797038530-2c107229654b',
  curryCombo: '1585937421612-70a008356fbe',
  friedChicken: '1626082927389-6cd097cdc6ec',
  pizza: '1565299624946-b28f40a0ae38',
  burger: '1568901346375-23c9450c58cd',
  salad: '1512621776951-a57141f2eefd',
  pastry: '1565958011703-44f9829ba187',
  tiramisu: '1571877227200-a0d98ea607e9',
  donuts: '1551024601-bec78aea704b',
  grill: '1555939594-58d7cb561ad1',
};

// [id, name, description, category, price, discount%, veg, bestseller, photo]
const products = [
  ['chicken-biryani', 'Chicken Dum Biryani', 'Slow-cooked basmati, tender chicken, saffron & fried onions. Served with raita and salan.', 'Biryani', 279, 20, false, true, P.chickenBiryani],
  ['veg-biryani', 'Veg Handi Biryani', 'Fragrant basmati layered with garden vegetables and whole spices, sealed in a handi.', 'Biryani', 219, 15, true, false, P.vegBiryani],
  ['paneer-butter-masala', 'Paneer Butter Masala', 'Soft paneer cubes in a silky tomato-butter gravy. Best with butter naan.', 'Mains', 229, 0, true, true, P.paneerMasala],
  ['chicken-curry', 'Home-style Chicken Curry', 'Bone-in chicken simmered with onions, tomatoes and ghar ka masala.', 'Mains', 259, 0, false, false, P.chickenCurry],
  ['curry-combo', 'Butter Chicken Rice Combo', 'Butter chicken, jeera rice, salad and a gulab jamun — a full meal.', 'Combos', 319, 15, false, true, P.curryCombo],
  ['paneer-tikka', 'Paneer Tikka (8 pc)', 'Char-grilled paneer, capsicum and onion marinated in tandoori spices.', 'Starters', 249, 25, true, false, P.paneerTikka],
  ['chicken-tikka', 'Chicken Tikka Kebab', 'Juicy chicken skewers fresh off the grill with mint chutney.', 'Starters', 269, 0, false, true, P.kebab],
  ['pav-bhaji', 'Mumbai Pav Bhaji', 'Buttery bhaji with 2 soft pav, onions and lemon — Juhu beach style.', 'Street Food', 149, 10, true, true, P.pavBhaji],
  ['samosa', 'Punjabi Samosa (2 pc)', 'Crispy pastry stuffed with spiced potato & peas, with green chutney.', 'Street Food', 59, 0, true, false, P.samosa],
  ['fried-chicken', 'Crispy Fried Chicken (4 pc)', 'Golden, crunchy and juicy — with peri-peri dip.', 'Fast Food', 239, 20, false, false, P.friedChicken],
  ['cheese-pizza', 'Cheese Burst Veg Pizza', 'Loaded with mozzarella, onion, capsicum and sweet corn.', 'Pizza', 299, 30, true, true, P.pizza],
  ['smash-burger', 'Double Smash Burger', 'Two chicken patties, cheese, pickles and our secret sauce.', 'Fast Food', 199, 0, false, false, P.burger],
  ['garden-bowl', 'Fresh Garden Bowl', 'Avocado, chickpeas, greens and crunchy veggies with lemon dressing.', 'Healthy', 179, 0, true, false, P.salad],
  ['strawberry-pastry', 'Strawberry Cream Pastry', 'Light sponge layered with fresh cream and strawberries.', 'Desserts', 129, 0, true, false, P.pastry],
  ['tiramisu', 'Classic Tiramisu', 'Coffee-soaked layers with mascarpone and cocoa.', 'Desserts', 149, 10, true, false, P.tiramisu],
  ['donuts', 'Choco Sprinkle Donuts (2 pc)', 'Soft donuts dipped in chocolate with rainbow sprinkles.', 'Desserts', 99, 0, true, false, P.donuts],
];

// [name, photo] in menu order
const categories = [
  ['Biryani', P.chickenBiryani], ['Mains', P.paneerMasala], ['Combos', P.curryCombo], ['Starters', P.paneerTikka],
  ['Street Food', P.pavBhaji], ['Pizza', P.pizza], ['Fast Food', P.burger], ['Healthy', P.salad], ['Desserts', P.pastry],
];

const banners = [
  ['hero-biryani', 'hero', 'Biryani Festival — Flat 20% OFF', 'Dum-cooked chicken & veg biryani, sealed in handi and delivered hot.', 'Order biryani', 'Biryani', img(P.chickenBiryani, 1800, 1000), 1],
  ['hero-pizza', 'hero', 'Weekend Pizza Party 🍕', 'Cheese-burst pizzas at 30% off — this weekend only.', 'Grab a slice', 'Pizza', img(P.pizza, 1800, 1000), 2],
  ['promo-desserts', 'bottom', 'Sweet tooth? Desserts from ₹99', 'Pastries, tiramisu & donuts to end every meal right.', 'See desserts', 'Desserts', img(P.donuts, 1200, 600), 1],
  ['promo-street', 'bottom', 'Mumbai street food cravings', 'Pav bhaji & samosa — 10% off today.', 'Order now', 'Street Food', img(P.pavBhaji, 1200, 600), 2],
  ['promo-grill', 'bottom', 'Grill night 🔥', 'Paneer tikka & kebabs fresh off the grill — up to 25% off.', 'View starters', 'Starters', img(P.grill, 1200, 600), 3],
];

const offers = [
  ['HUNGRY20', 'Flat 20% off on your order', 'Valid on orders above ₹299', 20, 100, 299],
  ['FIRSTBITE', '50% off your first order', 'New here? Max ₹120 off on orders above ₹199', 50, 120, 199],
  ['FEAST15', '15% off on big feasts', 'No cap — on orders above ₹599', 15, 0, 599],
];

// ---------- Firestore REST helpers ----------
const enc = (v) => {
  if (v === null || v === undefined) return { nullValue: null };
  if (typeof v === 'boolean') return { booleanValue: v };
  if (typeof v === 'number') return Number.isInteger(v) ? { integerValue: String(v) } : { doubleValue: v };
  if (typeof v === 'string') return { stringValue: v };
  if (Array.isArray(v)) return { arrayValue: { values: v.map(enc) } };
  return { mapValue: { fields: Object.fromEntries(Object.entries(v).map(([k, x]) => [k, enc(x)])) } };
};
const docName = (path) => `projects/${PROJECT}/databases/(default)/documents/${path}`;
const write = (path, data) => ({
  update: { name: docName(path), fields: Object.fromEntries(Object.entries(data).map(([k, v]) => [k, enc(v)])) },
  updateTransforms: [{ fieldPath: 'updatedAt', setToServerValue: 'REQUEST_TIME' }],
});

const login = await (await fetch(`${AUTH_BASE}/v1/accounts:signInWithPassword?key=${API_KEY}`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ email: EMAIL, password: PASSWORD, returnSecureToken: true }),
})).json();
if (!login.idToken) throw new Error('Admin login failed: ' + JSON.stringify(login.error));

const writes = [];
products.forEach(([id, name, description, category, price, discountPercent, isVeg, isBestseller, photo], i) =>
  writes.push(write(`products/demo-${id}`, {
    name, description, category, price, discountPercent, isVeg, isBestseller,
    imageUrl: img(photo), isAvailable: true,
    vendorId: 'house', vendorName: 'HungryKya Kitchen', vendorActive: true, sortOrder: i,
  })));
categories.forEach(([name, photo], i) =>
  writes.push(write(`categories/demo-${name.toLowerCase().replace(/\s+/g, '-')}`, { name, imageUrl: img(photo, 600, 600), sortOrder: i, active: true })));
const badges = { 'promo-desserts': 'Sweet deal', 'promo-street': 'Today only', 'promo-grill': 'Limited time' };
banners.forEach(([id, placement, title, subtitle, ctaText, category, imageUrl, sortOrder]) =>
  writes.push(write(`banners/demo-${id}`, { placement, title, subtitle, ctaText, category, imageUrl, sortOrder, active: true, badge: badges[id] ?? '', productId: '' })));
offers.forEach(([code, title, description, discountPercent, maxDiscount, minOrder]) =>
  writes.push(write(`offers/demo-${code.toLowerCase()}`, { code, title, description, discountPercent, maxDiscount, minOrder, active: true })));
writes.push(write('settings/store', {
  upiId: '903177188@axl', payeeName: 'HungryKya', deliveryFee: 30, freeDeliveryAbove: 399, minOrder: 99, etaMinutes: 35, storeOpen: true,
}));

const res = await fetch(`${FS_BASE}/v1/projects/${PROJECT}/databases/(default)/documents:commit`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${login.idToken}` },
  body: JSON.stringify({ writes }),
});
const out = await res.json();
if (!res.ok) throw new Error(`Seed failed (${res.status}): ${JSON.stringify(out.error ?? out)}`);
console.log(`Seeded ${categories.length} categories, ${products.length} products, ${banners.length} banners, ${offers.length} coupons and store settings.`);
