module layout

import css

// UA placeholders share the editor's flex area. Chromium paints the editor
// and caret above that decorative text without changing their layout order.
fn (box &BlockBox) chromium_placeholder_paints_before_editor() bool {
	if box.children.len != 2 { return false }
	placeholder := unsafe { &box.children[1] }
	if placeholder.layout_handle == unsafe { nil } { return false }
	node := unsafe { &Node(placeholder.layout_handle) }
	if node.document().font_rendering_policy() != .chromium { return false }
	element := (node.dom_node() or { return false }).as_element() or { return false }
	return element.associated_shadow_host_pseudo_element() or { -1 } == int(css.PseudoElement.placeholder)
}
