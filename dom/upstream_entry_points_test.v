module dom

import strings

fn fixed_scroll_margin_for_test(_ voidptr, _ &Element) ScrollMarginData {
	return ScrollMarginData{
		top: 5
		right: 4
		bottom: 15
		left: 3
	}
}

fn fixed_scroll_padding_for_test(_ voidptr, _ &Node) ScrollMarginData {
	return ScrollMarginData{
		top: 10
		right: 8
		bottom: 20
		left: 6
	}
}

fn test_upstream_node_type_predicates_preserve_dynamic_interface_identity() {
	document := Document.create(url_about_blank())
	anchor := document.create_element_ns(namespace_html_uri, 'a') or { panic(err) }
	anchor_node := anchor.as_node()
	assert anchor_node.is_dom_node()
	assert anchor_node.is_html_element()
	assert anchor_node.is_html_anchor_element()
	assert !anchor_node.is_html_area_element()
	assert !anchor_node.is_svg_element()

	foreign_object := document.create_element_ns(namespace_svg_uri, 'foreignObject') or {
		panic(err)
	}
	foreign_object_node := foreign_object.as_node()
	assert foreign_object_node.is_svg_element()
	assert foreign_object_node.is_svg_graphics_element()
	assert foreign_object_node.is_svg_foreign_object_element()
	assert foreign_object_node.requires_svg_container()

	svg := document.create_element_ns(namespace_svg_uri, 'svg') or { panic(err) }
	assert svg.as_node().is_svg_container()
	assert !svg.as_node().requires_svg_container()
}

fn test_upstream_slottable_and_tree_mixin_state() {
	document := Document.create(url_about_blank())
	mut parent := document.create_element_ns(namespace_html_uri, 'div') or { panic(err) }
	mut first := document.create_element_ns(namespace_html_uri, 'span') or { panic(err) }
	mut text := document.create_text_node('between')
	mut last := document.create_element_ns(namespace_html_uri, 'strong') or { panic(err) }
	mut parent_node := parent.as_node()
	parent_node.append_child(first.as_node()) or { panic(err) }
	parent_node.append_child(text.as_node()) or { panic(err) }
	parent_node.append_child(last.as_node()) or { panic(err) }

	assert text.as_node().previous_element_sibling() or { panic('previous element') } == first
	assert text.as_node().next_element_sibling() or { panic('next element') } == last
	assert last.as_node().previous_element_in_pre_order() or { panic('previous in preorder') } == first
	assert first.as_node().next_element_in_pre_order() or { panic('next in preorder') } == last

	first.set_attribute_value('slot', 'leading')
	assert first.as_node().slottable_name() == 'leading'
	first.remove_attribute('slot')
	assert first.as_node().slottable_name() == ''
}

fn test_upstream_inline_state_accessors() {
	document := Document.create(url_about_blank())
	mut node := Node.new(document, .text_node)
	mut range_ := Range{
		start_container_: node
		end_container_: node
	}
	range_.set_start_offset(3)
	range_.increase_start_offset(4)
	range_.decrease_start_offset(2)
	range_.set_end_offset(9)
	range_.decrease_end_offset(1)
	assert range_.start_offset_ == 5
	assert range_.end_offset_ == 8

	record := &MutationRecord{
		target: node
		added_nodes: [node]
		attribute_name: 'class'
		old_value: 'before'
	}
	assert record.mutation_record_target() or { panic('missing target') } == node
	assert record.mutation_record_added_nodes() == [node]
	assert record.mutation_record_attribute_name() or { '' } == 'class'
	assert record.mutation_record_old_value() or { '' } == 'before'

	mut element := document.create_element_ns(namespace_html_uri, 'div') or { panic(err) }
	element.set_affected_by_direct_sibling_combinator(true)
	element.set_sibling_invalidation_distance(7)
	assert element.element_affected_by_direct_sibling_combinator()
	assert element.element_sibling_invalidation_distance() == 7
}

