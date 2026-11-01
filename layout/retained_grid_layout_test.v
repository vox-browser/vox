module layout

import dom
import html

fn retained_grid_handle(document &dom.Document, id string) &Node {
	element := document.get_element_by_id(id) or { panic('missing element') }
	return unsafe { &Node(element.as_node().unsafe_layout_node() or { panic('missing layout') }.real_layout_handle()) }
}

fn retained_grid_assert_full_layout(mut document dom.Document) {
	before := (document.record_display_list() or { panic('missing paint') }).dump()
	document.set_needs_full_layout_tree_update(true)
	document.update_layout(.debugging)
	assert (document.record_display_list() or { panic('missing rebuilt paint') }).dump() == before
}

fn test_retained_grid_layout_preserves_tracks_placement_and_baselines_after_movement() {
	for rules in ['grid-template-columns:[start] minmax(0,1fr) [middle] 2fr [end];align-items:baseline',
		'grid-template-columns:repeat(auto-fit,minmax(70px,1fr));gap:7px',
		'grid-template-columns:80px 1fr;grid-auto-flow:row dense;direction:rtl',
		'grid-template-rows:30px 40px;grid-auto-flow:column;grid-auto-columns:80px'] {
		mut document := html.parse_document('<!doctype html><div id="changed"></div><section id="stable" style="display:grid;width:240px;${rules}"><div id="item">Several wrapping words.</div><div style="font-size:22px">Tall item.</div><div>Last item.</div></section>')
		defer { document.finalize() }
		_ = layout_document_typed_in_viewport(document, 400, 400)
		root := retained_grid_handle(document, 'stable')
		key := u64(voidptr(root))
		before := document_layout_result(document) or { panic('missing layout') }
		previous := before.state.block_layouts_[key] or { unsafe { &RetainedBlockLayout(nil) } }
		if !disable_retained_grid_layout { assert previous != unsafe { nil } }
		styled := root.as_node_with_style() or { panic('missing styled grid') }
		values := before.state.get(styled)
		columns := values.grid_template_columns().clone()
		rows := values.grid_template_rows().clone()
		lines := values.grid_column_line_names().clone()
		baseline := layout_box_baseline(before.state, root, .first)
		old_y := document.get_element_by_id('item')?.get_bounding_client_rect().y
		mut changed := document.get_element_by_id('changed')?
		changed.set_attribute_value('style', 'height:50px')
		document.update_layout(.debugging)
		after := document_layout_result(document) or { panic('missing current layout') }
		if !disable_retained_grid_layout {
			assert voidptr(after.state.block_layouts_[key] or { panic('missing reused grid') }) == voidptr(previous)
		}
		actual := after.state.get(styled)
		assert actual.grid_template_columns() == columns
		assert actual.grid_template_rows() == rows
		assert actual.grid_column_line_names() == lines
		assert layout_box_baseline(after.state, root, .first) == baseline
		assert document.get_element_by_id('item')?.get_bounding_client_rect().y == old_y + 50
		retained_grid_assert_full_layout(mut document)
	}
}

