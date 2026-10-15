// Local protocol/security fixture; Node and OpenSSL are development tools only.
import fs from 'node:fs';
import path from 'node:path';
import http2 from 'node:http2';
import https from 'node:https';
import { gzipSync } from 'node:zlib';
import { execFileSync } from 'node:child_process';

const directory = process.argv[2];
process.chdir(directory);
const openssl = process.argv[3] || 'openssl';
const run = args => execFileSync(openssl, args, { stdio: ['ignore', 'ignore', 'pipe'] });
fs.writeFileSync('ca.cnf', '[req]\ndistinguished_name=dn\n[dn]\n[v3_ca]\nbasicConstraints=critical,CA:TRUE\nkeyUsage=critical,keyCertSign,cRLSign\nsubjectKeyIdentifier=hash\n');
for (const name of ['ca', 'untrusted-ca']) {
    run(['ecparam', '-name', 'prime256v1', '-genkey', '-noout', '-out', name + '.key']);
    run(['req', '-new', '-x509', '-key', name + '.key', '-days', '2', '-sha256', '-subj', '/CN=Vox local TLS test ' + name, '-out', name + '.pem', '-config', 'ca.cnf', '-extensions', 'v3_ca']);
}
for (const [name, hostname] of [['server', 'DNS:localhost,IP:127.0.0.1'], ['wrong-host', 'DNS:wrong-host.invalid']]) {
    fs.writeFileSync(name + '.cnf', 'basicConstraints=critical,CA:FALSE\nkeyUsage=critical,digitalSignature\nextendedKeyUsage=serverAuth\nsubjectAltName=' + hostname + '\n');
    run(['ecparam', '-name', 'prime256v1', '-genkey', '-noout', '-out', name + '.key']);
    run(['req', '-new', '-key', name + '.key', '-subj', '/CN=localhost', '-out', name + '.csr']);
    run(['x509', '-req', '-in', name + '.csr', '-CA', 'ca.pem', '-CAkey', 'ca.key', '-CAcreateserial', '-days', '2', '-sha256', '-extfile', name + '.cnf', '-out', name + '.pem']);
}
const state = { handshakes: { h2: 0, h1: 0, wrong_host: 0 }, requests: [], active: 0, maximum_active: 0 };
function save() {
    fs.writeFileSync('stats.json.tmp', JSON.stringify(state));
    fs.renameSync('stats.json.tmp', 'stats.json');
}
const binary = Buffer.from([0, 1, 127, 128, 255, 0, 42]);
function request(req, res) {
    state.requests.push({ url: req.url, protocol: req.httpVersion });
    state.active++;
    state.maximum_active = Math.max(state.maximum_active, state.active);
    save();
    res.on('finish', () => { state.active--; save(); });
    if (req.url === '/dir/redirect') { res.writeHead(302, { location: '../binary?allowed=1' }); res.end(); return; }
    if (req.url === '/blocked-redirect') { res.writeHead(302, { location: 'https://www.google-analytics.com/g/collect?v=2' }); res.end(); return; }
    const gzip = req.url === '/gzip';
    const body = gzip ? gzipSync(binary) : binary;
    const headers = { 'content-type': 'application/octet-stream', 'content-length': body.length, 'x-fixture': 'retained' };
    if (gzip) headers['content-encoding'] = 'gzip';
    const send = () => { res.writeHead(200, headers); res.end(body); };
    if (req.url.startsWith('/pooled/')) setTimeout(send, 20); else send();
}
function configure(server, name) {
    server.on('secureConnection', () => { state.handshakes[name]++; save(); });
    server.on('tlsClientError', () => {});
    server.on('sessionError', () => {});
    return new Promise(resolve => server.listen(0, '127.0.0.1', () => resolve(server.address().port)));
}
const credentials = { key: fs.readFileSync('server.key'), cert: fs.readFileSync('server.pem') };
const h2 = http2.createSecureServer({ ...credentials, allowHTTP1: true }, request);
const h1 = https.createServer(credentials, request);
const wrong = https.createServer({ key: fs.readFileSync('wrong-host.key'), cert: fs.readFileSync('wrong-host.pem') }, request);
const [h2_port, h1_port, wrong_host_port] = await Promise.all([configure(h2, 'h2'), configure(h1, 'h1'), configure(wrong, 'wrong_host')]);
save();
fs.writeFileSync('ready.json', JSON.stringify({ h2_port, h1_port, wrong_host_port, node_version: process.version, ca: path.join(directory, 'ca.pem') }));
