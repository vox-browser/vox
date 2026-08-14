module layout

import dom

// dom <-> layout bridge. The DOM keeps a per-node `dom.LayoutNode` placeholder (node.layout_node()); the
// layout tree is the real thing (layout.Node) but dom can't name it (dom can't import layout). After
// laying out, walk the layout tree and populate + attach a placeholder onto each DOM node, mirroring the
// layout node's data (dom_node / parent / is_anonymous / is_text_node / display) and stashing an opaque
// handle to the real layout.Node. This retires the DOM's Layout::Node boundary stubs.

// Attach populated LayoutNode placeholders onto the DOM for the laid-out tree rooted at `root_box`.
pub fn attach_layout_nodes(root_box &Node) {
	attach_layout_node_recursive(root_box, none, none)
}

pub fn attach_layout_nodes_with_state(root_box &Node, state &LayoutState) {
	attach_layout_node_recursive(root_box, none, state)
}

fn attach_layout_node_recursive(box &Node, parent_placeholder ?&dom.LayoutNode, state ?&LayoutState) {
	mut placeholder := &dom.LayoutNode{
		dom_node_:                 box.dom_node()
		parent_:                   parent_placeholder
		is_anonymous_:             box.is_anonymous()
		is_text_node_:             box.is_text_node()
		display_:                  layout_node_display(box)
		pseudo_element_generator_: box.pseudo_element_generator()
		generated_for_:            box.generated_for_pseudo_element()
		layout_handle:             voidptr(box)
	}
	if layout_state := state {
		if node_with_style := box.as_node_with_style() {
			if used := layout_state.try_get(node_with_style) {
				offset := used.cumulative_offset()
				placeholder.has_geometry_ = true
				placeholder.border_box_ = dom.Rect{
					x:      offset.x().to_double() - used.border_box_left().to_double()
					y:      offset.y().to_double() - used.border_box_top().to_double()
					width:  used.border_box_width().to_double()
					height: used.border_box_height().to_double()
				}
				placeholder.content_width_ = used.content_width().to_double()
				placeholder.content_height_ = used.content_height().to_double()
				placeholder.border_left_ = used.border_left.to_double()
				placeholder.border_top_ = used.border_top.to_double()
				placeholder.padding_left_ = used.padding_left.to_double()
				placeholder.padding_right_ = used.padding_right.to_double()
				placeholder.padding_top_ = used.padding_top.to_double()
				placeholder.padding_bottom_ = used.padding_bottom.to_double()
			}
		}
	}
	if parent := parent_placeholder {
		unsafe {
			parent.children_ << placeholder
		}
	}
	if dom_node := box.dom_node() {
		mut mutable_dom_node := unsafe { &dom.Node(dom_node) }
		mutable_dom_node.set_layout_node(placeholder)
	}
	for child in box.children() {
		attach_layout_node_recursive(child, placeholder, state)
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
