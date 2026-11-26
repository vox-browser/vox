"""Local media origin and SOCKS5 route; never connects to the requested host."""
import http.server
import json
import select
import socket
import socketserver
import sys
import threading
from pathlib import Path

root = Path(sys.argv[1])
lock = threading.Lock()
state = {'requests': [], 'proxy_hosts': []}


def record(key, value):
    with lock:
        state[key].append(value)
        temporary = root / 'stats.tmp'
        temporary.write_text(json.dumps(state))
        temporary.replace(root / 'stats.json')


class Origin(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        record('requests', self.path)
        headers = {}
        if self.path == '/redirect.mp4':
            status, body = 302, b''
            headers['Location'] = f'http://proxied-media.invalid:{origin.server_port}/movie.mp4'
        elif self.path == '/movie.mp4':
            status, body = 200, (root / 'movie.mp4').read_bytes()
            headers['Content-Type'] = 'video/mp4'
        elif self.path == '/playlist.m3u8':
            status, body = 200, b'#EXTM3U\nhttp://unarchived.invalid/segment.ts\n'
            headers['Content-Type'] = 'application/vnd.apple.mpegurl'
        else:
            status, body = 404, b'media is not archived'
        self.send_response(status)
        for name, value in headers.items():
            self.send_header(name, value)
        self.send_header('Content-Length', str(len(body)))
        self.send_header('Connection', 'close')
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass


def receive(stream, size):
    result = b''
    while len(result) < size:
        part = stream.recv(size - len(result))
        if not part:
            raise EOFError('incomplete SOCKS request')
        result += part
    return result


class Proxy(socketserver.BaseRequestHandler):
    def handle(self):
        client = self.request
        version, count = receive(client, 2)
        methods = receive(client, count)
        if version != 5 or 0 not in methods:
            return
        client.sendall(b'\x05\x00')
        if receive(client, 4) != b'\x05\x01\x00\x03':
            return
        host = receive(client, receive(client, 1)[0]).decode('ascii')
        port = int.from_bytes(receive(client, 2), 'big')
        record('proxy_hosts', host)
        if host != 'proxied-media.invalid' or port != origin.server_port:
            client.sendall(b'\x05\x02\x00\x01' + bytes(6))
            return
        with socket.create_connection(('127.0.0.1', origin.server_port)) as upstream:
            client.sendall(b'\x05\x00\x00\x01' + bytes(6))
            while True:
                readable, _, _ = select.select([client, upstream], [], [], 10)
                if not readable:
                    return
                for source in readable:
                    data = source.recv(65536)
                    if not data:
                        return
                    (upstream if source is client else client).sendall(data)


class ProxyServer(socketserver.ThreadingTCPServer):
    daemon_threads = True


origin = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Origin)
proxy = ProxyServer(('127.0.0.1', 0), Proxy)
threading.Thread(target=origin.serve_forever, daemon=True).start()
(root / 'ready.tmp').write_text(json.dumps({'origin_port': origin.server_port,
                                         'proxy_port': proxy.server_address[1]}))
(root / 'ready.tmp').replace(root / 'ready.json')
proxy.serve_forever()
