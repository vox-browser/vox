module main

import adblock
import json

fn decode_browser_cached_response_headers(encoded string) ![]adblock.ResponseHeader {
	// x.json2's generic struct decoder lazily publishes a mutable static field
	// array. Concurrent first cache reads can observe that array before it is
	// populated. The generated JSON decoder has no shared initialization state.
	return json.decode([]adblock.ResponseHeader, encoded)
}
