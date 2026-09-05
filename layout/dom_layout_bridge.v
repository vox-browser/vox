module layout

import dom
import css

// dom <-> layout bridge. The DOM keeps a per-node `dom.LayoutNode` placeholder (node.layout_node()); the
// layout tree is the real thing (layout.Node) but dom can't name it (dom can't import layout). After
// laying out, walk the layout tree and populate + attach a placeholder onto each DOM node, mirroring the
// layout node's data (dom_node / parent / is_anonymous / is_text_node / display) and stashing an opaque
// handle to the real layout.Node. This retires the DOM's Layout::Node boundary stubs.

// Attach populated LayoutNode placeholders onto the DOM for the laid-out tree rooted at `root_box`.
pub fn attach_layout_nodes(root_box &Node) &dom.LayoutNode {
	mut placeholders := map[u64]&dom.LayoutNode{}
	return attach_layout_node_recursive(root_box, none, none, mut placeholders)
}

pub fn attach_layout_nodes_with_state(root_box &Node, state &LayoutState) &dom.LayoutNode {
	mut placeholders := map[u64]&dom.LayoutNode{}
	return attach_layout_node_recursive(root_box, none, state, mut placeholders)
}

fn attach_layout_node_recursive(box &Node, parent_placeholder ?&dom.LayoutNode, state ?&LayoutState, mut placeholders map[u64]&dom.LayoutNode) &dom.LayoutNode {
	mut visibility := dom.CSSVisibility_.visible
	mut content_visibility := dom.CSSContentVisibility_.visible
	if styled := box.as_node_with_style() {
		visibility = visibility_to_dom_for_layout(styled.computed_values().visibility())
		content_visibility = content_visibility_to_dom_for_layout(styled.computed_values().content_visibility())
	}
	mut placeholder := &dom.LayoutNode{
		dom_node_: box.dom_node()
		parent_: parent_placeholder
		is_anonymous_: box.is_anonymous()
		is_text_node_: box.is_text_node()
		display_: layout_node_display(box)
		pseudo_element_generator_: box.pseudo_element_generator()
		generated_for_: dom_pseudo_element_for_layout_node(box.generated_for_pseudo_element())
		is_viewport_: box.is_viewport()
		is_positioned_: box.is_positioned()
		is_sticky_position_: box.is_sticky_position()
		is_fixed_position_: box.is_fixed_position()
		is_scroll_container_: box.is_scroll_container()
		establishes_fixed_positioning_containing_block_: box.establishes_a_fixed_positioning_containing_block()
		visibility_: visibility
		content_visibility_: content_visibility
		layout_handle: voidptr(box)
		apply_style_callback: apply_style_to_layout_node
		set_needs_layout_update_callback: set_layout_node_needs_layout_update
	}
	if text_node := box.as_text_node() {
		// DOM::Node::name_or_description() reads TextNode::text_for_rendering()
		// directly. Keep that value separate from the ChunkIterator output used
		// by HTMLElement::rendered_text_collection_steps().
		placeholder.rendered_text_ = text_node.text_for_rendering()
		// HTMLElement::rendered_text_collection_steps consumes TextNode::ChunkIterator with both
		// wrapping and line-break preservation disabled. The chunks, rather than text_for_rendering()
		// itself, apply the remaining collapsible-space processing used by innerText.
		mut iterator := TextNodeChunkIterator.new(text_node, false, false)
		for {
			chunk := iterator.next() or { break }
			placeholder.rendered_text_chunks_ << chunk.view
		}
	}
	placeholders[u64(voidptr(box))] = placeholder
	if containing_block := box.containing_block() {
		if containing_block_placeholder := placeholders[u64(voidptr(containing_block))] {
			placeholder.containing_block_ = containing_block_placeholder
		}
	}
	if layout_state := state {
		if box.is_inline_node() {
			if metrics := layout_debug_inline_metrics(box, layout_state) {
				placeholder.has_geometry_ = true
				placeholder.border_box_ = dom.Rect{
					x: metrics.position.x().to_double()
					y: metrics.position.y().to_double()
					width: metrics.width.to_double()
					height: metrics.height.to_double()
				}
				placeholder.content_width_ = metrics.width.to_double()
				placeholder.content_height_ = metrics.height.to_double()
				if node_with_style := box.as_node_with_style() {
					if used := layout_state.try_get(node_with_style) {
						copy_used_box_model_to_dom_layout_node(mut placeholder, used)
					}
				}
			}
		} else if node_with_style := box.as_node_with_style() {
			if used := layout_state.try_get(node_with_style) {
				offset := paint_cumulative_offset(box, layout_state, used)
				placeholder.has_geometry_ = true
				placeholder.border_box_ = dom.Rect{
					x: offset.x().to_double() - used.border_box_left().to_double()
					y: offset.y().to_double() - used.border_box_top().to_double()
					width: used.border_box_width().to_double()
					height: used.border_box_height().to_double()
				}
				placeholder.content_width_ = used.content_width().to_double()
				placeholder.content_height_ = used.content_height().to_double()
				copy_used_box_model_to_dom_layout_node(mut placeholder, used)
			}
		}
		materialize_dom_paintables(box, layout_state, mut placeholder)
	}
	if parent := parent_placeholder {
		unsafe {
			parent.children_ << placeholder
		}
	}
	if dom_node := box.dom_node() {
		// A DOM element has one primary layout node. Inline continuations carry
		// the same DOM node but point back to that primary node.
		is_continuation := if metrics := box.as_node_with_style_and_box_model_metrics() {
			metrics.continuation_of_node() != none
		} else {
			false
		}
		if !is_continuation {
			mut mutable_dom_node := unsafe { &dom.Node(dom_node) }
			mutable_dom_node.set_layout_node(placeholder)
		}
	}
	for child in box.children() {
		attach_layout_node_recursive(child, placeholder, state, mut placeholders)
	}
	return placeholder
}

