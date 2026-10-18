module layout

import html

fn test_retained_independent_flow_reuses_descendants_after_preceding_comment_changes() {
	mut document := html.parse_document('<!doctype html><div id="changed"></div><section id="stable" style="overflow:hidden;width:180px"><div><p>Several <strong>unchanged words</strong> wrap onto lines in an independent comment.</p></div><p>Second paragraph.</p></section>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	root := retained_inline_handle(document, 'stable')
	before := document_layout_result(document)?
	cache := before.state.block_layouts_[u64(voidptr(root))] or { panic('uncached BFC') }
	old_list := document.record_display_list()?
	old_commands := display_list_commands(old_list).clone()
	mut old_values := map[u64]&UsedValues{}
	for entry in cache.values { old_values[u64(voidptr(entry.node))] = before.state.try_get(entry.node)? }
	old_rect := document.get_element_by_id('stable')?.get_bounding_client_rect()
	mut changed := document.get_element_by_id('changed')?
	changed.set_inner_html('<p>Expanded preceding comment</p>')!
	document.update_layout(.debugging)
	after := document_layout_result(document)?
	assert voidptr(after.state.block_layouts_[u64(voidptr(root))]) == voidptr(cache)
	assert after.state.previous_block_layouts_.len == 0
	new_rect := document.get_element_by_id('stable')?.get_bounding_client_rect()
	assert new_rect.y > old_rect.y && new_rect.height == old_rect.height
	for entry in cache.values {
		used := after.state.try_get(entry.node)?
		if containing := entry.containing {
			assert voidptr(used.containing_block_used_values_?) == voidptr(after.state.try_get(containing)?)
		}
		old_used := old_values[u64(voidptr(entry.node))] or { panic('missing old values') }
		if old_used.line_boxes.len > 0 {
			assert used.line_boxes.data != old_used.line_boxes.data
			assert used.line_boxes[0].fragments_.data != old_used.line_boxes[0].fragments_.data
		}
	}
	assert old_commands.len > 0
	assert display_list_commands(old_list).clone() == old_commands
	retained_inline_assert_full_layout(mut document)
}

fn test_retained_independent_flow_rechecks_width_height_inherited_style_and_content() {
	mut document := html.parse_document('<!doctype html><div id="parent" style="width:250px"><section id="stable" style="overflow:hidden;height:120px"><p style="width:70%;height:50%">Several <strong id="text">unchanged words</strong> wrap to lines.</p></section></div><div id="changed"></div>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	mut parent := document.get_element_by_id('parent')?
	for style in ['width:120px', 'width:120px;font-size:22px;color:red', 'width:280px'] {
		parent.set_attribute_value('style', style)
		document.update_layout(.debugging)
		retained_inline_assert_full_layout(mut document)
	}
	mut stable := document.get_element_by_id('stable')?
	stable.set_attribute_value('style', 'overflow:hidden;height:200px')
	document.update_layout(.debugging)
	retained_inline_assert_full_layout(mut document)
	mut text := document.get_element_by_id('text')?
	text.set_inner_html('Different text with more words')!
	document.update_layout(.debugging)
	retained_inline_assert_full_layout(mut document)
}

fn test_retained_independent_flow_leaves_specialized_layout_and_float_dependencies_uncached() {
	for contents in [
		'<div style="float:left;width:60px;height:80px"></div><p>Float intrusion changes lines.</p>',
		'<p>Text <span style="position:relative;top:3px">shifted</span></p>',
		'<ol><li>Marker</li></ol>',
		'<p style="max-lines:1;continue:discard">Text that may be clamped to one line.</p>',
		'<div style="display:grid"><p>Grid</p></div>',
	] {
		mut document := html.parse_document('<!doctype html><div id="changed"></div><section id="stable" style="overflow:hidden;width:180px">' + contents + '</section>')
		defer { document.finalize() }
		_ = layout_document_typed_in_viewport(document, 400, 300)
		root := retained_inline_handle(document, 'stable')
		assert u64(voidptr(root)) !in document_layout_result(document)?.state.block_layouts_
		mut changed := document.get_element_by_id('changed')?
		changed.set_inner_html('<p>Expanded preceding comment</p>')!
		document.update_layout(.debugging)
		retained_inline_assert_full_layout(mut document)
	}
}

fn test_retained_independent_flow_keeps_atomic_action_menu_geometry_and_intrinsic_sizes() {
	mut document := html.parse_document('<!doctype html><div id="changed"></div><section id="stable" style="overflow:hidden;width:180px"><p>Comment body with wrapping text.</p><ul style="padding:0"><li style="display:inline"><span id="action" style="display:inline-block;max-width:80%">A wrapping action label</span></li><li style="display:inline"><a style="display:inline-block">reply</a></li></ul></section>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	root := retained_inline_handle(document, 'stable')
	cache := document_layout_result(document)?.state.block_layouts_[u64(voidptr(root))] or { panic('uncached action menu') }
	mut changed := document.get_element_by_id('changed')?
	changed.set_inner_html('<p>Expanded preceding comment</p>')!
	document.update_layout(.debugging)
	assert voidptr(document_layout_result(document)?.state.block_layouts_[u64(voidptr(root))]) == voidptr(cache)
	retained_inline_assert_full_layout(mut document)
	mut action := document.get_element_by_id('action')?
	for style in ['display:inline-block;width:40%', 'display:inline-block;font-size:22px;max-width:60%'] {
		action.set_attribute_value('style', style)
		document.update_layout(.debugging)
		retained_inline_assert_full_layout(mut document)
	}
}

fn test_retained_independent_flow_observes_changed_available_space_without_tree_rebuilding() {
	mut document := html.parse_document('<!doctype html><section id="stable" style="overflow:hidden;width:75%"><p>Text that changes wrapping as the viewport changes size.</p></section>')
	defer { document.finalize() }
	for width in [400.0, 200.0, 600.0, 400.0] {
		_ = layout_document_typed_in_viewport(document, width, 300)
		retained_inline_assert_full_layout(mut document)
	}
}
