
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
}