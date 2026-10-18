module layout

import html

fn test_retained_flow_never_keeps_a_layout_document_from_before_adoption() {
	mut source :=
		html.parse_document('<!doctype html><div id="moving"><section id="nested"><p>adopted comment</p></section></div>')
	mut target := html.parse_document('<!doctype html><main id="target"></main>')
	_ = layout_document_typed_in_viewport(source, 400, 300)
	_ = layout_document_typed_in_viewport(target, 400, 300)
	moving := source.get_element_by_id('moving')?
	nested := source.get_element_by_id('nested')?
	old_handle := nested.as_node().unsafe_layout_node()?.real_layout_handle()
	mut parent := target.get_element_by_id('target')?.as_node()
	parent.append_child(moving.as_node())!
	target.update_layout(.debugging)
	current := nested.as_node().unsafe_layout_node()?.real_layout_handle()
	assert current != old_handle
	assert voidptr(unsafe { &Node(current) }.document()) == voidptr(target)
	paint := (target.record_display_list()?).dump()
	target.set_needs_full_layout_tree_update(true)
	target.update_layout(.debugging)
	assert (target.record_display_list()?).dump() == paint
}
