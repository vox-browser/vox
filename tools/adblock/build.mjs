// Rebuild the isolated full-uBO engine bundle. Run npm ci, then npm run build.
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { build } from 'esbuild';
import vm from 'node:vm';
import { gzipSync } from 'node:zlib';
import crypto from 'node:crypto';
import { parseArgs } from 'node:util';
import * as serializer from '../../adblock/vendor/ublock/js/s14e-serializer.js';
import { encodeSnapshot, encodeNativeSnapshot } from './snapshot.mjs';
import { parserStub } from './lazy_parser.mjs';
import { resourcesStub } from './lazy_resources.mjs';
import { urlStub } from './lazy_url.mjs';
import { base64Stub } from './lazy_base64.mjs';
import * as parserExports from '../../adblock/vendor/ublock/js/static-filtering-parser.js';
const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, '../..');
const { values } = parseArgs({ options: {
    output: { type: 'string' },
    'site-policy': { type: 'string' },
} });
const outputDir = values.output ? path.resolve(values.output) : path.join(root, 'adblock');
const auxiliaryDir = values.output ? outputDir : here;
const extraPolicy = values['site-policy']
    ? JSON.parse(await fs.readFile(values['site-policy'], 'utf8')) : null;
if (extraPolicy && (typeof extraPolicy.filters !== 'string' ||
    !extraPolicy.resources || Array.isArray(extraPolicy.resources) ||
    Object.values(extraPolicy.resources).some(source => typeof source !== 'string'))) {
    throw new Error('Site policy requires filters and a resource-name/source object');
}
if (extraPolicy && !values.output) throw new Error('--site-policy requires an isolated --output directory');
await fs.mkdir(outputDir, { recursive: true });
const manifest = JSON.parse(await fs.readFile(path.join(root, 'adblock/lists/manifest.json'), 'utf8'));
const lists = await Promise.all(manifest.lists.map(async list => {
    const raw = await fs.readFile(path.join(root, 'adblock', list.file), 'utf8');
    if (crypto.createHash('sha256').update(raw).digest('hex') !== list.sha256) throw new Error(`Filter snapshot hash mismatch: ${list.name}`);
    return { name: list.name, raw };
}));
const publicSuffixText = await fs.readFile(path.join(root, 'adblock/lists/public_suffix_list.dat'), 'utf8');
let defaultsSource = `export default {lists:${JSON.stringify(lists)},publicSuffixText(){return ${JSON.stringify(publicSuffixText)}}};\n`;
let lazyParser = false;
const options = {
    entryPoints: [path.join(here, 'runtime.js')], outfile: path.join(outputDir, 'engine.js'),
    bundle: true, platform: 'browser', format: 'iife', target: 'safari16.4',
    define: { global: 'globalThis' }, minify: true, legalComments: 'eof', loader: { '.dat': 'text' }, metafile: true,
    plugins: [{ name: 'standalone-ublock-background', setup(b) {
        b.onResolve({filter: /^\.\/generated-defaults\.js$/}, () => ({path:'defaults', namespace:'vox-build'}));
        b.onLoad({filter: /.*/, namespace:'vox-build'}, () => ({contents:defaultsSource, loader:'js', resolveDir:here}));
        b.onLoad({filter: /\/site_optimizations\/resources\.js$/}, async args => {
            if (!extraPolicy) return;
            const source = await fs.readFile(args.path, 'utf8');
            return {contents:source.replace('export const siteFilters =', 'const baseSiteFilters =') +
                `\nexport const siteFilters = baseSiteFilters + ${JSON.stringify('\n' + extraPolicy.filters)};\n` +
                Object.entries(extraPolicy.resources).map(([name, code]) =>
                    `siteResources.set(${JSON.stringify(name)}, ${JSON.stringify(code)});`).join('\n'),
                loader:'js', resolveDir:path.dirname(args.path)};
        });
        b.onLoad({filter: /\/tools\/adblock\/base64\.js$/}, () => lazyParser ? {
            contents: base64Stub(), loader:'js', resolveDir:here,
        } : undefined);
        b.onLoad({filter: /\/tools\/adblock\/url\.js$/}, () => lazyParser ? {
            contents: urlStub(), loader:'js', resolveDir:here,
        } : undefined);
        b.onLoad({filter: /\/lib\/regexanalyzer\/regex\.js$/}, () => lazyParser ? {
            contents: '', loader:'js',
        } : undefined);
        b.onLoad({filter: /\/js\/regex-analyzer\.js$/}, async args => {
            if (!lazyParser) return;
            const source = await fs.readFile(args.path, 'utf8');
            const anchor = 'const RegexAnalyzer = globalThis.Regex && globalThis.Regex.Analyzer || null;';
            if (source.split(anchor).length !== 2) throw new Error('Unexpected regex analyzer binding');
            return {contents: source.replace(anchor,
                'const RegexAnalyzer = (...args) => globalThis.voxAdblockLoadRegexAnalyzer()(...args);'),
                loader:'js', resolveDir:path.dirname(args.path)};
        });
        // The indexed catalog supplies ordinary redirect/scriptlet queries.
        // Keep the vendor's asynchronous full-catalog API, but parse its
        // original module only if a caller actually requests that API.
        b.onLoad({filter: /\/redirect-engine\.js$/}, async args => {
            if (!lazyParser) return;
            const source = await fs.readFile(args.path, 'utf8');
            const anchor = "import('/js/resources/scriptlets.js')";
            if (source.split(anchor).length !== 2) throw new Error('Unexpected uBO builtin resource import');
            return {contents:source.replace(anchor,
                'Promise.resolve().then(() => globalThis.voxAdblockLoadBuiltinScriptlets())'),
                loader:'js', resolveDir:path.dirname(args.path)};
        });
        b.onLoad({filter: /\/tools\/adblock\/resources\.js$/}, () => lazyParser ? {
            contents: resourcesStub(), loader:'js', resolveDir:here,
        } : undefined);
        b.onLoad({filter: /\/static-filtering-parser\.js$/}, args => lazyParser ? {
            contents: parserStub(parserExports), loader:'js', resolveDir:path.dirname(args.path),
        } : undefined);
        // Preserve the pinned vendor sources while using the host's exact
        // integer checksum backend for cold trie validation. Node/build hosts
        // without this callback retain uBO's original JavaScript checksum.
        b.onLoad({filter: /\/(biditrie|hntrie)\.js$/}, async args => {
            const source = await fs.readFile(args.path, 'utf8');
            const anchor = 'const i32Checksum = (buf32) => {\n';
            if (source.split(anchor).length !== 2) throw new Error(`Unexpected uBO checksum source: ${args.path}`);
            let contents = source.replace(anchor, anchor + '    if (typeof globalThis.voxAdblockTrieChecksum === \'function\') return globalThis.voxAdblockTrieChecksum(buf32);\n');
            if (args.path.endsWith('/biditrie.js')) {
                const copy = '        this.reallocateBuf(byteLength);\n        this.buf32.set(selfie.buf32);\n';
                if (contents.split(copy).length !== 2) throw new Error('Unexpected uBO trie restoration');
                contents = contents.replace(copy, `        if (this.wasmMemory === null && typeof globalThis.voxAdblockCloneSnapshotView === 'function') {
            this.buf32 = globalThis.voxAdblockCloneSnapshotView(selfie.buf32);
            this.buf8 = new Uint8Array(this.buf32.buffer);
            this.haystack = this.buf8.subarray(HAYSTACK_START, HAYSTACK_START + HAYSTACK_SIZE);
        } else {
${copy}        }
`);
            }
            return { contents, loader: 'js', resolveDir: path.dirname(args.path) };
        });
        // Replacing trie storage invalidates the tokenizer's retained URL and
        // offsets, even when a subsequent request has exactly the same URL.
        b.onLoad({filter: /\/static-net-filtering\.js$/}, async args => {
            let source = await fs.readFile(args.path, 'utf8');
            for (const anchor of ['    resetKnownTokens() {\n', '    fromSelfie(selfie) {\n        this.knownTokens = selfie;\n']) {
                if (source.split(anchor).length !== 2) throw new Error(`Unexpected uBO tokenizer source: ${args.path}`);
                source = source.replace(anchor, anchor + "        this._urlIn = ''; this._urlOut = ''; this._tokenized = false;\n");
            }
            if (lazyParser) {
                const declaration = 'const filterRefs = [ null ];';
                const copy = '    for ( let i = 0, n = selfie.length; i < n; i++ ) {\n        filterRefs[i] = selfie[i];\n    }';
                if (source.split(declaration).length !== 2 || source.split(copy).length !== 2)
                    throw new Error('Unexpected uBO filter reference restoration');
                source = source.replace(declaration, 'let filterRefs = [ null ];')
                    .replace(copy, `    const owned = globalThis.voxAdblockTakeFilterReferences?.(selfie);
    if (owned !== undefined) {
        filterRefs = owned;
    } else {
${copy}
    }`);
            }
            return { contents: source, loader: 'js', resolveDir: path.dirname(args.path) };
        });
        b.onResolve({filter: /\/(background|logger)\.js$/}, args => {
            if (!args.importer.includes('/adblock/vendor/ublock/js/')) return;
            return { path: path.join(here, args.path.endsWith('/background.js') ? 'background-stub.js' : 'logger-stub.js') };
        });
        b.onResolve({filter: /^\/js\/resources\/scriptlets\.js$/}, () => ({ path: path.join(root, 'adblock/vendor/ublock/js/resources/scriptlets.js') }));
    } }],
};
const bootstrap = await build({ ...options, write: false });
const context = vm.createContext({ console, TextEncoder, TextDecoder });
vm.runInContext(bootstrap.outputFiles[0].text, context);
let selfie;
try {
    context.voxAdblockInitialize();
    selfie = context.voxAdblockSnapshot();
} catch (error) {
    console.error('Cannot compile default filter snapshot: ' + error.message);
    process.exit(1);
}
const parserBundle = await build({entryPoints:[path.join(root,'adblock/vendor/ublock/js/static-filtering-parser.js')],
    bundle:true,platform:'browser',format:'iife',globalName:'voxAdblockParser',target:'safari16.4',
    minify:true,legalComments:'eof',write:false});
