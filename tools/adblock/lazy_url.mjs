// The isolated helper has no page observers. Preserve the complete core-js URL
// implementation, but avoid installing it until filtering actually uses URLs.
export function installLazyURL(load) {
    let loaded = false;
    const pending = new Map();
    function ensure() {
        if (loaded) return;
        loaded = true;
        for (const [name, getter] of pending) {
            if (Object.getOwnPropertyDescriptor(globalThis, name)?.get === getter)
                delete globalThis[name];
        }
        load();
    }
    for (const name of ['URL', 'URLSearchParams']) {
        // Existing host implementations still undergo core-js's normal
        // conformance checks when the other service first needs its polyfill.
        if (typeof globalThis[name] !== 'undefined') continue;
        const getter = () => { ensure(); return globalThis[name]; };
        pending.set(name, getter);
        Object.defineProperty(globalThis, name, {
            configurable: true, enumerable: false, get: getter,
            set(value) { ensure(); globalThis[name] = value; },
        });
    }
}

export function urlStub() {
    return `import defaultData from './generated-defaults.js';
(${installLazyURL})(() => { (0,eval)(defaultData.urlSource()); globalThis.voxAdblockURLLoaded=true; });`;
}
