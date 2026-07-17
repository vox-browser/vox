module layout

import dom

// dom <-> layout bridge. The DOM keeps a per-node `dom.LayoutNode` placeholder (node.layout_node()); the
// layout tree is the real thing (layout.Node) but dom can't name it (dom can't import layout). After
// laying out, walk the layout tree and populate + attach a placeholder onto each DOM node, mirroring the
// layout node's data (dom_node / parent / is_anonymous / is_text_node / display) and stashing an opaque
// handle to the real layout.Node. This retires the DOM's Layout::Node boundary stubs.

// Attach populated LayoutNode placeholders onto the DOM for the laid-out tree rooted at `root_box`.
pub fn attach_layout_nodes(root_box &Node) {
	attach_layout_node_recursive(root_box, none)
}

fn attach_layout_node_recursive(box &Node, parent_placeholder ?&dom.LayoutNode) {
	placeholder := &dom.LayoutNode{
		dom_node_:     box.dom_node()
		parent_:       parent_placeholder
		is_anonymous_: box.is_anonymous()
		is_text_node_: box.is_text_node()
		display_:      layout_node_display(box)
		layout_handle: voidptr(box)
	}
	if dom_node := box.dom_node() {
		mut mutable_dom_node := unsafe { &dom.Node(dom_node) }
		mutable_dom_node.set_layout_node(placeholder)
	}
	for child in box.children() {
		attach_layout_node_recursive(child, placeholder)
	}
}

// The layout node's computed display as the DOM-side CSSDisplay_ (mirrored from CSS::Display, like the
// css computed-properties bridge). Anonymous boxes (no NodeWithStyle) get the empty default.
fn layout_node_display(box &Node) dom.CSSDisplay_ {
	node_with_style := box.as_node_with_style() or { return dom.CSSDisplay_{} }
	display := node_with_style.computed_values().display()
	return dom.CSSDisplay_{
		is_none_:           display.is_none()
		is_list_item_:      display.is_list_item()
		is_contents_:       display.is_contents()
		is_inline_outside_: display.is_inline_outside()
		is_flow_inside_:    display.is_flow_inside()
	}
}
