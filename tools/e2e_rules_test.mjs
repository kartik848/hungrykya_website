// End-to-end check of every role's flow against firestore.rules, using the
// local emulators. It mirrors the exact writes the app makes.
//
//   firebase emulators:start --only auth,firestore     (in another terminal)
//   node tools/e2e_rules_test.mjs
//
// WARNING: wipes all emulator data at start (never touches production).
const PROJECT = 'hungrykya-30719';
const AUTH = 'http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1';
const DB = `projects/${PROJECT}/databases/(default)/documents`;
const FS = `http://127.0.0.1:8081/v1/${DB}`;

// ---------- helpers ----------
const enc = (v) => {
  if (v === null || v === undefined) return { nullValue: null };
  if (v instanceof Date) return { timestampValue: v.toISOString() };
  if (typeof v === 'boolean') return { booleanValue: v };
  if (typeof v === 'number') return Number.isInteger(v) ? { integerValue: String(v) } : { doubleValue: v };
  if (typeof v === 'string') return { stringValue: v };
  if (Array.isArray(v)) return { arrayValue: { values: v.map(enc) } };
  return { mapValue: { fields: Object.fromEntries(Object.entries(v).map(([k, x]) => [k, enc(x)])) } };
};
const fields = (o) => Object.fromEntries(Object.entries(o).map(([k, v]) => [k, enc(v)]));
const ts = (fieldPath) => ({ fieldPath, setToServerValue: 'REQUEST_TIME' });
const union = (fieldPath, values) => ({ fieldPath, appendMissingElements: { values: values.map(enc) } });

/** set() — full overwrite (create if missing). */
const set = (path, data, transforms = []) => ({ update: { name: `${DB}/${path}`, fields: fields(data) }, updateTransforms: transforms });
/** set(..., merge: true) */
const merge = (path, data, transforms = []) => ({
  update: { name: `${DB}/${path}`, fields: fields(data) },
  updateMask: { fieldPaths: Object.keys(data) },
  updateTransforms: transforms,
});
/** update() — doc must exist. */
const update = (path, data, transforms = []) => ({ ...merge(path, data, transforms), currentDocument: { exists: true } });

async function commit(user, writes) {
  const r = await fetch(`${FS}:commit`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', ...(user ? { Authorization: `Bearer ${user.token}` } : {}) },
    body: JSON.stringify({ writes }),
  });
  if (!r.ok) throw new Error(`${r.status} ${(await r.json()).error?.status}`);
}
async function get(user, path) {
  const r = await fetch(`${FS}/${path}`, { headers: user ? { Authorization: `Bearer ${user.token}` } : {} });
  if (!r.ok) throw new Error(`${r.status} ${(await r.json()).error?.status}`);
  return r.json();
}
async function query(user, collectionId, where, orderBy) {
  const structuredQuery = { from: [{ collectionId }] };
  if (where) structuredQuery.where = { fieldFilter: { field: { fieldPath: where[0] }, op: 'EQUAL', value: enc(where[1]) } };
  if (orderBy) structuredQuery.orderBy = [{ field: { fieldPath: orderBy }, direction: 'DESCENDING' }];
  const r = await fetch(`${FS}:runQuery`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', ...(user ? { Authorization: `Bearer ${user.token}` } : {}) },
    body: JSON.stringify({ structuredQuery }),
  });
  const body = await r.json();
  if (!r.ok || body.some?.((x) => x.error)) throw new Error(`${r.status} ${JSON.stringify(body).slice(0, 80)}`);
  return body.filter((x) => x.document);
}
async function signUp(email) {
  const r = await (await fetch(`${AUTH}/accounts:signUp?key=fake`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password: '123456', returnSecureToken: true }),
  })).json();
  if (!r.idToken) throw new Error('signUp failed: ' + JSON.stringify(r));
  return { uid: r.localId, token: r.idToken, email };
}

