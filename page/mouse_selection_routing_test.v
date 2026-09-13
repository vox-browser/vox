module page

import css
import dom

struct MouseSelectionHitHarness {
	node  &dom.Node
	index int
}

fn mouse_selection_hit_test(target voidptr, _ f64, _ f64,
	_ dom.HitTestType) ?dom.HitTestResult {
	harness := unsafe { &MouseSelectionHitHarness(target) }
	return dom.HitTestResult{
		node: harness.node
		index_in_node: harness.index
	}
}

fn mouse_selection_document(node &dom.Node, index int) (&dom.Document, &MouseSelectionHitHarness) {
	document := node.document()
	mut mutable_document := unsafe { &dom.Document(document) }
	mutable_document.set_layout_viewport(&dom.LayoutViewport{
		root_node: &dom.LayoutNode{}
	})
	harness := &MouseSelectionHitHarness{
		node: node
		index: index
	}
	mutable_document.set_viewport_paintable(&dom.ViewportPaintable{
		target: voidptr(harness)
		hit_test_callback: mouse_selection_hit_test
	})
	return document, harness
}

fn test_choose_caret_boundary_uses_edge_farthest_from_selection_anchor() {
	mut document := dom.Document.create_for_fragment_parsing()
	text := document.create_text_node('0123456789')
	primary := dom.BoundaryPoint{node: text.as_node(), offset: 3}
	secondary := dom.BoundaryPoint{node: text.as_node(), offset: 7}
	caret := CaretPosition{
		boundary: primary
		secondary_boundary: secondary
	}
	assert choose_caret_boundary_for_selection_focus(caret,
		dom.BoundaryPoint{node: text.as_node(), offset: 1}).offset == 7
	assert choose_caret_boundary_for_selection_focus(caret,
		dom.BoundaryPoint{node: text.as_node(), offset: 9}).offset == 3
	assert choose_caret_boundary_for_selection_focus(caret,
		dom.BoundaryPoint{node: text.as_node(), offset: 5}).offset == 3
}

fn test_form_control_selection_containment_requires_a_noncollapsed_inclusive_range() {
	mut document := dom.Document.create_for_fragment_parsing()
	text := document.create_text_node('Ladybird')
	caret := CaretPosition{boundary: dom.BoundaryPoint{node: text.as_node(), offset: 5}}
	assert form_control_selection_contains_position(SelectionRange{start: 2, end: 5}, caret)
	assert !form_control_selection_contains_position(SelectionRange{start: 5, end: 5}, caret)
	assert !form_control_selection_contains_position(SelectionRange{start: 0, end: 4}, caret)
}

fn test_middle_click_paste_targets_editing_hosts_and_selectable_form_controls() {
	mut document := dom.Document.create_for_fragment_parsing()
	mut host := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div')!
	host.set_attribute_value('contenteditable', 'true')
	mut host_node := host.as_node()
	host_node.recompute_editable_subtree_flag()
	assert is_middle_click_paste_target(host.as_node())

	mut input := document.create_element_ns('http://www.w3.org/1999/xhtml', 'input')!
	input.set_attribute_value('type', 'email')
	assert is_middle_click_paste_target(input.as_node())
	input.set_attribute_value('type', 'checkbox')
	assert !is_middle_click_paste_target(input.as_node())
	textarea := document.create_element_ns('http://www.w3.org/1999/xhtml', 'textarea')!
	assert is_middle_click_paste_target(textarea.as_node())
}

fn test_context_menu_url_token_trims_punctuation_and_preserves_utf16_offsets() {
	mut document := dom.Document.create_for_fragment_parsing()
	text := document.create_text_node('😀 (https://ladybird.org/path?), tail')
	mut handler := EventHandler{}
	caret := CaretPosition{
		boundary: dom.BoundaryPoint{
			node: text.as_node()
			offset: 12
		}
	}
	assert handler.select_context_menu_url_token(document, caret, css.UserSelect.auto_)
	// The emoji occupies two UTF-16 code units; leading '(' and trailing '?)'
	// are excluded from the selected URL token.
	assert handler.input_selection_range_? == SelectionRange{start: 4, end: 29}

	plain := document.create_text_node('ordinary')
	assert !handler.select_context_menu_url_token(document, CaretPosition{
		boundary: dom.BoundaryPoint{node: plain.as_node(), offset: 4}
	}, css.UserSelect.auto_)
	mut password := document.create_text_node('secret.example')
	password.set_is_password_input(true)
	assert !handler.select_context_menu_url_token(document, CaretPosition{
		boundary: dom.BoundaryPoint{node: password.as_node(), offset: 4}
	}, css.UserSelect.auto_)
}

fn test_preserved_selection_and_middle_click_paste_use_fresh_caret_hit() {
	mut document := dom.Document.create_for_fragment_parsing()
	mut host := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div')!
	host.set_attribute_value('contenteditable', 'true')
	mut text := document.create_text_node('editable')
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(host.as_node())!
	mut host_node := host.as_node()
	host_node.append_child(text.as_node())!
	host_node.recompute_editable_subtree_flag()
	mut text_node := text.as_node()
	text_node.recompute_editable_subtree_flag()
	text_node.set_layout_node(&dom.LayoutNode{paintables_: [&dom.Paintable{}]})
	_, harness := mouse_selection_document(text.as_node(), 3)
	assert harness.index == 3

	mut client := &PageClient{}
	mut handler := EventHandler{}
	handler.set_page_client(client)
	position := PixelPoint{x: 4, y: 5}
	handler.preserve_selection_for_mousedown(position)
	assert handler.mousedown_preserved_selection()
	handler.start_selection_from_preserved_mousedown(document)
	assert !handler.mousedown_preserved_selection()
	assert handler.selection_mode_ == .character
	selection_boundary := handler.selection_boundary_ or { panic('missing selection boundary') }
	assert selection_boundary.offset == 3

	assert handler.maybe_request_paste_for_middle_click(document, position)
	assert handler.input_selection_range_? == SelectionRange{start: 3, end: 3}
	assert client.primary_paste_request_count() == 1
	handler.primary_paste_enabled_ = false
	assert !handler.maybe_request_paste_for_middle_click(document, position)
}
