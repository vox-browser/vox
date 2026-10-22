module dom

import platform

fn test_full_style_attribute_invalidation_does_not_build_attribute_deltas() {
	mut document := Document.create(url_about_blank())
	mut element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic(err) }
	document.set_needs_full_style_update(true)
	old := ?string('old classes with several words')
	new := ?string('new classes with other words')
	before := platform.thread_arena_usage().used
	for _ in 0 .. 1024 {
		element.invalidate_style_after_attribute_change('class', old, new)
		element.invalidate_style_after_attribute_change('id', old, new)
		element.invalidate_style_after_attribute_change('data-removed', old, none)
		schedule_has_invalidation_for_inherited_attribute_change(element, 'lang')
		schedule_has_invalidation_for_inherited_attribute_change(element, 'dir')
	}
	after := platform.thread_arena_usage().used
	assert element.as_node().needs_style_update()
	assert element.removed_attribute_names_for_style_invalidation().len == 0
	$if prealloc { assert after == before }
	document.finalize()
}