let pass = 0, fail = 0;
async function expectAllow(name, fn) {
  try { await fn(); pass++; console.log(`  ✅ ${name}`); } catch (e) { fail++; console.log(`  ❌ ${name} — expected ALLOW, got ${e.message}`); }
}
async function expectDeny(name, fn) {
  try { await fn(); fail++; console.log(`  ❌ ${name} — expected DENY, but it was allowed`); } catch { pass++; console.log(`  ✅ ${name} (blocked)`); }
}

// Mirrors AuthService._ensureProfile
const profile = (u, role = 'customer') =>
  set(`users/${u.uid}`, { name: u.email.split('@')[0], email: u.email, phone: '9876543210', role, blocked: false }, [ts('createdAt')]);

// Mirrors CheckoutPage._place + Db.placeOrder
function order(u, id, { vendorId = 'house', vendorName = 'HungryKya Kitchen', commissionRate = 0, paymentMethod = 'upi', paymentStatus = 'pending', status = 'placed' } = {}) {
  const food = 538;
  return set(`orders/${id}`, {
    orderNo: 'HK2610010001', userId: u.uid, customerName: 'Test Customer', phone: '9876543210', email: u.email,
    address: 'Home: 12, MG Road, Nagpur', landmark: 'Near park', pincode: '440001', note: '', lat: 21.1458, lng: 79.0882,
    items: [{ productId: 'demo-chicken-biryani', name: 'Chicken Dum Biryani', price: 223, qty: 2, isVeg: false }, { productId: 'demo-samosa', name: 'Samosa', price: 92, qty: 1, isVeg: true }],
    vendorId, vendorName, mrpTotal: 617, subtotal: food, couponDiscount: 0, couponCode: '', deliveryFee: 0, total: food,
    commissionRate, commissionAmount: Math.round(food * commissionRate * 100) / 100, vendorPayout: vendorId === 'house' ? 0 : food * (1 - commissionRate),
    paymentMethod, paymentStatus, upiRef: '', status,
    statusHistory: [{ status: 'placed', at: new Date() }],
  }, [ts('createdAt'), ts('updatedAt')]);
}
// Mirrors Db.setOrderStatus
const setStatus = (id, status, extra = {}) =>
  update(`orders/${id}`, { status, ...extra }, [union('statusHistory', [{ status, at: new Date() }]), ts('updatedAt')]);

// ---------- run ----------
await fetch(`http://127.0.0.1:8081/emulator/v1/projects/${PROJECT}/databases/(default)/documents`, { method: 'DELETE' });
await fetch(`http://127.0.0.1:9099/emulator/v1/projects/${PROJECT}/accounts`, { method: 'DELETE' });

const admin = await signUp('admin@123.hungrykya.app');
const cust = await signUp('rahul@example.com');
const cust2 = await signUp('priya@example.com');
const vendor = await signUp('sharma.kitchen@example.com');
const rogue = await signUp('rogue@example.com');

console.log('\n👑 ADMIN');
await expectAllow('admin creates own profile', () => commit(admin, [profile(admin)]));
await expectAllow('admin adds a TOP banner', () => commit(admin, [set('banners/t1', { placement: 'hero', title: 'Biryani Festival', subtitle: '', imageUrl: 'https://i.ibb.co/x/a.jpg', ctaText: 'Order now', category: 'Biryani', active: true, sortOrder: 1 }, [ts('createdAt')])]));
await expectAllow('admin adds a BOTTOM banner', () => commit(admin, [set('banners/b1', { placement: 'bottom', title: 'Desserts from ₹99', subtitle: '', imageUrl: 'https://i.ibb.co/x/b.jpg', ctaText: 'See desserts', category: 'Desserts', active: true, sortOrder: 1 }, [ts('createdAt')])]));
await expectAllow('admin edits a banner (toggle off)', () => commit(admin, [update('banners/b1', { active: false })]));
await expectAllow('admin adds a product', () => commit(admin, [set('products/p1', { name: 'Chicken Dum Biryani', description: '', category: 'Biryani', imageUrl: '', price: 279, discountPercent: 20, isVeg: false, isAvailable: true, isBestseller: true, vendorId: 'house', vendorName: 'HungryKya Kitchen', vendorActive: true, sortOrder: 0 }, [ts('createdAt'), ts('updatedAt')])]));
await expectAllow('admin runs flash sale (update discount)', () => commit(admin, [update('products/p1', { discountPercent: 30 }, [ts('updatedAt')])]));
await expectAllow('admin creates coupon', () => commit(admin, [set('offers/o1', { code: 'HUNGRY20', title: '20% off', description: '', discountPercent: 20, maxDiscount: 100, minOrder: 299, active: true })]));
await expectAllow('admin saves settings + delivery areas', () => commit(admin, [merge('settings/store', { upiId: '903177188@axl', restrictArea: true, serviceCities: ['Nagpur'], servicePincodes: ['440001'], radiusKm: 5, kitchenLat: 21.14, kitchenLng: 79.08 }, [ts('updatedAt')])]));

