module http

struct VoxCreditTransport {
mut:
    writes [][]u8
}

fn (mut transport VoxCreditTransport) read(mut bytes []u8) !int { return error('unused reader') }
fn (mut transport VoxCreditTransport) write(bytes []u8) !int {
    transport.writes << bytes.clone()
    return bytes.len
}

fn vox_credit_frames(transport &VoxCreditTransport) []H2WindowUpdateFrame {
    mut frames := []H2WindowUpdateFrame{}
    for bytes in transport.writes {
        assert bytes.len % 13 == 0
        for offset := 0; offset < bytes.len; offset += 13 {
            header := h2_parse_frame_header(bytes[offset..offset+9]) or { panic(err) }
            frame := h2_parse_frame(header, bytes[offset+9..offset+13]) or { panic(err) }
            if frame is H2WindowUpdateFrame { frames << frame } else { assert false }
        }
    }
    return frames
}

fn test_small_chunks_wait_for_completion_and_credit_every_consumed_byte_once() {
    mut transport := &VoxCreditTransport{}
    mut stream := new_h2_mux_stream()
    mut conn := &H2MuxConn{transport: transport, streams: {u32(1): stream}}
    for index in 0 .. 3 {
        stream.recv_window -= 4096
        conn.conn_recv_window -= 4096
        conn.send_window_updates(1, 4096)!
        assert transport.writes.len == 0
        assert conn.vox_pending_conn_credit == u32((index+1)*4096)
    }
    stream.ended = true
    stream.recv_window -= 100
    conn.conn_recv_window -= 100
    conn.send_window_updates(1, 100)!
    assert transport.writes.len == 1
    frames := vox_credit_frames(transport)
    assert frames.len == 2
    assert frames[0].stream_id == 0 && frames[1].stream_id == 1
    assert frames.all(it.window_size_increment == 12388)
    assert conn.conn_recv_window == i64(h2_default_initial_window)
    assert stream.recv_window == i64(h2_default_initial_window)
    assert conn.vox_pending_conn_credit == 0 && stream.vox_pending_recv_credit == 0
}

fn test_large_active_response_replenishes_before_either_window_runs_out() {
    mut transport := &VoxCreditTransport{}
    mut stream := new_h2_mux_stream()
    mut conn := &H2MuxConn{transport: transport, streams: {u32(1): stream}}
    for _ in 0 .. 16 {
        stream.recv_window -= 2048
        conn.conn_recv_window -= 2048
        conn.send_window_updates(1, 2048)!
    }
    assert transport.writes.len == 1
    assert vox_credit_frames(transport).all(it.window_size_increment == 32768)
    assert conn.conn_recv_window == i64(h2_default_initial_window)
    assert stream.recv_window == i64(h2_default_initial_window)
}

fn test_shared_connection_pressure_flushes_even_a_tiny_consumption() {
    mut transport := &VoxCreditTransport{}
    mut stream := new_h2_mux_stream()
    stream.recv_window -= 100
    // Other streams have used the rest of the shared receive window.
    mut conn := &H2MuxConn{transport: transport, streams: {u32(1): stream}, conn_recv_window: 0}
    conn.send_window_updates(1, 100)!
    frames := vox_credit_frames(transport)
    assert frames.len == 1 && frames[0].stream_id == 0
    assert frames[0].window_size_increment == 100
    assert conn.conn_recv_window == 100
    assert stream.vox_pending_recv_credit == 100
}

fn test_stream_pressure_flushes_without_unnecessarily_writing_connection_credit() {
    mut transport := &VoxCreditTransport{}
    mut stream := new_h2_mux_stream()
    stream.recv_window = 0
    mut conn := &H2MuxConn{transport: transport, streams: {u32(1): stream}}
    conn.conn_recv_window -= 100
    conn.send_window_updates(1, 100)!
    frames := vox_credit_frames(transport)
    assert frames.len == 1 && frames[0].stream_id == 1
    assert frames[0].window_size_increment == 100
    assert stream.recv_window == 100
    assert conn.vox_pending_conn_credit == 100
}

fn test_cancellation_restores_pending_credit_and_leaves_other_streams_usable() {
    mut transport := &VoxCreditTransport{}
    mut stream := new_h2_mux_stream()
    mut conn := &H2MuxConn{transport: transport, streams: {u32(1): stream}}
    conn.conn_recv_window -= 120
    stream.recv_window -= 120
    conn.send_window_updates(1, 100)!
    assert transport.writes.len == 0
    conn.send_conn_window_update(20)!
    frames := vox_credit_frames(transport)
    assert frames.len == 1 && frames[0].stream_id == 0
    assert frames[0].window_size_increment == 120
    assert conn.vox_pending_conn_credit == 0
    assert conn.conn_recv_window == i64(h2_default_initial_window)
}
