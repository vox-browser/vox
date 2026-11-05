module querywire

import os
import sync.stdatomic
import x.json2

const retain_identity_reply_map = os.getenv('VOX_RETAIN_IDENTITY_REPLY_MAP') != ''
const identity_reply_diagnostics = os.getenv('VOX_IDENTITY_REPLY_DIAGNOSTICS') != ''
const max_direct_identity_key_bytes = 256

__global identity_reply_reported stdatomic.AtomicVal[bool]

// Already-hydrated wrappers need only their identity. Keep the ordinary string
// encoder for arbitrary keys, without constructing a one-property JSON map.
pub fn encode_identity_reply(key string) string {
	// Large keys are cheaper to write directly into the map encoder's builder
	// than to copy its encoded string into a second object-sized allocation.
	if retain_identity_reply_map || key.len > max_direct_identity_key_bytes {
		return json2.encode(json2.Any({
			'bridgeKey': json2.Any(key)
		}))
	}
	if identity_reply_diagnostics && identity_reply_reported.compare_and_swap(false, true) {
		eprintln('Vox compact identity reply: direct object encoding')
	}
	encoded_key := json2.encode(key)
	return '{"bridgeKey":' + encoded_key + '}'
}