console.log('\n🙋 CUSTOMER');
await expectAllow('anyone (logged out) can read menu, banners, offers, settings', async () => {
  await query(null, 'products'); await query(null, 'banners'); await query(null, 'offers'); await get(null, 'settings/store');
});
await expectAllow('customer signs up (creates profile)', () => commit(cust, [profile(cust)]));
await expectAllow('customer saves address with GPS location', () => commit(cust, [merge(`users/${cust.uid}`, { addresses: [{ id: 'a1', label: 'Home', house: '12', area: 'MG Road', landmark: '', city: 'Nagpur', district: 'Nagpur', pincode: '440001', lat: 21.1458, lng: 79.0882 }], defaultAddressId: 'a1' })]));
await expectDeny('customer cannot make themselves admin-blocked=false / edit blocked', () => commit(cust, [merge(`users/${cust.uid}`, { blocked: true })]));
await expectDeny('customer cannot add a banner', () => commit(cust, [set('banners/x', { title: 'hack', active: true })]));
await expectDeny('customer cannot change a price', () => commit(cust, [update('products/p1', { price: 1 })]));
await expectDeny('customer cannot read other users', () => query(cust, 'users'));
await expectAllow('customer places UPI order', () => commit(cust, [order(cust, 'o-upi')]));
await expectAllow('customer places COD order', () => commit(cust, [order(cust, 'o-cod', { paymentMethod: 'cod' })]));
await expectDeny('customer cannot place an already-"paid" order', () => commit(cust, [order(cust, 'o-fake', { paymentStatus: 'paid' })]));
await expectDeny('customer cannot place order for someone else', () => commit(cust, [order(cust2, 'o-other')]));
await expectAllow('customer lists own orders (My orders)', () => query(cust, 'orders', ['userId', cust.uid]));
await expectAllow('customer reads own order (tracking)', () => get(cust, 'orders/o-upi'));
await expectDeny('another customer cannot read it', () => get(cust2, 'orders/o-upi'));
await expectAllow('customer submits UPI reference (UTR)', () => commit(cust, [update('orders/o-upi', { paymentStatus: 'verification', upiRef: '412345678901' }, [ts('updatedAt')])]));
await expectDeny('customer cannot mark own payment as paid', () => commit(cust, [update('orders/o-upi', { paymentStatus: 'paid' })]));
await expectAllow('customer cancels COD order before acceptance', () => commit(cust, [setStatus('o-cod', 'cancelled')]));

console.log('\n👑 ADMIN — orders');
await expectAllow('admin lists all orders (dashboard)', () => query(admin, 'orders', null, 'createdAt'));
await expectAllow('admin verifies UPI payment → paid', () => commit(admin, [update('orders/o-upi', { paymentStatus: 'paid' }, [ts('updatedAt')])]));
await expectAllow('admin accepts order → confirmed', () => commit(admin, [setStatus('o-upi', 'confirmed')]));
await expectDeny('customer cannot cancel after kitchen accepted', () => commit(cust, [setStatus('o-upi', 'cancelled')]));
await expectAllow('admin moves order to delivered', async () => {
  for (const s of ['preparing', 'out_for_delivery', 'delivered']) await commit(admin, [setStatus('o-upi', s)]);
});
await expectAllow('admin lists customers & vendors', async () => { await query(admin, 'users'); await query(admin, 'vendors'); });

