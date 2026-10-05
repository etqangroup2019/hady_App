// يولّد مفاتيح VAPID. شغّله مرة واحدة:  node scripts/gen-vapid.mjs
import { generateKeyPairSync } from 'node:crypto';

const { privateKey } = generateKeyPairSync('ec', { namedCurve: 'P-256' });
const jwk = privateKey.export({ format: 'jwk' });
const secret = JSON.stringify({ kty: jwk.kty, crv: jwk.crv, x: jwk.x, y: jwk.y, d: jwk.d });

console.log('\nانسخ السطر التالي كاملاً عند طلب القيمة في الأمر:');
console.log('  npx wrangler secret put VAPID_PRIVATE_JWK\n');
console.log(secret + '\n');
console.log('تحذير: هذا مفتاح سرّي. لا ترفعه إلى GitHub ولا تشاركه.');
