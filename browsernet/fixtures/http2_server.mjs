// Local protocol/security fixture; Node and OpenSSL are development tools only.
import fs from 'node:fs';
import path from 'node:path';
import http2 from 'node:http2';
import https from 'node:https';
import http from 'node:http';
import net from 'node:net';
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
const state = { handshakes: { h2: 0, h1: 0, wrong_host: 0 }, requests: [], active: 0, maximum_active: 0, proxy_hosts: [] };
function save() {
    fs.writeFileSync('stats.json.tmp', JSON.stringify(state));
    fs.renameSync('stats.json.tmp', 'stats.json');
}
const binary = Buffer.from([0, 1, 127, 128, 255, 0, 42]);
function request(req, res) {
    state.requests.push({ url: req.url, method: req.method, protocol: req.httpVersion, headers: req.headers });
    state.active++;
    state.maximum_active = Math.max(state.maximum_active, state.active);
    save();
    res.on('finish', () => { state.active--; save(); });
    // Keep the connection healthy while one response stalls. The browser must
    // recover this request without abandoning other multiplexed streams.
    if (req.url.startsWith('/timeout/') && req.httpVersionMajor === 2) {
        if (req.url === '/timeout/partial') {
            res.writeHead(200, { 'content-length': 256 });
            res.write(Buffer.alloc(128, 120));
        }
        return;
    }
    if (req.url === '/never-responds') return;
    if (req.url === '/timeout/partial') { res.writeHead(200, { 'content-length': 64 }); res.end(Buffer.alloc(64, 120)); return; }
    if (req.url === '/timeout/redirect') { res.writeHead(302, { location: '../binary?recovered=1' }); res.end(); return; }
    if (req.url === '/timeout/blocked-redirect') { res.writeHead(302, { location: 'https://www.google-analytics.com/g/collect?v=2' }); res.end(); return; }
    if (req.url === '/unavailable') { res.writeHead(503); res.end('unavailable'); return; }
    if (req.url === '/dir/redirect') { res.writeHead(302, { location: '../binary?allowed=1' }); res.end(); return; }
    if (req.url === '/proxy-to-direct') { res.writeHead(302, { location: `http://127.0.0.1:${http_port}/binary` }); res.end(); return; }
    if (req.url === '/direct-to-proxy') { res.writeHead(302, { location: `http://remote-dns.invalid:${http_port}/binary` }); res.end(); return; }
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
const plain = http.createServer(request);
const proxy = net.createServer(client => {
    let buffer = Buffer.alloc(0), stage = 'greeting';
    client.on('error', () => {});
    function receive(chunk) {
        buffer = Buffer.concat([buffer, chunk]);
        if (stage === 'greeting') {
            if (buffer.length < 2 || buffer.length < 2 + buffer[1]) return;
            buffer = buffer.subarray(2 + buffer[1]);
            client.write(Buffer.from([5, 0]));
            stage = 'connect';
        }
        if (stage !== 'connect' || buffer.length < 5) return;
        const type = buffer[3];
        const length = type === 1 ? 4 : type === 3 ? buffer[4] + 1 : 0;
        if (!length) { client.destroy(); return; }
        if (buffer.length < 4 + length + 2) return;
        const host = type === 1 ? [...buffer.subarray(4, 8)].join('.') : buffer.subarray(5, 4 + length).toString();
        state.proxy_hosts.push(host);
        save();
        const port = buffer.readUInt16BE(4 + length);
        const pending = buffer.subarray(6 + length);
        stage = 'connected';
        // Resolve the synthetic name here, proving the browser did not use DNS.
        const upstream = net.connect(port, host === 'remote-dns.invalid' ? '127.0.0.1' : host, () => {
            client.write(Buffer.from([5, 0, 0, 1, 127, 0, 0, 1, 0, 0]));
            client.off('data', receive);
            if (pending.length) upstream.write(pending);
            client.pipe(upstream).pipe(client);
        });
        upstream.on('error', () => client.destroy());
        client.on('close', () => upstream.destroy());
    }
    client.on('data', receive);
});
const listen = server => new Promise(resolve => server.listen(0, '127.0.0.1', () => resolve(server.address().port)));
const [h2_port, h1_port, wrong_host_port, http_port, proxy_port] = await Promise.all([
    configure(h2, 'h2'), configure(h1, 'h1'), configure(wrong, 'wrong_host'), listen(plain), listen(proxy)]);
save();
fs.writeFileSync('ready.json', JSON.stringify({ h2_port, h1_port, wrong_host_port, http_port, proxy_port, node_version: process.version, ca: path.join(directory, 'ca.pem') }));
