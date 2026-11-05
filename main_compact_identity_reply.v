module main

import browserjs.querywire
import dom
import x.json2

fn (mut binding CompactElementQueryBinding) encode_element_state(element &dom.Element) string {
	key := binding.element_key(element)
	if binding.materialized[key] { return querywire.encode_identity_reply(key) }
	binding.materialized[key] = true
	return json2.encode(binding.initial_element_state(element, key))
}

fn (mut binding CompactElementQueryBinding) encode_node_state(node &dom.Node) string {
	if element := node.as_element() { return binding.encode_element_state(element) }
	return json2.encode(binding.node_state(node))
}
