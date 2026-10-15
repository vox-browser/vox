module layout

import css
import dom
import html

fn viewport_isolation_body_style(document &dom.Document) &css.ComputedProperties {
	body := document.body() or { panic('body') }
	return css.computed_properties_for_element(unsafe { &dom.Element(body) }) or {
		panic('body style')
	}
}

fn viewport_isolation_body_values(result &DocumentLayoutResult) &css.ComputedValues {
	root := result.root.first_child() or { panic('root') }
	body := direct_body_layout_node(root) or { panic('body box') }
	return (body.as_node_with_style() or { panic('body values') }).computed_values()
}

fn test_viewport_overflow_preserves_computed_style_and_unchanged_cascade_tree_identity() {
	mut document :=
		html.parse_document('<!doctype html><style>html,body{margin:0}body{overflow-y:scroll}#child{height:20px}</style><div id="child">text</div>')
	_ = layout_document_typed_in_viewport(document, 320, 180)
	initial := document_layout_result(document) or { panic('initial') }
	computed := viewport_isolation_body_style(document)
	assert computed.overflow_x() == .auto_
	assert computed.overflow_y() == .scroll
	assert (computed.property(.overflow_y, .no) or { panic('property') }).css_text == 'scroll'
	used := viewport_isolation_body_values(initial)
	assert used.overflow_x() == .visible && used.overflow_y() == .visible
	assert voidptr(used) != voidptr(computed)
	viewport := (initial.root.as_node_with_style() or { panic('viewport') }).computed_values()
	assert viewport.overflow_x() == .auto_ && viewport.overflow_y() == .scroll
	body := document.body() or { panic('body') }
	mut body_node := unsafe { &dom.Node(body) }
	body_node.set_needs_style_update(true)
	document.update_layout(.debugging)
	after := document_layout_result(document) or { panic('after') }
	assert voidptr(after.root) == voidptr(initial.root)
	assert viewport_isolation_body_style(document).overflow_y() == .scroll
	assert viewport_isolation_body_values(after).overflow_y() == .visible
	resolved :=
		css.CSSStyleProperties.create_resolved_style(dom.AbstractElement.new(unsafe { &dom.Element(body) }, none))
	assert resolved.get_property_value('overflow-y') == 'scroll'
}

fn test_viewport_overrides_survive_paint_only_style_and_retained_geometry_updates() {
	mut document :=
		html.parse_document('<!doctype html><style>html,body{margin:0}body{overflow-y:scroll}#child{height:20px}</style><div id="child">text</div>')
	_ = layout_document_typed_in_viewport(document, 320, 180)
	initial := document_layout_result(document) or { panic('initial') }
	old_values := viewport_isolation_body_values(initial)
	mut body := unsafe { &dom.Element(document.body() or { panic('body') }) }
	body.set_attribute_value('style', 'color:red')
	document.update_layout(.debugging)
	paint_only := document_layout_result(document) or { panic('paint') }
	assert voidptr(paint_only.root) == voidptr(initial.root)
	assert viewport_isolation_body_values(paint_only).overflow_y() == .visible
	assert viewport_isolation_body_style(document).overflow_y() == .scroll
	mut child := document.get_element_by_id('child') or { panic('child') }
	child.set_attribute_value('style', 'height:60px')
	document.update_layout(.debugging)
	after := document_layout_result(document) or { panic('after') }
	assert voidptr(after.root) == voidptr(initial.root)
	assert viewport_isolation_body_values(after).overflow_y() == .visible
	assert child.client_height() == 60
	assert old_values.overflow_y() == .visible
	assert viewport_isolation_body_style(document).overflow_y() == .scroll
}

