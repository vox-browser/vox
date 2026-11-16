module dom

$if test {
	__global direct_collection_walk_disabled_for_test bool
	__global direct_collection_walk_diagnostic_for_test bool
	__global direct_collection_walks_for_test u64
	pub fn set_direct_collection_walk_for_testing(enabled bool) { direct_collection_walk_disabled_for_test = !enabled }
	pub fn diagnose_direct_collection_walk_for_testing(enabled bool) u64 {
		previous := direct_collection_walks_for_test
		direct_collection_walks_for_test = 0
		direct_collection_walk_diagnostic_for_test = enabled
		return previous
	}
}
fn use_direct_collection_walk() bool {
	$if test {
		if direct_collection_walk_disabled_for_test { return false }
		if direct_collection_walk_diagnostic_for_test { direct_collection_walks_for_test++ }
	}
	return true
}

// Match for_each_child/for_each_in_subtree's iteration and callback order while
// passing the result array directly, without creating a capturing adapter.
fn append_collection_elements(root &Node, scope CollectionScope, filter fn(&Element) bool, mut elements []&Element) {
	for child in root.children {
		if element := child.as_element() {
			if filter(element) { elements << element }
		}
		if scope == .descendants { append_collection_elements(child, scope, filter, mut elements) }
	}
}
