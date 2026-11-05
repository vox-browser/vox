module querywire

import os
import sync.stdatomic
import x.json2

const retain_document_reply_map = os.getenv('VOX_RETAIN_DOCUMENT_REPLY_MAP') != ''
const document_reply_diagnostics = os.getenv('VOX_DOCUMENT_REPLY_DIAGNOSTICS') != ''
const max_direct_document_key_bytes = 256
__global document_reply_reported stdatomic.AtomicVal[bool]

// The document envelope contains only its bridge identity and fixed node-kind
// fields. Keep arbitrary-key escaping on the ordinary string encoder, and the
// original map path for large keys. No document or owner is cached here.
pub fn encode_document_reply(key string) string {
	if key.len > max_direct_document_key_bytes || retain_document_reply_map {
		return json2.encode(json2.Any({
			'bridgeKey': json2.Any(key)
			'nodeType': json2.Any(9)
			'nodeName': json2.Any('#document')
			'tagName': json2.Any('#node')
		}))
	}
	if document_reply_diagnostics && document_reply_reported.compare_and_swap(false, true) {
		eprintln('Vox document identity reply: encoded fixed node metadata without a map')
	}
	if key.len == 0 {
		return '{"bridgeKey":"","nodeName":"#document","nodeType":9,"tagName":"#node"}'
	}
	return '{"bridgeKey":' + json2.encode(key)
		+ ',"nodeName":"#document","nodeType":9,"tagName":"#node"}'
}
