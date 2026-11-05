// Establish TCP before constructing TLS state and parsing its CA bundle. This
// is the same verified handshake and ALPN path as SSLConn.dial(), with socket
// ownership transferred only after connect() succeeds.
fn vox_http_dial_tls(req &Request, host string, port int, alpn []string) !&ssl.SSLConn {
    $if use_openssl ? {
        mut connection := ssl.new_ssl_conn(
            verify: req.verify
            cert: req.cert
            cert_key: req.cert_key
            validate: req.validate
            in_memory_verification: req.in_memory_verification
            alpn_protocols: alpn
        )!
        connection.dial(host, port)!
        return connection
    } $else {
        mut tcp := vox_http_dial_tcp(req, host, port)!
        mut transferred := false
        defer {
            if !transferred { tcp.close() or {} }
        }
        mut connection := ssl.new_ssl_conn(
            verify: req.verify
            cert: req.cert
            cert_key: req.cert_key
            validate: req.validate
            in_memory_verification: req.in_memory_verification
            alpn_protocols: alpn
        )!
        // Preserve the TLS backend's configured handshake read timeout.
        tcp.set_read_timeout(connection.read_timeout())
        connection.connect(mut tcp, host) or {
            // This compatibility backend exposes shutdown only for an opened
            // SSLConn. All TLS structures are initialized here; let shutdown
            // release them while the defer above still owns the TCP socket.
            connection.owns_socket = false
            connection.opened = true
            connection.shutdown() or {}
            return err
        }
        connection.owns_socket = true
        transferred = true
        return connection
    }
}

// Pooled connections to an origin open their TCP stream through the request's
// proxy. SOCKS5 and HTTP CONNECT both tunnel bytes end to end, so TLS, ALPN and
// HTTP/1 or HTTP/2 framing inside the tunnel are those of a direct connection.
fn vox_http_dial_tcp(req &Request, host string, port int) !&net.TcpConn {
    address := if host.contains(':') { '[${host}]:${port}' } else { '${host}:${port}' }
    if req.proxy != unsafe { nil } {
        return req.proxy.connect_tcp(address)!
    }
    return net.dial_tcp(address)!
}

// The OpenSSL and Windows TLS backends dial their own sockets, so proxied
// requests there keep V's one-shot proxy path.
fn vox_transport_tunnels_proxy() bool {
    $if use_openssl ? {
        return false
    }
    $if windows {
        return false
    }
    return true
}

fn vox_transport_proxy_key(req &Request) string {
    return if req.proxy == unsafe { nil } { '' } else { req.proxy.str() }
}
