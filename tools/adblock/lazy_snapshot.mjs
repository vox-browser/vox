// These factories are embedded in the generated snapshot module. Only the
// immutable lookup tables in uBO's restored cosmetics database use them.
// Mutating or enumerating an array materializes the original dense array;
// maps likewise retain their normal mutation and insertion-order behavior.
export function packedArray(bytes, read, eager = false) {
    const count = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength).getUint32(4, true);
    const target = new Array(count);
    let pending = true;
    const indexOf = key => typeof key === 'string' && /^(0|[1-9][0-9]*)$/.test(key)
        && Number(key) < count ? Number(key) : -1;
    const at = index => {
        if (!Object.hasOwn(target, index)) target[index] = read(bytes, index);
        return target[index];
    };
    const materialize = () => {
        if (!pending) return;
        for (let index = 0; index < count; ++index) at(index);
        pending = false;
        bytes = null;
    };
    const proxy = new Proxy(target, {
        get(object, key, receiver) {
            if (pending) {
                if (key === 'length') return count;
                const index = indexOf(key);
                if (index !== -1) return at(index);
                materialize();
            }
            return Reflect.get(object, key, receiver);
        },
        has(object, key) {
            return pending && indexOf(key) !== -1 || Reflect.has(object, key);
        },
        set(object, key, value, receiver) { materialize(); return Reflect.set(object, key, value, receiver); },
        deleteProperty(object, key) { materialize(); return Reflect.deleteProperty(object, key); },
        defineProperty(object, key, value) { materialize(); return Reflect.defineProperty(object, key, value); },
        getOwnPropertyDescriptor(object, key) { materialize(); return Reflect.getOwnPropertyDescriptor(object, key); },
        ownKeys(object) { materialize(); return Reflect.ownKeys(object); },
        preventExtensions(object) { materialize(); return Reflect.preventExtensions(object); },
        setPrototypeOf(object, prototype) { materialize(); return Reflect.setPrototypeOf(object, prototype); },
    });
    if (eager) materialize();
    return proxy;
}

export function packedMap(bytes, read, eager = false) {
    const count = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength).getUint32(4, true);
    let pending = true;
    const cache = new Map(), missing = new Set();
    const materialize = target => {
        if (!pending) return;
        for (let index = 0; index < count; ++index) {
            const [key, value] = read(bytes, index, true);
            Map.prototype.set.call(target, key, value);
        }
        pending = false;
        bytes = null;
        cache.clear(); missing.clear();
    };
    const lookup = key => {
        if (cache.has(key)) return cache.get(key);
        if (missing.has(key)) return undefined;
        const value = read(bytes, key);
        if (value === undefined) { if (missing.size < 256) missing.add(key); }
        else cache.set(key, value);
        return value;
    };
    class LookupMap extends Map {
        get size() { return pending ? count : super.size; }
        get(key) { return pending ? lookup(key) : super.get(key); }
        has(key) { return pending ? lookup(key) !== undefined : super.has(key); }
        set(key, value) { materialize(this); return super.set(key, value); }
        delete(key) { materialize(this); return super.delete(key); }
        clear() { pending = false; bytes = null; cache.clear(); missing.clear(); return super.clear(); }
        entries() { materialize(this); return super.entries(); }
        keys() { materialize(this); return super.keys(); }
        values() { materialize(this); return super.values(); }
        forEach(fn, receiver) { materialize(this); return super.forEach(fn, receiver); }
        [Symbol.iterator]() { return this.entries(); }
    }
    const result = new LookupMap();
    if (eager) materialize(result);
    return result;
}

// Node and other hosts keep an exact portable reader. Native hosts install the
// same bounded format reader through the isolated filter context's C API.
export function readPackedValue(bytes, key, entryAt = false) {
    const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
    const count = view.getUint32(4, true), kind = view.getUint32(0, true);
    const json = index => {
        const start = view.getUint32(8 + index * 4, true);
        const end = view.getUint32(12 + index * 4, true);
        return JSON.parse(new TextDecoder().decode(bytes.subarray(start, end)));
    };
    if (kind === 1) return Number.isInteger(key) && key >= 0 && key < count ? json(key) : undefined;
    if (entryAt) return Number.isInteger(key) && key >= 0 && key < count ? json(key) : undefined;
    // Map entries retain insertion order; a separate index provides sorted lookup.
    if ((kind === 2 && typeof key !== 'string') || (kind === 3 && typeof key !== 'number')) return undefined;
    if (kind === 3 && (!Number.isSafeInteger(key) || key < 0)) return undefined;
    let low = 0, high = count;
    const sorted = 12 + count * 4;
    while (low < high) {
        const mid = (low + high) >>> 1;
        const index = view.getUint32(sorted + mid * 4, true);
        const keyTable = 12 + count * 8;
        const start = view.getUint32(keyTable + index * 4, true);
        const end = view.getUint32(keyTable + index * 4 + 4, true);
        let found = '';
        for (let offset = start; offset < end; offset += 2)
            found += String.fromCharCode(view.getUint16(offset, true));
        if (kind === 3) found = Number(found);
        if (found < key) low = mid + 1;
        else if (found > key) high = mid;
        else return json(index)[1];
    }
    return undefined;
}

export function encodePackedTable(values, kind) {
    const entries = kind === 1 ? values : [...values];
    const payloads = entries.map(value => Buffer.from(JSON.stringify(value), 'utf8'));
    const keys = kind === 1 ? [] : entries.map(([key]) => Buffer.from(String(key), 'utf16le'));
    const count = entries.length, header = Buffer.alloc(kind === 1 ? 12 + count * 4 : 16 + count * 12);
    header.writeUInt32LE(kind, 0); header.writeUInt32LE(count, 4);
    let offset = header.length;
    keys.forEach((key, index) => {
        header.writeUInt32LE(offset, 12 + count * 8 + index * 4);
        offset += key.length;
    });
    if (kind !== 1) header.writeUInt32LE(offset, 12 + count * 12);
    for (let index = 0; index < count; ++index) {
        header.writeUInt32LE(offset, 8 + index * 4);
        offset += payloads[index].length;
    }
    header.writeUInt32LE(offset, 8 + count * 4);
    if (kind !== 1) {
        const indices = entries.map((_, index) => index).sort((a, b) =>
            entries[a][0] < entries[b][0] ? -1 : entries[a][0] > entries[b][0] ? 1 : 0);
        indices.forEach((value, index) => header.writeUInt32LE(value, 12 + count * 4 + index * 4));
    }
    return Buffer.concat([header, ...keys, ...payloads]);
}
