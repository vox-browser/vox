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

// Blink's BlockLayoutAlgorithm::HandleTextControlPlaceholder() places the
// placeholder so its first baseline matches the editor's. The editor's line
// floors its ascent-side leading, so centering both lines in the control left
// a shorter placeholder line half a pixel low: GitHub's "Go to file" placeholder
// in a 20px line painted one pixel below Brave's.
fn chromium_align_text_control_placeholder(mut state LayoutState, container &Node) {
	if container.document().font_rendering_policy() != .chromium { return }
	children := container.children()
	if children.len != 2 { return }
	// The editor and its overlaid placeholder are the only children of the
	// control's text container; number controls nest it beside the steppers.
	parent := container.parent() or { return }
	if !parent.is_text_input_box() {
		grandparent := parent.parent() or { return }
		if !grandparent.is_text_input_box() { return }
	}
	editor := children[0]
	placeholder := children[1]
	editor_styled := editor.as_node_with_style() or { return }
	placeholder_styled := placeholder.as_node_with_style() or { return }
	editor_used := state.get(editor_styled)
	if editor_used.line_boxes.len == 0 { return }
	editor_top := editor_used.offset.y().minus(editor_used.margin_box_top())
	baseline := editor_top.plus(layout_box_baseline(state, editor, .first))
	placeholder_baseline := layout_box_baseline(state, placeholder, .first)
	mut placeholder_used := state.get_mutable(placeholder_styled)
	placeholder_used.set_content_y(baseline.minus(placeholder_baseline).plus(placeholder_used.margin_box_top()))
}
