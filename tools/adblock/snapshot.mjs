// Preserve uBO's engine selfies, loading large typed arrays as native bytes and
// parsing metadata with JSON.parse rather than interpreting giant JS literals.
export function encodeSnapshot(snapshot) {
    const chunks = [], views = [], fixups = [];
    let byteLength = 0;
    const active = new Set();
    function encode(value, path) {
        if (value === undefined) { fixups.push(`${path}=void 0;`); return null; }
        if (typeof value === 'number' && (!Number.isFinite(value) || Object.is(value, -0))) {
            fixups.push(`${path}=${Object.is(value, -0) ? '-0' : String(value)};`); return null;
        }
        if (value === null || typeof value === 'string' || typeof value === 'number' || typeof value === 'boolean') return value;
        if (typeof value !== 'object') throw new TypeError(`Unsupported snapshot value at ${path}`);
        if (active.has(value)) throw new TypeError(`Cyclic filter snapshot at ${path}`);
        active.add(value);
        let result;
        if (ArrayBuffer.isView(value)) {
            const name = value.constructor.name;
            if (!['Uint8Array', 'Uint32Array', 'Int32Array'].includes(name)) throw new TypeError(`Unsupported snapshot view: ${name}`);
            const padding = (4 - byteLength % 4) % 4;
            if (padding) { chunks.push(Buffer.alloc(padding)); byteLength += padding; }
            const offset = byteLength;
            const bytes = Buffer.from(value.buffer, value.byteOffset, value.byteLength);
            chunks.push(bytes); byteLength += bytes.length;
            views.push({ path, type: name, offset, length: value.length, byte_length: value.byteLength });
            // uBO mutates restored tries; keep the bundled backing bytes intact
            // so custom/default reinitialization gets fresh engine-owned data.
            fixups.push(`${path}=new ${name}(new ${name}(bytes.buffer,bytes.byteOffset+${offset},${value.length}));`);
            result = null;
        } else if (value instanceof Map) {
            result = Array.from(value, ([key, item], index) => [encode(key, `${path}[${index}][0]`), encode(item, `${path}[${index}][1]`)]);
            fixups.push(`${path}=new Map(${path});`);
        } else if (value instanceof Set) {
            result = Array.from(value, (item, index) => encode(item, `${path}[${index}]`));
            fixups.push(`${path}=new Set(${path});`);
        } else if (value instanceof RegExp) {
            fixups.push(`${path}=new RegExp(${JSON.stringify(value.source)},${JSON.stringify(value.flags)});`);
            result = null;
        } else if (Array.isArray(value)) {
            result = value.map((item, index) => encode(item, `${path}[${index}]`));
        } else if (Object.getPrototypeOf(value) === Object.prototype || Object.getPrototypeOf(value) === null) {
            result = Object.create(null);
            for (const [key, item] of Object.entries(value)) result[key] = encode(item, `${path}[${JSON.stringify(key)}]`);
        } else {
            throw new TypeError(`Unsupported snapshot object at ${path}`);
        }
        active.delete(value);
        return result;
    }
    // Match esbuild's ASCII source encoding without asking JavaScriptCore to
    // lex a multi-megabyte string literal. JSON escapes preserve every UTF-16
    // code unit, including supplementary characters and lone surrogates.
    const metadata = JSON.stringify(encode(snapshot, 'snapshot')).replace(/[\u007F-\uFFFF]/g, character =>
        `\\u${character.charCodeAt(0).toString(16).padStart(4, '0')}`);
    const source = `export default {restore(){const bytes=globalThis.voxAdblockSnapshotBytes;if(!(bytes instanceof Uint8Array)||bytes.byteLength!==${byteLength})throw new Error('Invalid bundled uBlock Origin snapshot bytes');let snapshot=globalThis.voxAdblockReadSnapshotMetadata();${fixups.join('')}return snapshot;}};\n`;
    return { source, metadata, binary: Buffer.concat(chunks), layout: { byte_length: byteLength, views } };
}
