module layout

// A block containing only discarded indentation has no glyphs or line box.
// Decide this before creating the chunk iterator: resolving the font for a
// discarded space can otherwise start an unused web-font download and another
// layout when that download completes. Mixed runs and inline boxes still use
// normal whitespace processing, including their edge metrics.
fn inline_context_has_only_discarded_text(containing_block &BlockContainer) bool {
	node := unsafe { &Node(containing_block) }
	if node.is_list_item_marker_box() || !node.has_children() { return false }
	for child in node.children() {
		text := child.as_text_node() or { return false }
		if text.produces_line_box_fragment_when_empty_ || text.retains_empty_generated_fragment_
			|| text.is_empty_editable_
			|| text.Node.computed_values().white_space_collapse() != .collapse { return false }
		for byte in text.text_for_rendering().bytes() {
			if byte !in [u8(0x09), 0x0a, 0x0d, 0x20] { return false }
		}
	}
	return true
}
