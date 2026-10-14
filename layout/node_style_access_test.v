module layout

import css
import dom

fn style_access_properties(display css.DisplayShort) &css.ComputedProperties {
	return css.ComputedProperties.new().clone_for_anonymous_with_display(css.Display.from_short(display))
}

fn test_styled_base_accessors_keep_concrete_node_style_identity() {
	document := dom.Document.create(dom.url_about_blank())
	style := style_access_properties(.flex)
	styled := NodeWithStyle.new(document, none, style)
	box := Box.new(document, none, style)
	block := BlockContainer.new(document, none, style)
	inline_node := InlineNode.new(document, none, style)
	mut transformed := unsafe { &css.MutableComputedValues(inline_node.computed_values()) }
	transformed.set_display(css.Display.from_short(.block))
	transformed.set_display_before_box_type_transformation(css.Display.from_short(.inline_flex))
	for node in [unsafe { &Node(styled) }, unsafe { &Node(box) }, unsafe { &Node(block) }, unsafe { &Node(inline_node) }] {
		typed := node.as_node_with_style() or { panic('missing styled node') }
		assert voidptr(node.computed_values()) == voidptr(typed.computed_values())
		assert node.display() == typed.computed_values().display()
		assert node.display_before_box_type_transformation() == typed.computed_values().display_before_box_type_transformation()
	}
	assert unsafe { &Node(inline_node) }.display() == css.Display.from_short(.block)
	assert unsafe { &Node(inline_node) }.display_before_box_type_transformation() == css.Display.from_short(.inline_flex)
}

fn test_unstyled_chain_tracks_reparenting_and_live_ancestor_style() {
	document := dom.Document.create(dom.url_about_blank())
	mut first := BlockContainer.new(document, none, style_access_properties(.block))
	mut second := BlockContainer.new(document, none, style_access_properties(.grid))
	mut wrapper := Node.new(document, none)
	mut nested := Node.new(document, none)
	text := TextNode.new_generated(document, 'inherited text')
	nested.append_child(unsafe { &Node(text) })
	wrapper.append_child(nested)
	first.append_child(wrapper)
	text_node := unsafe { &Node(text) }
	assert voidptr(text_node.computed_values()) == voidptr(first.computed_values())
	first.replace_children([]&Node{})
	second.append_child(wrapper)
	assert voidptr(text_node.computed_values()) == voidptr(second.computed_values())
	old_style := second.computed_values()
	second.set_computed_values(style_access_properties(.flex))
	assert voidptr(text_node.computed_values()) == voidptr(second.computed_values())
	assert voidptr(text_node.computed_values()) != voidptr(old_style)
	assert text_node.computed_values().display() == css.Display.from_short(.flex)
	gc_collect()
	assert voidptr(text_node.computed_values()) == voidptr(second.computed_values())
}

fn test_closest_styled_node_wins_and_style_replacement_stays_live() {
	document := dom.Document.create(dom.url_about_blank())
	mut outer := BlockContainer.new(document, none, style_access_properties(.grid))
	mut inner := InlineNode.new(document, none, style_access_properties(.inline_))
	text := TextNode.new_generated(document, 'nested text')
	inner.append_child(unsafe { &Node(text) })
	outer.append_child(unsafe { &Node(inner) })
	node := unsafe { &Node(inner) }
	leaf := unsafe { &Node(text) }
	assert voidptr(leaf.computed_values()) == voidptr(inner.computed_values())
	assert voidptr(leaf.computed_values()) != voidptr(outer.computed_values())
	inner.apply_style(style_access_properties(.none_))
	assert node.display().is_none()
	assert node.display_before_box_type_transformation().is_none()
	assert voidptr(leaf.computed_values()) == voidptr(inner.computed_values())
}

fn test_unstyled_display_remains_inline_flow_independent_of_parent() {
	document := dom.Document.create(dom.url_about_blank())
	mut parent := BlockContainer.new(document, none, style_access_properties(.none_))
	child := Node.new(document, none)
	inline_flow := css.Display.from_outside_inside(.inline_, .flow)
	assert child.display() == inline_flow
	assert child.display_before_box_type_transformation() == inline_flow
	parent.append_child(child)
	assert child.computed_values().display().is_none()
	assert child.display() == inline_flow
	assert child.display_before_box_type_transformation() == inline_flow
}
