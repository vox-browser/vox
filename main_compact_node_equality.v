module main

import dom
import x.json2

fn (mut binding CompactElementQueryBinding) equality_node(key string, state json2.Any) !&dom.Node {
	if key == '' { return binding.document.as_node() }
	if node := binding.node_for_key(key) { return node }
	// A compact-created owner (for example new Image) need not be connected
	// before comparison. Materialize it through the existing retained-node path.
	return binding.materialize_shadow_host(key, state)
}

fn (mut binding CompactElementQueryBinding) equal_node_query(key string, input string) !string {
	request := json2.decode[map[string]json2.Any](input)!
	other_key := json_string_property(request, 'otherKey') or { return error('TypeError: Expected a Node') }
	root := binding.equality_node(key, request['ownState'] or { json2.Any(json2.Null{}) })!
	other := binding.equality_node(other_key, request['otherState'] or { json2.Any(json2.Null{}) })!
	// query() has replayed pending writes before consulting either live tree.
	return json2.encode(root.is_equal_node(other))
}
