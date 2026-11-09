// Always try TLS-buffered data before the first idle wait. After a benign
// timeout, socket readiness or a queued writer wake triggers the next attempt.
// The retained wake keeps its descriptors alive if close races with poll.
fn (mut t H2PooledTransport) read(mut buf []u8) !int {
    t.vox_lock_io()
    if t.closed {
        t.io_mu.unlock()
        return error('h2 pooled transport: closed')
    }
    if t.vox_wait_before_read && t.vox_wake != unsafe { nil } {
        wake := C.vox_h2_wake_retain(t.vox_wake)
        socket := t.conn.handle
        t.io_mu.unlock()
        ready := C.vox_h2_wake_wait(wake, i32(socket), 500)
        if ready == 0 { return error_with_code('h2 pooled transport: idle timeout', net.err_timed_out_code) }
        if ready < 0 { return error('h2 pooled transport: idle wait closed or failed') }
        t.vox_lock_io()
        if t.closed {
            t.io_mu.unlock()
            return error('h2 pooled transport: closed')
        }
    }
    n := t.conn.read(mut buf) or {
        // mbedTLS reports its short read deadline as MBEDTLS_ERR_SSL_TIMEOUT,
        // not net.err_timed_out_code. Any benign timeout must enter the idle
        // wait; otherwise an idle connection polls TLS every 5 ms forever.
        t.vox_wait_before_read = err.code() == net.err_timed_out_code
            || is_transport_timeout_error(err)
        t.io_mu.unlock()
        return err
    }
    t.vox_wait_before_read = false
    t.io_mu.unlock()
    return n
}