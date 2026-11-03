import { packedArray, packedMap, readPackedValue, encodePackedTable } from './lazy_snapshot.mjs';
import { classicScript } from './classic_script.mjs';

// Preserve uBO's engine selfies, loading large typed arrays as native bytes and
// parsing metadata with JSON.parse rather than interpreting giant JS literals.
export function encodeSnapshot(snapshot, { lazyCosmetics = false, lazyNetworkBuckets = false, lazyNetworkReferences = false, publicSuffixText, parserSource, builtinScriptletsSource, resourceCatalog, urlSource, regexSource, base64Source } = {}) {
    const chunks = [], views = [], fixups = [];
    let byteLength = 0;
    const active = new Set();
    let hasPackedTables = false;
    let hasPackedReferences = false;
    const primitive = value => value === null || ['string', 'boolean'].includes(typeof value)
        || typeof value === 'number' && Number.isFinite(value) && !Object.is(value, -0);
    const jsonValue = (value, ancestors = new Set()) => {
        if (primitive(value)) return true;
        if (!value || typeof value !== 'object' || ancestors.has(value)
            || !Array.isArray(value) && Object.getPrototypeOf(value) !== Object.prototype
                && Object.getPrototypeOf(value) !== null) return false;
        ancestors.add(value);
        const valid = Object.values(value).every(item => jsonValue(item, ancestors));
        ancestors.delete(value);
        return valid;
    };
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
        if (lazyNetworkReferences && path === 'snapshot["network"]["filterRefs"]'
            && Array.isArray(value) && value.every(item => item instanceof RegExp || jsonValue(item))) {
            const references = value.map(item => item instanceof RegExp
                ? [1, item.source, item.flags] : [0, item]);
            const table = encodePackedTable(references, 1), offset = byteLength;
            chunks.push(table); byteLength += table.length;
            fixups.push(`${path}=packedArray(clone(Uint8Array,${offset},${table.length}),(bytes,index)=>{const value=read(bytes,index);return value[0]===1?new RegExp(value[1],value[2]):value[1];},globalThis.voxAdblockEagerSnapshotTables===true);ownedReferences.add(${path});`);
            hasPackedTables = hasPackedReferences = true;
            active.delete(value);
            return null;
        }
        // The outer category map previously constructed every inner Map even
        // though one request uses only a few categories. Store each inner
        // primitive table separately and decode it only when its category is
        // queried. The normal map factories materialize before mutations or
        // iteration and preserve already-returned, possibly mutated inner maps.
        const networkBuckets = lazyNetworkBuckets && path === 'snapshot["network"]["bitsToBucket"]'
            && value instanceof Map && [...value].every(([key, bucket]) =>
                Number.isSafeInteger(key) && key >= 0 && bucket instanceof Map
                && [...bucket].every(([token, item]) => Number.isSafeInteger(token)
                    && token >= 0 && primitive(item)));
        if (networkBuckets) {
            const descriptors = new Map();
            for (const [key, bucket] of value) {
                const table = encodePackedTable(bucket, 3), offset = byteLength;
                chunks.push(table); byteLength += table.length;
                descriptors.set(key, [offset, table.length]);
            }
            const table = encodePackedTable(descriptors, 3), offset = byteLength;
            chunks.push(table); byteLength += table.length;
            const eager = 'globalThis.voxAdblockEagerSnapshotTables===true';
            fixups.push(`${path}=packedMap(clone(Uint8Array,${offset},${table.length}),read,${eager},([offset,length])=>packedMap(clone(Uint8Array,offset,length),read,${eager}));`);
            hasPackedTables = true;
            active.delete(value);
            return null;
        }
        // uBO assigns these immutable lookup tables directly during restoration.
        // Queries need a handful of entries; mutation/iteration materializes all
        // original entries. Other snapshot records keep the existing codec.
        const packedArrayTable = lazyCosmetics && path.startsWith('snapshot["cosmetics"]')
            && /\["(strSlots|linkedLists)"\]$/.test(path) && Array.isArray(value)
            && value.length > 1024 && value.every(primitive);
        const lookupThreshold = lazyCosmetics && path.startsWith('snapshot["cosmetics"]') ? 1024
            : lazyNetworkBuckets && path.startsWith('snapshot["network"]["bitsToBucket"]') ? 128 : Infinity;
        const packedMapTable = value instanceof Map && value.size > lookupThreshold
            && [...value.values()].every(primitive);
        const stringKeys = packedMapTable && [...value.keys()].every(key => typeof key === 'string');
        const numberKeys = packedMapTable && [...value.keys()].every(key => Number.isSafeInteger(key) && key >= 0);
        if (packedArrayTable || stringKeys || numberKeys) {
            const table = encodePackedTable(value, packedArrayTable ? 1 : stringKeys ? 2 : 3);
            const offset = byteLength;
            chunks.push(table); byteLength += table.length;
            fixups.push(`${path}=${packedArrayTable ? 'packedArray' : 'packedMap'}(clone(Uint8Array,${offset},${table.length}),read,globalThis.voxAdblockEagerSnapshotTables===true);`);
            result = null;
            hasPackedTables = true;
        } else if (ArrayBuffer.isView(value)) {
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
            fixups.push(`${path}=clone(${name},${offset},${value.length});`);
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
    let suffixReader = '';
    for (const [name, input] of [['publicSuffixText',publicSuffixText],['parserSource',parserSource],['builtinScriptletsSource',builtinScriptletsSource],['urlSource',urlSource],['regexSource',regexSource],['base64Source',base64Source]]) {
        const value = name.endsWith('Source') && typeof input === 'string' ? classicScript(input) : input;
        if (value === undefined) continue;
        const table = encodePackedTable([value], 1), offset = byteLength;
        chunks.push(table); byteLength += table.length;
        suffixReader += `${name}(){const bytes=globalThis.voxAdblockSnapshotBytes;return (globalThis.voxAdblockReadPackedValue||(${readPackedValue}))(new Uint8Array(bytes.buffer,bytes.byteOffset+${offset},${table.length}),0);},`;
    }
    if (resourceCatalog !== undefined) {
        const tables = [];
        for (const name of ['entries','aliases']) {
            const table = encodePackedTable(resourceCatalog[name],2), offset = byteLength;
            chunks.push(table); byteLength += table.length;
            tables.push(`${name}:packedMap(new Uint8Array(bytes.buffer,bytes.byteOffset+${offset},${table.length}),read,globalThis.voxAdblockEagerSnapshotTables===true)`);
        }
        suffixReader += `resources(){const bytes=globalThis.voxAdblockSnapshotBytes,packedMap=${packedMap},read=globalThis.voxAdblockReadPackedValue||(${readPackedValue});return {${tables.join(',')}};},`;
    }
    const readers = hasPackedTables ? `const packedArray=${packedArray},packedMap=${packedMap},read=globalThis.voxAdblockReadPackedValue||(${readPackedValue});` : '';
    // Only a newly restored private reference array can be transferred to uBO.
    // Ordinary fromSelfie callers retain the original copy semantics. Taking
    // ownership once prevents two engines from adopting the same mutable array.
    const ownership = hasPackedReferences ? `const ownedReferences=new WeakSet();globalThis.voxAdblockTakeFilterReferences=value=>{if(!ownedReferences.delete(value))return;return value;};` : '';
    const source = `${ownership}export default {${suffixReader}restore(){const bytes=globalThis.voxAdblockSnapshotBytes;if(!(bytes instanceof Uint8Array)||bytes.byteLength!==${byteLength})throw new Error('Invalid bundled uBlock Origin snapshot bytes');const clone=(Type,offset,length)=>{const view=new Type(bytes.buffer,bytes.byteOffset+offset,length);return typeof globalThis.voxAdblockCloneSnapshotView==='function'?globalThis.voxAdblockCloneSnapshotView(view):new Type(view);};${readers}let snapshot=globalThis.voxAdblockReadSnapshotMetadata();${fixups.join('')}return snapshot;}};\n`;
    return { source, metadata, binary: Buffer.concat(chunks), layout: { byte_length: byteLength, views } };
}

// Native startup validates this bounded lossless envelope, then copies its data
// directly into context-owned storage. CRC32 retains corruption detection without
// decoding a compressed stream for every browser process.
export function encodeNativeSnapshot(binary) {
    if (!binary.byteLength || binary.byteLength > 128 * 1024 * 1024) {
        throw new RangeError('Native snapshot payload must contain 1..128MiB');
    }
    const table = new Uint32Array(256);
    for (let value = 0; value < 256; value++) {
        let crc = value;
        for (let bit = 0; bit < 8; bit++) crc = (crc >>> 1) ^ ((crc & 1) ? 0xEDB88320 : 0);
        table[value] = crc;
    }
    let crc = 0xFFFFFFFF;
    for (const byte of binary) crc = table[(crc ^ byte) & 255] ^ (crc >>> 8);
    const header = Buffer.alloc(16);
    header.write('VOXSNAP1', 0, 'ascii');
    header.writeUInt32LE(binary.byteLength, 8);
    header.writeUInt32LE((crc ^ 0xFFFFFFFF) >>> 0, 12);
    return Buffer.concat([header, binary]);
}
