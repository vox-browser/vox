module layout

import dom
import html

$if gcboehm ? {
	fn C.GC_gcollect()
}

fn test_layout_mirrors_share_bridge_functions_and_keep_independent_geometry_snapshots() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}#host{display:inline-block;position:relative;width:80px;height:30px;margin:1px 2px 3px 4px;padding:5px 6px 7px 8px;border:9px solid;left:10px;top:11px}</style><div id="host">text</div><div id="empty"></div>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 320, 200)
	mut host := document.get_element_by_id('host')?
	mirror := host.as_node().layout_node()?
	snapshot := *mirror
	model := *snapshot.box_model()
	assert model.margin_left == 4 && model.margin_right == 2
	assert model.margin_top == 1 && model.margin_bottom == 3
	assert model.border_left == 9 && model.border_right == 9
	assert model.border_top == 9 && model.border_bottom == 9
	assert model.padding_left == 8 && model.padding_right == 6
	assert model.padding_top == 5 && model.padding_bottom == 7
	assert model.inset_left == 10 && model.inset_top == 11
	assert host.client_width() == 94 && host.client_height() == 42
	text := host.as_node().first_child()?
	text_mirror := text.layout_node()?
	empty := document.get_element_by_id('empty')?
	empty_mirror := empty.as_node().layout_node()?
	assert voidptr(mirror.callbacks_) == voidptr(text_mirror.callbacks_)
	assert voidptr(mirror.callbacks_) == voidptr(empty_mirror.callbacks_)
	assert mirror.callbacks_ != unsafe { nil }
	assert text_mirror.box_model_ == unsafe { nil }
	assert empty_mirror.box_model_ == unsafe { nil }
	host.set_attribute_value('style', 'padding:20px;border-width:2px;margin:0;left:0;top:0')
	_ = layout_document_typed_in_viewport(document, 320, 200)
	current := host.as_node().layout_node()?
	assert current.box_model().padding_left == 20
	assert current.box_model().border_left == 2
	assert *snapshot.box_model() == model
	$if gcboehm ? {
		C.GC_gcollect()
	}
	assert *snapshot.box_model() == model
}

fn test_explicit_layout_attachment_snapshots_box_model_before_source_state_mutation() {
	mut document := html.parse_document('<!doctype html><div id="host" style="padding:3px;border:2px solid;margin:4px">text</div>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 320, 200)
	result := document_layout_result(document)?
	_ = attach_layout_nodes_with_state(result.root, result.state)
	host := document.get_element_by_id('host')?
	mirror := host.as_node().layout_node()?
	before := *mirror.box_model()
	typed := unsafe { &Node(mirror.layout_handle) }.as_node_with_style()?
	mut state := result.state
	mut used := state.get_mutable(typed)
	used.margin_left = CSSPixels.new(40)
	used.padding_top = CSSPixels.new(30)
	used.border_bottom = CSSPixels.new(20)
	assert *mirror.box_model() == before
	_ = attach_layout_nodes_with_state(result.root, result.state)
	current := host.as_node().layout_node()?
	assert current.box_model().margin_left == 40
	assert current.box_model().padding_top == 30
	assert current.box_model().border_bottom == 20
	assert *mirror.box_model() == before
	_ = attach_layout_nodes(result.root)
	without_state := host.as_node().layout_node()?
	assert without_state.box_model_ == unsafe { nil }
	assert *mirror.box_model() == before
}
