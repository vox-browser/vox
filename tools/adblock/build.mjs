// Rebuild the isolated full-uBO engine bundle. Run npm ci, then npm run build.
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { build } from 'esbuild';
import vm from 'node:vm';
import { gzipSync } from 'node:zlib';
import crypto from 'node:crypto';
import * as serializer from '../../adblock/vendor/ublock/js/s14e-serializer.js';
import { encodeSnapshot } from './snapshot.mjs';
const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, '../..');
const manifest = JSON.parse(await fs.readFile(path.join(root, 'adblock/lists/manifest.json'), 'utf8'));
const lists = await Promise.all(manifest.lists.map(async list => {
    const raw = await fs.readFile(path.join(root, 'adblock', list.file), 'utf8');
    if (crypto.createHash('sha256').update(raw).digest('hex') !== list.sha256) throw new Error(`Filter snapshot hash mismatch: ${list.name}`);
    return { name: list.name, raw };
}));
await fs.writeFile(path.join(here, 'generated-defaults.js'), `export default ${JSON.stringify({lists})};\n`);
const options = {
    entryPoints: [path.join(here, 'runtime.js')], outfile: path.join(root, 'adblock/engine.js'),
    bundle: true, platform: 'browser', format: 'iife', target: 'safari16.4',
    define: { global: 'globalThis' }, minify: true, legalComments: 'eof', loader: { '.dat': 'text' }, metafile: true,
    plugins: [{ name: 'standalone-ublock-background', setup(b) {
        // Preserve the pinned vendor sources while using the host's exact
        // integer checksum backend for cold trie validation. Node/build hosts
        // without this callback retain uBO's original JavaScript checksum.
        b.onLoad({filter: /\/(biditrie|hntrie)\.js$/}, async args => {
            const source = await fs.readFile(args.path, 'utf8');
            const anchor = 'const i32Checksum = (buf32) => {\n';
            if (source.split(anchor).length !== 2) throw new Error(`Unexpected uBO checksum source: ${args.path}`);
            return { contents: source.replace(anchor, anchor + '    if (typeof globalThis.voxAdblockTrieChecksum === \'function\') return globalThis.voxAdblockTrieChecksum(buf32);\n'), loader: 'js', resolveDir: path.dirname(args.path) };
        });
        // Replacing trie storage invalidates the tokenizer's retained URL and
        // offsets, even when a subsequent request has exactly the same URL.
        b.onLoad({filter: /\/static-net-filtering\.js$/}, async args => {
            let source = await fs.readFile(args.path, 'utf8');
            for (const anchor of ['    resetKnownTokens() {\n', '    fromSelfie(selfie) {\n        this.knownTokens = selfie;\n']) {
                if (source.split(anchor).length !== 2) throw new Error(`Unexpected uBO tokenizer source: ${args.path}`);
                source = source.replace(anchor, anchor + "        this._urlIn = ''; this._urlOut = ''; this._tokenized = false;\n");
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
const snapshot = encodeSnapshot(serializer.deserialize(selfie));
await fs.writeFile(path.join(here, 'generated-defaults.js'), snapshot.source);
await fs.writeFile(path.join(root, 'adblock/engine.snapshot.bin.gz'), gzipSync(snapshot.binary, {level: 9, mtime: 0}));
await fs.writeFile(path.join(root, 'adblock/engine.snapshot.json.gz'), gzipSync(snapshot.metadata, {level: 9, mtime: 0}));
await fs.writeFile(path.join(here, 'snapshot-layout.json'), JSON.stringify(snapshot.layout, null, 2) + '\n');
const output = await build(options);
await fs.writeFile(path.join(here, 'bundle-inputs.json'), JSON.stringify(Object.keys(output.metafile.inputs).sort(), null, 2) + '\n');
const code = await fs.readFile(path.join(root, 'adblock/engine.js'));
await fs.writeFile(path.join(root, 'adblock/engine.js.gz'), gzipSync(code, {level: 9, mtime: 0}));
console.log(`Built adblock/engine.js using full uBlock Origin ${manifest.engine.version} and ${lists.length} lists.`);