// LayoutState::commit() creates each Layout::Node's paintables, transfers the
// visibility/scroll/stacking state required by DOM, and makes the last one the
// DOM node's primary paintable. Painting's renderer-independent objects are
// retained elsewhere; these wrappers are the cycle boundary consumed by DOM.
fn materialize_dom_paintables(box &Node, state &LayoutState, mut placeholder dom.LayoutNode) {
	if dom_node := box.dom_node() {
		mut mutable_dom_node := unsafe { &dom.Node(dom_node) }
		mutable_dom_node.clear_paintable()
	}
	count := layout_debug_paintable_count(box, state)
	for _ in 0 .. count {
		class_name := layout_debug_paintable_class(box)
		mut paintable := &dom.Paintable{
			layout_handle: voidptr(box)
		}
		if layout_debug_paintable_is_box(class_name) {
			mut paintable_box := &dom.PaintableBox{
				layout_handle: voidptr(box)
				dom_node_: box.dom_node() or { unsafe { nil } }
			}
			paintable_box.is_box = true
			paintable_box.visible = placeholder.visibility_ == .visible
				&& placeholder.content_visibility_ != .hidden
			paintable_box.scrollable = box.is_scroll_container()
			paintable_box.stacking_context = box.establishes_stacking_context()
			if styled := box.as_node_with_style() {
				if used := state.try_get(styled) {
					paintable_box.has_scrollable_overflow_ = used.has_scrollable_overflow()
					paintable_box.padding_box_width_ = used.content_width().to_double() + used.padding_left.to_double() + used.padding_right.to_double()
					paintable_box.padding_box_height_ = used.content_height().to_double() + used.padding_top.to_double() + used.padding_bottom.to_double()
					if overflow := used.scrollable_overflow_rect() {
						computed := styled.computed_values()
						paintable_box.wheel_scrolls_horizontal_ = computed.overflow_x() in [
							.auto_,
							.scroll,
						]
							&& overflow.width.to_double() > paintable_box.padding_box_width_
						paintable_box.wheel_scrolls_vertical_ = computed.overflow_y() in [
							.auto_,
							.scroll,
						]
							&& overflow.height.to_double() > paintable_box.padding_box_height_
						paintable_box.scrollable_overflow_rect_ = dom.CSSPixelRect_{
							x_: overflow.x.to_double()
							y_: overflow.y.to_double()
							width_: overflow.width.to_double()
							height_: overflow.height.to_double()
						}
					}
				}
			}
			paintable = unsafe { &dom.Paintable(paintable_box) }
		}
		placeholder.paintables_ << paintable
		if dom_node := box.dom_node() {
			mut mutable_dom_node := unsafe { &dom.Node(dom_node) }
			mutable_dom_node.set_paintable(paintable)
		}
	}
}

