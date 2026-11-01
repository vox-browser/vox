module layout

import html
import dom

fn flow_item_handle(element_id string, document &dom.Document) voidptr {
	element := document.get_element_by_id(element_id) or { panic(element_id) }
	mirror := element.as_node().unsafe_layout_node() or { panic('missing item layout') }
	return mirror.real_layout_handle()
}

fn test_retained_flow_items_rewrap_in_new_grid_tracks_and_flex_sizes() {
	for mode in ['grid;grid-template-columns:1fr 1fr', 'flex'] {
		mut document := html.parse_document('<!doctype html><style>body{margin:0}#parent{display:${mode};width:500px}article{min-width:0;flex:1}</style><div id="changed"></div><section id="parent"><article id="stable"><p>Unchanged text needs to wrap when its formatting parent becomes much narrower.</p></article><article>Other item</article></section>')
		defer { document.finalize() }
		_ = layout_document_typed_in_viewport(document, 600, 400)
		stable := document.get_element_by_id('stable') or { panic('stable') }
		before := flow_item_handle('stable', document)
		old_height := stable.get_bounding_client_rect().height
		previous_paint := document.record_display_list() or { panic('old paint') }
		previous_scene := retain_display_list_scene(previous_paint)
		defer { release_display_list_scene(previous_scene) }
		previous_dump := previous_paint.dump()
		mut changed := document.get_element_by_id('changed') or { panic('changed') }
		changed.set_inner_html('<p>New preceding content</p>')!
		mut parent := document.get_element_by_id('parent') or { panic('parent') }
		parent.set_attribute_value('style', 'width:150px')
		document.update_layout(.debugging)
		assert (flow_item_handle('stable', document) == before) == !disable_retained_flow_items
		assert stable.get_bounding_client_rect().height > old_height
		assert previous_paint.dump() == previous_dump
		current_dump := (document.record_display_list() or { panic('new paint') }).dump()
		document.set_needs_full_layout_tree_update(true)
		document.update_layout(.debugging)
		assert (document.record_display_list() or { panic('full paint') }).dump() == current_dump
	}
}

fn test_retained_flow_items_rebuild_after_parent_role_and_text_changes() {
	mut document := html.parse_document('<!doctype html><style>#parent{display:grid;grid-template-columns:1fr 1fr;width:300px}</style><div id="changed"></div><section id="parent"><article id="stable"><p id="label">Original text</p></article><article>Other item</article></section>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	mut parent := document.get_element_by_id('parent') or { panic('parent') }
	mut label := document.get_element_by_id('label') or { panic('label') }
	for style in ['display:flex', 'display:block', 'display:grid'] {
		before := flow_item_handle('stable', document)
		parent.set_attribute_value('style', style)
		label.set_inner_html('<strong>Changed text</strong>')!
		document.update_layout(.debugging)
		assert flow_item_handle('stable', document) != before
		current_dump := (document.record_display_list() or { panic('changed paint') }).dump()
		document.set_needs_full_layout_tree_update(true)
		document.update_layout(.debugging)
		assert (document.record_display_list() or { panic('full paint') }).dump() == current_dump
	}
}

fn test_retained_flow_items_drop_old_roles_when_only_the_parent_display_changes() {
	mut document := html.parse_document('<!doctype html><style>#parent{display:grid;grid-template-columns:1fr 1fr;width:300px}</style><section id="parent"><article id="stable"><p>Unchanged item text</p></article><article>Other item</article></section>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	mut parent := document.get_element_by_id('parent') or { panic('parent') }
	for style in ['flex', 'block', 'grid', 'flex'] {
		parent.set_attribute_value('style', 'display:${style}')
		document.update_layout(.debugging)
		item := unsafe { &Node(flow_item_handle('stable', document)) }
		assert item.is_flex_item() == (style == 'flex')
		assert item.is_grid_item_ == (style == 'grid')
		current_dump := (document.record_display_list() or { panic('role paint') }).dump()
		document.set_needs_full_layout_tree_update(true)
		document.update_layout(.debugging)
		assert (document.record_display_list() or { panic('full paint') }).dump() == current_dump
	}
}
