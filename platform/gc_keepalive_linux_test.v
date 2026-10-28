module platform

fn test_linux_boehm_keepalive_survives_collection() {
	$if gcboehm ? {
		values := []u8{len: 4096, init: u8(index % 251)}
		gc_collect()
		for index, value in values {
			assert value == u8(index % 251)
		}
		C.GC_reachable_here(values.data)
	}
}
