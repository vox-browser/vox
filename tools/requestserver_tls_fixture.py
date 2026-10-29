#!/usr/bin/env python3
"""Private loopback TLS origin for the native RequestServer CA regression."""
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import os
import ssl
import subprocess
import sys
import time


def main():
    root = Path(sys.argv[1])
    for name in ['trusted', 'unrelated']:
        config = root / (name + '.cnf')
        config.write_text('[req]\ndistinguished_name=dn\nx509_extensions=ext\nprompt=no\n'
                          '[dn]\nCN=Vox local test\n[ext]\nbasicConstraints=critical,CA:TRUE\n'
                          'keyUsage=critical,digitalSignature,keyEncipherment,keyCertSign\n'
                          'subjectAltName=IP:127.0.0.1\n')
        subprocess.run(['openssl', 'req', '-x509', '-newkey', 'rsa:2048', '-nodes', '-days', '1',
                        '-keyout', str(root / (name + '.key')), '-out', str(root / (name + '.pem')),
                        '-config', str(config)], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            body = b'private CA resource'
            self.send_response(200)
            self.send_header('Content-Type', 'text/plain;charset=utf-8')
            self.send_header('Content-Length', str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, *args):
            pass

    server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.load_cert_chain(root / 'trusted.pem', root / 'trusted.key')
    server.socket = context.wrap_socket(server.socket, server_side=True)
    (root / 'port').write_text(str(server.server_port))
    # V assertion failures can exit before defer cleanup. Do not retain its
    # inherited output pipes or leave a server behind after the owner exits.
    owner = os.getppid()
    deadline = time.monotonic() + 60
    server.timeout = .25
    try:
        while os.getppid() == owner and time.monotonic() < deadline:
            server.handle_request()
    finally:
        server.server_close()


if __name__ == '__main__':
    main()
