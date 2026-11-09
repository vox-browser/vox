fn new_h2_pooled_transport(mut conn ssl.SSLConn) &H2PooledTransport {
    mut transport := &H2PooledTransport{conn: conn, vox_wake: C.vox_h2_wake_create()}
    conn.set_read_timeout(transport.vox_read_timeout())
    return transport
}