module cachepolicy

import json2
import platform

// Cache publication encodes response headers and timing records inside a
// thread scratch scope that is freed immediately afterwards. json2 publishes
// each struct's field table in a process-wide static on first use, so module
// init must have built these tables before the first publication.
fn test_disk_record_json_tables_survive_release_of_the_first_encoding_scope() {
	headers := [Header{
		name:  'Content-Type'
		value: 'text/html'
	}]
	record := DiskTimingRecord{
		integrity:     'abc'
		request_time:  '1'
		response_time: '2'
	}
	mut scratch := platform.new_arena('released cache publication')
	entry := scratch.enter()
	first_headers := json2.encode(headers, escape_unicode: true)
	first_record := json2.encode(record)
	scratch.leave(entry)
	encoded_headers := first_headers.clone()
	encoded_record := first_record.clone()
	scratch.release()
	for _ in 0 .. 4 {
		work := platform.begin_thread_scratch('cache metadata overwrite')
		_ = []u8{len: 256 * 1024, init: u8(0xa5)}
		work.finish()
	}
	assert json2.encode(headers, escape_unicode: true) == encoded_headers
	assert json2.encode(record) == encoded_record
	assert encoded_headers.contains('"name":"Content-Type"')
	assert encoded_record.contains('"integrity":"abc"')
}
