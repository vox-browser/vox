#!/usr/bin/env python3
"""Exercise the staged TLS session adapter against independent TLS/proxy servers."""
import argparse
import hashlib
import http.server
import json
import os
from pathlib import Path
import select
import shutil
import socket
import socketserver
import ssl
import subprocess
import sys
import threading
import time


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--compiler', type=Path, required=True)
    parser.add_argument('--gc', choices=['default', 'none', 'prealloc'], default='default')
    parser.add_argument('--arms', nargs='+', choices=['candidate', 'control'],
                        default=['candidate', 'control'])
    parser.add_argument('--cases', help='Comma-separated focused case selection')
    parser.add_argument('--native-cache-probe', type=Path,
                        help='Optional separately pinned native ownership/expiry probe')
    parser.add_argument('--native-only', action='store_true')
    parser.add_argument('--tls13-openssl', type=Path,
                        help='OpenSSL3 provider for a separate TLS1.3-only endpoint')
    args = parser.parse_args()
    repo = Path(__file__).resolve().parents[1]
    out = args.output.resolve()
    out.mkdir()
    save = lambda name, value: (out / name).write_text(json.dumps(value, indent=2) + '\n')
    source_paths = [Path(__file__), repo / 'tools/httpcompat/check_tls_sessions.v',
                    repo / 'tools/httpcompat/tls_sessions.h', repo / 'tools/http_tls_sessions.v.inc',
                    repo / 'tools/http_tls_dial.v.inc', repo / 'tools/prepare_http_compat.py',
                    repo / 'platform/native_state.h', args.compiler.resolve()]
    before = {str(p): digest(p) for p in source_paths}
    save('source-before.json', before)
    env = {k: v for k, v in os.environ.items() if not (k.lower().endswith('_proxy') or
           k.startswith(('VOX_', 'LADYBIRD_', 'DYLD_', 'JSC_')))}
    env['V_MACOS_V3_NO_FALLBACK'] = '1'
    cmd = [sys.executable, str(repo / 'tools/prepare_http_compat.py'), str(args.compiler)]
    save('stage-command.json', cmd)
    with (out / 'stage.log').open('w') as log:
        process = subprocess.run(cmd, cwd=repo, env=env, stdout=log, stderr=subprocess.STDOUT)
    assert process.returncode == 0
    modules = Path(next(line for line in (out / 'stage.log').read_text().splitlines()
                        if line.startswith('/') and line.endswith('/modules')))
    staged = modules / 'net/http'
    for name, source in [('vox_tls_sessions.h', 'tools/httpcompat/tls_sessions.h'),
                         ('vox_tls_sessions.v', 'tools/http_tls_sessions.v.inc'),
                         ('vox_native_state.h', 'platform/native_state.h')]:
        assert (staged / name).read_bytes() == (repo / source).read_bytes()
    staged_pins = {str(p): digest(p) for p in staged.glob('*') if p.is_file()}
    save('staged-before.json', staged_pins)
    binary = out / 'client'
    cmd = [str(args.compiler), '-memory-limit', '10G', '-w', '-enable-globals', '-nocache',
           '-b', 'c', '-cc', 'clang',
           '-keepc', '-cflags', '-O0', '-path', str(modules) + '|' + str(repo) + '|@vmodules|@vlib']
    if args.gc == 'none':
        cmd += ['-gc', 'none']
    elif args.gc == 'prealloc':
        cmd += ['-prealloc', '-gc', 'none']
    cmd += ['-o', str(binary), str(repo / 'tools/httpcompat/check_tls_sessions.v')]
    save('compile-command.json', cmd)
    with (out / 'compile.log').open('w') as log:
        process = subprocess.run(cmd, cwd=repo, env=env, stdout=log, stderr=subprocess.STDOUT)
    save('compile-exit.json', {'exit': process.returncode})
    assert process.returncode == 0
    assert b'Vox TLS1.2 session: offered a verified cached session' in binary.read_bytes()
    save('client-identity.json', {'path': str(binary), 'sha256': digest(binary)})
    for index in [1, 2]:
        config = out / ('ca' + str(index) + '.cnf')
        config.write_text('[req]\ndistinguished_name=dn\nx509_extensions=ext\nprompt=no\n'
                          '[dn]\nCN=localhost\n[ext]\nsubjectAltName=DNS:localhost,IP:127.0.0.1\n'
                          'basicConstraints=critical,CA:TRUE\n'
                          'keyUsage=critical,digitalSignature,keyEncipherment,keyCertSign\n')
        cmd = ['openssl', 'req', '-x509', '-newkey', 'rsa:2048', '-nodes', '-days', '2',
               '-keyout', str(out / ('key' + str(index) + '.pem')), '-out',
               str(out / ('ca' + str(index) + '.pem')), '-config', str(config)]
        save('certificate' + str(index) + '-command.json', cmd)
        with (out / ('certificate' + str(index) + '.log')).open('w') as log:
            subprocess.run(cmd, check=True, stdout=log, stderr=subprocess.STDOUT)

    def make_context():
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        context.minimum_version = context.maximum_version = ssl.TLSVersion.TLSv1_2
        context.load_cert_chain(out / 'ca1.pem', out / 'key1.pem')
        context.set_alpn_protocols(['http/1.1'])
        return context

    context_ref = {'value': make_context()}
    observations = []
    handshake_rejections = []
    observation_lock = threading.Lock()

    class Handler(http.server.BaseHTTPRequestHandler):
        protocol_version = 'HTTP/1.1'

        def do_GET(self):
            record = dict(case=self.headers.get('X-Vox-TLS-Case'),
                          action=self.headers.get('X-Vox-TLS-Action'), path=self.path,
                          host=self.headers.get('Host'), port=self.server.server_address[1],
                          version=self.connection.version(),
                          session_reused=self.connection.session_reused,
                          method=self.command,
                          alpn=self.connection.selected_alpn_protocol())
            with observation_lock:
                observations.append(record)
                if self.path == '/rotate':
                    context_ref['value'] = make_context()
                if self.path == '/reject-next':
                    context_ref['reject'] = self.headers.get('X-Vox-TLS-Case')
            self.send_response(200)
            self.send_header('Content-Length', '2')
            self.send_header('Connection', 'close')
            self.end_headers()
            self.wfile.write(b'ok')
            self.close_connection = True

        def do_POST(self):
            body = self.rfile.read(int(self.headers.get('Content-Length', '0')))
            assert body == b'once'
            self.do_GET()

        def log_message(self, *unused):
            pass

    class Server(http.server.ThreadingHTTPServer):
        request_queue_size = 128
        def get_request(self):
            connection, address = super().get_request()
            try:
                with observation_lock:
                    rejected = context_ref.pop('reject', None)
                    if rejected:
                        handshake_rejections.append(dict(case=rejected, address=address,
                                                         reason='Controlled pre-HTTP fatal TLS alert'))
                if rejected:
                    connection.sendall(bytes([21, 3, 3, 0, 2, 2, 70]))
                    connection.close()
                    raise ConnectionError('Controlled TLS resumption rejection')
                return context_ref['value'].wrap_socket(connection, server_side=True), address
            except BaseException:
                connection.close()
                raise

    servers = [Server(('127.0.0.1', 0), Handler) for _ in range(2)]
    ports = {server.server_address[1] for server in servers}

    def exact(connection, count):
        data = b''
        while len(data) < count:
            part = connection.recv(count - len(data))
            if not part:
                raise ConnectionError('Incomplete SOCKS handshake')
            data += part
        return data

    class SocksHandler(socketserver.BaseRequestHandler):
        def handle(self):
            try:
                greeting = exact(self.request, 2)
                assert greeting[0] == 5 and 0 in exact(self.request, greeting[1])
                self.request.sendall(bytes([5, 0]))
                version, command, reserved, kind = exact(self.request, 4)
                assert (version, command, reserved) == (5, 1, 0)
                if kind == 3:
                    host = exact(self.request, exact(self.request, 1)[0]).decode('ascii')
                elif kind == 1:
                    host = socket.inet_ntoa(exact(self.request, 4))
                else:
                    raise ValueError('Unexpected fixture address family')
                port = int.from_bytes(exact(self.request, 2), 'big')
                assert host in ['localhost', '127.0.0.1'] and port in ports
                with socket.create_connection(('127.0.0.1', port), timeout=3) as remote:
                    self.request.sendall(bytes([5, 0, 0, 1, 127, 0, 0, 1, 0, 0]))
                    while True:
                        ready, _, _ = select.select([self.request, remote], [], [], 5)
                        if not ready:
                            return
                        for source in ready:
                            data = source.recv(65536)
                            if not data:
                                return
                            (remote if source is self.request else self.request).sendall(data)
            except (ConnectionError, OSError):
                return

    class SocksServer(socketserver.ThreadingTCPServer):
        daemon_threads = True
        request_queue_size = 128

    proxies = [SocksServer(('127.0.0.1', 0), SocksHandler) for _ in range(2)]
    threads = []
    for server in servers + proxies:
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        threads.append(thread)
    first = 'https://localhost:' + str(servers[0].server_address[1])
    second = 'https://localhost:' + str(servers[1].server_address[1])
    ip_origin = first.replace('localhost', '127.0.0.1')
    proxy_urls = ['socks5://127.0.0.1:' + str(p.server_address[1]) for p in proxies]
    ca = str(out / 'ca1.pem')
    mutable_ca = str(out / 'mutable-ca.pem')
    other_path = out / 'same-ca.pem'
    shutil.copyfile(ca, other_path)
    provider = None
    provider_log = None
    tls13_origin = None
    provider_before = None
    if args.tls13_openssl and not args.native_only and (not args.cases or 'tls13' in args.cases.split(',')):
        provider_path = args.tls13_openssl.resolve()
        provider_before = digest(provider_path)
        with socket.socket() as reservation:
            reservation.bind(('127.0.0.1', 0))
            tls13_port = reservation.getsockname()[1]
        cmd = [str(provider_path), 's_server', '-accept', '127.0.0.1:' + str(tls13_port),
               '-tls1_3', '-alpn', 'http/1.1', '-cert', str(out / 'ca1.pem'),
               '-key', str(out / 'key1.pem'), '-www', '-naccept', str(1 + 2 * len(args.arms))]
        save('tls13-server-command.json', dict(command=cmd, executable_sha256=provider_before,
             qualification='One deliberate TCP-only readiness connection plus two verified TLS1.3 HTTP connections per selected arm. This is focused testing, not an acceptance browser.'))
        provider_log = (out / 'tls13-server.log').open('w')
        provider = subprocess.Popen(cmd, cwd=repo, env=env, stdin=subprocess.DEVNULL,
                                    stdout=provider_log, stderr=subprocess.STDOUT)
        deadline = time.monotonic() + 5
        while True:
            assert provider.poll() is None, 'TLS1.3 provider failed before readiness'
            try:
                with socket.create_connection(('127.0.0.1', tls13_port), timeout=.1):
                    break
            except OSError:
                assert time.monotonic() < deadline
                time.sleep(.02)
        tls13_origin = 'https://localhost:' + str(tls13_port)

    def action(base=first, **settings):
        return dict(url=base + '/same', verify=ca, enable_http2=True, validate=True,
                    require_success=True, **settings)

    # Explicit settings override defaults without ambiguity in fixture plans.
    def changed(**settings):
        result = action()
        result.update(settings)
        return result

    cases = [
        ('reuse', [action(), action()], [False, True]),
        ('alpn', [action(), action(), changed(enable_http2=False),
                  changed(enable_http2=False), action()], [False, True, False, True, True]),
        ('port', [action(), action(), action(second), action(second), action()],
         [False, True, False, True, True]),
        ('host', [action(), action(), action(ip_origin), action(ip_origin), action()],
         [False, True, False, True, True]),
        ('trust-path', [action(), action(), changed(verify=str(other_path)),
                        changed(verify=str(other_path)), action()], [False, True, False, True, True]),
        ('trust-change', [changed(verify=mutable_ca, copy_ca_from=ca, copy_ca_to=mutable_ca),
                          changed(verify=mutable_ca),
                          changed(verify=mutable_ca, copy_ca_from=str(out / 'ca2.pem'),
                                  copy_ca_to=mutable_ca, require_success=False),
                          changed(verify=mutable_ca, copy_ca_from=ca, copy_ca_to=mutable_ca),
                          changed(verify=mutable_ca)], [False, True, None, True, True]),
        ('validation', [changed(validate=False), changed(validate=False), action(), action()],
         [False, False, False, True]),
        ('fresh-connections', [changed(disable_connection_reuse=True),
                               changed(disable_connection_reuse=True), action(), action()],
         [False, False, False, True]),
        ('client-auth', [changed(cert=ca, cert_key=str(out / 'key1.pem')),
                         changed(cert=ca, cert_key=str(out / 'key1.pem')), action(), action()],
         [False, False, False, True]),
        ('server-fallback', [action(), action(), changed(url=first + '/rotate'), action(), action()],
         [False, True, True, False, False]),
        ('handshake-fallback', [action(), action(), changed(url=first + '/reject-next'),
                                changed(post=True), action()], [False, True, True, False, True]),
        ('proxy', [action(), action(), changed(proxy=proxy_urls[0]), changed(proxy=proxy_urls[0]),
                   changed(proxy=proxy_urls[1]), changed(proxy=proxy_urls[1]),
                   changed(proxy=proxy_urls[0])], [False, True, False, True, False, True, True]),
        ('concurrent', [action(), action(), changed(parallel=20)], [False, True, True]),
    ]
    if tls13_origin:
        cases.append(('tls13', [changed(url=tls13_origin + '/', contains='TLSv1.3'),
                                changed(url=tls13_origin + '/', contains='TLSv1.3')], []))
    if args.cases:
        selected = set(args.cases.split(','))
        assert selected <= {case[0] for case in cases}
        cases = [case for case in cases if case[0] in selected]
    if args.native_only:
        assert args.native_cache_probe
        cases = []
    save('protocol.json', dict(purpose='Focused verified TLS1.2 transport checks, not performance acceptance.',
        gc=args.gc, compiler=str(args.compiler), modules=str(modules), openssl_server=ssl.OPENSSL_VERSION,
        cases=cases, host=dict(unix=time.time(), cpu_count=os.cpu_count(), load_average=os.getloadavg()),
        limits='TLS1.3 session reuse is not implemented; this fixture deliberately negotiatesTLS1.2.'))
    results = []
    try:
        for arm in args.arms:
            settings = dict(env, VOX_TLS12_SESSION_DIAGNOSTICS='1')
            if arm == 'control':
                settings['VOX_DISABLE_TLS12_SESSION_REUSE'] = '1'
            for label, actions, expected in cases:
                actions = [dict(action) for action in actions]
                expected = list(expected)
                if label == 'handshake-fallback' and arm == 'control':
                    actions[3]['require_success'] = False
                    expected[3] = None
                name = args.gc + '-' + arm + '-' + label
                spec = out / (name + '.json')
                spec.write_text(json.dumps(dict(name=name, actions=actions), indent=2) + '\n')
                request_plan = out / (name + '.tsv')
                fields = ['url', 'verify', 'proxy', 'cert', 'cert_key', 'copy_ca_from', 'copy_ca_to',
                          'enable_http2', 'validate', 'disable_connection_reuse', 'require_success', 'parallel',
                          'contains', 'post']
                plan = [name]
                for act in actions:
                    values = [act.get(field, 1 if field == 'parallel' else False if
                              field in ['disable_connection_reuse', 'post'] else '') for field in fields]
                    values = ['1' if value is True else '0' if value is False else str(value)
                              for value in values]
                    assert all('\t' not in value and '\n' not in value for value in values)
                    plan.append('\t'.join(values))
                request_plan.write_text('\n'.join(plan) + '\n')
                cmd = [sys.executable, str(repo / 'tools/run_memory_bounded.py'), '--limit-gib', '3',
                       '--timeout', '60', '--lock', str(out / (name + '.lock')), '--report',
                       str(out / (name + '.guard.json')), '--', str(binary), str(request_plan)]
                save(name + '-command.json', dict(command=cmd, environment={k: v for k, v in settings.items()
                       if k.startswith(('VOX_', 'V_MACOS_'))}))
                with (out / (name + '.log')).open('w') as log:
                    process = subprocess.run(cmd, cwd=repo, env=settings, stdout=log, stderr=subprocess.STDOUT)
                lines = (out / (name + '.log')).read_text().splitlines()
                responses = []
                for line in lines:
                    if line.startswith('TLS_RESULT\t'):
                        _, index, worker, success, status = line.split('\t')
                        responses.append(dict(action=int(index), worker=int(worker),
                                              success=success == '1', status=int(status)))
                actual = sorted([x for x in observations if x['case'] == name],
                                key=lambda x: tuple(map(int, x['action'].split('-'))))
                wanted = [value if arm == 'candidate' else False for act, value in zip(actions, expected)
                          for _ in range(act.get('parallel', 1)) if value is not None]
                passed = (process.returncode == 0 and len(responses) == sum(a.get('parallel', 1) for a in actions)
                          and [x['session_reused'] for x in actual] == wanted
                          and all(x['version'] == 'TLSv1.2' and x['path'] in
                                  ['/same', '/rotate', '/reject-next'] for x in actual))
                if label == 'tls13':
                    passed = passed and not any('Vox TLS1.2 session:' in line for line in lines)
                if label == 'handshake-fallback':
                    passed = passed and sum(x['method'] == 'POST' for x in actual) == (1 if arm == 'candidate' else 0)
                for response in responses:
                    passed = passed and response['success'] == actions[response['action']]['require_success']
                result = dict(name=name, passed=bool(passed), exit=process.returncode,
                              responses=responses, server=actual, expected_resumptions=wanted)
                results.append(result)
                save('results.json', results)
                print(name, 'passed' if passed else 'FAILED', flush=True)
                if not passed:
                    raise AssertionError(name)
        if args.native_cache_probe:
            probe = args.native_cache_probe.resolve()
            probe_identity = digest(probe)
            cmd = [sys.executable, str(repo / 'tools/run_memory_bounded.py'), '--limit-gib', '3',
                   '--timeout', '60', '--lock', str(out / 'native-cache.lock'), '--report',
                   str(out / 'native-cache.guard.json'), '--', str(probe),
                   str(servers[0].server_address[1]), ca]
            save('native-cache-command.json', dict(command=cmd, probe_sha256=probe_identity))
            with (out / 'native-cache.log').open('w') as log:
                process = subprocess.run(cmd, cwd=repo, env=env, stdout=log, stderr=subprocess.STDOUT)
            assert digest(probe) == probe_identity
            text = (out / 'native-cache.log').read_text()
            for label, expected in [('expiry', [False, True, False]),
                                    ('eviction', [False] * 65 + [True, False]),
                                    ('copy-error', [False, True, False])]:
                actual = sorted([x for x in observations if x['case'] == 'native-' + label],
                                key=lambda x: tuple(map(int, x['action'].split('-'))))
                passed = process.returncode == 0 and 'CACHE_CASE ' + label + ' passed' in text
                passed = passed and [x['session_reused'] for x in actual] == expected
                results.append(dict(name='native-' + label, passed=passed, exit=process.returncode,
                                    server=actual, expected_resumptions=expected))
                save('results.json', results)
                print('native-' + label, 'passed' if passed else 'FAILED', flush=True)
                assert passed
    finally:
        if provider:
            try:
                provider_exit = provider.wait(timeout=3)
            except subprocess.TimeoutExpired:
                provider.terminate()
                provider_exit = provider.wait(timeout=3)
            provider_log.close()
            provider_after = digest(args.tls13_openssl.resolve())
            save('tls13-server-exit.json', dict(exit=provider_exit, identity_unchanged=provider_before == provider_after))
        for server in servers + proxies:
            server.shutdown()
            server.server_close()
        for thread in threads:
            thread.join()
        save('server-observations.json', observations)
        save('handshake-rejections.json', handshake_rejections)
        after = {str(p): digest(p) for p in source_paths}
        staged_after = {p: digest(p) for p in staged_pins}
        save('source-after.json', after)
        save('staged-after.json', staged_after)
    assert before == after and staged_pins == staged_after
    if provider:
        assert provider_exit == 0 and provider_before == provider_after
    save('summary.json', dict(passed=True, cases_per_arm=len(cases), executions=len(results),
         results=results, inputs_unchanged=True, client_sha256=digest(binary), performance_credit=0))


if __name__ == '__main__':
    main()
