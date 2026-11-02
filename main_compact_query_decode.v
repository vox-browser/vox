module main

import json2
import platform
import sync.stdatomic

fn compact_decode_query[T](source string) !T {
	$if prealloc {
		static metadata_ready := u64(0)
		if stdatomic.load_u64(&metadata_ready) == 0 {
			initialize_compact_query_metadata[T]()
			stdatomic.store_u64(&metadata_ready, 1)
		}
	}
	return json2.decode[T](source)!
}

fn initialize_compact_query_metadata[T]() {
	// json2 keeps each struct's field metadata for the process lifetime. The
	// first query can arrive inside a document arena that navigation releases.
	// Warm only that immutable metadata in base storage; real request strings
	// still belong to the caller's current allocation scope. Compact query
	// records contain scalar fields and untyped JSON containers.
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	if _ := json2.decode[T]('{}') {}
}
