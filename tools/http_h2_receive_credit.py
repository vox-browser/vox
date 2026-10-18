"""Coalesce consumed HTTP/2 receive credit without delaying stream completion."""


def patch_h2_mux_receive_credit(source):
    stream = '\trecv_window i64 = i64(h2_default_initial_window)'
    connection = '\tconn_recv_window i64         = i64(h2_default_initial_window)'
    for field in (stream, connection):
        if source.count(field) != 1:
            raise RuntimeError('Unsupported V HTTP/2 receive-window layout')
    source = source.replace(stream, '\tvox_pending_recv_credit u32\n'
                            '\tvox_force_recv_credit bool\n' + stream, 1)
    source = source.replace(connection, connection + '\n\tvox_pending_conn_credit u32', 1)
    # Padding keeps its existing immediate accounting, including the race
    # between the reader crediting padding and the consumer draining data.
    padding_anchor = '\tif frame.data.len > 0 {\n\t\ts.chunks << frame.data.clone()'
    if source.count(padding_anchor) != 1:
        raise RuntimeError('Unsupported V HTTP/2 DATA delivery layout')
    source = source.replace(padding_anchor,
                            '\tif pad_overhead > 0 { s.vox_force_recv_credit = true }\n'
                            + padding_anchor, 1)
    start = source.index('fn (mut c H2MuxConn) send_window_updates(')
    end = source.index('\n}\n', start) + 2
    source = source[:start] + r'''
fn (mut c H2MuxConn) send_window_updates(stream_id u32, n u32) ! {
    if n == 0 { return }
    // A consumer need not write credit for every small DATA chunk. Keep
    // consumed credit until about half a window has been consumed.
    // Low remaining windows force a flush independently at
    // each level, so many small concurrent streams cannot exhaust the shared
    // connection window while waiting for their individual thresholds.
    threshold := u32(h2_default_initial_window / 2)
    mut stream_increment := u32(0)
    mut force_credit := true
    c.smu.lock()
    if mut s := c.streams[stream_id] {
        s.mu.lock()
        force_credit = s.vox_force_recv_credit || s.err != '' || s.cancelled
        s.vox_pending_recv_credit += n
        if s.ended && !force_credit {
            // A normally completed stream will receive no more DATA. Keep
            // its connection credit, but discard the unnecessary stream ACK.
            s.vox_pending_recv_credit = 0
        } else if force_credit || s.recv_window <= i64(threshold)
            || s.vox_pending_recv_credit >= threshold {
            stream_increment = s.vox_pending_recv_credit
            s.vox_pending_recv_credit = 0
            s.recv_window += i64(stream_increment)
        }
        s.mu.unlock()
    }
    c.smu.unlock()
    mut connection_increment := u32(0)
    c.recv_wmu.lock()
    c.vox_pending_conn_credit += n
    if force_credit || c.conn_recv_window <= i64(threshold)
        || c.vox_pending_conn_credit >= threshold {
        connection_increment = c.vox_pending_conn_credit
        c.vox_pending_conn_credit = 0
        c.conn_recv_window += i64(connection_increment)
    }
    c.recv_wmu.unlock()
    if connection_increment == 0 && stream_increment == 0 { return }
    mut buf := []u8{}
    if connection_increment > 0 {
        buf << H2Frame(H2WindowUpdateFrame{
            stream_id: 0
            window_size_increment: connection_increment
        }).encode()
    }
    if stream_increment > 0 {
        buf << H2Frame(H2WindowUpdateFrame{
            stream_id: stream_id
            window_size_increment: stream_increment
        }).encode()
    }
    c.wmu.lock()
    c.write_all_locked(buf) or {
        c.wmu.unlock()
        c.note_write_failure()
        return err
    }
    c.wmu.unlock()
}''' + source[end:]
    # Cancellation and discarded DATA still restore credit immediately,
    # including any consumption already accumulated on the connection.
    start = source.index('fn (mut c H2MuxConn) send_conn_window_update(')
    end = source.index('\n}\n', start) + 2
    function = source[start:end]
    anchor = '\tc.conn_recv_window += i64(n)'
    if function.count(anchor) != 1:
        raise RuntimeError('Unsupported V HTTP/2 cancellation credit')
    function = function.replace(anchor, '\tincrement := n + c.vox_pending_conn_credit\n'
                                '\tc.vox_pending_conn_credit = 0\n'
                                '\tc.conn_recv_window += i64(increment)', 1)
    function = function.replace('window_size_increment: n', 'window_size_increment: increment', 1)
    return source[:start] + function + source[end:]
