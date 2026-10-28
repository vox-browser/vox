module main

import adblock
import json2

$if prealloc {
	import platform
}

fn decode_browser_cached_response_headers(encoded string) ![]adblock.ResponseHeader {
	$if prealloc {
		scratch := platform.begin_thread_scratch('cached response header decoding')
		parsed := parse_browser_cached_response_headers(encoded) or {
			code := err.code()
			scratch.leave()
			message := err.msg().clone()
			scratch.finish()
			return error_with_code(message, code)
		}
		scratch.leave()
		mut headers := []adblock.ResponseHeader{cap:parsed.len}
		for header in parsed {
			headers << adblock.ResponseHeader{name:header.name.clone(), value:header.value.clone()}
		}
		scratch.finish()
		return headers
	}
	return parse_browser_cached_response_headers(encoded)
}

fn parse_browser_cached_response_headers(encoded string) ![]adblock.ResponseHeader {
	// json2's generic struct decoder lazily publishes a mutable static field
	// array, which concurrent first cache reads can observe before it is
	// populated. Decoding to Any has no struct metadata; read the two fields
	// from it.
	value := json2.decode[json2.Any](encoded)!
	if value !is []json2.Any {
		return error('cached response headers are not an array')
	}
	items := value as []json2.Any
	mut headers := []adblock.ResponseHeader{cap: items.len}
	for item in items {
		if item !is map[string]json2.Any {
			return error('cached response header is not an object')
		}
		fields := item as map[string]json2.Any
		name := fields['name'] or { return error('cached response header has no name') }
		header_value := fields['value'] or { return error('cached response header has no value') }
		if name !is string || header_value !is string {
			return error('cached response header fields are not strings')
		}
		headers << adblock.ResponseHeader{
			name:  name as string
			value: header_value as string
		}
	}
	return headers
}