fn test_retained_grid_layout_rechecks_available_size_and_percentage_bases() {
	mut document := html.parse_document('<!doctype html><div id="parent" style="width:300px;height:200px"><section id="stable" style="display:grid;width:80%;height:50%;grid-template-columns:1fr 2fr;grid-template-rows:1fr;gap:7px"><div><p style="height:50%">Percentage child.</p></div><div>Wrapping words across the remaining space.</div></section></div>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 400)
	mut parent := document.get_element_by_id('parent')?
	for style in ['height:100px;width:180px', 'height:300px;width:350px'] {
		parent.set_attribute_value('style', style)
		document.update_layout(.debugging)
		retained_grid_assert_full_layout(mut document)
	}
}

fn test_retained_grid_layout_rechecks_text_order_spans_and_tracks() {
	mut document := html.parse_document('<!doctype html><section id="stable" style="display:grid;width:180px;grid-template-columns:1fr 1fr;gap:7px"><div id="item">Original words.</div><div>Other item.</div></section>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 400)
	mut item := document.get_element_by_id('item')?
	for style in ['grid-column:span 2;order:2', 'grid-column:1;order:-1;font-size:22px'] {
		item.set_attribute_value('style', style)
		document.update_layout(.debugging)
		retained_grid_assert_full_layout(mut document)
	}
	item.set_text_content('Different words that change wrapping across tracks.')!
	document.update_layout(.debugging)
	retained_grid_assert_full_layout(mut document)
	mut root := document.get_element_by_id('stable')?
	root.set_attribute_value('style', 'display:grid;width:180px;grid-template-columns:2fr 1fr;gap:3px')
	document.update_layout(.debugging)
	retained_grid_assert_full_layout(mut document)
}

fn test_retained_grid_layout_keeps_nested_tracks_and_old_paint_immutable() {
	for outer in ['display:flex', 'overflow:hidden'] {
		mut document := html.parse_document('<!doctype html><div id="changed"></div><section id="stable" style="${outer};width:180px"><div style="display:grid;grid-template-columns:1fr 1fr;gap:7px"><div style="display:grid;grid-template-columns:1fr"><span>Nested words.</span></div><span>Other words.</span></div></section>')
		defer { document.finalize() }
		_ = layout_document_typed_in_viewport(document, 400, 400)
		old := document.record_display_list() or { panic('missing paint') }
		scene := retain_display_list_scene(old)
		defer { release_display_list_scene(scene) }
		old_text := old.dump()
		mut changed := document.get_element_by_id('changed')?
		changed.set_attribute_value('style', 'height:50px')
		document.update_layout(.debugging)
		assert old.dump() == old_text
		retained_grid_assert_full_layout(mut document)
	}
}

fn test_retained_grid_layout_keeps_subgrid_and_positioned_descendants_on_full_path() {
	for contents in ['<div style="display:grid;grid-template-columns:subgrid">subgrid</div>',
		'<div style="display:grid;grid-template-rows:subgrid">subgrid</div>',
		'<div style="position:absolute;top:10%">absolute</div>',
		'<div style="position:sticky;top:0">sticky</div>',
		'<div><span style="float:left">float</span> after</div>'] {
		mut document := html.parse_document('<!doctype html><section id="stable" style="display:grid;width:180px;grid-template-columns:1fr 1fr">${contents}</section>')
		defer { document.finalize() }
		_ = layout_document_typed_in_viewport(document, 400, 400)
		root := retained_grid_handle(document, 'stable')
		assert u64(voidptr(root)) !in (document_layout_result(document) or { panic('missing layout') }).state.block_layouts_
		retained_grid_assert_full_layout(mut document)
	}
}

fn test_retained_grid_track_vectors_detach_from_cached_and_previous_layouts() {
	mut document := html.parse_document('<!doctype html><div id="changed"></div><section id="stable" style="display:grid;width:180px;grid-template-columns:[start] 1fr [middle] 2fr [end]"><div>First item.</div><div>Second item.</div></section>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 400)
	root := retained_grid_handle(document, 'stable')
	styled := root.as_node_with_style() or { panic('missing styled grid') }
	before := document_layout_result(document) or { panic('missing layout') }
	expected := before.state.get(styled).grid_template_columns().clone()
	mut changed := document.get_element_by_id('changed')?
	changed.set_attribute_value('style', 'height:30px')
	document.update_layout(.debugging)
	after := document_layout_result(document) or { panic('missing current layout') }
	mut columns := after.state.get(styled).grid_template_columns()
	columns[0] = CSSPixels.new(12345)
	assert before.state.get(styled).grid_template_columns() == expected
	if !disable_retained_grid_layout {
		cached := after.state.block_layouts_[u64(voidptr(root))] or { panic('missing cache') }
		rare := cached.grid_container_rare or { panic('missing retained tracks') }
		assert rare.used_grid_template_columns == expected
	}
	changed.set_attribute_value('style', 'height:60px')
	document.update_layout(.debugging)
	current := document_layout_result(document) or { panic('missing final layout') }
	assert current.state.get(styled).grid_template_columns() == expected
	retained_grid_assert_full_layout(mut document)
}
