#!/usr/bin/env python3
"""Exercise the real Windows resource transport against isolated TLS servers."""
import argparse
import http.server
import os
from pathlib import Path
import ssl
import subprocess
import tempfile
import threading


class Fixture(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        body = b"vox-native-trust-fixture\n"
        self.send_response(200)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *_args):
        pass


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--guard", required=True, type=Path)
    parser.add_argument("--test", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--live-url", default="-", help="Optional public HTTPS URL to test Windows roots")
    args = parser.parse_args()
    if args.live_url != "-" and not args.live_url.startswith("https://"):
        parser.error("--live-url must use HTTPS")
    args.output.mkdir(parents=True, exist_ok=True)
    environment = {k: v for k, v in os.environ.items()
                   if k.lower() not in {"http_proxy", "https_proxy", "all_proxy", "vox_proxy"}}
    with tempfile.TemporaryDirectory(prefix="vox-tls-") as directory:
        root = Path(directory)
        def openssl(*command):
            subprocess.run(["openssl", *command], cwd=root, check=True,
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        openssl("req", "-x509", "-newkey", "rsa:2048", "-nodes", "-keyout", "ca.key",
                "-out", "ca.pem", "-days", "1", "-subj", "/CN=Vox isolated TLS test CA",
                "-addext", "basicConstraints=critical,CA:TRUE")
        servers = []
        threads = []
        try:
            for name, san in (("valid", "IP:127.0.0.1"), ("wrong", "DNS:wrong.invalid")):
                openssl("req", "-newkey", "rsa:2048", "-nodes", "-keyout", name + ".key",
                        "-out", name + ".csr", "-subj", "/CN=" + name)
                (root / (name + ".ext")).write_text(
                    "subjectAltName=" + san + "\nbasicConstraints=CA:FALSE\n"
                    "extendedKeyUsage=serverAuth\n", encoding="ascii")
                openssl("x509", "-req", "-in", name + ".csr", "-CA", "ca.pem", "-CAkey",
                        "ca.key", "-CAcreateserial", "-out", name + ".pem", "-days", "1",
                        "-extfile", name + ".ext")
                server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Fixture)
                context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
                context.load_cert_chain(root / (name + ".pem"), root / (name + ".key"))
                server.socket = context.wrap_socket(server.socket, server_side=True)
                thread = threading.Thread(target=server.serve_forever, daemon=True)
                servers.append(server)
                threads.append(thread)
                thread.start()
            subprocess.run([
                str(args.guard.resolve()), "240000", "3072",
                str((args.output / "https.out").resolve()),
                str((args.output / "https.err").resolve()), str(args.test.resolve()), args.live_url,
                *[f"https://127.0.0.1:{s.server_port}/" for s in servers], str(root / "ca.pem"),
            ], env=environment, check=True, timeout=270)
        finally:
            for server in servers:
                server.shutdown()
                server.server_close()
            for thread in threads:
                thread.join()


if __name__ == "__main__":
    main()