const parserSource = parserBundle.outputFiles[0].text;
const scriptletBundle = await build({entryPoints:[path.join(root,'adblock/vendor/ublock/js/resources/scriptlets.js')],
    bundle:true,platform:'browser',format:'iife',globalName:'voxAdblockBuiltinScriptlets',target:'safari16.4',
    minify:true,legalComments:'eof',write:false});
const builtinScriptletsSource = scriptletBundle.outputFiles[0].text;
const resourceCatalog = context.voxAdblockResourceSnapshot();
const urlBundle = await build({entryPoints:[path.join(here,'url.js')],
    bundle:true,platform:'browser',format:'iife',target:'safari16.4',
    minify:true,legalComments:'eof',write:false});
const urlSource = urlBundle.outputFiles[0].text;
const regexSource = await fs.readFile(path.join(root,'adblock/vendor/ublock/lib/regexanalyzer/regex.js'),'utf8');
const base64Bundle = await build({entryPoints:[path.join(here,'base64.js')],
    bundle:true,platform:'browser',format:'iife',target:'safari16.4',
    minify:true,legalComments:'eof',write:false});
const base64Source = base64Bundle.outputFiles[0].text;
const snapshot = encodeSnapshot(serializer.deserialize(selfie), { lazyCosmetics: true, lazyNetworkBuckets: true, lazyNetworkReferences: true, publicSuffixText, parserSource, builtinScriptletsSource, resourceCatalog, urlSource, regexSource, base64Source });
defaultsSource = snapshot.source;
await fs.writeFile(path.join(auxiliaryDir, 'generated-defaults.js'), defaultsSource);
await fs.writeFile(path.join(outputDir, 'engine.snapshot.bin'), encodeNativeSnapshot(snapshot.binary));
await fs.writeFile(path.join(outputDir, 'engine.snapshot.json.gz'), gzipSync(snapshot.metadata, {level: 9, mtime: 0}));
await fs.writeFile(path.join(auxiliaryDir, 'snapshot-layout.json'), JSON.stringify(snapshot.layout, null, 2) + '\n');
lazyParser = true;
const output = await build(options);
await fs.writeFile(path.join(auxiliaryDir, 'bundle-inputs.json'), JSON.stringify(Object.keys(output.metafile.inputs).sort(), null, 2) + '\n');
const code = await fs.readFile(path.join(outputDir, 'engine.js'));
await fs.writeFile(path.join(outputDir, 'engine.js.gz'), gzipSync(code, {level: 9, mtime: 0}));
console.log(`Built ${outputDir}/engine.js using full uBlock Origin ${manifest.engine.version} and ${lists.length} lists.`);
