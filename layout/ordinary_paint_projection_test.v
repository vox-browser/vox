module layout

import dom
import html

fn ordinary_projection_test_node(document &dom.Document, id string) &Node {
	element := document.get_element_by_id(id) or { panic('missing owner') }
	return unsafe { &Node(element.as_node().unsafe_layout_node() or { panic('missing layout') }.real_layout_handle()) }
}

fn ordinary_projection_test_compare(document &dom.Document, id string) {
	node := ordinary_projection_test_node(document, id)
	state := document_layout_result(document) or { panic('missing result') }.state
	actual := ordinary_paint_box_from_typed_layout(node, state, [6]f64{})
	expected := uncached_block_box_from_typed_layout_shallow(node, state, [6]f64{})
	assert actual.x == expected.x && actual.y == expected.y
	assert actual.width == expected.width && actual.height == expected.height
	assert actual.scrollable_overflow == expected.scrollable_overflow
	assert retained_paint_payload_equal(actual, expected)
}

fn test_ordinary_projection_rebases_unchanged_boxes_without_retaining_paint_arena_arrays() {
	mut document := html.parse_document('<!doctype html><div id="changed"></div><section id="stable" style="padding:4px;border:2px solid blue;outline:1px solid red;border-radius:4px;box-shadow:1px 2px 3px gray"><p>Comment <strong>content</strong>.</p></section>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	old := document.record_display_list()?
	retained_scene := retain_display_list_scene(old)
	defer { release_display_list_scene(retained_scene) }
	commands := display_list_commands(old).clone()
	stable := ordinary_projection_test_node(document, 'stable')
	snapshot := stable.ordinary_paint_box_
	assert snapshot != unsafe { nil }
	assert snapshot.paint.box.children.len == 0 && snapshot.paint.box.lines.len == 0
	mut changed := document.get_element_by_id('changed')?
	for content in ['<p>Preceding comment expanded</p>', '', '<p>one</p><p>two</p>'] {
		changed.set_inner_html(content)!
		document.update_layout(.debugging)
		ordinary_projection_test_compare(document, 'stable')
		assert voidptr(stable.ordinary_paint_box_) == voidptr(snapshot)
		assert display_list_commands(old).clone() == commands
	}
}

fn test_ordinary_projection_rechecks_final_box_model_children_and_scrollable_overflow() {
	mut document := html.parse_document('<!doctype html><div id="parent" style="width:240px"><section id="target" style="padding:5%;border:1px solid green;height:50px;overflow:auto"><span></span></section></div>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	mut parent := document.get_element_by_id('parent')?
	for style in ['width:120px', 'width:300px;font-size:22px', 'width:240px'] {
		parent.set_attribute_value('style', style)
		document.update_layout(.debugging)
		ordinary_projection_test_compare(document, 'target')
	}
	mut target := document.get_element_by_id('target')?
	for content in ['', '<div style="height:200px;width:400px">overflowing</div>', '<span></span>'] {
		target.set_inner_html(content)!
		document.update_layout(.debugging)
		ordinary_projection_test_compare(document, 'target')
	}
}

fn test_ordinary_projection_does_not_reuse_old_colors_effects_or_dynamic_backgrounds() {
	mut document := html.parse_document('<!doctype html><div id="target" style="width:100px;height:30px;background:lime"></div>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	mut target := document.get_element_by_id('target')?
	for style in ['background:blue;outline:2px solid red', 'background-image:linear-gradient(red,blue)',
		'transform:translateX(4px)', 'filter:blur(1px)', 'background:yellow;border:3px solid green'] {
		target.set_attribute_value('style', 'width:100px;height:30px;' + style)
		document.update_layout(.debugging)
		ordinary_projection_test_compare(document, 'target')
	}
}
