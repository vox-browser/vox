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
        address := if host.contains(':') { '[${host}]:${port}' } else { '${host}:${port}' }
        mut tcp := net.dial_tcp(address)!
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
