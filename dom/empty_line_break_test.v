module dom

fn test_empty_line_break_stops_at_its_containing_block() {
	mut document := Document.create_for_fragment_parsing()
	defer { document.finalize() }
	host := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic(err) }
	mut mutable_host := unsafe { &Element(host) }
	mutable_host.set_attribute_value('contenteditable', 'true')
	mut document_node := document.as_node()
	document_node.append_child(host.as_node()) or { panic(err) }
	block := &LayoutNode{
		dom_node_: host.as_node()
		// The host itself must never participate in the preceding-content scan.
		is_replaced_box_: true
	}
	mut host_node := host.as_node()
	host_node.set_layout_node(block)
	first := document.create_element_ns('http://www.w3.org/1999/xhtml', 'br') or { panic(err) }
	mut first_node := first.as_node()
	first_node.set_layout_node(&LayoutNode{ containing_block_: block })
	host_node.append_child(first_node) or { panic(err) }
	assert is_empty_line_break(first_node)

	text := document.create_text_node('visible')
	mut text_node := text.as_node()
	text_node.set_layout_node(&LayoutNode{
		is_text_node_: true
		visual_lines_provider_: LayoutVisualLinesProvider.new(unsafe { nil }, fn (_ voidptr, _ voidptr) []VisualLine {
			return [VisualLine{ has_fragments: true }]
		})
	})
	host_node.append_child(text_node) or { panic(err) }
	second := document.create_element_ns('http://www.w3.org/1999/xhtml', 'br') or { panic(err) }
	mut second_node := second.as_node()
	second_node.set_layout_node(&LayoutNode{ containing_block_: block })
	host_node.append_child(second_node) or { panic(err) }
	assert !is_empty_line_break(second_node)

	third := document.create_element_ns('http://www.w3.org/1999/xhtml', 'br') or { panic(err) }
	mut third_node := third.as_node()
	third_node.set_layout_node(&LayoutNode{ containing_block_: block })
	host_node.append_child(third_node) or { panic(err) }
	assert is_empty_line_break(third_node)
}