fn apply_style_to_layout_node(layout_handle voidptr, css_computed_properties_handle voidptr) {
	if layout_handle == unsafe { nil } || css_computed_properties_handle == unsafe { nil } {
		return
	}
	node := unsafe { &Node(layout_handle) }
	styled := node.as_node_with_style() or { return }
	computed := unsafe { &css.ComputedProperties(css_computed_properties_handle) }
	mut mutable_styled := unsafe { &NodeWithStyle(styled) }
	mutable_styled.apply_style(computed)
}

fn set_layout_node_needs_layout_update(layout_handle voidptr, needs_layout_update bool) {
	if layout_handle == unsafe { nil } {
		return
	}
	mut node := unsafe { &Node(layout_handle) }
	node.set_needs_layout_update(needs_layout_update)
}

// Mirror LayoutState::UsedValues onto DOM's module-cycle boundary object. CSSOM's
// resolved-value algorithm consumes exactly these used box-model values, just as
// CSSStyleProperties.cpp reads them from Painting::PaintableBox::box_model().
fn copy_used_box_model_to_dom_layout_node(mut placeholder dom.LayoutNode, used &UsedValues) {
	placeholder.margin_left_ = used.margin_left.to_double()
	placeholder.margin_right_ = used.margin_right.to_double()
	placeholder.margin_top_ = used.margin_top.to_double()
	placeholder.margin_bottom_ = used.margin_bottom.to_double()
	placeholder.border_left_ = used.border_left.to_double()
	placeholder.border_right_ = used.border_right.to_double()
	placeholder.border_top_ = used.border_top.to_double()
	placeholder.border_bottom_ = used.border_bottom.to_double()
	placeholder.padding_left_ = used.padding_left.to_double()
	placeholder.padding_right_ = used.padding_right.to_double()
	placeholder.padding_top_ = used.padding_top.to_double()
	placeholder.padding_bottom_ = used.padding_bottom.to_double()
	placeholder.inset_left_ = used.inset_left.to_double()
	placeholder.inset_right_ = used.inset_right.to_double()
	placeholder.inset_top_ = used.inset_top.to_double()
	placeholder.inset_bottom_ = used.inset_bottom.to_double()
}

fn dom_pseudo_element_for_layout_node(pseudo_element ?css.PseudoElement) ?dom.PseudoElement {
	type_ := pseudo_element or { return none }
	return match type_ {
		.before { dom.PseudoElement.before }
		.after { dom.PseudoElement.after }
		.first_line { dom.PseudoElement.first_line }
		.first_letter { dom.PseudoElement.first_letter }
		.marker { dom.PseudoElement.marker }
		.placeholder { dom.PseudoElement.placeholder }
		.selection { dom.PseudoElement.selection }
		.backdrop { dom.PseudoElement.backdrop }
		else { none }
	}
}

// The layout node's computed display as the DOM-side CSSDisplay_ (mirrored from CSS::Display, like the
// css computed-properties bridge). Anonymous boxes (no NodeWithStyle) get the empty default.
fn layout_node_display(box &Node) dom.CSSDisplay_ {
	node_with_style := box.as_node_with_style() or { return dom.CSSDisplay_{} }
	display := node_with_style.computed_values().display()
	return dom.CSSDisplay_{
		is_none_: display.is_none()
		is_list_item_: display.is_list_item()
		is_contents_: display.is_contents()
		is_inline_outside_: display.is_inline_outside()
		is_flow_inside_: display.is_flow_inside()
		is_block_outside_: display.is_block_outside()
		is_table_caption_: display.is_table_caption()
		is_table_cell_: display.is_table_cell()
		is_table_row_: display.is_table_row()
	}
}

fn visibility_to_dom_for_layout(value css.Visibility) dom.CSSVisibility_ {
	return match value {
		.visible { .visible }
		.hidden { .hidden }
		.collapse { .collapse }
	}
}

fn content_visibility_to_dom_for_layout(value css.ContentVisibility) dom.CSSContentVisibility_ {
	return match value {
		.visible { .visible }
		.hidden { .hidden }
		.auto_ { .auto_ }
	}
}
