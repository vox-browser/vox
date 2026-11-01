module layout

import dom
import html

fn retained_flex_handle(document &dom.Document, id string) &Node {
	element := document.get_element_by_id(id) or { panic('missing element') }
	return unsafe { &Node(element.as_node().unsafe_layout_node() or { panic('missing layout') }.real_layout_handle()) }
}

fn retained_flex_assert_full_layout(mut document dom.Document) {
	before := (document.record_display_list() or { panic('missing paint') }).dump()
	document.set_needs_full_layout_tree_update(true)
	document.update_layout(.debugging)
	assert (document.record_display_list() or { panic('missing rebuilt paint') }).dump() == before
}

fn test_independent_flex_layout_reuses_rows_columns_and_reverse_directions_after_external_movement() {
	for direction in ['row','column','row-reverse','column-reverse'] {
		mut document := html.parse_document('<!doctype html><div id="changed"></div><section id="stable" style="display:flex;flex-direction:${direction};width:180px;gap:7px;align-items:baseline"><div style="flex:1">Several wrapping words.</div><div style="flex:2">Another wrapping item.</div></section>')
		defer { document.finalize() }
		_ = layout_document_typed_in_viewport(document, 400, 400)
		root := retained_flex_handle(document, 'stable')
		key := u64(voidptr(root))
		before := document_layout_result(document) or { panic('missing layout') }
		cache := before.state.block_layouts_[key] or { panic('missing flex cache') }
		old_y := document.get_element_by_id('stable')?.get_bounding_client_rect().y
		mut changed := document.get_element_by_id('changed')?
		changed.set_attribute_value('style', 'height:50px')
		document.update_layout(.debugging)
		after := document_layout_result(document) or { panic('missing current layout') }
		assert voidptr(after.state.block_layouts_[key] or { panic('missing retained flex cache') }) == voidptr(cache)
		assert document.get_element_by_id('stable')?.get_bounding_client_rect().y == old_y + 50
		retained_flex_assert_full_layout(mut document)
	}
}

fn test_retained_flex_descendants_keep_nested_inline_baselines_and_old_paint_immutable() {
	mut document := html.parse_document('<!doctype html><div id="changed"></div><section id="stable" style="overflow:hidden;width:180px"><p>Before <span style="display:inline-flex;align-items:baseline;gap:3px"><span style="font-size:22px">tall<br>last</span><span>small</span></span> after.</p><div style="display:flex;flex-wrap:wrap;gap:7px"><span style="width:70px">First item.</span><span style="width:70px">Second item.</span><span style="width:70px">Third item.</span></div></section>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 400)
	root := retained_flex_handle(document, 'stable')
	key := u64(voidptr(root))
	cache := (document_layout_result(document) or { panic('missing layout') }).state.block_layouts_[key] or { panic('missing nested flex cache') }
	old := document.record_display_list() or { panic('missing paint') }
	scene := retain_display_list_scene(old)
	defer { release_display_list_scene(scene) }
	old_paint_text := old.dump()
	mut changed := document.get_element_by_id('changed')?
	changed.set_attribute_value('style', 'height:50px')
	document.update_layout(.debugging)
	assert voidptr((document_layout_result(document) or { panic('missing current layout') }).state.block_layouts_[key] or { panic('missing retained nested flex cache') }) == voidptr(cache)
	assert old.dump() == old_paint_text
	retained_flex_assert_full_layout(mut document)
}

fn test_retained_flex_layout_rechecks_available_width_and_percentage_height_bases() {
	mut document := html.parse_document('<!doctype html><div id="parent" style="height:200px;width:300px"><section id="stable" style="display:flex;width:80%;height:50%;align-items:stretch"><div style="flex:1"><p style="height:50%">Percentage child.</p></div><div style="flex:2">Wrapping words across the remaining space.</div></section></div>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 400)
	mut parent := document.get_element_by_id('parent')?
	for style in ['height:100px;width:180px','height:300px;width:350px'] {
		parent.set_attribute_value('style', style)
		document.update_layout(.debugging)
		retained_flex_assert_full_layout(mut document)
	}
}

fn test_retained_flex_layout_rechecks_order_alignment_and_descendant_text_changes() {
	mut document := html.parse_document('<!doctype html><section id="stable" style="display:flex;width:180px;gap:7px"><div id="item" style="flex:1">Original text.</div><div style="flex:1">Other item.</div></section>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 400)
	mut item := document.get_element_by_id('item')?
	for style in ['flex:2;order:2;align-self:center','flex:1;order:-1;font-size:22px'] {
		item.set_attribute_value('style', style)
		document.update_layout(.debugging)
		retained_flex_assert_full_layout(mut document)
	}
	item.set_text_content('Different words that change wrapping.')!
	document.update_layout(.debugging)
	retained_flex_assert_full_layout(mut document)
}

fn test_retained_flex_layout_keeps_positioned_subgrid_and_floating_descendants_uncached() {
	for contents in ['<div style="position:absolute;top:10%">absolute</div>',
		'<div style="position:sticky;top:0">sticky</div>',
		'<div style="display:grid;grid-template-columns:subgrid"><span>grid item</span></div>',
		'<div><span style="float:left">float</span> after</div>'] {
		mut document := html.parse_document('<!doctype html><section id="stable" style="display:flex;width:180px">${contents}</section>')
		defer { document.finalize() }
		_ = layout_document_typed_in_viewport(document, 400, 400)
		root := retained_flex_handle(document, 'stable')
		assert u64(voidptr(root)) !in (document_layout_result(document) or { panic('missing layout') }).state.block_layouts_
		retained_flex_assert_full_layout(mut document)
	}
}
