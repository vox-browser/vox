"""Adapt the supported V HTTP transports without modifying the V checkout."""

from pathlib import Path


def tls_dial_helper():
    return Path(__file__).with_suffix('.v.inc').read_text()


def patch_transport_tls(source, http2=False):
    name = 'h2_dial_and_do' if http2 else 'tls_fresh_round_trip'
    start = source.index('fn (mut t Transport) ' + name + '(')
    begin = source.index('\tmut ssl_conn := ssl.new_ssl_conn(', start)
    end = source.index('\n\tif req.read_timeout > 0 {', begin)
    previous = source[begin:end]
    for field in ['verify', 'cert', 'cert_key', 'validate', 'in_memory_verification']:
        if 'req.' + field not in previous:
            raise RuntimeError('Unsupported V HTTP TLS configuration: ' + field)
    if previous.count('ssl_conn.dial(host, port)') != 1:
        raise RuntimeError('Unsupported V HTTP TLS connection sequence')
    if http2:
        failure = ' or { return t.h2_dial_failed(key, mut call, err) }'
        if previous.count(failure) != 2:
            raise RuntimeError('Unsupported V HTTP/2 TLS failure handling')
        replacement = "\tmut ssl_conn := vox_http_dial_tls(req, host, port, ['h2', 'http/1.1'])" + failure
    else:
        if 'alpn_protocols:         alpn' not in previous:
            raise RuntimeError('Unsupported V HTTP/1 TLS ALPN configuration')
        replacement = '\tmut ssl_conn := vox_http_dial_tls(req, host, port, alpn)!'
    return source[:begin] + replacement + source[end:]
