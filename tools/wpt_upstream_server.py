"""Serve pinned fixtures through an existing upstream WPT checkout."""

import contextlib
import hashlib
import importlib.util
import json
from pathlib import Path
import socket
import ssl
import subprocess
import sys


def load_wptserve(checkout):
    checkout = Path(checkout).resolve()
    paths = checkout / 'tools/localpaths.py'
    if not paths.is_file():
        raise ValueError(f'Not a WPT checkout: {checkout}')
    spec = importlib.util.spec_from_file_location('_vox_upstream_wpt_paths', paths)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    from wptserve import config, handlers, logger, router, server, stash
    return checkout, config, handlers, logger, router, server, stash


def free_ports(count):
    with contextlib.ExitStack() as stack:
        sockets = [stack.enter_context(socket.socket()) for _ in range(count)]
        for connection in sockets:
            connection.bind(('127.0.0.1', 0))
        return [connection.getsockname()[1] for connection in sockets]


class UpstreamWPTServer:
    def __init__(self, checkout, root, runner, resources, alive_path, result_path, certificates):
        self.stack = contextlib.ExitStack()
        self.servers = []
        self.checkout, config, handlers, logger, router, server, stash = load_wptserve(checkout)
        # Match upstream serve's origin groups. Shared helpers substitute even
        # the local/public and currently unserved protocol ports eagerly.
        counts = {'http': 2, 'http-local': 1, 'http-public': 1,
                  'https': 2, 'https-local': 1, 'https-public': 1,
                  'h2': 1, 'ws': 1, 'wss': 1, 'webtransport-h3': 1, 'dns': 1}
        available = iter(free_ports(sum(counts.values())))
        ports = {name: [next(available) for _ in range(count)] for name, count in counts.items()}
        http_origins = {name: values for name, values in ports.items()
                        if name.startswith(('http', 'https'))}
        builder = config.ConfigBuilder(
            logger.get_logger(), browser_host='localhost', server_host='127.0.0.1',
            alternate_hosts={'alt': 'not.localhost'}, subdomains={'www', 'www1', 'www2'},
            doc_root=str(Path(root).resolve()),
            ports=ports,
            check_subdomains=False, logging={'level': 'warning'})
        builder.ssl = {'type': 'openssl', 'openssl': {'base_path': str(Path(certificates).resolve())}}
        try:
            actual = self.stack.enter_context(builder)
            self.stack.enter_context(stash.StashServer())

            class RecordingRouter(router.Router):
                def get_handler(self, request):
                    target = request.request_path
                    runner.note_request(target)
                    path = request.url_parts.path
                    if request.method in ('GET', 'HEAD') and path in resources:
                        body, content_type = resources[path]

                        def resource(request, response):
                            runner.log_request(request.method, target, 200)
                            return [(b'Content-Type', content_type.encode()),
                                    (b'Cache-Control', b'no-store')], body
                        return handlers.handler(resource)
                    if request.method == 'POST' and path in (alive_path, result_path):
                        def collect(request, response):
                            if path == alive_path:
                                runner.note_harness(request.body.decode('utf-8', errors='replace'))
                                response.status = 204
                                return b''
                            try:
                                payload = json.loads(request.body)
                            except (ValueError, UnicodeError):
                                response.status = 400
                                return b'Invalid result'
                            response.headers.set(b'Content-Type', b'application/json')
                            return json.dumps({'next': runner.accept(payload)}).encode()
                        return handlers.handler(collect)
                    original = super().get_handler(request)
                    if original is None:
                        return None

                    def handle(request, response):
                        try:
                            result = original(request, response)
                        except Exception as error:
                            runner.log_request(request.method, target, getattr(error, 'code', 500))
                            raise
                        status = result[0] if isinstance(result, tuple) and len(result) == 3 \
                            and isinstance(result[0], int) else response.status[0]
                        runner.log_request(request.method, target, status)
                        return result
                    return handle

            class GracefulTLSHandler(server.Http1WebTestRequestHandler):
                def finish(self):
                    super().finish()
                    # Upstream already closes CONNECT tunnels this way. Direct
                    # HTTPS needs the same close_notify for EOF-delimited bodies;
                    # otherwise strict TLS clients reject a complete script.
                    connection = self.request
                    if isinstance(connection, ssl.SSLSocket) and not self.server.encrypt_after_connect:
                        try:
                            connection.settimeout(1)
                            connection.unwrap().close()
                        except (OSError, ValueError):
                            pass
                        finally:
                            connection.close()

            for name, origin_ports in http_origins.items():
                for port in origin_ports:
                    options = dict(host='127.0.0.1', port=port, doc_root=str(Path(root).resolve()),
                                   router_cls=RecordingRouter, handler_cls=GracefulTLSHandler, config=actual)
                    if name.startswith('https'):
                        options.update(use_ssl=True, key_file=actual.ssl_config['key_path'],
                                       certificate=actual.ssl_config['cert_path'])
                    httpd = server.WebTestHttpd(**options)
                    self.servers.append(httpd)
                    httpd.start()
            self.server_address = ('localhost', ports['http'][0])
            self.base_url = f'http://localhost:{ports["http"][0]}'
            self.identity = dict(
                kind='upstream-wptserve', checkout=str(self.checkout),
                revision=subprocess.check_output(['git', '-C', str(self.checkout), 'rev-parse', 'HEAD'],
                                                 text=True).strip(),
                host='localhost', http_ports=ports['http'], https_ports=ports['https'],
                http_origin_ports=http_origins,
                unserved_protocols={name: values for name, values in ports.items() if name not in http_origins},
                ca_certificate=actual.ssl_config['ca_cert_path'],
                ca_sha256=hashlib.sha256(Path(actual.ssl_config['ca_cert_path']).read_bytes()).hexdigest(),
                tls_close_notify=True, tls_shutdown_timeout_seconds=1,
                source_files=self.source_hashes())
        except BaseException:
            self.shutdown()
            raise

    def source_hashes(self):
        files = {Path(module.__file__).resolve() for module in tuple(sys.modules.values())
                 if getattr(module, '__file__', None)}
        files.update((self.checkout / 'tools/wptserve').rglob('*.py'))
        return {str(path): hashlib.sha256(path.read_bytes()).hexdigest() for path in sorted(files)
                if path.is_file() and self.checkout in path.parents}

    def changed_inputs(self):
        return [path for path, digest in self.identity['source_files'].items()
                if not Path(path).is_file() or hashlib.sha256(Path(path).read_bytes()).hexdigest() != digest]

    def shutdown(self):
        for server in reversed(self.servers):
            server.stop()
        self.servers.clear()
        self.stack.close()
