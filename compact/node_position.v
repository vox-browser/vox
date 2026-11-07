module main

import x.json2

fn (mut binding CompactElementQueryBinding) node_position_query(key string, input string) !string {
	request := json2.decode[map[string]json2.Any](input)!
	other_key := json_string_property(request, 'otherKey') or { return error('TypeError: Expected a Node') }
	root := binding.equality_node(key, request['ownState'] or { json2.Any(json2.Null{}) })!
	other := binding.equality_node(other_key, request['otherState'] or { json2.Any(json2.Null{}) })!
	return json2.encode(root.compare_document_position(other))
}
