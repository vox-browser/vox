// Establish TCP before constructing TLS state and parsing its CA bundle. This
// is the same verified handshake and ALPN path as SSLConn.dial(), with socket
// ownership transferred only after connect() succeeds.
struct VoxTLSResumeDialFailure {
    cause string
    cause_code int
}

fn (failure VoxTLSResumeDialFailure) msg() string { return failure.cause }
fn (failure VoxTLSResumeDialFailure) code() int { return failure.cause_code }

fn vox_http_dial_tls(req &Request, host string, port int, alpn []string) !&ssl.SSLConn {
    for attempt in 0 .. 2 {
        connection := vox_http_dial_tls_attempt(req, host, port, alpn, attempt == 0) or {
            // Mbed TLS1.2 resumption pins its previous protocol version. A
            // server can have upgraded to TLS1.3-only or rejected the offer.
            // The failed attempt has sent no HTTP bytes; close it completely
            // before one ordinary full-handshake dial with the same policy.
            if attempt == 0 && err is VoxTLSResumeDialFailure { continue }
            return err
        }
        return connection
    }
    return error('http: TLS dial exhausted cached-session fallback')
}

fn vox_http_dial_tls_attempt(req &Request, host string, port int, alpn []string, allow_restore bool) !&ssl.SSLConn {
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
        mut connected := false
        defer {
            if !connected {
                // A failed session copy or handshake may own partial TLS
                // structures. The TCP defer still owns the socket here.
                connection.owns_socket = false
                connection.opened = true
                connection.shutdown() or {}
            }
        }
        session := vox_http_prepare_tls_session(req, host, port, allow_restore, mut connection)!
        // Preserve the TLS backend's configured handshake read timeout.
        tcp.set_read_timeout(connection.read_timeout())
        connection.connect(mut tcp, host) or {
            if session.offered {
                vox_http_forget_tls_session(session)
                return VoxTLSResumeDialFailure{cause:err.msg(), cause_code:err.code()}
            }
            return err
        }
        connection.owns_socket = true
        connected = true
        transferred = true
        vox_http_remember_tls_session(req, host, port, session, connection)
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
