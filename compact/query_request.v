module main

import platform
import browserjs.querywire
import os
import x.json2

const disable_compact_query_envelope = os.getenv('VOX_DISABLE_COMPACT_QUERY_ENVELOPE') != ''
const compact_query_envelope_diagnostics = os.getenv('VOX_COMPACT_QUERY_ENVELOPE_DIAGNOSTICS') != ''

__global compact_query_envelope_reported bool

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
	if !disable_compact_query_envelope {
		if envelope := querywire.parse_compact_envelope(input) {
			if compact_query_envelope_diagnostics && !compact_query_envelope_reported {
				compact_query_envelope_reported = true
				eprintln('Vox compact query decoder: direct ASCII envelope')
			}
			return CompactElementQueryRequest{
				key: envelope.key
				action: envelope.action
				selector: envelope.selector
			}
		}
	}
	mut work := platform.begin_thread_scratch('compact query request')
	request := json2.decode[map[string]json2.Any](compact_replay_json_text(input)) or {
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
