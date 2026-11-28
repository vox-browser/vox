// The compiled default snapshot needs no list parser. Preserve its exports,
// loading the original bundled parser on first compilation or modifier parse.
export function lazyParserFunction(name) {
    const load = () => globalThis.voxAdblockLoadParser()[name];
    let proxy;
    proxy = new Proxy(function () {}, {
        apply(_target, receiver, args) { return Reflect.apply(load(), receiver, args); },
        construct(_target, args, target) {
            return Reflect.construct(load(), args, target === proxy ? load() : target);
        },
        get(_target, key) { return Reflect.get(load(), key, load()); },
    });
    return proxy;
}

export function lazyParserObject(name) {
    const load = () => globalThis.voxAdblockLoadParser()[name];
    return new Proxy({}, {
        get(_target, key) {
            const owner = load(), value = Reflect.get(owner, key, owner);
            return typeof value === 'function' && (owner instanceof Map || owner instanceof Set)
                ? value.bind(owner) : value;
        },
        has(_target, key) { return key in load(); },
        getPrototypeOf() { return Object.getPrototypeOf(load()); },
    });
}

// The value parsers the matching engine calls for removeparam and redirect
// filters. They use only built-ins, so their own source is emitted: the first
// such directive of a page otherwise evaluated the whole parser bundle (about
// 100M instructions in the worker on github.com). parseHeaderValue and
// parseReplaceByRegexValue call the parser's own helpers and stay lazy.
export const eagerParserFunctions = new Set(['parseQueryPruneValue', 'parseRedirectValue']);

export function parserStub(exports) {
    const lines = [`const lazyFunction=${lazyParserFunction},lazyObject=${lazyParserObject};`];
    for (const [name, value] of Object.entries(exports)) {
        if (typeof value === 'number') lines.push(`export const ${name}=${JSON.stringify(value)};`);
        else if (typeof value === 'function' && eagerParserFunctions.has(name)) lines.push(`export const ${name}=${value.toString()};`);
        else if (typeof value === 'function') lines.push(`export const ${name}=/* @__PURE__ */lazyFunction(${JSON.stringify(name)});`);
        else if (value && typeof value === 'object') lines.push(`export const ${name}=/* @__PURE__ */lazyObject(${JSON.stringify(name)});`);
        else throw new Error('Unsupported parser export: ' + name);
    }
    return lines.join('\n');
}