fn test_viewport_principal_writing_mode_overrides_leave_element_style_unchanged() {
	mut document :=
		html.parse_document('<!doctype html><style>html{writing-mode:horizontal-tb;direction:ltr;overflow:hidden;scrollbar-width:thin}body{writing-mode:vertical-rl;direction:rtl;overflow:scroll}</style><body></body>')
	_ = layout_document_typed_in_viewport(document, 320, 180)
	result := document_layout_result(document) or { panic('layout') }
	root_box := result.root.first_child() or { panic('root') }
	root := document.document_element() or { panic('root element') }
	computed := css.computed_properties_for_element(root) or { panic('computed') }
	assert computed.writing_mode() == .horizontal_tb && computed.direction() == .ltr
	assert computed.overflow_x() == .hidden && computed.overflow_y() == .hidden
	values := (root_box.as_node_with_style() or { panic('used') }).computed_values()
	assert values.writing_mode() == .vertical_rl && values.direction() == .rtl
	assert values.overflow_x() == .visible && values.overflow_y() == .visible
	viewport := (result.root.as_node_with_style() or { panic('viewport') }).computed_values()
	assert viewport.overflow_x() == .hidden && viewport.overflow_y() == .hidden
	assert viewport.scrollbar_width() == .thin
	mut body := unsafe { &dom.Element(document.body() or { panic('body') }) }
	body.set_attribute_value('style', 'contain:layout')
	document.update_layout(.debugging)
	after := document_layout_result(document) or { panic('after') }
	updated := (after.root.as_node_with_style() or { panic('viewport') }).computed_values()
	assert updated.writing_mode() == .horizontal_tb && updated.direction() == .ltr
	assert viewport_isolation_body_values(after).overflow_y() == .scroll
	assert values.writing_mode() == .vertical_rl
}

fn test_viewport_clip_mapping_and_hidden_body_preserve_authored_overflow() {
	for overflow in ['clip', 'scroll', 'hidden'] {
		document :=
			html.parse_document('<!doctype html><style>html{overflow:${overflow}}body{display:none;overflow:scroll;writing-mode:vertical-rl}</style><body></body>')
		result := run_document_layout(document, 320, 180) or { panic('layout') }
		root := document.document_element() or { panic('root') }
		computed := css.computed_properties_for_element(root) or { panic('computed') }
		assert (computed.property(.overflow_x, .no) or { panic('overflow') }).css_text == overflow
		viewport := (result.root.as_node_with_style() or { panic('viewport') }).computed_values()
		assert viewport.overflow_x() == if overflow == 'scroll' {
			css.Overflow.scroll
		} else {
			css.Overflow.hidden
		}
		assert viewport.writing_mode() == .horizontal_tb
		assert viewport_isolation_body_style(document).overflow_y() == .scroll
	}
}

fn test_viewport_value_overrides_copy_changed_values_and_preserve_published_snapshots() {
	document := html.parse_document('<!doctype html><body style="overflow:scroll"></body>')
	_ = run_document_layout(document, 320, 180) or { panic('layout') }
	source := viewport_isolation_body_style(document)
	values := unsafe { &css.ComputedValues(source) }
	changed := values.with_viewport_overrides(.visible, .hidden, .vertical_rl, .rtl, .thin)
	assert voidptr(changed) != voidptr(values)
	assert values.overflow_x() == .scroll && values.overflow_y() == .scroll
	assert values.writing_mode() == .horizontal_tb && values.direction() == .ltr
	assert changed.overflow_x() == .visible && changed.overflow_y() == .hidden
	assert changed.writing_mode() == .vertical_rl && changed.direction() == .rtl
	assert changed.scrollbar_width() == .thin
	assert voidptr(changed.with_viewport_overrides(.visible, .hidden, .vertical_rl, .rtl, .thin)) == voidptr(changed)
	_ = changed.with_viewport_overrides(.scroll, .scroll, .horizontal_tb, .ltr, .none_)
	assert changed.overflow_x() == .visible && changed.scrollbar_width() == .thin
	assert values.overflow_x() == .scroll && changed.overflow_x() == .visible
}

