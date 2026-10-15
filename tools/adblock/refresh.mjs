// Refresh the default lists selected by full uBlock Origin 1.75.0.
// The engine source stays pinned; list SHA-256 hashes are recorded for replay.
import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const commit = '21f0e686506bb21b514b451c8c6cb9bf8c82d232';
const metadata = JSON.parse(await fs.readFile(path.join(root, 'adblock/vendor/ublock/assets.json'), 'utf8'));
const keys = ['ublock-filters', 'ublock-badware', 'ublock-privacy', 'ublock-unbreak', 'ublock-quick-fixes', 'easylist', 'easyprivacy', 'urlhaus-1', 'plowe-0'];
const download = async (url) => {
    const response = await fetch(url);
    if (!response.ok) throw new Error(`${url}: HTTP ${response.status}`);
    return await response.text();
};
const entries = await Promise.all(keys.map(async name => {
    const asset = metadata[name];
    const urls = [...asset.contentURL.filter(s => s.startsWith('https:')), ...(asset.cdnURLs || [])];
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
    return { name, title: asset.title, source_url, file, sha256: crypto.createHash('sha256').update(raw).digest('hex'), includes };
}));
const psl_url = 'https://publicsuffix.org/list/public_suffix_list.dat';
const psl = await download(psl_url);
await fs.writeFile(path.join(root, 'adblock/lists/public_suffix_list.dat'), psl);
const manifest = { engine: { name: 'uBlock Origin', version: '1.75.0', commit, source: `https://github.com/gorhill/uBlock/tree/${commit}` }, downloaded_at: new Date().toISOString(), preprocessor_environment: ['ublock', 'chromium', 'user_stylesheet'], lists: entries, public_suffix_list: { source_url: psl_url, sha256: crypto.createHash('sha256').update(psl).digest('hex') } };
await fs.writeFile(path.join(root, 'adblock/lists/manifest.json'), JSON.stringify(manifest, null, 2) + '\n');
console.log(`Refreshed ${entries.length} full uBlock Origin default lists.`);
