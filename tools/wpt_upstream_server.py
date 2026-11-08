"""Serve pinned fixtures through an existing upstream WPT checkout."""

import contextlib
import hashlib
import importlib.util
import json
from pathlib import Path
import socket
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
        http1, http2, https1, https2 = free_ports(4)
        builder = config.ConfigBuilder(
            logger.get_logger(), browser_host='localhost', server_host='127.0.0.1',
            alternate_hosts={'alt': 'not.localhost'}, subdomains={'www', 'www1', 'www2'},
            doc_root=str(Path(root).resolve()), ports={'http': [http1, http2], 'https': [https1, https2]},
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
                        except Exception:
                            runner.log_request(request.method, target, 500)
                            raise
                        status = result[0] if isinstance(result, tuple) and len(result) == 3 \
                            and isinstance(result[0], int) else response.status[0]
                        runner.log_request(request.method, target, status)
                        return result
                    return handle

            for port, secure in [(http1, False), (http2, False), (https1, True), (https2, True)]:
                options = dict(host='127.0.0.1', port=port, doc_root=str(Path(root).resolve()),
                               router_cls=RecordingRouter, config=actual)
                if secure:
                    options.update(use_ssl=True, key_file=actual.ssl_config['key_path'],
                                   certificate=actual.ssl_config['cert_path'])
                httpd = server.WebTestHttpd(**options)
                self.servers.append(httpd)
                httpd.start()
            self.server_address = ('localhost', http1)
            self.base_url = f'http://localhost:{http1}'
            self.identity = dict(
                kind='upstream-wptserve', checkout=str(self.checkout),
                revision=subprocess.check_output(['git', '-C', str(self.checkout), 'rev-parse', 'HEAD'],
                                                 text=True).strip(),
                host='localhost', http_ports=[http1, http2], https_ports=[https1, https2],
                ca_certificate=actual.ssl_config['ca_cert_path'],
                ca_sha256=hashlib.sha256(Path(actual.ssl_config['ca_cert_path']).read_bytes()).hexdigest(),
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
