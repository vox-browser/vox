module layout

import css
import dom
import html

fn flow_style_handle(document &dom.Document, id string) &Node {
	element := document.get_element_by_id(id) or { panic(id) }
	return unsafe { &Node(element.as_node().unsafe_layout_node() or { panic('layout') }.real_layout_handle()) }
}

fn flow_style_check_rebuilt_paint(mut document dom.Document) {
	expected := (document.record_display_list() or { panic('paint') }).dump()
	document.set_needs_full_layout_tree_update(true)
	document.update_layout(.debugging)
	assert (document.record_display_list() or { panic('rebuilt paint') }).dump() == expected
}

fn test_noop_restyles_preserve_closed_flow_grid_and_flex_layout_trees() {
	for display in ['block', 'grid;grid-template-columns:1fr 1fr', 'flex;flex-wrap:wrap'] {
		mut document := html.parse_document('<!doctype html><style>body{margin:0}#stable{display:${display};width:240px;gap:7px}article{min-width:0;flex:1}</style><div id="changed"></div><section id="stable"><article><p>Several words wrap into unchanged lines.</p></article><article><p>Other content.</p></article></section>')
		defer { document.finalize() }
		_ = layout_document_typed_in_viewport(document, 400, 300)
		mut changed := document.get_element_by_id('changed')?
		stable := document.get_element_by_id('stable')?
		for index in 0 .. 3 {
			before := flow_style_handle(document, 'stable')
			old_width := stable.get_bounding_client_rect().width
			document.set_needs_full_style_update(true)
			document.update_style()
			fresh := css.computed_properties_for_element(stable)?
			assert voidptr(fresh) != voidptr(before.computed_values())
			assert before.computed_values().has_identical_retained_layout_inputs(fresh, document)
			changed.set_inner_html('<p>Changed sibling ${index}</p>')!
			document.update_layout(.debugging)
			after := flow_style_handle(document, 'stable')
			assert (voidptr(after) == voidptr(before)) == !retain_flow_style_identities
			assert stable.get_bounding_client_rect().width == old_width
			flow_style_check_rebuilt_paint(mut document)
		}
	}
}

fn test_restyled_retained_flow_observes_changed_text_color_width_and_tree_order() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}</style><div id="changed"></div><section id="parent" style="width:240px"><article id="stable"><p id="text">Words wrap when the width changes.</p><p id="other">Second</p></article></section>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	mut parent := document.get_element_by_id('parent')?
	mut text := document.get_element_by_id('text')?
	mut stable := document.get_element_by_id('stable')?
	mut changed := document.get_element_by_id('changed')?
	for style in ['width:120px;color:red', 'width:300px;font-size:23px', 'width:180px;color:blue'] {
		document.set_needs_full_style_update(true)
		document.update_style()
		parent.set_attribute_value('style', style)
		text.set_text_content('Changed text must replace old shaping.')!
		changed.set_inner_html('<p>Changed sibling</p>')!
		document.update_layout(.debugging)
		flow_style_check_rebuilt_paint(mut document)
	}
	mut node := stable.as_node()
	node.append_child(text.as_node())!
	document.update_layout(.debugging)
	flow_style_check_rebuilt_paint(mut document)
}

fn test_restyled_flow_keeps_replaced_and_generated_descendants_on_the_builder_path() {
	for content in ['<img width="20" height="10">', '<span class="generated">Generated</span>',
		'<svg width="20" height="10"><rect width="20" height="10"/></svg>'] {
		mut document := html.parse_document('<!doctype html><style>.generated::before{content:"before"}</style><div id="changed"></div><section id="stable">${content}</section>')
		defer { document.finalize() }
		_ = layout_document_typed_in_viewport(document, 400, 300)
		before := flow_style_handle(document, 'stable')
		document.set_needs_full_style_update(true)
		document.update_style()
		mut changed := document.get_element_by_id('changed')?
		changed.set_inner_html('<p>Changed</p>')!
		document.update_layout(.debugging)
		assert voidptr(flow_style_handle(document, 'stable')) != voidptr(before)
		flow_style_check_rebuilt_paint(mut document)
	}
}
