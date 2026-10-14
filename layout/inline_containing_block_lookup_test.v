module layout

import html

fn inline_lookup_node_with_id(root &Node, id string) &Node {
	return inline_lookup_find_id(root, id) or { panic('missing #${id}') }
}

fn inline_lookup_find_id(root &Node, id string) ?&Node {
	if node := root.dom_node() {
		if element := node.as_element() {
			if element.get_attribute_value('id') == id {
				return root
			}
		}
	}
	for child in root.children() {
		if found := inline_lookup_find_id(child, id) {
			return found
		}
	}
	return none
}

fn test_inline_lookup_uses_first_continuation_in_current_viewport_for_subtree_recomputation() {
	document := html.parse_document('<!doctype html><div id="frame" style="position:relative"><span id="inline" style="position:relative">text<div id="absolute" style="position:absolute"></div></span></div>')
	root := build_layout_tree(document) or { panic('missing tree') }
	mut frame := unsafe { &Node(inline_lookup_node_with_id(root, 'frame')) }
	inline := inline_lookup_node_with_id(root, 'inline').as_inline_node() or { panic('missing inline') }
	mut absolute := unsafe { &Node(inline_lookup_node_with_id(root, 'absolute')) }
	element := document.get_element_by_id('inline') or { panic('missing element') }
	mut continuation := InlineNode.new(document, element.as_node(), inline.computed_values())
	frame.prepend_child(unsafe { &Node(continuation) })
	// The absolute box's layout subtree does not contain its DOM inline parent.
	// The lookup must still use the whole current viewport and preserve order.
	recompute_containing_blocks(absolute)
	assert voidptr(absolute.inline_containing_block_if_applicable() or { panic('missing containing block') }) == voidptr(continuation)
	continuation.remove()
	recompute_containing_blocks(absolute)
	assert voidptr(absolute.inline_containing_block_if_applicable() or { panic('missing original inline') }) == voidptr(inline)
}

fn test_inline_lookup_does_not_reuse_dom_handles_from_previous_layout_tree() {
	document := html.parse_document('<!doctype html><span id="inline" style="position:relative"><span id="absolute" style="position:absolute"></span></span>')
	previous := run_document_layout(document, 800, 600) or { panic('missing layout') }
	old_inline := inline_lookup_node_with_id(previous.root, 'inline')
	new_root := build_layout_tree(document) or { panic('missing replacement tree') }
	new_inline := inline_lookup_node_with_id(new_root, 'inline')
	absolute := inline_lookup_node_with_id(new_root, 'absolute')
	assert voidptr(old_inline) != voidptr(new_inline)
	assert voidptr(absolute.inline_containing_block_if_applicable() or { panic('missing new containing block') }) == voidptr(new_inline)
}