console.log('\n🏪 VENDOR');
await expectAllow('vendor registers (profile + pending application with 2% consent)', () => commit(vendor, [
  profile(vendor, 'vendor'),
  set(`vendors/${vendor.uid}`, {
    businessName: 'Sharma Rasoi', ownerName: 'Amit Sharma', email: vendor.email, phone: '9876500000', address: 'Sitabuldi', city: 'Nagpur', pincode: '440012',
    cuisine: 'North Indian', fssai: '', status: 'pending', commissionRate: 0.02,
    commissionConsent: { accepted: true, rate: 0.02, version: 'v1-2026-10', text: '…' },
  }, [ts('commissionConsent.acceptedAt'), ts('createdAt')]),
]));
await expectDeny('a vendor cannot register as already approved', () => commit(rogue, [set(`vendors/${rogue.uid}`, { businessName: 'X', status: 'approved', commissionRate: 0.02, commissionConsent: { accepted: true } })]));
await expectDeny('a vendor cannot register without 2% consent', () => commit(rogue, [set(`vendors/${rogue.uid}`, { businessName: 'X', status: 'pending', commissionRate: 0.02, commissionConsent: { accepted: false } })]));
await expectDeny('a vendor cannot register with 0% commission', () => commit(rogue, [set(`vendors/${rogue.uid}`, { businessName: 'X', status: 'pending', commissionRate: 0, commissionConsent: { accepted: true } })]));
await expectDeny('pending vendor cannot create categories', () => commit(vendor, [set('categories/vc0', { name: 'X', active: true })]));
await expectDeny('pending vendor cannot add products', () => commit(vendor, [set('products/v1', { name: 'Dal', price: 100, vendorId: vendor.uid, vendorActive: true })]));
await expectDeny('vendor cannot approve themselves', () => commit(vendor, [update(`vendors/${vendor.uid}`, { status: 'approved' })]));
await expectAllow('vendor can edit own profile (phone)', () => commit(vendor, [update(`vendors/${vendor.uid}`, { phone: '9876500001' }, [ts('updatedAt')])]));
await expectAllow('admin approves vendor (vendor + user + products batch)', () => commit(admin, [
  update(`vendors/${vendor.uid}`, { status: 'approved', rejectionReason: '' }, [ts('approvedAt'), ts('updatedAt')]),
  merge(`users/${vendor.uid}`, { blocked: false }),
]));
await expectAllow('approved vendor adds own product', () => commit(vendor, [set('products/v1', { name: 'Dal Makhani', description: '', category: 'Mains', imageUrl: 'https://i.ibb.co/x/c.jpg', price: 180, discountPercent: 0, isVeg: true, isAvailable: true, isBestseller: false, vendorId: vendor.uid, vendorName: 'Sharma Rasoi', vendorActive: true, sortOrder: 0 }, [ts('createdAt'), ts('updatedAt')])]));
await expectAllow('approved vendor creates a new category', () => commit(vendor, [set('categories/vc1', { name: 'Thali', imageUrl: '', sortOrder: 20, active: true }, [ts('createdAt')])]));
await expectDeny('vendor cannot rename/edit a category', () => commit(vendor, [update('categories/vc1', { name: 'Hacked' })]));
await expectDeny('vendor cannot delete a category', () => fetch(`${FS}/categories/vc1`, { method: 'DELETE', headers: { Authorization: `Bearer ${vendor.token}` } }).then(r => { if (!r.ok) throw new Error(String(r.status)); }));
await expectDeny('vendor cannot add product under HungryKya kitchen', () => commit(vendor, [set('products/v2', { name: 'X', price: 1, vendorId: 'house' })]));
await expectDeny('vendor cannot edit admin products', () => commit(vendor, [update('products/p1', { price: 1 })]));
await expectAllow('customer orders from vendor with 2% commission', () => commit(cust, [order(cust, 'o-v', { vendorId: vendor.uid, vendorName: 'Sharma Rasoi', commissionRate: 0.02, paymentMethod: 'cod' })]));
await expectDeny('vendor order without commission is rejected', () => commit(cust, [order(cust, 'o-v0', { vendorId: vendor.uid, vendorName: 'Sharma Rasoi', commissionRate: 0 })]));
await expectAllow('vendor lists own orders', () => query(vendor, 'orders', ['vendorId', vendor.uid]));
await expectDeny("vendor cannot read HungryKya's own orders", () => get(vendor, 'orders/o-upi'));
await expectAllow('vendor accepts & prepares order', async () => { await commit(vendor, [setStatus('o-v', 'confirmed')]); await commit(vendor, [setStatus('o-v', 'preparing')]); });
await expectDeny('vendor cannot change order total', () => commit(vendor, [update('orders/o-v', { total: 1 })]));
await expectAllow('vendor delivers COD order (auto-marked paid)', async () => {
  await commit(vendor, [setStatus('o-v', 'out_for_delivery')]);
  await commit(vendor, [setStatus('o-v', 'delivered', { paymentStatus: 'paid' })]);
});

