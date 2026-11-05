// Same-executable component comparison for document identity replies. Read keys
// from a manifest so compilation cannot specialize loops to literal root keys.
module main

import browserjs.querywire
import os
import platform
import processmetrics
import x.json2

struct DocumentReplyCase {
	name string
	keys []string
	iterations int
}

fn original_document_reply(key string) string {
	return json2.encode(json2.Any({
		'bridgeKey': json2.Any(key)
		'nodeType': json2.Any(9)
		'nodeName': json2.Any('#document')
		'tagName': json2.Any('#node')
	}))
}

fn main() {
	if os.args.len != 2 { panic('expected a document-reply case manifest') }
	cases := json2.decode[[]DocumentReplyCase](os.read_file(os.args[1]) or { panic(err) }) or { panic(err) }
	for entry in cases {
		assert entry.keys.len > 0 && entry.iterations > 0 && entry.iterations % 100 == 0
		expected := entry.keys.map(original_document_reply(it))
		mut expected_checksum := u64(0)
		for index in 0 .. entry.iterations { expected_checksum += u64(expected[index % expected.len].len) }
		mut checksum := u64(0)
		before := processmetrics.instruction_snapshot()
		for batch in 0 .. entry.iterations / 100 {
			work := platform.begin_thread_scratch('document reply batch')
			for offset in 0 .. 100 {
				index := (batch * 100 + offset) % entry.keys.len
				actual := querywire.encode_document_reply(entry.keys[index])
				assert actual == expected[index]
				checksum += u64(actual.len)
			}
			work.finish()
		}
		instructions := processmetrics.instruction_snapshot().since(before) or {
			panic('instruction counter unavailable')
		}
		assert checksum == expected_checksum
		println(json2.encode({
			'scene': json2.Any(entry.name)
			'instructions': json2.Any(instructions)
			'iterations': json2.Any(entry.iterations)
			'checksum': json2.Any(checksum)
		}))
	}
}
