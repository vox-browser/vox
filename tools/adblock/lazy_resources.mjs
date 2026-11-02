// Scriptlet source remains indexed data until the page requests that entry.
export function restoreResources({entries,aliases}) {
    class ResourceMap extends Map {
        get size() { return entries.size; }
        get(name) {
            const entry = entries.get(name);
            if (!entry || typeof entry.toContent === 'function') return entry;
            entry.toContent = () => entry.content;
            if (entry.redirect) entry.toURL = fctx => name === 'empty'
                ? `data:${({script:'text/javascript',stylesheet:'text/css',main_frame:'text/html',sub_frame:'text/html'})[fctx.type] || 'text/plain'},`
                : entry.data;
            return entry;
        }
        has(key) { return entries.has(key); }
        set(key,value) { entries.set(key,value); return this; }
        delete(key) { return entries.delete(key); }
        clear() { entries.clear(); }
        *entries() { for (const key of entries.keys()) yield [key,this.get(key)]; }
        keys() { return entries.keys(); }
        *values() { for (const key of entries.keys()) yield this.get(key); }
        forEach(fn,receiver) { for (const [key,value] of this) fn.call(receiver,value,key,this); }
        [Symbol.iterator]() { return this.entries(); }
    }
    return {resources:new ResourceMap(),aliases};
}

export function resourcesStub() {
    return `const restoreResources=${restoreResources};
export function createResources(){return restoreResources(globalThis.voxAdblockLoadResources());}
export function snapshotResources(){return globalThis.voxAdblockLoadResources();}`;
}