console.log('\n💸 VENDOR PAYOUTS');
await expectAllow('vendor saves bank + UPI payout details', () => commit(vendor, [update(`vendors/${vendor.uid}`, { payout: { accountName: 'Amit Sharma', accountNumber: '123456789012', ifsc: 'BKID0000900', bankName: 'Bank of India', branch: 'Kolhapur', upiId: 'amit@ybl' } }, [ts('updatedAt')])]));
await expectAllow('admin records payout + marks order settled', () => commit(admin, [
  set('payouts/p1', { vendorId: vendor.uid, vendorName: 'Sharma Rasoi', amount: 527.24, commission: 10.76, orderIds: ['o-v'], method: 'upi', reference: '512345678901', note: '' }, [ts('paidAt')]),
  update('orders/o-v', { payoutId: 'p1' }, [ts('updatedAt')]),
]));
await expectAllow('vendor sees own payout history', () => query(vendor, 'payouts', ['vendorId', vendor.uid]));
await expectDeny('customer cannot read payouts', () => get(cust2, 'payouts/p1'));
await expectDeny('vendor cannot create a payout for themselves', () => commit(vendor, [set('payouts/fake', { vendorId: vendor.uid, amount: 99999 })]));
await expectDeny('vendor cannot mark own order settled', () => commit(vendor, [update('orders/o-v', { payoutId: 'fake' })]));
await expectDeny('customer cannot read vendor bank details', () => get(cust2, `vendors/${vendor.uid}`));

console.log('\n🚫 BLOCKING');
await expectAllow('admin blocks customer', () => commit(admin, [update(`users/${cust.uid}`, { blocked: true }, [ts('updatedAt')])]));
await expectDeny('blocked customer cannot order', () => commit(cust, [order(cust, 'o-blocked')]));
await expectDeny('blocked customer cannot unblock themselves', () => commit(cust, [merge(`users/${cust.uid}`, { blocked: false })]));
await expectAllow('admin blocks vendor (status + user + hide products)', () => commit(admin, [
  update(`vendors/${vendor.uid}`, { status: 'blocked', rejectionReason: 'Hygiene complaint' }, [ts('updatedAt')]),
  merge(`users/${vendor.uid}`, { blocked: true }),
  update('products/v1', { vendorActive: false, vendorName: 'Sharma Rasoi' }),
]));
await expectDeny('blocked vendor cannot add products', () => commit(vendor, [set('products/v3', { name: 'X', price: 1, vendorId: vendor.uid, vendorActive: true })]));
await expectDeny('blocked vendor cannot update orders', () => commit(vendor, [setStatus('o-v', 'cancelled')]));

console.log(`\n${fail === 0 ? '🎉' : '⚠️'}  ${pass} passed, ${fail} failed`);
process.exit(fail ? 1 : 0);
