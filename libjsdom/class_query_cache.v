module libjsdom

import dom
import platform

const class_query_cache_limit = 256

struct ClassQueryCacheEntry {
	root &dom.Node
	document &dom.Document
	quirks bool
	query string
	collection &dom.HTMLCollection
}

$if test {
	__global class_query_cache_disabled_for_test bool
	__global class_query_cache_diagnostic_for_test bool
	__global class_query_cache_hits_for_test u64
	pub fn set_class_query_cache_for_testing(enabled bool) { class_query_cache_disabled_for_test = !enabled }
	pub fn diagnose_class_query_cache_for_testing(enabled bool) u64 {
		previous := class_query_cache_hits_for_test
		class_query_cache_hits_for_test = 0
		class_query_cache_diagnostic_for_test = enabled
		return previous
	}
}

// DOM's list-of-elements-with-class-names permits reusing the collection for
// the same argument. Retain the native live collection, never a result snapshot.
fn (mut host Host) class_collection(root &dom.Node, query string) &dom.HTMLCollection {
	mut parent := unsafe { &dom.ParentNode(root) }
	$if test { if class_query_cache_disabled_for_test { return parent.get_elements_by_class_name(query) } }
	if query.len > 128 { return parent.get_elements_by_class_name(query) }
	document := root.document()
	quirks := document.in_quirks_mode()
	mut hash := u64(14695981039346656037) ^ u64(uint(root))
	for byte in query { hash = (hash ^ u64(byte)) * 1099511628211 }
	if entry := host.class_query_cache[hash] {
		if voidptr(entry.root) == voidptr(root) && voidptr(entry.document) == voidptr(document)
			&& entry.quirks == quirks && entry.query == query {
			$if test { if class_query_cache_diagnostic_for_test { class_query_cache_hits_for_test++ } }
			return entry.collection
		}
	}
	// Both the captured filter strings and the retained cache live across
	// transient browser tasks. Own their bytes before constructing the filter.
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	retained := query.clone()
	collection := parent.get_elements_by_class_name(retained)
	if host.class_query_cache.len >= class_query_cache_limit { host.class_query_cache.clear() }
	host.class_query_cache[hash] = ClassQueryCacheEntry{root, document, quirks, retained, collection}
	return collection
}
