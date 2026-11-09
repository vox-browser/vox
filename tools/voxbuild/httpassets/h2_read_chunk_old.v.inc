	for c.rbuf.len < n {
		mut tmp := []u8{len: h2_conn_read_chunk}
		got := c.transport.read(mut tmp)!
		if got <= 0 {
			return error('connection closed by peer')
		}
		c.rbuf << tmp[..got]
	}