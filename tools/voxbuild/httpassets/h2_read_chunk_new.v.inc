	if c.vox_read_chunk.len != h2_conn_read_chunk {
		c.vox_read_chunk = []u8{len: h2_conn_read_chunk}
	}
	for c.rbuf.len < n {
		got := c.transport.read(mut c.vox_read_chunk)!
		if got <= 0 {
			return error('connection closed by peer')
		}
		c.rbuf << c.vox_read_chunk[..got]
	}