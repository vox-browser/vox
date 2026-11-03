#!/usr/bin/env python3
"""Capture original page resources once, or replay their bytes from disk only.

Replay preserves HTTPS origins and author scripts. It never forwards a missing
request. Its certificate is private to the browser process, not system trust.
"""
import argparse
import hashlib
from html.parser import HTMLParser
import json
from pathlib import Path
import re
import socket
import socketserver
import ssl
import subprocess
import threading
import time
from urllib.parse import urldefrag, urljoin, urlsplit


def digest(data):
    return hashlib.sha256(data).hexdigest()


def http_url(base, value):
    url = urldefrag(urljoin(base, value))[0]
    return url if urlsplit(url).scheme in {'http', 'https'} else None


class ResourceLinks(HTMLParser):
    def __init__(self, base):
        super().__init__(convert_charrefs=True)
        self.base, self.links = base, set()
        self.in_style = False

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == 'style':
            self.in_style = True
        if tag == 'base' and attrs.get('href'):
            self.base = urljoin(self.base, attrs['href'])
        values = [attrs.get('src', ''), attrs.get('poster', '')]
        if tag == 'link' and set(attrs.get('rel', '').lower().split()) & {
                'stylesheet', 'icon', 'preload', 'modulepreload'}:
            values.append(attrs.get('href', ''))
        # data: sources are already embedded and may contain commas.
        if not attrs.get('srcset', '').startswith('data:'):
            values += [part.strip().split()[0] for part in attrs.get('srcset', '').split(',')
                       if part.strip()]
        for value in values:
            url = http_url(self.base, value) if value else None
            if url:
                self.links.add(url)
        self.links.update(css_links(self.base, attrs.get('style') or ''))

    def handle_endtag(self, tag):
        if tag == 'style':
            self.in_style = False

    def handle_data(self, data):
        if self.in_style:
            self.links.update(css_links(self.base, data))


def css_links(base, text):
    values = re.findall(r'url\(\s*[\"\']?([^\)\"\']+)', text, re.I)
    values += re.findall(r'@import\s+[\"\']([^\"\']+)', text, re.I)
    return {url for value in values if (url := http_url(base, value.strip()))}


def mime(headers):
    return next((h['value'] for h in headers if h['name'].lower() == 'content-type'), '')


