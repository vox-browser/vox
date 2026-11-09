
fn (pr &HttpProxy) ssl_dial(host string, req &Request) !&ssl.SSLConn {
    mut ssl_conn := ssl.new_ssl_conn(
        verify: req.verify
        cert: req.cert
        cert_key: req.cert_key
        validate: req.validate
        in_memory_verification: req.in_memory_verification
    )!
    mut tcp := pr.connect_tcp(host)!
    tcp.set_read_timeout(req.read_timeout)
    tcp.set_write_timeout(req.write_timeout)
    ssl_conn.connect(mut tcp, host.all_before_last(':')) or {
        tcp.close() or {}
        ssl_conn.shutdown() or {}
        return err
    }
    ssl_conn.owns_socket = true
    ssl_conn.set_read_timeout(req.read_timeout)
    return ssl_conn
}