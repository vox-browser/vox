"""Let an idle HTTP/2 reader wait outside the serialized TLS context."""


def patch_h2_wakeup(source):
    fields = '\tclosed bool\n}'
    if source.count(fields) != 1:
        raise RuntimeError('Unsupported HTTP/2 transport state layout')
    source = source.replace(fields, '\tvox_wake voidptr\n\tvox_wait_before_read bool\n' + fields, 1)
    source += '''

#include "@DIR/vox_h2_wake.h"
fn C.vox_h2_wake_create() voidptr
fn C.vox_h2_wake_retain(voidptr) voidptr
fn C.vox_h2_wake_signal(voidptr)
fn C.vox_h2_wake_close(voidptr)
fn C.vox_h2_wake_wait(voidptr, i32, i32) i32

fn (t &H2PooledTransport) vox_read_timeout() time.Duration {
    return if t.vox_wake != unsafe { nil } { 5 * time.millisecond } else { h2_pooled_io_timeout }
}
'''
    start = source.index('fn new_h2_pooled_transport(')
    end = source.index('\n}', start) + 2
    source = source[:start] + '''fn new_h2_pooled_transport(mut conn ssl.SSLConn) &H2PooledTransport {
    mut transport := &H2PooledTransport{conn: conn, vox_wake: C.vox_h2_wake_create()}
    conn.set_read_timeout(transport.vox_read_timeout())
    return transport
}''' + source[end:]
    start = source.index('fn (mut t H2PooledTransport) read(')
    end = source.index('\n}', start) + 2
    source = source[:start] + '''// Always try TLS-buffered data before the first idle wait. After a benign
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
}''' + source[end:]
    # A TLS write can consume a peer control record and buffer application data.
    # Signal even on failure; retry policy and the full write budget stay intact.
    start = source.index('fn (mut t H2PooledTransport) write(')
    end = source.index('\n}', start) + 2
    write = source[start:end]
    if write.count('t.conn.set_read_timeout(h2_pooled_io_timeout)') != 2:
        raise RuntimeError('Unsupported HTTP/2 TLS timeout restoration')
    write = write.replace('t.conn.set_read_timeout(h2_pooled_io_timeout)',
                          't.conn.set_read_timeout(t.vox_read_timeout())\n        C.vox_h2_wake_signal(t.vox_wake)')
    source = source[:start] + write + source[end:]
    source = source.replace('t.closed = true\n\tt.conn.shutdown()',
                            't.closed = true\n\tC.vox_h2_wake_close(t.vox_wake)\n\tt.vox_wake = unsafe { nil }\n\tt.conn.shutdown()', 1)
    return source


def patch_h2_mux_read_chunk(source):
    """Reuse one receive chunk per connection instead of one per read attempt.

    The reader thread lives as long as its pooled connection. Each idle wake
    used to allocate a fresh 16 KiB chunk, which a prealloc build never frees.
    """
    field = '\tidle_since          time.Time\n'
    if source.count(field) != 1:
        raise RuntimeError('Unsupported V HTTP/2 connection layout')
    source = source.replace(field, field + '\tvox_read_chunk      []u8\n', 1)
    old = """	for c.rbuf.len < n {
		mut tmp := []u8{len: h2_conn_read_chunk}
		got := c.transport.read(mut tmp)!
		if got <= 0 {
			return error('connection closed by peer')
		}
		c.rbuf << tmp[..got]
	}"""
    if source.count(old) != 1:
        raise RuntimeError('Unsupported V HTTP/2 frame reader')
    new = """	if c.vox_read_chunk.len != h2_conn_read_chunk {
		c.vox_read_chunk = []u8{len: h2_conn_read_chunk}
	}
	for c.rbuf.len < n {
		got := c.transport.read(mut c.vox_read_chunk)!
		if got <= 0 {
			return error('connection closed by peer')
		}
		c.rbuf << c.vox_read_chunk[..got]
	}"""
    return source.replace(old, new, 1)