fn test_live_range_registry_follows_boundaries_across_documents() {
	document_a := Document.create(url_about_blank())
	document_b := Document.create(url_about_blank())
	mut parent := document_b.create_element_ns(namespace_html_uri, 'div') or { panic(err) }
	child := document_b.create_element_ns(namespace_html_uri, 'span') or { panic(err) }
	mut parent_node := parent.as_node()
	parent_node.append_child(child.as_node()) or { panic(err) }

	mut range_ := document_a.create_range()
	range_.set_start(child.as_node(), 0) or { panic(err) }
	range_.set_end(child.as_node(), 0) or { panic(err) }
	assert Range.live_ranges().contains(range_)

	mut child_node := child.as_node()
	child_node.remove(false)
	assert range_.start_container() == parent.as_node()
	assert range_.start_offset() == 0
	assert range_.end_container() == parent.as_node()
	assert range_.end_offset() == 0

	range_.finalize()
	assert !Range.live_ranges().contains(range_)
}

fn test_range_constructor_uses_the_realm_windows_document() {
	document := Document.create(url_about_blank())
	window := &Window{
		associated_document_: document
	}
	mut range_ := Range.construct_impl(window)

	assert range_.start_container() == unsafe { &Node(document) }
	assert range_.start_offset() == 0
	assert range_.end_container() == unsafe { &Node(document) }
	assert range_.end_offset() == 0
	assert Range.live_ranges().contains(range_)

	range_.finalize()
	assert !Range.live_ranges().contains(range_)
}

fn test_upstream_document_and_named_element_algorithms() {
	mut document := Document.create(url_about_blank())
	document.set_ready_for_post_load_tasks(true)
	document.set_ready_to_run_scripts()
	document.set_parser_cannot_change_the_mode(true)
	document.set_needs_accumulated_visual_contexts_update(true)
	assert document.document_ready_for_post_load_tasks()
	assert document.document_ready_to_run_scripts()
	assert document.document_parser_cannot_change_the_mode()
	assert document.document_needs_accumulated_visual_contexts_update()

	mut image := document.create_element_ns(namespace_html_uri, 'img') or { panic(err) }
	image.set_attribute_value('name', 'hero')
	image.set_attribute_value('id', 'hero-id')
	assert is_potentially_named_element(image)
	assert is_potentially_named_element_by_id(image)
	document.potentially_named_elements << image
	assert named_elements_with_name(document, 'hero') == [image]
	assert named_elements_with_name(document, 'hero-id') == [image]

	mut sheet := CSSStyleSheet{
		url: 'outer.css'
		imported_style_sheets: [&CSSStyleSheet{
			url: 'inner.css'
		}]
	}
	assert find_style_sheet_with_url('outer.css', sheet) or { panic('outer sheet') } == sheet
	assert (find_style_sheet_with_url('inner.css', sheet) or { panic('inner sheet') }).url == 'inner.css'
}

fn test_upstream_fullscreen_and_selectionchange_boundaries() {
	assert request_fullscreen_error_to_string(.unsupported_element) == 'Not supported element'
	assert request_fullscreen_error_to_string(.element_node_doc_is_not_pending_doc) == "Element's node document is not pending doc"

	mut document := Document.create(url_about_blank())
	schedule_a_selectionchange_event(mut document, document)
	assert document.has_scheduled_selectionchange_event()
	fire_a_selectionchange_event(mut document, document)
	assert !document.has_scheduled_selectionchange_event()
}

fn test_element_json_serialization_uses_upstream_child_and_pseudo_order() {
	document := Document.create(url_about_blank())
	mut element := document.create_element_ns(namespace_html_uri, 'div') or { panic(err) }
	mut whitespace := document.create_text_node('   ')
	mut child := document.create_element_ns(namespace_html_uri, 'span') or { panic(err) }
	mut element_node := element.as_node()
	element_node.append_child(whitespace.as_node()) or { panic(err) }
	element_node.append_child(child.as_node()) or { panic(err) }
	element.set_pseudo_element_node(int(PseudoElement.before), &LayoutNodeWithStyle_{})
	element.set_pseudo_element_node(int(PseudoElement.after), &LayoutNodeWithStyle_{})

	mut builder := strings.new_builder(512)
	element.as_node().serialize_tree_as_json(mut builder)
	serialized := builder.str()
	before_index := serialized.index('"name":"::before"') or { panic('missing ::before') }
	child_identity := '"name":"${child.as_node().node_name()}","id":${child.as_node().unique_id().value()}'
	child_index := serialized.index(child_identity) or { panic('missing child') }
	after_index := serialized.index('"name":"::after"') or { panic('missing ::after') }
	assert before_index < child_index
	assert child_index < after_index
	assert !serialized.contains('"text":"   "')
	assert serialized.contains('"parent-id":${element.as_node().unique_id().value()}')
}