fn test_unboxed_body_supplies_principal_mode_without_propagating_its_overflow() {
	mut document :=
		html.parse_document('<!doctype html><style>html{writing-mode:horizontal-tb;direction:ltr}body{display:contents;writing-mode:vertical-rl;direction:rtl;overflow:scroll}</style><div>text</div>')
	_ = layout_document_typed_in_viewport(document, 320, 180)
	initial := document_layout_result(document) or { panic('initial') }
	viewport := (initial.root.as_node_with_style() or { panic('viewport') }).computed_values()
	assert viewport.writing_mode() == .vertical_rl && viewport.direction() == .rtl
	assert viewport.overflow_x() == .auto_ && viewport.overflow_y() == .auto_
	assert viewport_isolation_body_style(document).overflow_y() == .scroll
	mut body := unsafe { &dom.Element(document.body() or { panic('body') }) }
	assert body.as_node().layout_node() == none
	body.set_attribute_value('style', 'contain:layout')
	document.update_layout(.debugging)
	after := document_layout_result(document) or { panic('after') }
	updated := (after.root.as_node_with_style() or { panic('viewport') }).computed_values()
	assert updated.writing_mode() == .horizontal_tb && updated.direction() == .ltr
	assert viewport.writing_mode() == .vertical_rl
}

fn test_root_paint_style_reinherits_anonymous_boxes_before_principal_mode_override() {
	mut document :=
		html.parse_document('<!doctype html><style>html{writing-mode:horizontal-tb;direction:ltr}body{writing-mode:vertical-rl;direction:rtl}</style><body><div>body</div></body>')
	mut root := document.document_element() or { panic('root') }
	mut root_dom := unsafe { &dom.Node(root) }
	root_dom.append_child(document.create_text_node('root text').as_node())!
	_ = layout_document_typed_in_viewport(document, 320, 180)
	initial := document_layout_result(document) or { panic('initial') }
	root_box := initial.root.first_child() or { panic('root box') }
	wrappers := root_box.children().filter(it.is_anonymous())
	assert wrappers.len > 0
	for wrapper in wrappers {
		values := (wrapper.as_node_with_style() or { panic('wrapper') }).computed_values()
		assert values.writing_mode() == .horizontal_tb && values.direction() == .ltr
	}
	root.set_attribute_value('style', 'color:red')
	document.update_layout(.debugging)
	after := document_layout_result(document) or { panic('after') }
	assert voidptr(after.root) == voidptr(initial.root)
	root_values := (root_box.as_node_with_style() or { panic('root values') }).computed_values()
	assert root_values.writing_mode() == .vertical_rl && root_values.direction() == .rtl
	for wrapper in wrappers {
		values := (wrapper.as_node_with_style() or { panic('wrapper') }).computed_values()
		assert values.writing_mode() == .horizontal_tb && values.direction() == .ltr
	}
}

fn test_viewport_propagation_finds_root_and_body_through_anonymous_table_wrappers() {
	for declaration in ['body{display:table}', 'html{display:table}', 'html,body{display:table}'] {
		mut document :=
			html.parse_document('<!doctype html><style>html{overflow:visible}body{overflow:scroll;writing-mode:vertical-rl;direction:rtl}${declaration}</style><body><div id="target">text</div></body>')
		_ = layout_document_typed_in_viewport(document, 320, 180)
		initial := document_layout_result(document) or { panic('initial') }
		viewport := (initial.root.as_node_with_style() or { panic('viewport') }).computed_values()
		assert viewport.writing_mode() == .vertical_rl && viewport.direction() == .rtl
		assert viewport.overflow_y() == .scroll
		root_box := viewport_document_element_box(initial.root) or { panic('root') }
		body_element := viewport_first_body_element(root_box) or { panic('body element') }
		body_box := viewport_body_box(root_box, body_element) or { panic('body box') }
		assert (body_box.as_node_with_style() or { panic('body values') }).computed_values().overflow_y() == .visible
		mut target := document.get_element_by_id('target') or { panic('target') }
		target.set_attribute_value('style', 'height:40px')
		document.update_layout(.debugging)
		after := document_layout_result(document) or { panic('after') }
		assert voidptr(after.root) == voidptr(initial.root)
		updated := (after.root.as_node_with_style() or { panic('viewport') }).computed_values()
		assert updated.writing_mode() == .vertical_rl && updated.overflow_y() == .scroll
		assert viewport_isolation_body_style(document).overflow_y() == .scroll
	}
}