def capture(args):
    output = args.output.resolve()
    progress_source = getattr(args, 'from_progress', None)
    progress_sha = getattr(args, 'expected_progress_sha256', None)
    progress = None
    if progress_source:
        progress_source = progress_source.resolve()
        if args.from_archive or args.from_cache:
            raise ValueError('Capture progress cannot be combined with another import')
        if output == progress_source or progress_source in output.parents:
            raise ValueError('Output must be outside the imported capture')
        progress = load_capture_progress(progress_source, progress_sha)
        if progress['url'] != args.url:
            raise ValueError('Capture progress references a different entry URL')
    elif progress_sha is not None:
        raise ValueError('Expected progress SHA256 requires --from-progress')
    output.mkdir(parents=True, exist_ok=False)
    (output / 'bodies').mkdir()
    entries, pending = {}, {args.url, *args.extra_url}
    if progress is not None:
        pending.update(progress['responses'])
    previous = progress or (load_archive(args.from_archive) if args.from_archive else None)
    # Reuse a previous raw native cache without refetching or serializing a DOM.
    cached = {}
    if args.from_cache:
        for item in (args.from_cache / 'resources').glob('*.url'):
            cached[item.read_text()] = item.with_suffix('')
        cached[args.url] = args.from_cache / 'pages' / digest(args.url.encode())
    manifest = dict(version=1, url=args.url, captured_unix=time.time(),
                    proxy_used_for_capture=args.proxy, author_scripts='original bytes retained',
                    imported_cache=str(args.from_cache) if args.from_cache else None,
                    imported_archive=str(args.from_archive) if args.from_archive else None,
                    imported_capture_progress=str(progress_source) if progress_source else None,
                    imported_capture_progress_sha256=progress_sha,
                    optional_http_error_urls=sorted(set(args.extra_url)),
                    responses=entries)
    while pending:
        url = sorted(pending)[0]
        pending.remove(url)
        if url in entries:
            continue
        path = cached.get(url)
        if previous and url in previous['responses']:
            entry = previous['responses'][url]
            imported = progress_source if progress is not None else args.from_archive
            body = checked_response_body(imported, url, entry)
            headers, status = entry['headers'], entry['status']
            if progress is not None:
                provenance = dict(source='unfinished capture', capture=str(progress_source),
                                  capture_progress_sha256=progress_sha,
                                  original_provenance=entry.get('provenance'))
            else:
                provenance = dict(source='sealed archive', archive=str(args.from_archive.resolve()),
                                  manifest_sha256=digest((args.from_archive / 'manifest.json').read_bytes()))
        elif path and path.is_file():
            body = path.read_bytes()
            hp = Path(str(path) + '.headers.json')
            headers = json.loads(hp.read_text()) if hp.exists() else [dict(
                name='Content-Type', value=Path(str(path) + '.content-type').read_text().strip())]
            sp = Path(str(path) + '.status')
            status = int(sp.read_text()) if sp.exists() else 200
            provenance = dict(source='existing raw cache', path=str(path.resolve()))
        else:
            path, hp = output / 'download.body', output / 'download.headers'
            command = ['curl', '--silent', '--show-error', '--compressed', '--location', '--max-time', '45',
                       '--proto', '=http,https', '--proto-redir', '=http,https',
                       '--dump-header', str(hp), '--output', str(path), '--write-out', '%{http_code}']
            if args.proxy:
                command += ['--proxy', args.proxy]
            result = subprocess.run([*command, url], text=True, capture_output=True)
            result.check_returncode()
            status, body, headers = int(result.stdout), path.read_bytes(), []
            for line in hp.read_text().splitlines():
                if line.startswith('HTTP/'):
                    headers = []
                elif ':' in line:
                    name, value = line.split(':', 1)
                    headers.append(dict(name=name, value=value.strip()))
            provenance = dict(source='curl', captured_unix=time.time(), command=[*command, url])
        if not 200 <= status < 300:
            # Failed optional API requests are frozen too, rather than retried live.
            if url == args.url or url not in args.extra_url:
                raise RuntimeError(f'Could not archive required resource: {status} {url}')
        sha = digest(body)
        (output / 'bodies' / sha).write_bytes(body)
        entries[url] = dict(status=status, headers=headers, sha256=sha,
                            bytes=len(body), provenance=provenance)
        if 'text/html' in mime(headers) and 200 <= status < 300:
            parser = ResourceLinks(url)
            parser.feed(body.decode('utf-8', errors='replace'))
            pending.update(parser.links - entries.keys())
        if 'text/css' in mime(headers):
            pending.update(css_links(url, body.decode('utf-8', errors='replace')) - entries.keys())
        # Save partial progress as evidence; only a sealed manifest is replayable.
        (output / 'capture-progress.json').write_text(json.dumps(manifest, indent=2) + '\n')
    for name in ['download.body', 'download.headers']:
        (output / name).unlink(missing_ok=True)
    if progress is not None:
        load_capture_progress(progress_source, progress_sha)
    manifest['sealed_unix'] = time.time()
    (output / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print(f'Sealed {len(entries)} responses in {output}', flush=True)


def checked_response_body(archive, url, entry):
    sha = entry['sha256']
    if not re.fullmatch('[0-9a-f]{64}', sha):
        raise ValueError('Invalid body identity')
    path = archive / 'bodies' / sha
    if path.is_symlink():
        raise ValueError('Archived body is a symlink: ' + url)
    body = path.read_bytes()
    if digest(body) != sha or len(body) != entry['bytes']:
        raise ValueError('Archived response changed: ' + url)
    if urlsplit(url).scheme not in {'http', 'https'}:
        raise ValueError('Invalid archive URL')
    return body


def load_capture_progress(archive, expected_sha256):
    """Import verified responses without treating a failed capture as sealed."""
    if not isinstance(expected_sha256, str) or not re.fullmatch('[0-9a-f]{64}', expected_sha256):
        raise ValueError('Capture progress requires its expected SHA256')
    raw = (archive / 'capture-progress.json').read_bytes()
    if digest(raw) != expected_sha256:
        raise ValueError('Capture progress SHA256 mismatch')
    manifest = json.loads(raw)
    if (manifest.get('version') != 1 or manifest.get('sealed_unix')
            or not isinstance(manifest.get('responses'), dict) or not manifest['responses']):
        raise ValueError('Import requires nonempty unfinished capture progress')
    for url, entry in manifest['responses'].items():
        checked_response_body(archive, url, entry)
    return manifest


def load_archive(archive):
    manifest = json.loads((archive / 'manifest.json').read_text())
    if manifest.get('version') != 1 or not manifest.get('sealed_unix'):
        raise ValueError('Archive must be sealed')
    for url, entry in manifest['responses'].items():
        checked_response_body(archive, url, entry)
    return manifest


class Replay:
    def __init__(self, archive, output):
        self.archive, self.output = archive.resolve(), output.resolve()
        self.manifest = load_archive(self.archive)
        self.output.mkdir(parents=True, exist_ok=False)
        self.lock = threading.Lock()
        hosts = {urlsplit(url).hostname for url in self.manifest['responses']}
        if not all(host and re.fullmatch(r'[a-zA-Z0-9.-]+', host) for host in hosts):
            raise ValueError('Invalid archive host')
        config = self.output / 'openssl.cnf'
        config.write_text('[req]\ndistinguished_name=dn\nx509_extensions=ext\nprompt=no\n'
                          '[dn]\nCN=Vox disk archive\n[ext]\nbasicConstraints=critical,CA:TRUE\n'
                          'keyUsage=critical,digitalSignature,keyEncipherment,keyCertSign\n'
                          'subjectAltName=' + ','.join('DNS:' + h for h in sorted(hosts)) + '\n')
        cert, key = self.output / 'cert.pem', self.output / 'key.pem'
        with (self.output / 'openssl.log').open('w') as log:
            subprocess.run(['openssl', 'req', '-x509', '-newkey', 'rsa:2048', '-nodes', '-days', '2',
                            '-keyout', str(key), '-out', str(cert), '-config', str(config)],
                           stdout=log, stderr=subprocess.STDOUT, check=True)
        self.tls = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        self.tls.load_cert_chain(cert, key)
        replay = self

        class Handler(socketserver.BaseRequestHandler):
            def handle(self):
                replay.handle(self.request, hosts)

        class Server(socketserver.ThreadingMixIn, socketserver.TCPServer):
            daemon_threads = True
            # A browser can open connections for many archived origins in one
            # burst. The default five-entry queue resets excess connections on
            # macOS before a request reaches the replay log.
            request_queue_size = 128

        self.server = Server(('127.0.0.1', 0), Handler)
        self.ready = dict(url=self.manifest['url'], archive=str(self.archive), forwarding=False,
                          manifest_sha256=digest((self.archive / 'manifest.json').read_bytes()),
                          proxy='socks5h://127.0.0.1:' + str(self.server.server_address[1]),
                          ca=str(cert), certificate_sha256=digest(cert.read_bytes()))
        (self.output / 'ready.json').write_text(json.dumps(self.ready, indent=2) + '\n')

    def record(self, **row):
        with self.lock, (self.output / 'requests.jsonl').open('a') as log:
            log.write(json.dumps(dict(t_unix=time.time(), **row)) + '\n')

    @staticmethod
    def receive(sock, count):
        data = bytearray()
        while len(data) < count:
            part = sock.recv(count - len(data))
            if not part:
                raise ValueError('Incomplete proxy handshake')
            data.extend(part)
        return bytes(data)

    def socks_tunnel(self, sock, hosts):
        # Resolve nothing and forward nothing: only archived HTTPS hosts qualify.
        version, count = self.receive(sock, 2)
        methods = self.receive(sock, count)
        if version != 5 or 0 not in methods:
            sock.sendall(b'\x05\xff')
            raise ValueError('SOCKS5 requires unauthenticated negotiation')
        sock.sendall(b'\x05\x00')
        if self.receive(sock, 4) != b'\x05\x01\x00\x03':
            sock.sendall(b'\x05\x08\x00\x01' + bytes(6))
            raise ValueError('SOCKS5 requires a domain CONNECT')
        host = self.receive(sock, self.receive(sock, 1)[0]).decode('ascii')
        port = int.from_bytes(self.receive(sock, 2), 'big')
        allowed = host in hosts and port == 443
        sock.sendall(b'\x05' + (b'\x00' if allowed else b'\x02') + b'\x00\x01' + bytes(6))
        if not allowed:
            self.record(connect=f'{host}:{port}', status=403, archived=False)
            return None
        return host

    @staticmethod
    def request(sock):
        data = bytearray()
        while not data.endswith(b'\r\n\r\n'):
            part = sock.recv(1)
            if not part:
                return None
            data += part
            if len(data) > 65536:
                raise ValueError('Oversized request')
        return data.decode('iso-8859-1').split('\r\n')[0].split(' ', 2)

    def handle(self, sock, hosts):
        sock.settimeout(15)
        try:
            host = None
            if sock.recv(1, socket.MSG_PEEK) == b'\x05':
                host = self.socks_tunnel(sock, hosts)
                if host is None:
                    return
                sock = self.tls.wrap_socket(sock, server_side=True)
            request = self.request(sock)
            if not request:
                return
            method, target, _ = request
            if method == 'CONNECT':
                host, port = target.rsplit(':', 1)
                if host not in hosts or port != '443':
                    sock.sendall(b'HTTP/1.1 403 Unarchived host\r\nContent-Length: 0\r\n\r\n')
                    self.record(connect=target, status=403, archived=False)
                    return
                sock.sendall(b'HTTP/1.1 200 Connection established\r\n\r\n')
                sock = self.tls.wrap_socket(sock, server_side=True)
                request = self.request(sock)
                if not request:
                    return
                method, target, _ = request
            if host:
                target = 'https://' + host + target
            entry = self.manifest['responses'].get(target) if method in {'GET', 'HEAD'} else None
            body = (self.archive / 'bodies' / entry['sha256']).read_bytes() if entry else b''
            if entry and (digest(body) != entry['sha256'] or len(body) != entry['bytes']):
                raise ValueError('Archived response changed: ' + target)
            status = entry['status'] if entry else 404
            # Bodies are decoded; neither compression nor transfer framing is retained.
            excluded = {'content-encoding', 'transfer-encoding', 'content-length',
                        'connection', 'keep-alive', 'set-cookie'}
            headers = [h for h in entry['headers'] if h['name'].lower() not in excluded] if entry else []
            headers += [dict(name='Content-Length', value=str(len(body))),
                        dict(name='Connection', value='close')]
            if any('\r' in h['name'] + h['value'] or '\n' in h['name'] + h['value'] for h in headers):
                raise ValueError('Invalid archived header')
            self.record(method=method, url=target, status=status, archived=bool(entry),
                        bytes=len(body), sha256=digest(body))
            response = f'HTTP/1.1 {status} Archive\r\n' + ''.join(
                h['name'] + ': ' + h['value'] + '\r\n' for h in headers) + '\r\n'
            sock.sendall(response.encode('iso-8859-1') + (body if method != 'HEAD' else b''))
            if isinstance(sock, ssl.SSLSocket):
                # Deliver close_notify after the complete response. An abrupt
                # TLS EOF can make Chromium discard an otherwise served body.
                try:
                    sock = sock.unwrap()
                except (OSError, ValueError):
                    # Some clients close after Content-Length without sending
                    # their own alert. The response has already been sent.
                    pass
        except (OSError, ValueError) as error:
            self.record(error=str(error))
        finally:
            sock.close()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    cap = commands.add_parser('capture')
    cap.add_argument('url')
    cap.add_argument('--output', type=Path, required=True)
    cap.add_argument('--proxy')
    cap.add_argument('--from-cache', type=Path)
    cap.add_argument('--from-archive', type=Path)
    cap.add_argument('--from-progress', type=Path,
                     help='Import verified responses from an unfinished capture into a new output.')
    cap.add_argument('--expected-progress-sha256',
                     help='Required SHA256 of the imported capture-progress.json.')
    cap.add_argument('--extra-url', action='append', default=[])
    serve = commands.add_parser('replay')
    serve.add_argument('archive', type=Path)
    serve.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if args.command == 'capture':
        capture(args)
    else:
        replay = Replay(args.archive, args.output)
        print(json.dumps(replay.ready), flush=True)
        replay.server.serve_forever()


if __name__ == '__main__':
    main()