fn test_scroll_into_view_uses_committed_paintable_overflow() {
	mut document := Document.create(url_about_blank())
	document.set_viewport_rect(Rect{0, 30, 100, 100})
	mut window := &Window{
		associated_document_: document
	}
	document.set_window(window)

	mut html_element := document.create_element_ns(namespace_html_uri, 'html') or { panic(err) }
	mut target := document.create_element_ns(namespace_html_uri, 'div') or { panic(err) }
	mut document_node := unsafe { &Node(document) }
	document_node.append_child(html_element.as_node()) or { panic(err) }
	mut html_node := html_element.as_node()
	html_node.append_child(target.as_node()) or { panic(err) }

	mut target_node := target.as_node()
	target_node.set_layout_node(&LayoutNode{
		dom_node_: target.as_node()
		has_geometry_: true
		border_box_: Rect{10, 200, 20, 20}
	})
	mut viewport_paintable := &PaintableBox{
		Paintable: Paintable{
			is_box: true
		}
		has_scrollable_overflow_: true
	}
	document_node.set_paintable(unsafe { &Paintable(viewport_paintable) })

	position := determine_the_scroll_into_view_position(target, .end_, .nearest, document_node)
	assert position.x() == 0
	assert position.y() == 120
	promise := target.scroll_into_view()
	assert promise.state() == .fulfilled
	assert window.scroll_x() == 0
	assert window.scroll_y() == 230

	document.set_scroll_style_hook(DocumentScrollStyleHook{
		scroll_margin: fixed_scroll_margin_for_test
	})
	margin_position := determine_the_scroll_into_view_position(target, .end_, .nearest, document_node)
	assert margin_position.x() == 0
	assert margin_position.y() == 135
	start_position := determine_the_scroll_into_view_position(target, .start, .start, document_node)
	assert start_position.x() == 7
	assert start_position.y() == 195
	target.scroll_into_view()
	assert window.scroll_y() == 225

	document.set_scroll_style_hook(DocumentScrollStyleHook{
		scroll_margin: fixed_scroll_margin_for_test
		scroll_padding: fixed_scroll_padding_for_test
	})
	padded_position := determine_the_scroll_into_view_position(target, .end_, .nearest,
		document_node)
	assert padded_position.x() == 0
	assert padded_position.y() == 155
	padded_start_position := determine_the_scroll_into_view_position(target, .start, .start,
		document_node)
	assert padded_start_position.x() == 1
	assert padded_start_position.y() == 185
	target.scroll_into_view()
	assert window.scroll_y() == 215
}

fn test_element_scroll_routes_viewport_branches_and_resolves_promises() {
	mut document := Document.create(url_about_blank())
	document.set_document_type(.html)
	document.populate_with_html_head_and_body() or { panic(err) }
	document.set_browsing_context(&BrowsingContext{
		active_document_: document
	})
	mut window := &Window{
		associated_document_: document
	}
	document.set_window(window)

	mut root := document.document_element() or { panic('missing document element') }
	initial_scroll := window.scroll(4, 5)
	assert initial_scroll.state() == .fulfilled
	root_scroll := root.el_scroll(17, 23)
	assert root_scroll.state() == .fulfilled
	assert window.scroll_x() == 4
	assert window.scroll_y() == 23

	document.set_quirks_mode(.yes)
	mut body := unsafe { &Element(document.body() or { panic('missing body') }) }
	body_scroll := body.el_scroll(9, 11)
	assert body_scroll.state() == .fulfilled
	assert window.scroll_x() == 9
	assert window.scroll_y() == 11

	root_scroll_in_quirks_mode := root.el_scroll(31, 37)
	assert root_scroll_in_quirks_mode.state() == .fulfilled
	assert window.scroll_x() == 9
	assert window.scroll_y() == 11

	mut inactive_document := Document.create(url_about_blank())
	mut detached := inactive_document.create_element_ns(namespace_html_uri, 'div') or {
		panic(err)
	}
	inactive_scroll := detached.el_scroll(1, 2)
	assert inactive_scroll.state() == .fulfilled
}
