// Refresh Vox's full-uBO defaults, including the Russian RU AdList.
// The engine source stays pinned; list SHA-256 hashes are recorded for replay.
import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const commit = '21f0e686506bb21b514b451c8c6cb9bf8c82d232';
const metadata = JSON.parse(await fs.readFile(path.join(root, 'adblock/vendor/ublock/assets.json'), 'utf8'));
const defaultKeys = ['ublock-filters', 'ublock-badware', 'ublock-privacy', 'ublock-unbreak', 'ublock-quick-fixes', 'easylist', 'easyprivacy', 'urlhaus-1', 'plowe-0', 'RUS-0'];
const args = process.argv.slice(2);
if (args.length && (args.length !== 2 || args[0] !== '--only')) throw new Error('Usage: node refresh.mjs [--only RUS-0,...]');
const keys = args.length ? args[1].split(',') : defaultKeys;
if (!keys.length || new Set(keys).size !== keys.length || keys.some(key => !defaultKeys.includes(key))) throw new Error('Unknown or repeated default list');
const previous = args.length ? JSON.parse(await fs.readFile(path.join(root, 'adblock/lists/manifest.json'), 'utf8')) : null;
const downloadedAt = new Date().toISOString();
const download = async (url) => {
    const response = await fetch(url);
    if (!response.ok) throw new Error(`${url}: HTTP ${response.status}`);
    return await response.text();
};
const entries = await Promise.all(keys.map(async name => {
    const asset = metadata[name];
    const sources = Array.isArray(asset.contentURL) ? asset.contentURL : [asset.contentURL];
    const urls = [...sources.filter(s => s.startsWith('https:')), ...(asset.cdnURLs || [])];
    let raw, source_url, lastError;
    for (const url of urls) {
        try { raw = await download(url); source_url = url; break; } catch (error) { lastError = error; }
    }
    if (raw === undefined) throw lastError;
    // uBO resolves same-origin !#include files before conditional preprocessing.
    const includes = [];
    async function expand(text, base, ancestors = []) {
        const parts = [];
        for (const line of text.split(/\r?\n/)) {
            const match = /^!#include\s+(\S+)\s*$/.exec(line);
            if (!match) { parts.push(line); continue; }
            const url = new URL(match[1], base);
            if (url.origin !== new URL(base).origin || ancestors.includes(url.href)) throw new Error(`Unsafe/cyclic include: ${url.href}`);
            const included = await download(url.href);
            includes.push({ url: url.href, sha256: crypto.createHash('sha256').update(included).digest('hex') });
            parts.push(`! Included from ${url.href}`, await expand(included, url.href, [...ancestors, url.href]));
        }
        return parts.join('\n');
    }
    raw = await expand(raw, source_url);
    const file = `lists/${name}.txt`;
    await fs.writeFile(path.join(root, 'adblock', file), raw);
    return { name, title: asset.title, source_url, file, sha256: crypto.createHash('sha256').update(raw).digest('hex'), downloaded_at: downloadedAt, includes };
}));
const psl_url = 'https://publicsuffix.org/list/public_suffix_list.dat';
const psl = previous ? null : await download(psl_url);
if (psl !== null) await fs.writeFile(path.join(root, 'adblock/lists/public_suffix_list.dat'), psl);
const updated = new Map((previous?.lists || []).map(entry => [entry.name, entry]));
for (const entry of entries) updated.set(entry.name, entry);
const manifest = { engine: { name: 'uBlock Origin', version: '1.75.0', commit, source: `https://github.com/gorhill/uBlock/tree/${commit}` }, downloaded_at: previous?.downloaded_at || downloadedAt, ...(previous ? {updated_at: downloadedAt} : {}), preprocessor_environment: ['ublock', 'chromium', 'user_stylesheet'], lists: defaultKeys.filter(key => updated.has(key)).map(key => updated.get(key)), public_suffix_list: previous?.public_suffix_list || { source_url: psl_url, sha256: crypto.createHash('sha256').update(psl).digest('hex') } };
await fs.writeFile(path.join(root, 'adblock/lists/manifest.json'), JSON.stringify(manifest, null, 2) + '\n');
console.log(`Refreshed ${entries.length} full uBlock Origin lists; ${manifest.lists.length} enabled defaults.`);
