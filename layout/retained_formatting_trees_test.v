module layout

import dom
import html

fn formatting_tree_handle(document &dom.Document, id string) &Node {
	element := document.get_element_by_id(id) or { panic(id) }
	return unsafe { &Node(element.as_node().unsafe_layout_node() or { panic('missing layout') }.real_layout_handle()) }
}

fn formatting_tree_full_paint_check(mut document dom.Document) {
	expected_dump := (document.record_display_list() or { panic('paint') }).dump()
	document.set_needs_full_layout_tree_update(true)
	document.update_layout(.debugging)
	assert (document.record_display_list() or { panic('rebuilt paint') }).dump() == expected_dump
}

fn test_clean_block_grid_and_flex_trees_retain_their_nodes_after_unrelated_mutations() {
	for mode in ['grid;grid-template-columns:1fr 1fr', 'flex;flex-wrap:wrap'] {
		mut document := html.parse_document('<!doctype html><style>body{margin:0}#stable{display:${mode};width:240px;gap:7px}article{min-width:0;flex:1}</style><div id="changed"></div><section id="stable"><article><p>Several unchanged words wrap into multiple lines.</p></article><article><p>Other unchanged content.</p></article></section>')
		defer { document.finalize() }
		_ = layout_document_typed_in_viewport(document, 400, 300)
		mut changed := document.get_element_by_id('changed')?
		stable := document.get_element_by_id('stable')?
		for index in 0 .. 3 {
			before := formatting_tree_handle(document, 'stable')
			children := before.child_count()
			old_rect := stable.get_bounding_client_rect()
			old_paint := document.record_display_list()?
			old_scene := retain_display_list_scene(old_paint)
			old_dump := old_paint.dump()
			changed.set_inner_html('<p>' + 'Preceding changed content. '.repeat(index + 1) + '</p>')!
			document.update_layout(.debugging)
			after := formatting_tree_handle(document, 'stable')
			assert (voidptr(after) == voidptr(before)) == !disable_retained_formatting_trees
			assert after.child_count() == children
			assert stable.get_bounding_client_rect().y > 0
			assert stable.get_bounding_client_rect().width == old_rect.width
			assert stable.get_bounding_client_rect().height == old_rect.height
			assert old_paint.dump() == old_dump
			release_display_list_scene(old_scene)
		}
		formatting_tree_full_paint_check(mut document)
	}
}

fn test_retained_formatting_trees_keep_anonymous_text_items_without_wrapping_twice() {
	for mode in ['grid;grid-template-columns:1fr 1fr', 'flex'] {
		mut document := html.parse_document('<!doctype html><div id="changed"></div><section id="stable" style="display:${mode};width:250px">leading text<strong>strong text</strong>trailing text</section>')
		defer { document.finalize() }
		_ = layout_document_typed_in_viewport(document, 400, 300)
		mut changed := document.get_element_by_id('changed')?
		for index in 0 .. 3 {
			before := formatting_tree_handle(document, 'stable')
			count := before.child_count()
			changed.set_inner_html('<p>Update ${index}</p>')!
			document.update_layout(.debugging)
			after := formatting_tree_handle(document, 'stable')
			assert (voidptr(after) == voidptr(before)) == !disable_retained_formatting_trees
			assert after.child_count() == count
		}
		formatting_tree_full_paint_check(mut document)
	}
}

fn test_retained_formatting_trees_relayout_after_sizing_role_and_text_changes() {
	mut document := html.parse_document('<!doctype html><div id="changed"></div><section id="parent" style="width:320px"><section id="stable" style="display:grid;grid-template-columns:1fr 1fr"><article id="item"><p id="label">Text that must wrap differently when the available width changes.</p></article><article>Other item</article></section></section>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 500, 300)
	mut parent := document.get_element_by_id('parent')?
	mut stable := document.get_element_by_id('stable')?
	mut label := document.get_element_by_id('label')?
	mut changed := document.get_element_by_id('changed')?
	for style in ['width:120px', 'width:300px;font-size:22px;color:red', 'width:220px'] {
		parent.set_attribute_value('style', style)
		changed.set_inner_html('<p>Changed sibling</p>')!
		document.update_layout(.debugging)
		formatting_tree_full_paint_check(mut document)
	}
	for mode in ['flex', 'block', 'grid', 'flex'] {
		stable.set_attribute_value('style', 'display:${mode};grid-template-columns:1fr 1fr')
		label.set_inner_html('<strong>Changed descendant</strong>')!
		document.update_layout(.debugging)
		item := formatting_tree_handle(document, 'item')
		assert item.is_flex_item() == (mode == 'flex')
		assert item.is_grid_item_ == (mode == 'grid')
		formatting_tree_full_paint_check(mut document)
	}
}

fn test_retained_formatting_trees_keep_replaced_generated_and_subgrid_content_on_the_builder_path() {
	for contents in [
		'<img width="20" height="10" alt="image">',
		'<svg width="20" height="10"><rect width="20" height="10"/></svg>',
		'<span class="generated">Generated</span>',
		'<div style="display:grid;grid-template-columns:subgrid"><p>Subgrid</p></div>',
	] {
		mut document := html.parse_document('<!doctype html><style>.generated::before{content:"before"}</style><div id="changed"></div><section id="stable" style="display:grid;grid-template-columns:1fr 1fr">' + contents + '</section>')
		defer { document.finalize() }
		_ = layout_document_typed_in_viewport(document, 400, 300)
		before := formatting_tree_handle(document, 'stable')
		mut changed := document.get_element_by_id('changed')?
		changed.set_inner_html('<p>Changed sibling</p>')!
		document.update_layout(.debugging)
		assert voidptr(formatting_tree_handle(document, 'stable')) != voidptr(before)
		formatting_tree_full_paint_check(mut document)
	}
}
