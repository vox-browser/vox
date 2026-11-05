module dom

import platform

fn test_repeated_load_delay_checks_retire_descendant_traversal_storage() {
	mut document := Document.create(url_about_blank())
	mut child_document := Document.create(url_about_blank())
	defer { document.finalize(); child_document.finalize() }
	mut document_node := document.as_node()
	root := document.create_element_ns(namespace_html_uri, 'main')!
	document_node.append_child(root.as_node())!
	mut root_node := root.as_node()
	for _ in 0 .. 192 {
		element := document.create_element_ns(namespace_html_uri, 'span')!
		root_node.append_child(element.as_node())!
	}
	container := document.create_element_ns(namespace_html_uri, 'iframe')!
	root_node.append_child(container.as_node())!
	mut child := &Navigable{container_: container.as_node(), active_document_: child_document}
	child_document.set_navigable(child)
	defer { child.remove_from_all_navigables() }
	assert !document.anything_is_delaying_the_load_event()
	before := platform.thread_arena_usage().used
	mut delayed := false
	for _ in 0 .. 256 {
		delayed = delayed || document.anything_is_delaying_the_load_event()
	}
	assert !delayed
	$if prealloc {
		growth := platform.thread_arena_usage().used - before
		assert growth < 4096, 'load-delay traversal retained ${growth} bytes'
	}
	// Hooks run in the caller's allocation owner: embedders can update retained
	// state while answering a delay query. That state must outlive the query.
	mut container_node := container.as_node()
	container_node.set_load_event_delay_hook(NodeLoadEventDelayHook{
		target: container
		callback: fn (target voidptr) bool {
			mut element := unsafe { &Element(target) }
			element.set_attribute_value('data-load-check', 'retained query result')
			return true
		}
	})
	assert document.anything_is_delaying_the_load_event()
	assert container.get_attribute('data-load-check')? == 'retained query result'
	container_node.set_load_event_delay_hook(none)
	assert !document.anything_is_delaying_the_load_event()
}
