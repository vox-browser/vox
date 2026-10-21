module layout

import css
import dom
import html

fn test_external_seed_alone_copies_the_complete_deep_root_chain() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	style := css.ComputedProperties.new()
	mut boxes := []&Box{}
	for index in 0 .. 9 {
		mut box := Box.new(document, none, style)
		if index > 0 {
			box.containing_block_ = boxes[index - 1]
			mut parent := unsafe { &Node(boxes[index - 1]) }
			parent.append_child(unsafe { &Node(box) })
		}
		boxes << box
	}
	assert assign_layout_indexes(unsafe { &Node(boxes[0]) }) == 9
	mut source := LayoutState.new()
	for index, box in boxes[..8] {
		mut value := source.get_mutable(unsafe { &NodeWithStyle(box) })
		value.set_content_width(CSSPixels.new(100 + index))
		value.set_content_height(CSSPixels.new(200 + index))
		value.set_has_definite_height(true)
	}
	root := unsafe { &Node(boxes[8]) }
	mut probe := LayoutState.new_for_subtree(unsafe { &NodeWithStyle(boxes[8]) })
	defer { probe.release_measurement() }
	populate_intrinsic_external_containing_blocks(mut probe, mut source, root, root)
	assert probe.try_get(unsafe { &NodeWithStyle(boxes[8]) }) == none
	for index, box in boxes[..8] {
		copied := probe.try_get(unsafe { &NodeWithStyle(box) }) or { panic('missing ancestor') }
		assert copied.content_width() == CSSPixels.new(100 + index)
		assert copied.content_height() == CSSPixels.new(200 + index)
		assert copied.has_definite_width() && copied.has_definite_height()
		assert copied.containing_block_used_values() == none
		mut original := source.get_mutable(unsafe { &NodeWithStyle(box) })
		original.set_content_width(CSSPixels.new(900))
		assert copied.content_width() == CSSPixels.new(100 + index)
	}
}

fn test_external_seed_creates_missing_source_ancestors_and_hoisted_blocks() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	style := css.ComputedProperties.new()
	mut outer := Box.new(document, none, style)
	mut ancestor := Box.new(document, none, style)
	mut external := Box.new(document, none, style)
	mut measured := Box.new(document, none, style)
	ancestor.containing_block_ = outer
	external.containing_block_ = outer
	measured.containing_block_ = ancestor
	mut outer_node := unsafe { &Node(outer) }
	mut ancestor_node := unsafe { &Node(ancestor) }
	mut measured_node := unsafe { &Node(measured) }
	outer_node.append_child(ancestor_node)
	outer_node.append_child(unsafe { &Node(external) })
	ancestor_node.append_child(measured_node)
	for _ in 0 .. 8 {
		mut child := Box.new(document, none, style)
		child.containing_block_ = external
		measured_node.append_child(unsafe { &Node(child) })
	}
	assert assign_layout_indexes(outer_node) == 12
	mut source := LayoutState.new()
	mut outer_value := source.get_mutable(unsafe { &NodeWithStyle(outer) })
	outer_value.set_content_width(CSSPixels.new(300))
	assert source.try_get(unsafe { &NodeWithStyle(ancestor) }) == none
	assert source.try_get(unsafe { &NodeWithStyle(external) }) == none
	mut probe := LayoutState.new_for_subtree(unsafe { &NodeWithStyle(measured) })
	defer { probe.release_measurement() }
	populate_intrinsic_external_containing_blocks(mut probe, mut source, measured_node, measured_node)
	for box in [ancestor, external, outer] {
		original := source.try_get(unsafe { &NodeWithStyle(box) }) or { panic('missing source') }
		copied := probe.try_get(unsafe { &NodeWithStyle(box) }) or { panic('missing copied block') }
		assert copied.content_width() == original.content_width()
		assert copied.has_definite_width() == original.has_definite_width()
		assert copied.containing_block_used_values() == none
	}
	assert probe.try_get(unsafe { &NodeWithStyle(measured) }) == none
}

fn combined_seed_find(root &Node, id string) ?&Node {
	if node := root.dom_node() {
		if element := node.as_element() {
			if element.get_attribute_value('id') == id { return root }
		}
	}
	for child in root.children() {
		if found := combined_seed_find(child, id) { return found }
	}
	return none
}

fn test_public_intrinsic_width_and_height_keep_external_percentage_geometry() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}#outer{position:relative;width:240px;height:120px}#measured{display:inline-block}#leaf{width:40px;height:30px}#positioned{position:absolute;width:50%;height:25%}</style><div id="outer"><div id="measured"><div id="leaf"></div><div id="positioned"></div></div></div>')
	defer { document.finalize() }
	result := run_document_layout(document, 800, 600) or { panic('missing layout') }
	measured := combined_seed_find(result.root, 'measured') or { panic('missing measured') }
	box := measured.as_box() or { panic('missing box') }
	mut state := result.state
	assert calculate_min_content_width(mut state, box) == CSSPixels.new(40)
	assert calculate_max_content_width(mut state, box) == CSSPixels.new(40)
	assert calculate_min_content_height(mut state, box, CSSPixels.new(40)) == CSSPixels.new(30)
	assert calculate_max_content_height(mut state, box, CSSPixels.new(40)) == CSSPixels.new(30)
	positioned := combined_seed_find(result.root, 'positioned') or { panic('missing positioned') }
	styled := positioned.as_node_with_style() or { panic('missing style') }
	values := state.try_get(styled) or { panic('missing committed geometry') }
	assert values.content_width() == CSSPixels.new(120)
	assert values.content_height() == CSSPixels.new(30)
}
