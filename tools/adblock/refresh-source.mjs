// Restore only the pinned full-uBO files retained in the vendor manifest.
import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const manifest = JSON.parse(await fs.readFile(path.join(root, 'adblock/vendor/manifest.json'), 'utf8'));
for (const file of manifest.files) {
    const url = `https://raw.githubusercontent.com/gorhill/uBlock/${manifest.commit}/${file.upstream_path}`;
    const response = await fetch(url);
    if (!response.ok) throw new Error(`${url}: HTTP ${response.status}`);
    const bytes = Buffer.from(await response.arrayBuffer());
    const digest = crypto.createHash('sha256').update(bytes).digest('hex');
    if (digest !== file.sha256) throw new Error(`Upstream hash mismatch for ${file.file}`);
    const destination = path.join(root, 'adblock/vendor/ublock', file.file);
    await fs.mkdir(path.dirname(destination), {recursive: true});
    await fs.writeFile(destination, bytes);
}
console.log(`Restored ${manifest.files.length} pinned uBlock Origin ${manifest.version} source files.`);
