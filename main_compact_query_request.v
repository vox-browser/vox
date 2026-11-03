module main

import platform
import x.json2

struct CompactElementQueryRequest {
	selector ?string
	action ?string
	key string
	snapshot ?string
	log_count int
	workspace platform.ThreadScratchScope
}

// Identity and operation strings can reach persistent DOM records. The pending
// snapshot is transport consumed synchronously by replay, so borrow it until
// the query finishes instead of retaining another document-sized string.
fn decode_compact_element_query_request(input string) !CompactElementQueryRequest {
	mut work := platform.begin_thread_scratch('compact query request')
	request := json2.decode[map[string]json2.Any](input) or {
		work.leave()
		message := err.msg().clone()
		work.finish()
		return error(message)
	}
	selector := json_string_property(request, 'selector')
	action := json_string_property(request, 'action')
	key := json_string_property(request, 'key') or { '' }
	snapshot := json_string_property(request, 'snapshot')
	log_count := json_int_property(request, 'logCount') or { 0 }
	work.leave()
	result := CompactElementQueryRequest{
		selector: if value := selector { ?string(value.clone()) } else { none }
		action: if value := action { ?string(value.clone()) } else { none }
		key: key.clone()
		snapshot: snapshot
		log_count: log_count
		workspace: work
	}
	return result
}
