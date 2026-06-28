// Minimal store-only (no compression) ZIP writer. Works in the browser and in
// Node (dual-mode export at the bottom) so it can be unit-tested offline.
// ponytail: store method only — the bundle is three tiny text files; deflate
// would add a compressor for zero real benefit. Add deflate only if bundles grow.

function crc32(bytes) {
  let crc = 0 ^ -1;
  for (let i = 0; i < bytes.length; i++) {
    let c = (crc ^ bytes[i]) & 0xff;
    for (let k = 0; k < 8; k++) c = c & 1 ? (c >>> 1) ^ 0xedb88320 : c >>> 1;
    crc = (crc >>> 8) ^ c;
  }
  return (crc ^ -1) >>> 0;
}

// files: [{ name, content }]  →  Uint8Array of a valid .zip
function makeZip(files) {
  const enc = new TextEncoder();
  const u16 = (n) => [n & 0xff, (n >>> 8) & 0xff];
  const u32 = (n) => [n & 0xff, (n >>> 8) & 0xff, (n >>> 16) & 0xff, (n >>> 24) & 0xff];

  const parts = [];   // local entries
  const central = []; // central directory
  let offset = 0;

  for (const f of files) {
    const name = enc.encode(f.name);
    const data = enc.encode(f.content);
    const crc = crc32(data);

    const local = Uint8Array.from([
      ...u32(0x04034b50), ...u16(20), ...u16(0), ...u16(0),
      ...u16(0), ...u16(0), ...u32(crc),
      ...u32(data.length), ...u32(data.length),
      ...u16(name.length), ...u16(0),
    ]);
    parts.push(local, name, data);

    central.push(Uint8Array.from([
      ...u32(0x02014b50), ...u16(20), ...u16(20), ...u16(0), ...u16(0),
      ...u16(0), ...u16(0), ...u32(crc),
      ...u32(data.length), ...u32(data.length),
      ...u16(name.length), ...u16(0), ...u16(0), ...u16(0), ...u16(0),
      ...u32(0), ...u32(offset),
    ]), name);

    offset += local.length + name.length + data.length;
  }

  const centralStart = offset;
  const centralSize = central.reduce((n, a) => n + a.length, 0);
  const end = Uint8Array.from([
    ...u32(0x06054b50), ...u16(0), ...u16(0),
    ...u16(files.length), ...u16(files.length),
    ...u32(centralSize), ...u32(centralStart), ...u16(0),
  ]);

  const all = [...parts, ...central, end];
  const total = all.reduce((n, a) => n + a.length, 0);
  const out = new Uint8Array(total);
  let p = 0;
  for (const a of all) { out.set(a, p); p += a.length; }
  return out;
}

if (typeof module !== "undefined" && module.exports) module.exports = { makeZip, crc32 };
