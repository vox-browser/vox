module layout

import dom
import html

fn focused_control_test_focus(document &dom.Document, element &dom.Element) {
	mut mutable_document := unsafe { &dom.Document(document) }
	host := &dom.Navigable{
		active_document_: document
	}
	mut navigable := html.NavigableModel.create(host, none) or { panic(err) }
	navigable.set_focused(true)
	mutable_document.set_cached_navigable(host)
	mutable_document.set_focused_area(element.as_node())
}

fn focused_control_fragment(box &BlockBox, node &dom.Node, offset int) ?TextFragment {
	if fragment := fragment_at_node_offset(box, node, offset) { return *fragment }
	for child in box.children {
		if fragment := focused_control_fragment(&child, node, offset) { return fragment }
	}
	return none
}

fn focused_control_assert_current_after_paint_and_hit_test(document &dom.Document) {
	mut mutable_document := unsafe { &dom.Document(document) }
	before := document_layout_result(document) or { panic('missing layout result') }
	root := voidptr(before.root)
	handle := document.layout_engine_handle()
	_ = mutable_document.record_display_list() or { panic('missing display list') }
	assert document.layout_is_up_to_date()
	assert !document.needs_full_layout_tree_update()
	assert !document.as_node().child_needs_layout_tree_update_()
	mutable_document.update_layout(.event_handler_handle_mouse_move)
	_ = mutable_document.element_from_point(5, 5)
	after := document_layout_result(document) or { panic('missing retained layout') }
	assert voidptr(after.root) == root
	assert document.layout_engine_handle() == handle
}

fn test_focused_appearance_none_input_is_ready_before_first_paint_and_keeps_layout() {
	document :=
		html.parse_document('<!doctype html><style>input { appearance:none; width:160px } body { margin:0 }</style><p>outside text</p><input id="focused" type="search" value="search"><input id="untouched" type="search">')
	control := document.get_element_by_id('focused') or { panic('missing focused input') }
	untouched := document.get_element_by_id('untouched') or { panic('missing other input') }
	focused_control_test_focus(document, control)
	assert control.shadow_root() == none
	assert unsafe { &dom.HTMLInputElement(control) }.input_element_model_ == unsafe { nil }
	_ = layout_document_typed_in_viewport(document, 320, 200)
	assert control.shadow_root() != none
	assert unsafe { &dom.HTMLInputElement(control) }.input_element_model_ != unsafe { nil }
	focused_control_assert_current_after_paint_and_hit_test(document)
	assert untouched.shadow_root() == none
	assert unsafe { &dom.HTMLInputElement(untouched) }.input_element_model_ == unsafe { nil }
}

fn test_prepared_focused_input_preserves_native_selection_caret_and_shadow_identity() {
	document :=
		html.parse_document('<!doctype html><style>input { appearance:none; width:180px; caret-color:rgb(17,23,31) }</style><input id="control" value="abcd">')
	control := document.get_element_by_id('control') or { panic('missing input') }
	mut model := html.HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(control) })
	shadow := control.shadow_root() or { panic('missing input shadow') }
	text := model.form_associated_element_to_text_node() or { panic('missing input text') }
	focused_control_test_focus(document, control)
	model.text_control.set_the_selection_range(1, 3, .forward, .dom)
	root := layout_document_typed_in_viewport(document, 320, 200)
	assert voidptr(control.shadow_root() or { panic('missing retained shadow') }) == voidptr(shadow)
	fragment := focused_control_fragment(&root, text.as_node(), 1) or {
		panic('missing input fragment')
	}
	offsets := selection_offsets(fragment) or { panic('missing input selection') }
	assert offsets.start == 1
	assert offsets.end == 3
	focused_control_assert_current_after_paint_and_hit_test(document)
	model.text_control.set_the_selection_range(2, 2, .none, .dom)
	mut mutable_document := unsafe { &dom.Document(document) }
	commands := display_list_commands(mutable_document.record_display_list() or {
		panic('missing caret list')
	})
	assert commands.any(it.kind == 'fill_rect' && it.color == 'rgb(17 23 31)' && it.width == 1)
	assert model.text_control.selection_start() == 2
	assert model.text_control.selection_end() == 2
	focused_control_assert_current_after_paint_and_hit_test(document)
}

fn test_prepared_focused_textarea_preserves_native_selection_and_existing_shadow_tree() {
	document :=
		html.parse_document('<!doctype html><style>textarea { caret-color:rgb(29,37,41) }</style><textarea id="control">abcde</textarea>')
	control := document.get_element_by_id('control') or { panic('missing textarea') }
	mut model :=
		html.html_text_area_element_model_for_dom_element(unsafe { &dom.HTMLTextAreaElement(control) })
	model.create_shadow_tree_if_needed()
	shadow := control.shadow_root() or { panic('missing textarea shadow') }
	text := model.form_associated_element_to_text_node() or { panic('missing textarea text') }
	focused_control_test_focus(document, control)
	model.set_selection_start_binding(1)!
	model.set_selection_end_binding(4)!
	model.set_selection_direction_binding('forward')
	root := layout_document_typed_in_viewport(document, 320, 200)
	assert voidptr(control.shadow_root() or { panic('missing retained textarea shadow') }) == voidptr(shadow)
	fragment := focused_control_fragment(&root, text.as_node(), 1) or {
		panic('missing textarea fragment')
	}
	offsets := selection_offsets(fragment) or { panic('missing textarea selection') }
	assert offsets.start == 1
	assert offsets.end == 4
	focused_control_assert_current_after_paint_and_hit_test(document)
	model.set_selection_start_binding(2)!
	model.set_selection_end_binding(2)!
	model.set_selection_direction_binding('none')
	mut mutable_document := unsafe { &dom.Document(document) }
	commands := display_list_commands(mutable_document.record_display_list() or {
		panic('missing textarea caret list')
	})
	assert commands.any(it.kind == 'fill_rect' && it.color == 'rgb(29 37 41)' && it.width == 1)
	assert model.selection_start_binding() == 2
	assert model.selection_end_binding() == 2
	focused_control_assert_current_after_paint_and_hit_test(document)
}
