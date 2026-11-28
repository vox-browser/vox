module main

import browserjs.querywire
import dom
import platform
import x.json2

fn (mut binding CompactElementQueryBinding) encode_element_state(element &dom.Element) string {
	key := binding.element_key(element)
	materialized := binding.materialized[key]
	if !materialized { binding.materialized[key] = true }
	mut reply := platform.ThreadScratchScope{}
	$if prealloc {
		if binding.temporary_reply_enabled {
			// Identity and lazily created control models belong to the document.
			// Only the response graph and its encoded bytes go into the reply.
			if !materialized { prepare_compact_element_serialization(element) }
			reply = platform.begin_thread_scratch('compact element reply')
			binding.reply_workspace = reply
		}
	}
	defer { reply.leave() }
	return if materialized {
		querywire.encode_identity_reply(key)
	} else {
		json2.encode(binding.initial_element_state(element, key))
	}
}

fn (mut binding CompactElementQueryBinding) encode_node_state(node &dom.Node) string {
	if node.is_document() { return binding.encode_document_state(node.document()) }
	if element := node.as_element() { return binding.encode_element_state(element) }
	return json2.encode(binding.node_state(node))
}
