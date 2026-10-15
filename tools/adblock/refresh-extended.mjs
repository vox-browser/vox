// Restore the exact full-uBO procedural implementation and redirect resources.
import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const directory = path.join(root, 'adblock/extended');
const manifest = JSON.parse(await fs.readFile(path.join(directory, 'manifest.json'), 'utf8'));
async function read(file) {
    const url = `https://raw.githubusercontent.com/gorhill/uBlock/${manifest.commit}/${file.upstream_path}`;
    const response = await fetch(url);
    if (!response.ok) throw new Error(`${url}: HTTP ${response.status}`);
    const bytes = Buffer.from(await response.arrayBuffer());
    if (crypto.createHash('sha256').update(bytes).digest('hex') !== file.sha256) {
        throw new Error(`Upstream hash mismatch for ${file.upstream_path}`);
    }
    return bytes;
}
const resources = {};
for (const resource of manifest.resources) {
    const bytes = await read(resource);
    resources[resource.name] = {
        mime: resource.mime,
        data: `data:${resource.mime};base64,${bytes.toString('base64')}`,
        ...(resource.text ? { text: bytes.toString('utf8') } : {}),
    };
}
await fs.writeFile(path.join(directory, 'procedural.js'), await read(manifest.procedural));
await fs.writeFile(path.join(directory, 'redirect-resources.json'), JSON.stringify(resources) + '\n');
console.log(`Restored ${manifest.resources.length} pinned uBO redirects and the procedural selector runtime.`);
