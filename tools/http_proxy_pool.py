"""Route proxied requests through V's pooled HTTP transport.

V's net.http only pools direct connections: a request with a proxy opens a new
SOCKS/CONNECT tunnel and TLS session, without ALPN, for every resource. A page
with hundreds of subresources then pays the tunnel and handshake latency
hundreds of times. Both supported proxy kinds establish an end-to-end TCP
tunnel, so the pooled HTTP/1 and HTTP/2 connections can run inside it
unchanged. The proxy is part of the pool key: a direct connection is never
reused for a proxied request, nor one proxy's tunnel for another.
"""


def patch_pooled_proxy_request(source):
    old = 'if req.proxy == unsafe { nil } && !req.disable_connection_reuse'
    if source.count(old) != 1:
        raise RuntimeError('Unsupported V HTTP pooled-transport selection')
    new = 'if (req.proxy == unsafe { nil } || vox_transport_tunnels_proxy()) && !req.disable_connection_reuse'
    return source.replace(old, new, 1)


def patch_pooled_proxy_transport(source):
    key_start = source.index('fn transport_pool_key(')
    key_end = source.index('\n}', key_start)
    key = source[key_start:key_end]
    old_key = '|${req.in_memory_verification}\''
    if key.count(old_key) != 1:
        raise RuntimeError('Unsupported V HTTP transport pool key')
    key = key.replace(old_key, '|${req.in_memory_verification}|${pk_part(vox_transport_proxy_key(req))}\'', 1)
    source = source[:key_start] + key + source[key_end:]
    start = source.index('fn (mut t Transport) dial_h1_tcp(')
    end = source.index('\n}', start)
    dial = source[start:end]
    old_dial = "mut client := net.dial_tcp('${host}:${port}')!"
    if dial.count(old_dial) != 1:
        raise RuntimeError('Unsupported V HTTP/1 transport dial')
    dial = dial.replace(old_dial, 'mut client := vox_http_dial_tcp(req, host, port)!', 1)
    return source[:start] + dial + source[end:]
