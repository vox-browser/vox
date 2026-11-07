module main

import x.json2

fn (mut binding CompactElementQueryBinding) replace_child_query(key string, source string) !string {
	request := json2.decode[map[string]json2.Any](source)!
	own := request['own'] or { return error('TypeError: Expected a Node') }
	replacement := request['replacement'] or { return error('TypeError: Expected a Node') }
	child := request['child'] or { return error('TypeError: Expected a Node') }
	if own !is map[string]json2.Any || replacement !is map[string]json2.Any || child !is map[string]json2.Any {
		return error('TypeError: Expected a Node')
	}
	parent_key := json_string_property(own as map[string]json2.Any, 'bridgeKey') or { return error('TypeError: Expected a Node') }
	if parent_key != key { return error('TypeError: Invalid Node receiver') }
	replacement_key := json_string_property(replacement as map[string]json2.Any, 'bridgeKey') or { return error('TypeError: Expected a Node') }
	child_key := json_string_property(child as map[string]json2.Any, 'bridgeKey') or { return error('TypeError: Expected a Node') }
	mut parent := binding.equality_node(key, own)!
	node := binding.equality_node(replacement_key, replacement)!
	old := binding.equality_node(child_key, child)!
	connected := parent.is_connected() || node.is_connected()
	parent.replace_child(node, old)!
	if connected { binding.note_node_tree_mutation() }
	return 'null'
}
